@echo off

rem ��ȡ����ԱȨ��
pushd "%~dp0" && Dism 1>nul 2>nul || mshta vbscript:CreateObject("Shell.Application").ShellExecute("cmd.exe","/c %~s0 "%*"","","runas",1)(window.close) && Exit /B 1
rem ���ñ���
color 1F
mode con cols=120
cls
setlocal EnableDelayedExpansion
set NSudo="%~dp0Bin\%PROCESSOR_ARCHITECTURE%\NSudo.exe"
set "Dism=Dism.exe /NoRestart /LogLevel:1"
set "MNT=%~dp0Mount"
set "TMP=%~dp0Temp"
set "ImagePath=%~1"

rem �ű���ʼ
:Start
if "%ImagePath%" equ "" goto :SelectImage
if not exist "%ImagePath%" ( echo ���� %ImagePath% ������ && goto :Exit )
Dism /Get-ImageInfo /ImageFile:"%ImagePath%" 1>nul 2>nul || echo �ļ� %ImagePath% ������Ч�ľ����ļ� && goto :Exit

title ���ڳ�ʼ��
call :CleanUp
md "%TMP%" && md "%MNT%"
call :MakeWim "%ImagePath%", "%~2"
goto :Exit

rem ѡ����
:SelectImage
set selectimage=mshta "about:<input type=file id=f><script>f.click();new ActiveXObject('Scripting.FileSystemObject').GetStandardStream(1).Write(f.value);window.close();</script>"
for /f "tokens=* delims=" %%f in ('%selectimage%') do set "ImagePath=%%f"
if "%ImagePath%" equ "" goto :Exit
goto :Start

rem �������� [ %~1 : �����ļ�·�� ]
:MakeWim
if /i "%~x1" equ ".esd" ( call :MakeESD "%~1" && goto :eof )
for /f "tokens=3" %%f in ('Dism.exe /English /Get-ImageInfo /ImageFile:"%~1" ^| findstr /i Index') do ( set "ImageCount=%%f" )
for /l %%f in (1, 1, %ImageCount%) do call :MakeWimIndex "%~1", %%f, "%MNT%"
call :ImageOptimize "%~1"
rem ����ΪESD����
if /i "%~x2" equ ".esd" %Dism% /Export-Image /SourceImageFile:"%~1" /All /DestinationImageFile:"%~2" /CheckIntegrity /Compress:recovery
goto :eof

rem �������� [ %~1 : �����ļ�·�� ]
:MakeESD
setlocal
set "WimPath=%TMP%\%~n1.wim"
Dism.exe /Export-Image /SourceImageFile:"%~1" /All /DestinationImageFile:"%WimPath%" /CheckIntegrity /Compress:max
call :MakeWim "%WimPath%", "%~1"
call :RemoveFile "%WimPath%"
endlocal
goto :eof

rem �������� [ %~1 : �����ļ�·��, %~2 : �������, %~3 : ����·�� ]
:MakeWimIndex
call :GetImageInfo "%~1", %~2
title ���ڴ��� [%~2] ���� %ImageName% �汾 %ImageVersion% ���� %ImageLanguage%
%Dism% /Mount-Wim /WimFile:"%~1" /Index:%~2 /MountDir:"%~3"
call :RemoveAppx "%~3"
for /f %%f in ('type "%~dp0Pack\RemoveList.%ImageVersion%.%ImageArch%.txt" 2^>nul') do call :RemoveComponent "%~3", "%%f"
call :IntRollupFix "%~3"
call :AddAppx "%~3", "DesktopAppInstaller", "VCLibs.14"
call :AddAppx "%~3", "Store", "Runtime.1.6 Framework.1.6"
call :AddAppx "%~3", "FoxitMobilePDF"
call :ImportOptimize "%~3"
call :ImportUnattend "%~3"
call :ImageClean "%~3"
%Dism% /Commit-Image /MountDir:"%~3"
call :ImportUnattend "%~3", "Admin"
call :ImageClean "%~3"
%Dism% /Commit-Image /MountDir:"%~3" /Append
%Dism% /Unmount-Wim /MountDir:"%~3" /Discard
rem ����Admin�־�
set /a "ImageAdmin=%ImageCount%+%~2"
%Dism% /Export-Image /SourceImageFile:"%~1" /SourceIndex:%~2 /DestinationImageFile:"%TMP%\%~nx1"
%Dism% /Export-Image /SourceImageFile:"%~1" /SourceIndex:%ImageAdmin% /DestinationImageFile:"%TMP%\%~nx1" /DestinationName:"%ImageName% [Admin]"
goto :eof

