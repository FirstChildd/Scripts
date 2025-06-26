# === ЛОГ ===
$logFile = "C:\intune\wallpaper_log.txt"
Add-Content -Path $logFile -Value "`n[$(Get-Date)] Скрипт запущен"

# === ПУТИ ===
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path $scriptPath -Parent
$WallpapersFolder = Join-Path $scriptDir "Wallpapers"
$ImageDestinationFolder = "C:\intune"
$BackgroundFile = "background.jpg"
$LockscreenFile = "lockscreen.jpg"
$BackgroundImage = Join-Path $ImageDestinationFolder $BackgroundFile
$LockScreenImage = Join-Path $ImageDestinationFolder $LockscreenFile

# === СОЗДАНИЕ ПАПОК ===
if (-not (Test-Path $WallpapersFolder)) {
    New-Item -ItemType Directory -Path $WallpapersFolder -Force | Out-Null
    Add-Content -Path $logFile -Value "Создана папка: $WallpapersFolder. Положите туда изображения."
    exit
}
if (-not (Test-Path $ImageDestinationFolder)) {
    New-Item -ItemType Directory -Path $ImageDestinationFolder -Force | Out-Null
}

# === ВЫБОР ИЗОБРАЖЕНИЯ ===
$images = Get-ChildItem -Path $WallpapersFolder -File | Where-Object {
    $_.Extension -match '\.(jpg|jpeg|png)$'
}
if ($images.Count -eq 0) {
    Add-Content -Path $logFile -Value "Нет изображений в $WallpapersFolder"
    exit
}
$selectedImage = Get-Random -InputObject $images
Copy-Item -Path $selectedImage.FullName -Destination $BackgroundImage -Force
Copy-Item -Path $selectedImage.FullName -Destination $LockScreenImage -Force
Add-Content -Path $logFile -Value "Скопировано изображение: $($selectedImage.Name)"

# === ИЗМЕНЕНИЕ ОБОЕВ И ЭКРАНА БЛОКИРОВКИ ===
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
New-Item -Path $RegPath -Force -ErrorAction SilentlyContinue | Out-Null

Set-ItemProperty -Path $RegPath -Name LockScreenImagePath -Value $LockScreenImage -Force
Set-ItemProperty -Path $RegPath -Name LockScreenImageUrl -Value $LockScreenImage -Force
Set-ItemProperty -Path $RegPath -Name LockScreenImageStatus -Value 1 -Force

Set-ItemProperty -Path $RegPath -Name DesktopImagePath -Value $BackgroundImage -Force
Set-ItemProperty -Path $RegPath -Name DesktopImageUrl -Value $BackgroundImage -Force
Set-ItemProperty -Path $RegPath -Name DesktopImageStatus -Value 1 -Force

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
[Wallpaper]::SystemParametersInfo(0x0014, 0, $BackgroundImage, 0x0001)

Add-Content -Path $logFile -Value "Обои и экран блокировки применены."

# === Создание/перезапись задачи в планировщике ===
$taskName = "Rotate Wallpaper Every Day at 9AM"
$logFile = "C:\intune\wallpaper_log.txt"

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Add-Content -Path $logFile -Value "[$(Get-Date)] Старая задача $taskName удалена"
} catch {}

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

# Триггер — запускать ежедневно в 9:00 утра
$trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable

$principal = New-ScheduledTaskPrincipal -UserId $currentUser `
    -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName $taskName `
    -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal

Add-Content -Path $logFile -Value "[$(Get-Date)] Создана задача $taskName"
