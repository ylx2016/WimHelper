@echo off

rem ��ȡ����ԱȨ��
pushd "%~dp0" && Dism 1>nul 2>nul || mshta vbscript:CreateObject("Shell.Application").ShellExecute("cmd.exe","/c %~s0 "%*"","","runas",1)(window.close) && Exit /B 1
rem ���ñ���
color 1F
mode con cols=120
set "ESDPath=%~1"

if "%ESDPath%" equ "" call :SelectFolder
rem call :ExportISO "E G", "%~dp0install.wim"
for %%i in (x86 x64) do call :MakeRS3 "%ESDPath%", "%~dp0DVD_%%i", "%%i"
goto :Exit

:SelectFolder
set folder=mshta "javascript:var folder=new ActiveXObject('Shell.Application').BrowseForFolder(0,'ѡ��ESD��������Ŀ¼', 513, '');if(folder) new ActiveXObject('Scripting.FileSystemObject').GetStandardStream(1).Write(folder.Self.Path);window.close();"
for /f %%f in ('%folder%') do set "ESDPath=%%f"
if "%ESDPath%" equ "" goto :Exit
goto :eof

rem ����ISO���� [ %~1 : �̷��б�[�ո�ָ�], %~2 : Ŀ��·�� ]
:ExportISO
if exist "%~2" del /q "%~2"
for %%i in (%~1) do call :ExportImage "%%i:\sources\install.wim", "%~2"
goto :eof

rem ����RS2���� [ %~1 : Դ·��, %~2 : Ŀ��·��, %~3 �������ܹ� ]
:MakeRS2
if not exist "%~1" echo [%~1] ������ && goto :eof
if exist "%~2" rd /s /q "%~2"
set "WimPath=%~dp0install_RS2_%~3_%date:~0,4%%date:~5,2%%date:~8,2%.wim"
if exist "%WimPath%" del /q "%WimPath%"
rem ������װ����
for %%i in (combinedchina enterprise) do (
    for %%j in ("%~1\*.rs2_release_*%%i*_%~3fre_*.esd") do (
        if not exist "%~2" call :ExportDVD "%%j", "%~2"
        call :ExportImage "%%j", "%WimPath%"
    )
)
call "%~dp0WimHelper.cmd" "%WimPath%", "%~2\sources\install.esd"
rem ����ISO����
for /f "tokens=3 delims=." %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%WimPath%" /Index:1 ^| findstr /i Version') do ( set "ImageRevision=%%f" )
for /f "tokens=4" %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%WimPath%" /Index:1 ^| find "ServicePack Level"') do ( set "ImageBuild=%%f" )
for /f "tokens=* delims=" %%f in ('Dism.exe /English /Get-ImageInfo /ImageFile:"%WimPath%" /Index:1 ^| findstr /i Default') do ( set "ImageLanguage=%%f" )
call "%~dp0MakeISO.cmd" "%~2" "Win10_%ImageRevision%.%ImageBuild%_RS2_%~3_%ImageLanguage:~1,-10%"
rd /s /q "%~2"
rem ���ɶ���һ����
Dism /Export-Image /SourceImageFile:"%WimPath%" /All /DestinationImageFile:"%~dp0cn_windows_10_1703_%ImageRevision%.%ImageBuild%_x86_x64.esd" /Compress:recovery
del /q "%WimPath%"
goto :eof