rem ����lopatkin���� [ %~1 : �����ļ�·��, %~2 : �������, %~3 : ����·�� ]
:MakeWimIndex2
call :GetImageInfo "%~1", %~2
title ���ڴ��� [%~2] ���� %ImageName% �汾 %ImageVersion% ���� %ImageLanguage%
%Dism% /Mount-Wim /WimFile:"%~1" /Index:%~2 /MountDir:"%~3"
rem �޸�Ĭ���û�ͷ��
xcopy /E /I /H /R /Y /J "%~dp0Pack\UAP\%ImageShortVersion%\*.*" "%~3\ProgramData\Microsoft\User Account Pictures" >nul
call :MountImageRegistry "%~3"
rem �޸�Ĭ������
call :RemoveFolder "%~3\Windows\Web\Wallpaper\Theme1"
call :RemoveFile "%~3\Windows\Resources\Themes\Theme1.theme"
reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\LastTheme" /v "ThemeFile" /t REG_EXPAND_SZ /d "%%SystemRoot%%\Resources\Themes\Aero.theme" /f >nul
rem �޸��豸������Ӣ��
for /f "tokens=2 delims=@," %%j in ('reg query "HKLM\TK_SYSTEM\ControlSet001\Control\Class" /v "ClassDesc" /s ^| findstr /i inf') do (
    for %%i in (System32\DriverStore\zh-CN INF) do (
        for %%f in (%SystemRoot%\%%i\%%j*) do %NSudo% cmd.exe /c copy /Y "%%f" "%~3\Windows\%%i\%%~nxf"
    )
)
call :UnMountImageRegistry
call :ImportOptimize "%~3"
if "%ImageType%" equ "Server" (
    call :ImportUnattend "%~3"
) else (
    call :ImportUnattend "%~3", "Admin"
)
call :ImageClean "%~3"
%Dism% /Unmount-Wim /MountDir:"%~3" /Commit
goto :eof

rem ############################################################################################
rem ����������
rem ############################################################################################

rem ���ɻ��۸��� [ %~1 : �������·�� ]
:IntRollupFix
setlocal
call :MountImageRegistry "%~1"
rem Enable DISM Image Cleanup with Full ResetBase...
Reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide\Configuration" /v "DisableResetbase" /t REG_DWORD /d "0" /f >nul
call :UnMountImageRegistry
set "UpdatePath=%~dp0Pack\Update\%ImageVersion%.%ImageArch%"
if exist "%UpdatePath%" (
    %Dism% /Image:"%~1" /Add-Package /ScratchDir:"%TMP%" /PackagePath:"%UpdatePath%"
rem %Dism% /Image:"%~1" /Cleanup-Image /ScratchDir:"%TMP%" /StartComponentCleanup /ResetBase
)
call :IntFeature "%~1", "NetFx3"
set "RollupPath=%~dp0Pack\RollupFix\%ImageVersion%.%ImageArch%"
if exist "%RollupPath%" (
    %Dism% /Image:"%~1" /Add-Package /ScratchDir:"%TMP%" /PackagePath:"%RollupPath%"
    call :IntRecovery "%~1", "%RollupPath%"
)
endlocal
%NSudo% cmd.exe /c rd /s /q "%~1\Windows\WinSxS\ManifestCache"
goto :eof

