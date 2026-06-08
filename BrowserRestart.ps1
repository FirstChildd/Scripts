# Проверка прав администратора
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Ошибка: Запустите этот скрипт от имени Администратора!" -ForegroundColor Red
    Read-Host "Нажмите Enter для выхода"
    exit
}

Write-Host "Начинаю принудительное завершение процессов браузеров..." -ForegroundColor Cyan

# Список имен процессов: Chrome, Yandex (его процесс называется browser.exe), IE, Edge
$processNames = @("chrome", "browser", "iexplore", "msedge")

foreach ($proc in $processNames) {
    $processes = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($processes) {
        Write-Host "Найден процесс: $proc.exe. Завершаю..." -ForegroundColor Yellow
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        Write-Host "Процесс $proc.exe успешно завершен." -ForegroundColor Green
    } else {
        Write-Host "Процесс $proc.exe не найден (не запущен)." -ForegroundColor Gray
    }
}

Write-Host "Готово! Все целевые браузеры закрыты." -ForegroundColor Cyan
Read-Host "Нажмите Enter для выхода"