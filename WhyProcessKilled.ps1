<#
.SYNOPSIS
    Диагностика причин закрытия Excel для конкретного пользователя и проверка на завершение администратором.
.DESCRIPTION
    Анализирует журналы событий Application, System и Security.
    Ищет ошибки Excel, а также события создания/завершения процесса EXCEL.EXE
    для указанного пользователя, чтобы определить, кто завершил процесс.
.PARAMETER UserName
    Имя пользователя, для которого проверяем (по умолчанию 'oaazarenok').
.PARAMETER Hours
    Период анализа в часах от текущего момента (по умолчанию 24).
.PARAMETER ShowAllEvents
    Если указан, показываются все события Excel (не только ошибки) из Application и System.
.EXAMPLE
    .\Check-ExcelTermination.ps1 -UserName oaazarenok -Hours 48
    Анализ за последние 48 часов для пользователя oaazarenok.
#>

param(
    [string]$UserName = "oaazarenok",
    [int]$Hours = 24,
    [switch]$ShowAllEvents
)

$endTime = Get-Date
$startTime = $endTime.AddHours(-$Hours)

Write-Host "Анализ событий с $startTime по $endTime для пользователя '$UserName'" -ForegroundColor Cyan

# --- Вспомогательная функция проверки, связано ли событие с Excel ---
function IsExcelEvent($evt) {
    $msg = $evt.Message
    if ($msg -match "EXCEL\.EXE" -or $msg -match "Microsoft Excel" -or $evt.ProviderName -match "Excel") {
        return $true
    }
    if ($evt.Id -in @(1000, 1001, 1005, 1026) -and $msg -match "EXCEL\.EXE") {
        return $true
    }
    return $false
}

# --- Сбор ошибок Excel из Application и System (как в первой версии) ---
$logNames = @("Application", "System")
$errorEvents = @()

foreach ($log in $logNames) {
    try {
        Write-Host "Проверка журнала: $log" -ForegroundColor Yellow
        $filter = @{
            LogName   = $log
            StartTime = $startTime
            EndTime   = $endTime
        }
        if (-not $ShowAllEvents) {
            $filter.Level = 1, 2   # Критический, Ошибка
        }

        $logEvents = Get-WinEvent -FilterHashtable $filter -ErrorAction Stop
        foreach ($evt in $logEvents) {
            if (IsExcelEvent $evt) {
                $errorEvents += $evt
            }
        }
    } catch {
        Write-Warning "Не удалось прочитать журнал $log : $_"
    }
}

if ($errorEvents.Count -gt 0) {
    Write-Host "`n--- События ошибок, связанные с Excel ---" -ForegroundColor Cyan
    $errorEvents = $errorEvents | Sort-Object TimeCreated
    foreach ($evt in $errorEvents) {
        Write-Host "Время: $($evt.TimeCreated) | ID: $($evt.Id) | Источник: $($evt.ProviderName)" -ForegroundColor Magenta
        Write-Host "Сообщение: $($evt.Message)" -ForegroundColor Gray
        if ($evt.Id -eq 1000 -or $evt.Id -eq 1001) {
            if ($evt.Message -match "код исключения:\s*(0x[0-9a-fA-F]+)") {
                Write-Host "Код исключения: $($matches[1])" -ForegroundColor Red
            }
            if ($evt.Message -match "имя сбойного модуля:\s*([^\s]+)") {
                Write-Host "Сбойный модуль: $($matches[1])" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "`nНе найдено событий ошибок Excel за указанный период." -ForegroundColor Green
}

# --- Анализ завершения процесса из Security log ---
Write-Host "`n--- Проверка журнала безопасности (завершение процессов) ---" -ForegroundColor Cyan

try {
    # Сначала ищем все события создания процесса Excel пользователем UserName
    $filterCreate = @{
        LogName   = "Security"
        ID        = 4688
        StartTime = $startTime
        EndTime   = $endTime
    }
    $createEvents = Get-WinEvent -FilterHashtable $filterCreate -ErrorAction Stop

    # Отбираем те, где процесс - Excel и создан нужным пользователем
    $excelProcesses = @{}
    foreach ($evt in $createEvents) {
        $message = $evt.Message
        if ($message -match "Process Name:\s*.*EXCEL\.EXE" -and $message -match "Account Name:\s*$UserName") {
            # Извлекаем Process ID
            if ($message -match "New Process ID:\s*(0x[0-9a-fA-F]+)") {
                $pidHex = $matches[1]
                $pidDec = [Convert]::ToInt32($pidHex, 16)
                $excelProcesses[$pidDec] = $evt   # сохраняем событие создания по PID
                Write-Host "Найден запуск Excel (PID: $pidDec) пользователем $UserName в $($evt.TimeCreated)" -ForegroundColor Yellow
            }
        }
    }

    if ($excelProcesses.Count -eq 0) {
        Write-Host "Не найдено записей о запуске Excel пользователем $UserName за указанный период." -ForegroundColor Green
    } else {
        # Теперь ищем события завершения процессов (4689) с этими PID
        $filterTerminate = @{
            LogName   = "Security"
            ID        = 4689
            StartTime = $startTime
            EndTime   = $endTime
        }
        $termEvents = Get-WinEvent -FilterHashtable $filterTerminate -ErrorAction Stop

        foreach ($evt in $termEvents) {
            $message = $evt.Message
            # Извлекаем PID завершённого процесса
            if ($message -match "Process ID:\s*(0x[0-9a-fA-F]+)") {
                $pidHex = $matches[1]
                $pidDec = [Convert]::ToInt32($pidHex, 16)
                if ($excelProcesses.ContainsKey($pidDec)) {
                    # Это завершение нашего Excel
                    Write-Host "`nПроцесс Excel (PID: $pidDec) был завершён." -ForegroundColor Magenta
                    Write-Host "Время завершения: $($evt.TimeCreated)"
                    # Кто завершил (Subject)
                    if ($message -match "Account Name:\s*([^\r\n]+)") {
                        $terminator = $matches[1].Trim()
                        Write-Host "Завершил процесс: $terminator" -ForegroundColor Cyan
                        if ($terminator -ne $UserName) {
                            Write-Host "ВНИМАНИЕ: Процесс завершён не пользователем $UserName, возможно администратором!" -ForegroundColor Red
                        } else {
                            Write-Host "Процесс завершён самим пользователем $UserName (штатно или через диспетчер)." -ForegroundColor Green
                        }
                    }
                    # Дополнительно: статус завершения (Exit Status)
                    if ($message -match "Exit Status:\s*(0x[0-9a-fA-F]+)") {
                        Write-Host "Код завершения: $($matches[1])" -ForegroundColor Gray
                    }
                }
            }
        }
    }
} catch {
    Write-Warning "Не удалось обработать журнал Security. Убедитесь, что скрипт запущен от имени администратора и аудит процессов включён. Ошибка: $_"
}

# --- Дополнительно: папка отчётов WER (если есть) ---
$werFolder = "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive"
if (Test-Path $werFolder) {
    $reports = Get-ChildItem $werFolder -Directory |
               Where-Object { $_.Name -like "*Excel*" -or $_.Name -like "*EXCEL*" } |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 5
    if ($reports) {
        Write-Host "`nПоследние отчёты об ошибках Excel в папке WER:" -ForegroundColor Cyan
        $reports | ForEach-Object { Write-Host $_.FullName -ForegroundColor Gray }
    }
}

Write-Host "`nАнализ завершён." -ForegroundColor Cyan