rem �� WinRe ���ɸ��� [ %~1 : �������·��, %~2 ���°�·�� ]
:IntRecovery
setlocal
set "WinrePath=%TMP%\Winre.%ImageVersion%.%ImageArch%.wim"
if not exist "%WinrePath%" (
    call :RemoveFolder "%TMP%\RE"
    md "%TMP%\RE"
    echo.���ؾ��� [%WinrePath%]
    %Dism% /Mount-Wim /WimFile:"%~1\Windows\System32\Recovery\Winre.wim" /Index:1 /MountDir:"%TMP%\RE" /Quiet
    call :MountImageRegistry "%TMP%\RE"
    rem Enable DISM Image Cleanup with Full ResetBase...
    Reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide\Configuration" /v "DisableResetbase" /t REG_DWORD /d "0" /f >nul
    call :UnMountImageRegistry
    echo.���ɸ��� [%WinrePath%]
    %Dism% /Image:"%TMP%\RE" /Add-Package /ScratchDir:"%TMP%" /PackagePath:"%~2" /Quiet
    %Dism% /Image:"%TMP%\RE" /Cleanup-Image /ScratchDir:"%TMP%" /StartComponentCleanup /ResetBase /Quiet
    call :ImageClean "%TMP%\RE"
    echo.���澵�� [%WinrePath%]
    %Dism% /Unmount-Wim /MountDir:"%TMP%\RE" /Commit /Quiet
    echo.�Ż����� [%WinrePath%]
    %Dism% /Export-Image /SourceImageFile:"%~1\Windows\System32\Recovery\Winre.wim" /All /DestinationImageFile:"%WinrePath%" /CheckIntegrity /Compress:max /Quiet
)
copy /Y "%WinrePath%" "%~1\Windows\System32\Recovery\Winre.wim" >nul
endlocal
goto :eof

rem ���ɹ��� [ %~1 : �������·��, %~2 �������� ]
:IntFeature
setlocal
set "FeaturePath=%~dp0Pack\%~2\%ImageVersion%.%ImageArch%"
if not exist "%FeaturePath%" ( echo.δ�ҵ� %FeaturePath% && goto :eof )
%Dism% /Image:"%~1" /Get-FeatureInfo /FeatureName:%~2 | findstr /c:"State : Enable Pending" >nul
if errorlevel 1 (
    echo.�������� [%~2]
    %Dism% /Image:"%~1" /Enable-Feature /All /LimitAccess /FeatureName:%~2 /Source:"%FeaturePath%" /Quiet
) else ( echo.���� [%~2] �ѿ��� )
endlocal
goto :eof

rem �����Ż� [ %~1 : �������·�� ]
:ImportOptimize
call :MountImageRegistry "%~1"
call :ImportRegistry "%~dp0Pack\Optimize\%ImageShortVersion%.reg"
call :ImportRegistry "%~dp0Pack\Optimize\%ImageShortVersion%.%ImageArch%.reg"
if "%ImageType%" equ "Server" call :ImportRegistry "%~dp0Pack\Optimize\Server.reg"
if "%ImageShortVersion%" equ "10.0" (
    rem Applying Anti Microsoft Telemetry Client Patches
    Reg add "HKLM\TK_SYSTEM\ControlSet001\Services\DiagTrack" /v "Start" /t REG_DWORD /d "4" /f >nul
    Reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\AutoLogger-Diagtrack-Listener" /f >nul 2>&1
    Reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\Diagtrack-Listener" /f >nul 2>&1
    Reg delete "HKLM\TK_SYSTEM\ControlSet001\Control\WMI\AutoLogger\SQMLogger" /f >nul 2>&1
    Reg delete "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" /f >nul 2>&1
    Reg delete "HKLM\TK_SOFTWARE\Policies\Microsoft\Windows\DataCollection" /f >nul 2>&1
    rem Removing Windows Mixed Reality Menu from Settings App
    Reg add "HKLM\TK_NTUSER\Software\Microsoft\Windows\CurrentVersion\Holographic" /v "FirstRunSucceeded" /t REG_DWORD /d "0" /f >nul
    rem ������Ƭ�鿴��
    %NSudo% cmd.exe /c "%~dp0Pack\Optimize\Photo.cmd"
    call :ImportRegistry "%~dp0Pack\Optimize\Context.reg"
    call :ImportStartLayout "%~1", "%~dp0Pack\StartLayout.xml"
)
call :UnMountImageRegistry

