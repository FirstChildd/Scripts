<#
.SYNOPSIS
    Собирает все события безопасности, связанные с административной активностью указанного пользователя,
    включая управление учётными записями и, опционально, файловые операции (создание/изменение файлов) в заданных папках.
.DESCRIPTION
    Анализирует журнал Security и находит события, в которых фигурирует указанный пользователь:
    - Специальные входы (4672)
    - Создание/удаление/изменение пользователей и групп (4720-4799)
    - Изменение политик и привилегий (4719, 4900-4956)
    - Запуск процессов (4688) – опционально
    - Доступ к объектам (4663) – опционально, с фильтрацией по пути и типу операции
    - Создание заданий планировщика (4698-4702)
    - И другие (полный список см. в коде)
.PARAMETER UserName
    Имя пользователя (можно с доменом). Поиск выполняется по всем полям (субъект/объект).
.PARAMETER Days
    Глубина анализа в днях (по умолчанию 7).
.PARAMETER IncludeProcessCreation
    Включать события создания процессов (Event 4688) – может быть много.
.PARAMETER TrackFileOperations
    Включать события доступа к объектам (Event 4663) и фильтровать их по типам операций создания/записи.
    Без указания TargetPaths будет искать по всей системе (очень много!).
.PARAMETER TargetPaths
    Массив путей для фильтрации событий 4663 (например, "C:\Users\*", "D:\Shared"). Поддерживает маску *.
    Работает только вместе с -TrackFileOperations.
.PARAMETER ExportCSV
    Экспортировать результаты в CSV.
.EXAMPLE
    # Все админские действия пользователя Ivanov за 30 дней
    .\Get-AdminActions.ps1 -UserName "Ivanov" -Days 30

    # Добавить отслеживание создания/изменения файлов в профилях пользователей
    .\Get-AdminActions.ps1 -UserName "Petrov" -TrackFileOperations -TargetPaths "C:\Users\*"

    # С отслеживанием процессов и экспортом
    .\Get-AdminActions.ps1 -UserName "Admin" -IncludeProcessCreation -ExportCSV
.NOTES
    Требуются права администратора. Для событий 4663 необходимо предварительно включить аудит на целевых папках
    (через свойства безопасности → Дополнительно → Аудит) и соответствующие подкатегории аудита.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$UserName,

    [int]$Days = 7,

    [switch]$IncludeProcessCreation,

    [switch]$TrackFileOperations,

    [string[]]$TargetPaths,

    [switch]$ExportCSV
)

# Проверка прав администратора
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ошибка: Скрипт должен быть запущен от имени администратора!" -ForegroundColor Red
    exit 1
}

Write-Host "=== Поиск административных действий пользователя '$UserName' за последние $Days дней ===" -ForegroundColor Cyan
if ($TrackFileOperations) {
    if ($TargetPaths) {
        Write-Host "Включено отслеживание файловых операций в папках: $($TargetPaths -join ', ')" -ForegroundColor Yellow
    } else {
        Write-Host "Включено отслеживание файловых операций по всей системе (может быть ОЧЕНЬ МНОГО событий)!" -ForegroundColor Red
    }
}

$startDate = (Get-Date).AddDays(-$Days)
$endDate = Get-Date

# Базовый список событий, связанных с администрированием
$adminEventIDs = @(
    4672,   # Special Logon
    4720,   # Создание пользователя
    4722,   # Пользователь включён
    4723,   # Попытка смены пароля (своей учётки)
    4724,   # Попытка сброса пароля другого пользователя
    4725,   # Пользователь отключён
    4726,   # Пользователь удалён
    4732,   # Пользователь добавлен в группу
    4733,   # Пользователь удалён из группы
    4735,   # Изменена локальная группа
    4738,   # Изменён объект пользователя
    4740,   # Учётная запись заблокирована
    4756,   # Пользователь добавлен в универсальную группу
    4767,   # Учётная запись разблокирована
    4781,   # Изменено имя учётной записи
    4794,   # Попытка задания каталога восстановления DSRM
    4798,   # Перечисление групп пользователя
    4799,   # Перечисление членов локальной группы
    5136,   # Изменён объект каталога (AD)
    5140,   # Сетевой доступ к объекту (например, SMB)
    5156,   # Соединение разрешено (Windows Filtering Platform)
    5158,   # Привязка к порту
    4698,   # Создание задания планировщика
    4699,   # Удаление задания планировщика
    4700,   # Включение задания планировщика
    4701,   # Отключение задания планировщика
    4702,   # Обновление задания планировщика
    4719,   # Изменена политика аудита
    4902,   # Изменена политика аудита PNP
    4904,   # Попытка регистрации источника событий
    4905,   # Попытка отмены регистрации источника событий
    4906,   # Значение CrashOnAuditFail изменено
    4907,   # Изменены параметры аудита объекта
    4946,   # Правило добавлено в политику Windows Firewall
    4947,   # Правило изменено
    4948,   # Правило удалено
    4950,   # Изменены настройки Windows Firewall
    4956,   # Изменён активный профиль Windows Firewall
    5024,   # Запуск службы безопасности
    5025,   # Остановка службы безопасности
    5030,   # Ошибка службы безопасности
    5038,   # Несоответствие целостности кода
    5120,   # OCSP Responder Service started
    5379,   # Учётные данные прочитаны
    5382    # Vault credentials read
)

