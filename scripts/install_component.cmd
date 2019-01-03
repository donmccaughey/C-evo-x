@echo off
setlocal enableextensions

rem 
rem Install a Delphi 4 Component Package (.bpl file)
rem

set command=%~n0
set action=%~1
set value=%~f2
set description=%~3

set key="HKCU\Software\Borland\Delphi\4.0\Known Packages"

if "%action%"=="" goto :usage
if "%value%"=="" goto :usage

if "%action%"=="add" goto :add
if "%action%"=="delete" goto :delete

goto :usage

:add
if not exist "%value%" goto :usage
if "%description%"=="" goto :usage
reg add %key% /v "%value%" /t REG_SZ /d "%description%" /f
goto :done

:delete
reg delete %key% /v "%value%" /f
goto :done

:usage
echo:
echo %command% - Install a Delphi 4 Component Package (.bpl file)
echo:
echo Usage:
echo:
echo    %command% add COMPONENT_PATH DESCRIPTION
echo or
echo    %command% delete COMPONENT_PATH
exit /b 1

:done