setlocal
set "AssociationXML=%~dp0Pack\Association.%ImageShortVersion%.xml"
if exist "%AssociationXML%" (
    echo.������� [%AssociationXML%]
    %Dism% /Image:"%~1" /Import-DefaultAppAssociations:"%AssociationXML%" /Quiet
)
endlocal

if "%ImageShortVersion%" equ "10.0" (
    if "%ImageVersion%" geq "10.0.15063" call :IntExtra "%~1", "Win32Calc"
)
goto :eof

rem ���ɶ������ [ %~1 : �������·��, %~2 : ������� ]
:IntExtra
echo.������� [%~2]
setlocal
set "ExtraPath=%~dp0Pack\Extra\%~2"
if "%ImageArch%"=="x86" set "PackageIndex=1"
if "%ImageArch%"=="x64" set "PackageIndex=2"
if exist "%ExtraPath%.tpk" (
   %Dism% /Apply-Image /ImageFile:"%ExtraPath%.tpk" /Index:%PackageIndex% /ApplyDir:"%~1" /CheckIntegrity /Verify /Quiet
)
if exist "%ExtraPath%.%ImageLanguage%.tpk" (
   %Dism% /Apply-Image /ImageFile:"%ExtraPath%.%ImageLanguage%.tpk" /Index:%PackageIndex% /ApplyDir:"%~1" /CheckIntegrity /Verify /Quiet
)
if exist "%ExtraPath%.%ImageArch%.reg" (
    call :MountImageRegistry "%~1"
    call :ImportRegistry "%ExtraPath%.%ImageArch%.reg"
    call :UnMountImageRegistry
)
if exist "%ExtraPath%.cmd" call %ExtraPath%.cmd "%~1" %ImageArch% %ImageLanguage%
endlocal
goto :eof

rem ############################################################################################
rem ���ߺ���
rem ############################################################################################

rem ����Ӧ���ļ� [ %~1 : �������·��, %~2 : Ӧ���ļ�����(Admin, Audit) ]
:ImportUnattend
call :RemoveFolder "%~1\Windows\Setup\Scripts"
md "%~1\Windows\Setup\Scripts"
xcopy /E /I /H /R /Y /J "%~dp0Pack\Scripts\*.*" "%~1\Windows\Setup\Scripts" >nul

setlocal
if /i "%~2" equ "Admin" (
    if exist "%~dp0Pack\AAct_%ImageArch%.exe" copy "%~dp0Pack\AAct_%ImageArch%.exe" "%~1\Windows\Setup\Scripts\AAct.exe" >nul
    
    set "UnattendFile=%~dp0Pack\Unattend.Admin.xml"
    call :MountImageRegistry "%~1"
    Reg add "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "FilterAdministratorToken" /t REG_DWORD /d 1 /f >nul
    call :UnMountImageRegistry
) else (
    set "UnattendFile=%~dp0Pack\Unattend.%ImageShortVersion%.xml"
)
if exist "%UnattendFile%" (
    echo.����Ӧ�� [%UnattendFile%]
    if not exist "%~1\Windows\Panther" md "%~1\Windows\Panther"
    copy /Y "%UnattendFile%" "%~1\Windows\Panther\unattend.xml" >nul
)
endlocal
goto :eof

rem ���뿪ʼ�˵������ļ� [ %~1 : �������·��, %~2 �����ļ�·�� ]
:ImportStartLayout
copy /y "%~2" "%~1\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml" >nul
call :RemoveFile "%~1\Users\Default\AppData\Local\TileDataLayer"
goto :eof