# Если запрошены процессы, добавляем 4688
if ($IncludeProcessCreation) {
    $adminEventIDs += 4688
    Write-Host "Включён поиск событий создания процессов (Event 4688)." -ForegroundColor Yellow
}

# Если запрошены файловые операции, добавляем 4663
if ($TrackFileOperations) {
    $adminEventIDs += 4663
}

# Формируем XPath для выборки всех этих событий
$xPath = "*[System["
$conditions = foreach ($id in $adminEventIDs) {
    "EventID=$id"
}
$xPath += ($conditions -join " or ")
$xPath += "]]"

Write-Host "`nВыполняется поиск по $($adminEventIDs.Count) типам событий..." -ForegroundColor Gray

try {
    $events = Get-WinEvent -LogName 'Security' -FilterXPath $xPath -ErrorAction Stop | 
              Where-Object { $_.TimeCreated -ge $startDate -and $_.TimeCreated -le $endDate }
    
    Write-Host "Всего событий для фильтрации: $($events.Count)" -ForegroundColor Gray
    
    $results = @()
    $count = 0
    $total = $events.Count
    $lastPercent = -1

    foreach ($event in $events) {
        $count++
        $percent = [int](($count / $total) * 100)
        if ($percent -ge $lastPercent + 5) {
            Write-Progress -Activity "Обработка событий" -Status "Обработано $count из $total ($percent%)" -PercentComplete $percent
            $lastPercent = $percent
        }

        $eventXml = [xml]$event.ToXml()
        
        # --- Проверка, относится ли событие к нашему пользователю ---
        $userFields = @('TargetUserName', 'SubjectUserName', 'AccountName', 'MemberName', 'ObjectName')
        $foundUser = $false
        $matchedField = ""
        
        foreach ($field in $userFields) {
            $value = $eventXml.Event.EventData.Data | Where-Object { $_.Name -eq $field } | Select-Object -ExpandProperty '#text'
            if ($value -and ($value -like "*$UserName*" -or $value.Split('\')[-1] -eq $UserName)) {
                $foundUser = $true
                $matchedField = $field
                break
            }
        }
        
        if (-not $foundUser) {
            $msg = $event.Message
            if ($msg -match $UserName) {
                $foundUser = $true
                $matchedField = "Message"
            }
        }

        if (-not $foundUser) { continue }

        # --- Дополнительная фильтрация для событий 4663 (файловый доступ) ---
        if ($event.Id -eq 4663 -and $TrackFileOperations) {
            # Извлекаем имя объекта (путь к файлу/папке)
            $objectName = $eventXml.Event.EventData.Data | Where-Object { $_.Name -eq "ObjectName" } | Select-Object -ExpandProperty '#text'
            $accessMask = $eventXml.Event.EventData.Data | Where-Object { $_.Name -eq "AccessMask" } | Select-Object -ExpandProperty '#text'
            $accessList = $eventXml.Event.EventData.Data | Where-Object { $_.Name -eq "AccessList" } | Select-Object -ExpandProperty '#text'

            # Определяем, является ли операция созданием/записью (примерные маски и строки)
            $isWriteOperation = $false
            if ($accessList -match 'CreateFile|WriteData|AppendData|AddFile') {
                $isWriteOperation = $true
            }
            # Можно также проверять AccessMask (0x2 - WriteData, 0x6 - AppendData и т.д.)
            
            if (-not $isWriteOperation) {
                continue   # Пропускаем операции чтения/удаления/др.
            }

            # Фильтрация по пути (если указаны TargetPaths)
            if ($TargetPaths -and $TargetPaths.Count -gt 0) {
                $pathMatched = $false
                foreach ($pattern in $TargetPaths) {
                    # Проверяем, соответствует ли ObjectName шаблону (с учётом маски *)
                    if ($objectName -like $pattern) {
                        $pathMatched = $true
                        break
                    }
                }
                if (-not $pathMatched) {
                    continue
                }
            }
        }

        # --- Определение категории действия ---
        $category = switch ($event.Id) {
            4672 { "Special Logon" }
            4688 { "Process Creation" }
            4720 { "User Creation" }
            4722 { "User Enabled" }
            4723 { "Password Change (own)" }
            4724 { "Password Reset (other)" }
            4725 { "User Disabled" }
            4726 { "User Deleted" }
            4732 { "Added to Group" }
            4733 { "Removed from Group" }
            4735 { "Group Changed" }
            4738 { "User Changed" }
            4740 { "Account Locked" }
            4756 { "Added to Universal Group" }
            4767 { "Account Unlocked" }
            4781 { "Account Renamed" }
            4794 { "DSRM Restore" }
            4798 { "Group Enumerated" }
            4799 { "Local Group Members Enumerated" }
            5136 { "AD Object Modified" }
            5140 { "Network Share Access" }
            5156 { "WFP Connection Allowed" }
            5158 { "Port Binding" }
            4663 { "File/Registry Access (Write)" }  # теперь только операции записи
            4698 { "Task Created" }
            4699 { "Task Deleted" }
            4700 { "Task Enabled" }
            4701 { "Task Disabled" }
            4702 { "Task Updated" }
            4719 { "Audit Policy Changed" }
            4902 { "PNP Audit Policy Changed" }
            4904 { "Event Source Registered" }
            4905 { "Event Source Unregistered" }
            4906 { "CrashOnAuditFail Changed" }
            4907 { "Object Audit Settings Changed" }
            4946 { "Firewall Rule Added" }
            4947 { "Firewall Rule Changed" }
            4948 { "Firewall Rule Deleted" }
            4950 { "Firewall Settings Changed" }
            4956 { "Firewall Profile Changed" }
            5024 { "Security Service Started" }
            5025 { "Security Service Stopped" }
            5030 { "Security Service Error" }
            5038 { "Code Integrity Error" }
            5120 { "OCSP Service Started" }
            5379 { "Credentials Read" }
            5382 { "Vault Credentials Read" }
            default { "Other Admin Action ($($event.Id))" }
        }

        # --- Извлечение IP и объекта ---
        $ip = ""
        $ipFields = @('IpAddress', 'ClientAddress', 'SourceAddress')
        foreach ($f in $ipFields) {
            $val = $eventXml.Event.EventData.Data | Where-Object { $_.Name -eq $f } | Select-Object -ExpandProperty '#text'
            if ($val -and $val -ne '-') {
                $ip = $val
                break
            }
        }
        if (-not $ip) { $ip = "N/A" }

        $object = ""
        $objFields = @('ObjectName', 'ProcessName', 'ServiceName', 'ShareName')
        foreach ($f in $objFields) {
            $val = $eventXml.Event.EventData.Data | Where-Object { $_.Name -eq $f } | Select-Object -ExpandProperty '#text'
            if ($val) {
                $object = $val
                break
            }
        }
        if (-not $object) { $object = "-" }

        $results += [PSCustomObject]@{
            Time = $event.TimeCreated
            EventID = $event.Id
            Category = $category
            User = $UserName   # Запоминаем, по кому искали
            SourceIP = $ip
            Object = $object
            RecordID = $event.RecordId
            FullMessage = $event.Message
        }
    }

    Write-Progress -Activity "Обработка событий" -Completed

    if ($results.Count -eq 0) {
        Write-Host "`nНе найдено событий для пользователя '$UserName'." -ForegroundColor Red
        Write-Host "Возможно, аудит отключён или пользователь не выполнял таких действий." -ForegroundColor Yellow
        exit
    }

    # Сортируем по времени
    $results = $results | Sort-Object Time

    Write-Host "`nНайдено событий: $($results.Count)" -ForegroundColor Green

    # Выводим в таблице (основные поля)
    $results | Format-Table Time, EventID, Category, SourceIP, Object -AutoSize

    # Статистика по категориям
    Write-Host "`n--- Статистика по категориям ---" -ForegroundColor Cyan
    $results | Group-Object Category | Sort-Object Count -Descending | 
        Select-Object @{N='Category';E={$_.Name}}, Count | 
        Format-Table -AutoSize

    if ($ExportCSV) {
        $csvPath = "AdminActions_$($UserName.Replace('\','_'))_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $results | Select-Object Time, EventID, Category, SourceIP, Object, RecordID | 
            Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "Результаты экспортированы в: $csvPath" -ForegroundColor Green
    }

} catch {
    Write-Host "Ошибка при чтении журнала: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nРекомендации:" -ForegroundColor Yellow
    Write-Host "1. Запустите от администратора." -ForegroundColor Yellow
    Write-Host "2. Проверьте, включены ли необходимые подкатегории аудита:" -ForegroundColor Yellow
    Write-Host "   auditpol /get /category:*" -ForegroundColor Yellow
    Write-Host "3. Для файловых операций (4663) нужно включить аудит Object Access и настроить SACL на целевых папках." -ForegroundColor Yellow
}