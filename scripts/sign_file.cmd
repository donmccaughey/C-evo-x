@echo off
setlocal enableextensions

rem 
rem Sign an executable, DLL or installer file.
rem

set command=%~n0
set file=%~1

if "%file%"=="" (
    echo:
    echo ERROR: missing PATH argument
    goto :usage
)

if "%CEVOX_CERT_PATH%"=="" (
    echo:
    echo ERROR: missing CEVOX_CERT_PATH environment variable
    goto :usage
)

if "%CEVOX_CERT_PWD%"=="" (
    echo:
    echo ERROR: missing CEVOX_CERT_PWD environment variable
    goto :usage
)

if "%CEVOX_TIMESTAMP_URL%"=="" (
    echo ERROR: missing CEVOX_TIMESTAMP_URL environment variable
    goto :usage
)

signtool sign ^
    /q ^
    /tr "%CEVOX_TIMESTAMP_URL%" ^
    /td sha256 ^
    /fd sha256 ^
    /f "%CEVOX_CERT_PATH%" ^
    /p "%CEVOX_CERT_PWD%" ^
    "%file%"
goto :done

:usage
echo:
echo %command% - Sign an executable, DLL or installer file
echo:
echo Usage:
echo:
echo    %command% PATH
echo:
echo Environment Variables:
echo:
echo    CEVOX_CERT_PATH :: Path to the code signing certificate.
echo    CEVOX_CERT_PWD :: Password for the code signing certificate.
echo    CEVOX_TIMESTAMP_URL :: URL for the code signing time stamp server.
exit /b 1

:done

