<#
.SYNOPSIS
    Lists all print jobs
.DESCRIPTION
    This PowerShell script lists all print jobs of all printer devices.
.EXAMPLE
    PS> ./list-print-jobs.ps1

    Printer                       Jobs
    -------                       ----
    ET-2810 Series                no jobs
    ...
.LINK
    https://github.com/fleschutz/PowerShell
.NOTES
    Author: Markus Fleschutz | License: CC0
#>

#Requires -Version 4

function ListPrintJobs {
    # Проверяем наличие модуля PrintManagement (есть во всех современных Windows)
    if (-not (Get-Module -ListAvailable -Name PrintManagement)) {
        throw "PrintManagement module not found. Are you on Windows 8/Server 2012 or later?"
    }

    $printers = Get-Printer
    if ($printers.Count -eq 0) {
        Write-Warning "No printers found."
        return
    }

    foreach ($printer in $printers) {
        $PrinterName = $printer.Name
        $printjobs = Get-PrintJob -PrinterObject $printer -ErrorAction SilentlyContinue

        if ($printjobs.Count -eq 0) {
            $JobsInfo = "no jobs"
        } else {
            # Формируем список заданий: ID, имя документа, статус
            $jobsList = @()
            foreach ($job in $printjobs) {
                $jobsList += "$($job.Id):$($job.DocumentName) [$($job.JobStatus)]"
            }
            $JobsInfo = $jobsList -join "; "
        }

        # Возвращаем объект для форматированного вывода
        [PSCustomObject]@{
            Printer = $PrinterName
            Jobs    = $JobsInfo
        }
    }
}

try {
    if ($IsLinux -or $IsMacOS) {
        Write-Host "This script works only on Windows."
        exit 1
    } else {
        ListPrintJobs | Format-Table -Property Printer, Jobs -AutoSize
    }

    # Пауза, чтобы окно не закрылось сразу при запуске двойным щелчком
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 0
} catch {
    Write-Host "⚠️ ERROR: $($Error[0])" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
