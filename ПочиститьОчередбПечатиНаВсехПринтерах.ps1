try {
    # Проверка ОС
    if ($IsLinux -or $IsMacOS) {
        Write-Host "This script works only on Windows." -ForegroundColor Red
        exit 1
    }

    # Проверка прав администратора (не обязательно, но полезно)
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Warning: Not running as administrator. You may not be able to remove jobs owned by other users." -ForegroundColor Yellow
    }

    # Получаем список принтеров
    $printers = Get-Printer -ErrorAction Stop
    if ($printers.Count -eq 0) {
        Write-Host "No printers found." -ForegroundColor Yellow
        exit 0
    }

    $totalRemoved = 0
    $failedPrinters = @()

    foreach ($printer in $printers) {
        Write-Host "Processing printer: $($printer.Name)" -ForegroundColor Cyan
        try {
            $printjobs = Get-PrintJob -PrinterObject $printer -ErrorAction Stop
            if (-not $printjobs) {
                Write-Host "  No jobs found." -ForegroundColor Gray
                continue
            }

            $jobCount = 0
            foreach ($printjob in $printjobs) {
                try {
                    Remove-PrintJob -InputObject $printjob -ErrorAction Stop
                    $jobCount++
                    Write-Host "  Removed job: $($printjob.Id) - $($printjob.DocumentName)" -ForegroundColor Green
                }
                catch {
                    Write-Host "  Failed to remove job ID $($printjob.Id): $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            $totalRemoved += $jobCount
            Write-Host "  Removed $jobCount job(s) from $($printer.Name)." -ForegroundColor Green
        }
        catch {
            Write-Host "  Error accessing printer $($printer.Name): $($_.Exception.Message)" -ForegroundColor Red
            $failedPrinters += $printer.Name
        }
    }

    # Итоговый отчёт
    Write-Host "`n=== Summary ===" -ForegroundColor Yellow
    Write-Host "Total jobs removed: $totalRemoved" -ForegroundColor Green
    if ($failedPrinters.Count -gt 0) {
        Write-Host "Failed to process printers: $($failedPrinters -join ', ')" -ForegroundColor Red
    } else {
        Write-Host "All printers processed successfully." -ForegroundColor Green
    }
}
catch {
    Write-Host "Critical error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
}
finally {
    # Пауза, если скрипт запущен не в ISE/VSCode
    if ($Host.Name -notmatch "ISE|Visual Studio Code") {
        Read-Host "`nPress Enter to exit"
    }
}