# Проверка наличия модуля ActiveDirectory
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "Модуль ActiveDirectory не найден. Установите RSAT-AD-PowerShell."
    exit 1
}

# Импортируем модуль (если не импортирован)
Import-Module ActiveDirectory -ErrorAction Stop

# Определяем дату неделю назад (UTC, так как whenCreated хранится в UTC)
$weekAgo = (Get-Date).AddDays(-7).ToUniversalTime()

try {
    # Получаем пользователей, созданных за последнюю неделю
    $newUsers = Get-ADUser -Filter {whenCreated -ge $weekAgo} -Properties whenCreated, SamAccountName, Name -ErrorAction Stop
    $count = $newUsers.Count

    Write-Host "`nКоличество пользователей, добавленных в AD за последние 7 дней: $count" -ForegroundColor Green

    if ($count -gt 0) {
        Write-Host "`nСписок добавленных пользователей:" -ForegroundColor Cyan
        # Выводим таблицу с именами (SamAccountName) и датой создания
        $newUsers | Select-Object SamAccountName, @{Name="DateCreated"; Expression={$_.whenCreated.ToLocalTime()}} | Format-Table -AutoSize
    }
} catch {
    Write-Error "Ошибка при получении пользователей: $_"
    exit 1
}