rem ����AppxӦ�� [ %~1 : �������·��, %~2 : Ӧ�ð���, %~3 : Ӧ���������� ]
:AddAppx
setlocal
set "Apps=%~dp0Pack\Appx"
set LicPath=/SkipLicense
if "%ImageArch%" equ "x86" ( set "AppxArch=*x86*" ) else ( set "AppxArch=*" )
for /f %%f in ('"dir /b %Apps%\*%~2*.xml" 2^>nul') do ( set LicPath=/LicensePath:"%Apps%\%%f" )
for %%j in (%~3) do for /f %%i in ('"dir /b %Apps%\*%%j%AppxArch%.appx" 2^>nul') do ( set Dependency=!Dependency! /DependencyPackagePath:"%Apps%\%%i" )
for /f %%i in ('"dir /b %Apps%\*%~2*.appxbundle" 2^>nul') do (
    echo.����Ӧ�� [%%~ni]
    %Dism% /Image:"%~1" /Add-ProvisionedAppxPackage /PackagePath:"%Apps%\%%i" %LicPath% %Dependency% /Quiet
)
endlocal
goto :eof

rem �Ƴ��Դ�Ӧ�� [ %~1 : �������·�� ]
:RemoveAppx
for /f "tokens=3" %%f in ('%Dism% /English /Image:"%~1" /Get-ProvisionedAppxPackages ^| findstr PackageName') do (
    echo.�Ƴ�Ӧ�� [%%f]
    %Dism% /Image:"%~1" /Remove-ProvisionedAppxPackage /PackageName:"%%f" /Quiet
)
goto :eof

rem �Ƴ�ϵͳ��� [ %~1 : �������·��, %~2 : ������� ]
:RemoveComponent
setlocal
rem �����������
call :MountImageRegistry "%~1"
set RegKey=
for /f "tokens=* delims=" %%f in ('reg query "HKLM\TK_SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages" /f "%~2" ^| findstr /i "%~2"') do ( set "RegKey=%%f" )
if "%RegKey%" neq "" (
    %NSudo% reg add "%RegKey%" /v Visibility /t REG_DWORD /d 1 /f
    %NSudo% reg add "%RegKey%" /v DefVis /t REG_DWORD /d 2 /f
    %NSudo% reg delete "%RegKey%\Owners" /f
    set RegKey=
)
call :UnMountImageRegistry

set PackageName=
for /f "tokens=3 delims=: " %%f in ('%Dism% /English /Image:"%~1" /Get-Packages ^| findstr /i "%~2"') do ( set "PackageName=%%f" ) 
if "%PackageName%" neq "" (
    echo.�Ƴ���� [%PackageName%]
    %Dism% /Image:"%~1" /Remove-Package /PackageName:"%PackageName%" /Quiet
    set PackageName=
)
endlocal
goto :eof

rem ����ע��� [ %~1 : ע���·�� ]
:ImportRegistry
if not exist "%~1" goto :eof
call :RemoveFile "%TMP%\%~nx1"
rem ����ע���·��
for /f "delims=" %%f in ('type "%~1"') do (
    set str=%%f
    set "str=!str:HKEY_CURRENT_USER=HKEY_LOCAL_MACHINE\TK_NTUSER!"
    set "str=!str:HKEY_LOCAL_MACHINE\SOFTWARE=HKEY_LOCAL_MACHINE\TK_SOFTWARE!"
    set "str=!str:HKEY_LOCAL_MACHINE\SYSTEM=HKEY_LOCAL_MACHINE\TK_SYSTEM!"
    echo !str!>>"%TMP%\%~nx1"
)
%NSudo% reg import "%TMP%\%~nx1"
goto :eof

rem ����ע��� [ %~1 : �������·�� ]
:MountImageRegistry
reg load HKLM\TK_NTUSER "%~1\Users\Default\ntuser.dat" >nul
reg load HKLM\TK_SOFTWARE "%~1\Windows\System32\config\SOFTWARE" >nul
reg load HKLM\TK_SYSTEM "%~1\Windows\System32\config\SYSTEM" >nul
goto :eof

rem ж��ע���
:UnMountImageRegistry
reg unload HKLM\TK_NTUSER >nul 2>&1
reg unload HKLM\TK_SOFTWARE >nul 2>&1
reg unload HKLM\TK_SYSTEM >nul 2>&1
goto :eof

