rem ��� 1�
rem =========== ����ன�� ===============
rem ��㤠 㤠����
set from=%USERPROFILE%\AppData\Local\1C\1cv8

rem ��᪠ ���᪠
set mask=????????-????-????-????-????????????

rem =====================================


FORFILES /P "%FROM%" /M %mask% /C "cmd /c RMDIR /s /q @path"

rem =========== ����ன�� ===============
rem ��㤠 㤠����
set from=%USERPROFILE%\AppData\Roaming\1C\1cv8

rem ��᪠ ���᪠
set mask=????????-????-????-????-????????????

rem =====================================

FORFILES /P "%FROM%" /M %mask% /C "cmd /c RMDIR /s /q @path"

rem =========== ����ன�� ===============
rem ��㤠 㤠����
set from=%USERPROFILE%\AppData\Roaming\1C\1cv82

rem ��᪠ ���᪠
set mask=????????-????-????-????-????????????

rem =====================================

FORFILES /P "%FROM%" /M %mask% /C "cmd /c RMDIR /s /q @path"

rem ********** Windows XP *****************

rem =========== ����ன�� ===============
rem ��㤠 㤠����
set from=%USERPROFILE%\Application Data\1C\1cv8

rem ��᪠ ���᪠
set mask=????????-????-????-????-????????????

rem =====================================

for /d %%i in ("%from%\%mask%") do rd /s /q %%i


rem =========== ����ன�� ===============
rem ��㤠 㤠����
set from=%USERPROFILE%\Local Settings\Application Data\1C\1cv8

rem ��᪠ ���᪠
set mask=????????-????-????-????-????????????

rem =====================================

for /d %%i in ("%from%\%mask%") do rd /s /q %%i

rem =========== ����ன�� ===============
rem ��㤠 㤠����
set from=%USERPROFILE%\Local Settings\Application Data\1C\1cv82

rem ��᪠ ���᪠
set mask=????????-????-????-????-????????????
rem      ec53fec5-d5a7-4c7f-9c86-ec1203c79f1d

rem =====================================

for /d %%i in ("%from%\%mask%") do rd /s /q %%i