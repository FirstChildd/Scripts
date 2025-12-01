# Задаем название контейнера
$City = "MSK"
$CityRu="Москва"
$DomainDN=(Get-ADDomain).DistinguishedName
$OUs = @(
"Admins",
"Computers",
"Contacts",
"Groups",
"Servers",
"Service Accounts",
"Users"
)
# создаем OU
$newOU=New-ADOrganizationalUnit -Name $City  –Description “Контейнер для пользователей $CityRu” -PassThru
ForEach ($OU In $OUs) {
    New-ADOrganizationalUnit -Name $OU -Path $newOU
    }