# Скрипт: Полная активность пользователя ovkirillin (RDP + все авторизации)
# Запускать от имени Администратора

param(
    [string]$TargetUser = "ovkirillin"
)

Write-Host "=== Полный анализ активности для пользователя: $TargetUser ===" -ForegroundColor Cyan

# Проверка прав администратора
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Ошибка: Скрипт требует прав Администратора." -ForegroundColor Red
    Write-Host "Закройте окно, затем нажмите правой кнопкой на PowerShell -> 'Запуск от имени администратора'" -ForegroundColor Yellow
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

# 1. Текущая активная RDP-сессия
Write-Host "`n--- Текущая RDP-сессия пользователя $TargetUser ---" -ForegroundColor Green
try {
    $currentSession = query user | Select-String $TargetUser -SimpleMatch
    if ($currentSession) {
        Write-Host "Сессия найдена:" -ForegroundColor Yellow
        $currentSession
    } else {
        Write-Host "Пользователь $TargetUser не имеет активных RDP-сессий в данный момент." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Не удалось выполнить 'query user'. Ошибка: $_" -ForegroundColor Red
}

# 2. Все успешные авторизации пользователя (Event ID 4624, любые типы входа)
Write-Host "`n=== ВСЕ УСПЕШНЫЕ АВТОРИЗАЦИИ (за 30 дней) ===" -ForegroundColor Green

$StartDate = (Get-Date).AddDays(-30)
$successLogins = @()

try {
    $events4624 = Get-WinEvent -FilterHashtable @{
        LogName   = 'Security'
        ID        = 4624
        StartTime = $StartDate
    } -ErrorAction SilentlyContinue

    foreach ($event in $events4624) {
        $xml = [xml]$event.ToXml()
        $username = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' }).'#text'
        if ($username -eq $TargetUser) {
            $logonType = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonType' }).'#text'
            $sourceIP = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' }).'#text'
            $processName = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'ProcessName' }).'#text'
            
            # Преобразуем код типа входа в понятное название
            $logonTypeName = switch ($logonType) {
                '2'  { 'Интерактивный (локальный)' }
                '3'  { 'Сетевой (NET use, SQL, etc)' }
                '4'  { 'Пакетный (Batch)' }
                '5'  { 'Служба (Service)' }
                '7'  { 'Разблокировка экрана' }
                '8'  { 'Сетевой с явными данными (Cleartext)' }
                '9'  { 'Новые учётные данные (RunAs)' }
                '10' { 'Удалённый интерактивный (RDP)' }
                '11' { 'Кэшированный интерактивный' }
                default { "Тип $logonType" }
            }
            
            $successLogins += [PSCustomObject]@{
                Time        = $event.TimeCreated
                LogonType   = $logonTypeName
                SourceIP    = $sourceIP
                ProcessName = $processName
            }
        }
    }

    if ($successLogins.Count -gt 0) {
        $successLogins | Sort-Object Time -Descending | Select-Object -First 30 | Format-Table Time, LogonType, SourceIP -AutoSize
        Write-Host "Всего успешных авторизаций для $TargetUser за 30 дней: $($successLogins.Count)" -ForegroundColor Cyan
        Write-Host "Последняя успешная авторизация: $($successLogins[0].Time)" -ForegroundColor Magenta
    } else {
        Write-Host "Не найдено успешных авторизаций для $TargetUser за последние 30 дней." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Ошибка при чтении событий успешного входа: $_" -ForegroundColor Red
}

# 3. Неудачные попытки авторизации (Event ID 4625)
Write-Host "`n=== НЕУДАЧНЫЕ ПОПЫТКИ АВТОРИЗАЦИИ (за 30 дней) ===" -ForegroundColor Red

$failedLogins = @()

try {
    $events4625 = Get-WinEvent -FilterHashtable @{
        LogName   = 'Security'
        ID        = 4625
        StartTime = $StartDate
    } -ErrorAction SilentlyContinue

    foreach ($event in $events4625) {
        $xml = [xml]$event.ToXml()
        $username = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' }).'#text'
        if ($username -eq $TargetUser) {
            $logonType = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonType' }).'#text'
            $sourceIP = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' }).'#text'
            $status = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'Status' }).'#text'
            $subStatus = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'SubStatus' }).'#text'
            
            $failedLogins += [PSCustomObject]@{
                Time      = $event.TimeCreated
                LogonType = $logonType
                SourceIP  = $sourceIP
                Status    = "0x$status"
                SubStatus = "0x$subStatus"
            }
        }
    }

    if ($failedLogins.Count -gt 0) {
        $failedLogins | Sort-Object Time -Descending | Select-Object -First 20 | Format-Table Time, LogonType, SourceIP, Status -AutoSize
        Write-Host "Всего неудачных попыток для $TargetUser за 30 дней: $($failedLogins.Count)" -ForegroundColor Red
        Write-Host "Последняя неудачная попытка: $($failedLogins[0].Time)" -ForegroundColor Magenta
    } else {
        Write-Host "Неудачных попыток авторизации для $TargetUser за 30 дней не найдено." -ForegroundColor Green
    }
} catch {
    Write-Host "Ошибка при чтении событий неудачного входа: $_" -ForegroundColor Red
}

# 4. Отдельно RDP-входы (для удобства)
Write-Host "`n=== ТОЛЬКО RDP-ВХОДЫ (LogonType=10) ===" -ForegroundColor Cyan
$rdpOnly = $successLogins | Where-Object { $_.LogonType -like '*RDP*' }
if ($rdpOnly.Count -gt 0) {
    $rdpOnly | Sort-Object Time -Descending | Format-Table Time, SourceIP -AutoSize
    Write-Host "Последний RDP-вход: $($rdpOnly[0].Time)" -ForegroundColor Magenta
} else {
    Write-Host "RDP-входов не обнаружено." -ForegroundColor Yellow
}

Write-Host "`n=== Готово ===" -ForegroundColor Cyan

# Пауза перед закрытием
Write-Host "`nНажмите любую клавишу, чтобы закрыть окно..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")