rem ����RS3���� [ %~1 : Դ·��, %~2 : Ŀ��·��, %~3 �������ܹ� ]
:MakeRS3
if not exist "%~1" echo [%~1] ������ && goto :eof
if exist "%~2" rd /s /q "%~2"
set "WimPath=%~dp0install_RS3_%~3_%date:~0,4%%date:~5,2%%date:~8,2%.wim"
if exist "%WimPath%" del /q "%WimPath%"
rem ������װ����
for %%i in (consumer china business) do (
    for %%j in ("%~1\*.rs3_release_*%%i*_%~3fre_*.esd") do (
        if not exist "%~2" call :ExportDVD "%%j", "%~2"
        call :ExportImage "%%j", "%WimPath%"
    )
)
call "%~dp0WimHelper.cmd" "%WimPath%", "%~2\sources\install.esd"
rem ����ISO����
for /f "tokens=3 delims=." %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%WimPath%" /Index:1 ^| findstr /i Version') do ( set "ImageRevision=%%f" )
for /f "tokens=4" %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%WimPath%" /Index:1 ^| find "ServicePack Level"') do ( set "ImageBuild=%%f" )
for /f "tokens=* delims=" %%f in ('Dism.exe /English /Get-ImageInfo /ImageFile:"%WimPath%" /Index:1 ^| findstr /i Default') do ( set "ImageLanguage=%%f" )
call "%~dp0MakeISO.cmd" "%~2" "Win10_%ImageRevision%.%ImageBuild%_RS3_%~3_%ImageLanguage:~1,-10%"
rd /s /q "%~2"
rem ���ɶ���һ����
Dism /Export-Image /SourceImageFile:"%WimPath%" /All /DestinationImageFile:"%~dp0cn_windows_10_1709_%ImageRevision%.%ImageBuild%_x86_x64.esd" /Compress:recovery
del /q "%WimPath%"
goto :eof

rem ����DVD����Ŀ¼ [ %~1 : Դ·��, %~2 : Ŀ��·�� ]
:ExportDVD
md "%~2"
Dism /Apply-Image /ImageFile:"%~1" /Index:1 /ApplyDir:"%~2"
rem ��ȡ�汾��Ϣ
for /f "tokens=3" %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%~1" /Index:3 ^| findstr /i Version') do ( set "FullVersion=%%f" )
for /f "tokens=3" %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%~1" /Index:3 ^| findstr /i Architecture') do ( set "ImageArch=%%f" )
set "NetFx3Path=%~dp0Pack\NetFx3\%FullVersion%.%ImageArch%"
if not exist "%NetFx3Path%" xcopy /I /H /R /Y "%~2\sources\sxs" "%NetFx3Path%" >nul
rem ���������ļ�
del /q "%~2\setup.exe"
del /q "%~2\autorun.inf"
rd /s /q "%~2\support"
rd /s /q "%~2\boot\zh-cn"
for /f "tokens=* delims=" %%f in ('dir /a:d /b "%~2\sources"') do rd /s /q "%~2\sources\%%f"
for /f "tokens=* delims=" %%f in ('dir /a:-d /b "%~2\sources" ^| findstr /v "setup.exe"') do del /q "%~2\sources\%%f"
for /f "tokens=* delims=" %%f in ('dir /a:-d /b "%~2\boot" ^| findstr /v "bcd boot.sdi etfsboot.com"') do del /q "%~2\boot\%%f"
for /f "tokens=* delims=" %%f in ('dir /a:-d /b "%~2\boot\fonts" ^| findstr /v "chs wgl4"') do del /q "%~2\boot\fonts\%%f"
for /f "tokens=* delims=" %%f in ('dir /a:-d /b "%~2\efi\microsoft\boot" ^| findstr /v "bcd efisys.bin"') do del /q "%~2\efi\microsoft\boot\%%f"
for /f "tokens=* delims=" %%f in ('dir /a:-d /b "%~2\efi\microsoft\boot\fonts" ^| findstr /v "chs wgl4"') do del /q "%~2\efi\microsoft\boot\fonts\%%f"
rem ����WinPE
Dism /Export-Image /SourceImageFile:"%~1" /SourceIndex:3 /DestinationImageFile:"%~2\sources\boot.wim" /Bootable /Compress:max
goto :eof

rem ############################################################################################
rem ���ߺ���
rem ############################################################################################

rem �������� [ %~1 : ����·��, %~2 : Ŀ��·�� ]
:ExportImage
if not exist "%~1" ( echo.���� %~1 ������ && goto :eof )
for /f "tokens=2 delims=: " %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%~1" ^| findstr /i Index') do ( call :ExportImageIndex "%~1", %%f, "%~2" )
goto :eof