rem ���澵�� [ %~1 : �������·�� ]
:ImageClean
rd /s /q "%~1\Users\Administrator" >nul 2>&1
rd /s /q "%~1\Program Files\Classic Shell" >nul 2>&1
rd /s /q "%~1\Recovery" >nul 2>&1
rd /s /q "%~1\$RECYCLE.BIN" >nul 2>&1
rd /s /q "%~1\Logs" >nul 2>&1
del /q "%~1\Windows\INF\*.pnf" >nul 2>&1
del /s /q "%~1\*.log" >nul 2>&1
del /s /q /a:h "%~1\*.log" >nul 2>&1
del /s /q /a:h "%~1\*.blf" >nul 2>&1
del /s /q /a:h "%~1\*.regtrans-ms" >nul 2>&1
goto :eof

rem ��ȡ���������Ϣ [ %~1 : �����ļ�·��, %~2 : ������� ]
:GetImageInfo
for /f "tokens=2 delims=:" %%f in ('Dism.exe /English /Get-ImageInfo /ImageFile:"%~1" /Index:%~2 ^| findstr /i Name') do ( set "ImageName=%%f" )
for /f "tokens=3" %%f in ('Dism.exe /English /Get-ImageInfo /ImageFile:"%~1" /Index:%~2 ^| findstr /i Architecture') do ( set "ImageArch=%%f" )
for /f "tokens=3" %%f in ('Dism.exe /English /Get-ImageInfo /ImageFile:"%~1" /Index:%~2 ^| findstr /i Version') do ( set "ImageVersion=%%f" )
for /f "tokens=3" %%f in ('Dism.exe /English /Get-ImageInfo /ImageFile:"%~1" /Index:%~2 ^| findstr /i Edition') do ( set "ImageEdition=%%f" )
for /f "tokens=3" %%f in ('Dism.exe /English /Get-ImageInfo /ImageFile:"%~1" /Index:%~2 ^| findstr /i Installation') do ( set "ImageType=%%f" )
for /f "tokens=* delims=" %%f in ('Dism.exe /English /Get-ImageInfo /ImageFile:"%~1" /Index:%~2 ^| findstr /i Default') do ( set "ImageLanguage=%%f" && set "ImageLanguage=!ImageLanguage:~1,-10!" )
for /f "tokens=1,2 delims=." %%f in ('echo %ImageVersion%') do ( set "ImageShortVersion=%%f.%%g" )
goto :eof

rem �Ż����� [ %~1 : �����ļ�·�� ]
:ImageOptimize
title �����Ż����� %~1
if not exist "%TMP%\%~nx1" %Dism% /Export-Image /SourceImageFile:"%~1" /All /DestinationImageFile:"%TMP%\%~nx1" /CheckIntegrity /Compress:max
move /Y "%TMP%\%~nx1" "%~1" >nul
goto :eof

rem �����ļ�
:CleanUp
call :UnMountImageRegistry
if exist "%MNT%\Windows" ( Dism.exe /Unmount-Wim /MountDir:"%MNT%" /ScratchDir:"%TMP%" /Discard /Quiet )
if exist "%TMP%\RE\Windows" ( Dism.exe /Unmount-Wim /MountDir:"%TMP%\RE" /ScratchDir:"%TMP%" /Discard /Quiet )
Dism.exe /Cleanup-Mountpoints /Quiet
Dism.exe /Cleanup-Wim /Quiet
call :RemoveFolder "%TMP%"
call :RemoveFolder "%MNT%"
if errorlevel 0 goto :eof
goto :Exit

rem ɾ���ļ� [ %~1 : �ļ�·�� ]
:RemoveFile
if exist "%~1" del /f /q "%~1"
goto :eof

rem ɾ��Ŀ¼ [ %~1 : Ŀ¼·�� ]
:RemoveFolder
if exist "%~1" rd /q /s "%~1"
goto :eof

:Exit
call :CleanUp
endlocal EnableDelayedExpansion
title �������
if "%~1" equ "" pause