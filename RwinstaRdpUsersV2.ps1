# Запуск от имени администратора
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Запустите скрипт от имени администратора!"
    pause
    exit
}

# Получаем ID текущей сессии
$currentSessionId = (Get-Process -Id $pid).SessionId
Write-Host "Текущий ID сессии: $currentSessionId" -ForegroundColor Cyan

Write-Host "Поиск отключённых сессий (Диск / Откл / Disc)..." -ForegroundColor Cyan

# Получаем список сессий
$lines = qwinsta

# Парсим строки
$sessions = @()
foreach ($line in $lines) {
    # Пропускаем заголовок
    if ($line -match "СЕАНС|SESSIONNAME") { continue }

    # Убираем начальные пробелы и возможный символ '>' (текущая сессия)
    $cleanLine = $line.TrimStart()
    if ($cleanLine -match '^>') {
        $cleanLine = $cleanLine.Substring(1).TrimStart()
    }

    # Ищем первое число в строке (ID сессии)
    if ($cleanLine -match '\b(\d+)\b') {
        $idMatch = $matches[1]
        $idIndex = $match.Index
        $idLength = $match.Length

        # Часть до ID
        $beforeId = $cleanLine.Substring(0, $idIndex).TrimEnd()
        # Часть после ID
        $afterId = $cleanLine.Substring($idIndex + $idLength).TrimStart()

        # Разбираем beforeId на слова
        $words = $beforeId -split '\s+', 3
        $sessionName = ""
        $userName = ""

        if ($words.Count -eq 0) {
            # нет ни имени сессии, ни пользователя
        } elseif ($words.Count -eq 1) {
            $word = $words[0]
            if ($word -match '#' -or $word -eq 'services' -or $word -eq 'console' -or $word -match '^rdp-tcp') {
                $sessionName = $word
                $userName = ""
            } else {
                $sessionName = ""
                $userName = $word
            }
        } else {
            $sessionName = $words[0]
            $userName = $words[1]
        }

        $sessions += [PSCustomObject]@{
            SessionId   = [int]$idMatch
            UserName    = $userName
            State       = $afterId
            SessionName = $sessionName
        }
    }
}

# Фильтруем отключённые сессии (исключая системную ID=0 и текущую)
$disconnected = $sessions | Where-Object {
    ($_.State -match "Диск|Откл|Disc") -and $_.SessionId -ne 0 -and $_.SessionId -ne $currentSessionId
}

if ($disconnected.Count -eq 0) {
    Write-Host "Отключённых сессий для сброса не найдено." -ForegroundColor Green
    pause
    exit
}

# Выводим найденные сессии с пользователями
Write-Host "`nНайдены следующие отключённые сессии:" -ForegroundColor Yellow
$disconnected | Format-Table SessionId, UserName, State -AutoSize

# ==========================================
# НОВОЕ: Выбор сессий для исключения
# ==========================================
Write-Host "`nВведите ID сессий, которые нужно ИСКЛЮЧИТЬ из сброса (через запятую или пробел)." -ForegroundColor Cyan
Write-Host "Нажмите Enter, чтобы сбросить все найденные сессии." -ForegroundColor Gray
$excludeInput = Read-Host

$excludeIds = @()
if ($excludeInput.Trim() -ne "") {
    # Разбиваем по запятой или пробелу, оставляем только числа
    $excludeIds = ($excludeInput -split '[,\s]+') | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    
    if ($excludeIds.Count -gt 0) {
        Write-Host "Сессии с ID $($excludeIds -join ', ') будут исключены." -ForegroundColor Yellow
    } else {
        Write-Host "Некорректный ввод. Исключений не добавлено." -ForegroundColor Red
    }
}

# Фильтруем сессии, исключая выбранные ID
$sessionsToReset = $disconnected | Where-Object { $_.SessionId -notin $excludeIds }

if ($sessionsToReset.Count -eq 0) {
    Write-Host "Нет сессий для сброса после применения исключений." -ForegroundColor Green
    pause
    exit
}

# Выводим итоговый список для сброса
Write-Host "`nИтоговый список сессий для сброса:" -ForegroundColor Yellow
$sessionsToReset | Format-Table SessionId, UserName, State -AutoSize

# Запрашиваем подтверждение
$confirmation = Read-Host "`nСбросить выбранные сессии? (y/n)"
if ($confirmation -ne 'y') {
    Write-Host "Операция отменена." -ForegroundColor Cyan
    pause
    exit
}

# Сбрасываем сессии
foreach ($session in $sessionsToReset) {
    try {
        Write-Host "Сброс сессии ID $($session.SessionId) (пользователь: $($session.UserName))..." -ForegroundColor Yellow
        & rwinsta $session.SessionId 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Сессия $($session.SessionId) успешно сброшена." -ForegroundColor Green
        } else {
            Write-Host "Ошибка при сбросе сессии $($session.SessionId)." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Исключение при сбросе сессии $($session.SessionId): $_" -ForegroundColor Red
    }
}

Write-Host "`nГотово." -ForegroundColor Green
pause