rem �������� [ %~1 : ����·��, %~2 : �������, %~3 : Ŀ��·�� ]
:ExportImageIndex
rem ��ȡ������Ϣ
for /f "tokens=3" %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%~1" /Index:%~2 ^| findstr /i Installation') do ( set "ImageType=%%f" )
for /f "tokens=2,3 delims=:. " %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%~1" /Index:%~2 ^| findstr /i Version') do ( set "ImageVersion=%%f.%%g" )
rem ϵͳ����
if "%ImageType%" equ "Client" (
    if "%ImageVersion%" equ "6.1" ( set "ImageName=Windows 7" )
    if "%ImageVersion%" equ "6.2" ( set "ImageName=Windows 8" )
    if "%ImageVersion%" equ "6.3" ( set "ImageName=Windows 8.1" )
    if "%ImageVersion%" equ "10.0" ( set "ImageName=Windows 10" )
) else if "%ImageType%" equ "Server" (
    if "%ImageVersion%" equ "6.1" ( set "ImageName=Windows 2008 R2" )
    if "%ImageVersion%" equ "6.2" ( set "ImageName=Windows 2012" )
    if "%ImageVersion%" equ "6.3" ( set "ImageName=Windows 2012 R2" )
    if "%ImageVersion%" equ "10.0" ( set "ImageName=Windows 2016" )
) else ( goto :eof )
rem ϵͳ�汾
for /f "tokens=3" %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%~1" /Index:%~2 ^| findstr /i Edition') do ( set "ImageEdition=%%f" )
if "%ImageEdition%" equ "Cloud" ( goto :eof )
if "%ImageEdition%" equ "CoreCountrySpecific" ( set "ImageName=%ImageName% ��ͥ���İ�" )
if "%ImageEdition%" equ "CoreSingleLanguage" ( set "ImageName=%ImageName% ��ͥ�����԰�" )
if "%ImageEdition%" equ "Core" ( set "ImageName=%ImageName% ��ͥ��" )
if "%ImageEdition%" equ "Education" ( set "ImageName=%ImageName% ������" )
if "%ImageEdition%" equ "Professional" ( set "ImageName=%ImageName% רҵ��" )
if "%ImageEdition%" equ "Enterprise" ( set "ImageName=%ImageName% ��ҵ��" )
if "%ImageEdition%" equ "ServerStandard" ( set "ImageName=%ImageName% ��׼��" )
if "%ImageEdition%" equ "ServerEnterprise" ( set "ImageName=%ImageName% ��ҵ��" )
if "%ImageEdition%" equ "ServerWeb" ( set "ImageName=%ImageName% Web��" )
if "%ImageEdition%" equ "ServerDatacenter" ( set "ImageName=%ImageName% �������İ�" )
rem �������ܹ�
rem for /f "tokens=3" %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%~1" /Index:%~2 ^| findstr /i Architecture') do ( set "ImageArch=%%f" )
rem if "%ImageArch%" equ "x86" ( set "ImageName=%ImageName% 32λ" )
rem if "%ImageArch%" equ "x64" ( set "ImageName=%ImageName% 64λ" )
rem �ж��Ƿ����ظ�����
for /f "tokens=3" %%f in ('Dism /English /Get-ImageInfo /ImageFile:"%~3" /Name:"%ImageName%" ^| findstr /i Index') do ( echo ���� %ImageName% �Ѵ��� %%f && goto :eof )
rem ������ʽ
if /i "%~x3" equ ".wim" ( set "Compress=/Compress:max" )
if /i "%~x3" equ ".esd" ( set "Compress=/Compress:recovery" )
Dism /Export-Image /SourceImageFile:"%~1" /SourceIndex:%~2 /DestinationImageFile:"%~3" /DestinationName:"%ImageName%" %Compress%
goto :eof

:Exit
if "%~1" equ "" pause