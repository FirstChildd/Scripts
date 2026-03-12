try {
    $MaxEvents = 10
    Write-Host "🔍 Расширенный поиск событий аварийного отключения..." -ForegroundColor Cyan

    $events = @()

    # --- События, напрямую указывающие на аварийное выключение ---

    # ID 41 (Kernel-Power) — неожиданное завершение (потеря питания, крах)
    $events += Get-WinEvent -LogName 'System' -FilterXPath "*[System[EventID=41]]" -ErrorAction SilentlyContinue

    # ID 6008 (EventLog) — предыдущее завершение было неожиданным
    $events += Get-WinEvent -LogName 'System' -FilterXPath "*[System[EventID=6008]]" -ErrorAction SilentlyContinue

    # ID 1001 (BugCheck) — синий экран (в System)
    $events += Get-WinEvent -LogName 'System' -FilterXPath "*[System[EventID=1001 and ProviderName='BugCheck']]" -ErrorAction SilentlyContinue

    # ID 1001 (WER) — отчёт о синем экране (в Application)
    $events += Get-WinEvent -LogName 'Application' -FilterXPath "*[System[EventID=1001 and ProviderName='Microsoft-Windows-WER-SystemErrorReporting']]" -ErrorAction SilentlyContinue

    # --- Дополнительные события, часто сопровождающие аварии ---

    # ID 109 (Kernel-Power) — сбой питания/гибернации
    $events += Get-WinEvent -LogName 'System' -FilterXPath "*[System[EventID=109]]" -ErrorAction SilentlyContinue

    # ID 1074 (User32) — выключение/перезагрузка. Оставляем только с кодом 0x500ff (аварийное)
    $evt1074 = Get-WinEvent -LogName 'System' -FilterXPath "*[System[EventID=1074]]" -ErrorAction SilentlyContinue
    foreach ($e in $evt1074) {
        # Ищем в сообщении "0x500ff"
        if ($e.Message -match "0x500ff") {
            $events += $e
        }
    }

    # ID 1000, 1002 (Application Error) — критические сбои приложений
    # Включаем только события уровня Error (2) или Critical (1)
    $events += Get-WinEvent -LogName 'Application' -FilterXPath "*[System[EventID=1000 or EventID=1002] and System[Level=1 or Level=2]]" -ErrorAction SilentlyContinue

    # ID 13 (VSS) — ошибки теневого копирования (могут быть связаны с нестабильностью)
    $events += Get-WinEvent -LogName 'Application' -FilterXPath "*[System[EventID=13 and ProviderName='VSS']]" -ErrorAction SilentlyContinue

    if ($events.Count -eq 0) {
        Write-Host "✅ Событий, связанных с аварийными отключениями, не найдено." -ForegroundColor Green
        exit 0
    }

    # Сортируем по времени и убираем дубликаты
    $sortedEvents = $events | Sort-Object TimeCreated -Descending
    $uniqueEvents = @()
    $seen = @{}
    foreach ($evt in $sortedEvents) {
        $key = $evt.TimeCreated.ToString() + $evt.Id + $evt.ProviderName
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $uniqueEvents += $evt
        }
        if ($uniqueEvents.Count -ge $MaxEvents) { break }
    }

    Write-Host "`n📋 Последние значимые события (макс. $MaxEvents):" -ForegroundColor Yellow

    foreach ($evt in $uniqueEvents) {
        $time = $evt.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        $id = $evt.Id
        $provider = $evt.ProviderName
        $msg = $evt.Message -replace '\s+', ' '
        if ($msg.Length -gt 400) { $msg = $msg.Substring(0, 400) + "…" }

        Write-Host "`n[$time] ID: $id, Источник: $provider" -ForegroundColor White
        Write-Host "$msg" -ForegroundColor Gray
    }

    # Расшифровка ID событий
    Write-Host "`n📌 Расшифровка ID событий:" -ForegroundColor Cyan
    Write-Host "  • ID 41 (Kernel-Power) — система перезагрузилась без чистого завершения (сбой питания, зависание)."
    Write-Host "  • ID 6008 (EventLog) — предыдущее завершение работы было неожиданным."
    Write-Host "  • ID 1001 (BugCheck / WER) — синий экран (BSOD) с указанием кода остановки."
    Write-Host "  • ID 109 (Kernel-Power) — ошибка, связанная с питанием или гибернацией."
    Write-Host "  • ID 1074 (User32) с кодом 0x500ff — аварийное выключение (обычно после зависания)."
    Write-Host "  • ID 1000, 1002 (Application Error, только ошибки/критические) — критические сбои приложений."
    Write-Host "  • ID 13 (VSS) — ошибки теневого копирования (могут сопровождать сбои)."
    Write-Host "  • Для детального анализа откройте журнал событий (eventvwr.msc)."
}
catch {
    Write-Host "⚠️ Ошибка: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Строка: $($_.InvocationInfo.ScriptLineNumber)"
}
finally {
    # Пауза, если запуск был не из ISE/VSCode
    if ($Host.Name -notmatch "ISE|Visual Studio Code") {
        Read-Host "`nНажмите Enter для выхода"
    }
}