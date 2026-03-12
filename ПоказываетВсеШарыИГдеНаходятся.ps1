try {
    # Проверка ОС
    if ($IsLinux -or $IsMacOS) {
        Write-Host "This script works only on Windows." -ForegroundColor Red
        exit 1
    }

    $computer = $env:COMPUTERNAME

    # Современный способ (Windows 8/Server 2012+)
    if (Get-Command Get-SmbShare -ErrorAction SilentlyContinue) {
        $shares = Get-SmbShare | Where-Object { $_.Name -notlike '*$' -and $_.Special -eq $false }
        if ($shares.Count -eq 0) {
            Write-Host "No regular shares found."
        } else {
            Write-Host "`nShares on \\$computer`:" -ForegroundColor Green
            foreach ($share in $shares) {
                $desc = if ($share.Description) { " ($($share.Description))" } else { "" }
                Write-Host "  \\$computer\$($share.Name) -> $($share.Path)$desc"
            }
        }
    }
    # Запасной вариант через WMI
    else {
        $shares = Get-CimInstance -ClassName Win32_Share | Where-Object { $_.Name -notlike '*$' }
        if ($shares.Count -eq 0) {
            Write-Host "No regular shares found."
        } else {
            Write-Host "`nShares on \\$computer`:" -ForegroundColor Green
            foreach ($share in $shares) {
                $desc = if ($share.Description) { " ($($share.Description))" } else { "" }
                Write-Host "  \\$computer\$($share.Name) -> $($share.Path)$desc"
            }
        }
    }

    # Пауза, если скрипт запущен не в ISE/VSCode
    if ($Host.Name -notmatch "ISE|Visual Studio Code") {
        Read-Host "`nPress Enter to exit"
    }
    exit 0
}
catch {
    Write-Host "ERROR: $($Error[0])" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)"
    if ($Host.Name -notmatch "ISE|Visual Studio Code") {
        Read-Host "`nPress Enter to exit"
    }
    exit 1
}
