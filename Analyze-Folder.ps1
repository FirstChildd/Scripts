#.\Analyze-Folder.ps1 -FolderPath "C:\полный\путь\к\папке" чтобы запустить скрипт в ps от Админа

param(
    [Parameter(Mandatory=$true)]
    [string]$FolderPath
)

# Проверка существования папки
if (-not (Test-Path $FolderPath -PathType Container)) {
    Write-Error "Папка '$FolderPath' не существует или это не папка."
    exit 1
}

# Функция для определения создателя папки
function Get-FolderCreator {
    param(
        [string]$Path,
        [datetime]$CreationTime
    )

    $creatorInfo = @{
        Owner = $null
        EventUser = $null
        RDPUser = $null
        MostLikely = $null
    }

    # 1. Владелец
    try {
        $acl = Get-Acl -Path $Path -ErrorAction Stop
        $creatorInfo.Owner = $acl.Owner
    } catch {
        $creatorInfo.Owner = "Не удалось определить владельца"
    }

    # 2. Поиск событий создания в журнале безопасности (Event ID 4663 с правами на создание)
    $startSearch = $CreationTime.AddSeconds(-5)
    $endSearch = $CreationTime.AddSeconds(5)

    try {
        # Ищем события 4663 (доступ к объекту) за узкий интервал
        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4663
            StartTime = $startSearch
            EndTime = $endSearch
        } -ErrorAction SilentlyContinue

        # Фильтруем только те, где путь совпадает с нашей папкой и есть признак создания
        foreach ($evt in $events) {
            $msg = $evt.Message
            # Проверяем, что событие относится к нашей папке
            if ($msg -match [regex]::Escape($Path)) {
                # Ищем Access Mask или права на создание
                # В сообщении может быть "CreateFile" или "CreateDirectory"
                if ($msg -match "CreateFile|CreateDirectory|WriteData|AppendData") {
                    # Извлекаем имя учётной записи
                    if ($msg -match 'Account Name:\s+(\S+)') {
                        $creatorInfo.EventUser = $matches[1]
                        break # берём первое подходящее
                    }
                }
            }
        }
    } catch {
        # Игнорируем ошибки (аудит может быть не включён)
    }

    # 3. Поиск активных RDP-сессий в тот же интервал (пользователи, которые могли создать папку)
    try {
        $rdpEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4624, 4648
            StartTime = $startSearch
            EndTime = $endSearch
        } -ErrorAction SilentlyContinue

        $rdpUsers = @()
        foreach ($evt in $rdpEvents) {
            $msg = $evt.Message
            # Проверяем, что это RDP-вход (Logon Type = 10)
            if ($msg -match 'Logon Type:\s+10') {
                if ($msg -match 'Account Name:\s+(\S+)') {
                    $rdpUsers += $matches[1]
                }
            }
        }
        $creatorInfo.RDPUser = $rdpUsers -join ", "
    } catch {
        $creatorInfo.RDPUser = "Не найдено"
    }

    # Определяем наиболее вероятного создателя
    if ($creatorInfo.EventUser) {
        $creatorInfo.MostLikely = "По событиям безопасности: $($creatorInfo.EventUser)"
    } elseif ($creatorInfo.RDPUser) {
        $creatorInfo.MostLikely = "Вероятно, пользователь RDP-сессии: $($creatorInfo.RDPUser)"
    } else {
        $creatorInfo.MostLikely = "По владельцу: $($creatorInfo.Owner)"
    }

    return $creatorInfo
}

Write-Host "=== Анализ папки: $FolderPath ===" -ForegroundColor Cyan

# Получаем базовую информацию о папке
$folder = Get-Item -Path $FolderPath
$acl = Get-Acl -Path $FolderPath
$created = $folder.CreationTime
$lastWrite = $folder.LastWriteTime
$lastAccess = $folder.LastAccessTime

# Определяем создателя
$creator = Get-FolderCreator -Path $FolderPath -CreationTime $created

Write-Host "`n--- Кто создал папку ---" -ForegroundColor Green
Write-Host "Владелец (из ACL):         $($creator.Owner)" -ForegroundColor Yellow
if ($creator.EventUser) {
    Write-Host "Событие создания (4663):    $($creator.EventUser)" -ForegroundColor Yellow
} else {
    Write-Host "Событие создания (4663):    не найдено (аудит может быть выключен)" -ForegroundColor Gray
}
if ($creator.RDPUser -and $creator.RDPUser -ne "Не найдено") {
    Write-Host "Активные RDP-сессии в момент создания: $($creator.RDPUser)" -ForegroundColor Yellow
} else {
    Write-Host "Активные RDP-сессии в момент создания: не обнаружено" -ForegroundColor Gray
}
Write-Host "`nНаиболее вероятный создатель: $($creator.MostLikely)" -ForegroundColor Green

# Далее остальная информация (время, права, события)
Write-Host "`n--- Временные метки ---" -ForegroundColor Green
Write-Host "Создано:          $created" -ForegroundColor Yellow
Write-Host "Изменено:         $lastWrite" -ForegroundColor Yellow
Write-Host "Последний доступ: $lastAccess" -ForegroundColor Yellow

Write-Host "`n--- Права доступа (разрешения) ---" -ForegroundColor Green
$acl.Access | ForEach-Object {
    Write-Host "$($_.IdentityReference) : $($_.FileSystemRights)"
}

# Поиск дополнительных событий аудита (оставлено как в исходном скрипте)
Write-Host "`n--- Поиск событий в журнале безопасности (Event ID 4663, 4660) ---" -ForegroundColor Green
$startTime = $created.AddMinutes(-5)
$endTime = $created.AddMinutes(5)

try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        ID = 4663, 4660
        StartTime = $startTime
        EndTime = $endTime
        Data = $FolderPath
    } -ErrorAction Stop

    if ($events.Count -gt 0) {
        Write-Host "Найдено событий: $($events.Count)" -ForegroundColor Yellow
        foreach ($evt in $events) {
            $time = $evt.TimeCreated
            Write-Host "$time - EventID $($evt.Id)" -ForegroundColor White
            if ($evt.Message -match 'Account Name:\s+(\S+)') {
                Write-Host "   Пользователь: $($matches[1])" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "События не найдены." -ForegroundColor Red
    }
} catch {
    Write-Host "Не удалось прочитать журнал безопасности: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Анализ завершён ===" -ForegroundColor Cyan