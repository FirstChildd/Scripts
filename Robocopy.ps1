#Копирование структуры
robocopy "E:\DOC\Документы" "E:\DOC\Test_Str\DOC\Документы" /e /create
#Копирование структуры
robocopy "G:\E_\DOC\" "E:\DOC\Test_Str\DOC\" /COPYALL /SEC /SECFIX /MIR
robocopy "G:\E_\DOC\" "E:\DOC\Test_Str\DOC\" /SEC /SECFIX /MIR /xo /xn /xc



chcp 65001 | Out-Null
robocopy "E:\DOC\Документы" "\\srv-ad-02\e$\DOC\Документы" /XD "E:\DOC\Документы\DfsrPrivate" "E:\DOC\Документы\__DFSR_DIAGNOSTICS_TEST_FOLDER__ " /MIR /COPYALL /SECFIX /Z /B /J /R:3 /W:1 /MT:32 /MON:1 /REG /TEE /LOG:"\\srv-ad-01\e$\DOC\robocopy.log"
chcp 866

robocopy "F:\Folders\Distr" "D:\Folders\Distr" /MIR /COPYALL /SECFIX /Z /B /J /R:3 /W:1 /MT:32



#Создание файла ACL
chcp 1251
icacls "G:\E_\DOC\Документы" /save "G:\E_\DOC\backup.txt" /t /c
# Восстановление
icacls "E:\DOC" /restore "G:\E_\DOC\backup.txt"


$sourcePath = 'E:\DOC\Test_Str\DOC'
$excludedFolders = @('DfsrPrivate')
chcp 1251
# Получаем список всех подпапок и файлов, исключив указанные
Get-ChildItem -Path $sourcePath -Recurse | Where-Object { $_ -notmatch 'DfsrPrivate' } | ForEach-Object {
    # Восстанавливаем ACL индивидуально для каждого элемента
    icacls "$($_.FullName)" /restore "G:\E_\DOC\backup.acl" /C /Q
}