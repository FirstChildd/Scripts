# Переменные для подключения
$NetworkPath = "\\office.local"
$Username = "username"
$Password = "password"
$ShortcutPath = "$env:USERPROFILE\Desktop\OfficeFolder.lnk"

# Сохранение учетных данных в Windows Credential Manager
cmdkey /add:office.local /user:$Username /pass:$Password

# Подключение сетевого диска с использованием командной строки
$DriveOutput = cmd.exe /c "net use O: $NetworkPath /persistent:yes 2>&1"
Write-Host $DriveOutput

# Создание ярлыка
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $NetworkPath
$Shortcut.Description = "Сетевая папка Office"
$Shortcut.Save()

Write-Host "Ярлык создан на рабочем столе: $ShortcutPath"