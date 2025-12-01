#Просто создать уч запись
New-ADUser testuser1
#Синтаксис создания уч записи
Get-Command New-ADUser –Syntax
#Заблокируем пользователя
Disable-ADAccount testuser1

# Задаем Должность
Set-ADUser alex_b –title “Ведущий программист” 
# Задаем номер сотового
Set-ADUser alex_b -MobilePhone +7900000101
# Задаем Должность и компанию
Set-ADUser alex_b -Replace @{title="Программист";company="Рога и Копыта"}
# Задаем компанию
Set-ADUser alex_b -Replace @{company="Ромашка"}
# Задаем Город
Set-ADUser alex_b -City "Москва"
#Просмотр информации о пользователе
Get-ADUser alex_b
# Перемещаем в нужное Подразделение, соответствующее городу
Move-ADObject -Identity "CN=alex b,OU=marketing,DC=company,DC=com" -TargetPath "OU=Users,OU=MSK,DC=company,DC=com"


#Создание учетной записи пк
New-ADComputer -Name "msk-002" -sAMAccountName "msk-002" -Path "ou=marketing,DC=company,DC=com"
#Блокировка учетной записи пк
Disable-ADAccount -Identity "cn=msk-002,ou=marketing,DC=company,DC=com"
#Включение учетной записи пк
Enable-ADAccount -Identity "cn=msk-002,ou=marketing,DC=company,DC=com"