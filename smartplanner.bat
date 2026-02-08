@echo off
setlocal

if "%1"=="" (
    echo Usage: smartplanner.bat [start^|stop^|restart^|shell]
    exit /b 1
)

if "%1"=="start" (
    echo Starting SmartPlanner node...
    start "SmartPlanner" rebar3 shell --sname smartplanner
    exit /b 0
)

if "%1"=="stop" (
    echo Stopping SmartPlanner node...
    for /f "delims=" %%i in ('hostname') do set HOSTNAME=%%i
    erl -sname stopper -noshell -eval "rpc:call('smartplanner@Tildugo', smartplanner_backend_app, shutdown, []), halt()."
    timeout /t 2 /nobreak >nul
    echo SmartPlanner stopped.
    exit /b 0
)

if "%1"=="restart" (
    echo Restarting SmartPlanner node...
    call %0 stop
    timeout /t 2 /nobreak >nul
    call %0 start
    exit /b 0
)

if "%1"=="shell" (
    echo Connecting to SmartPlanner node...
    for /f "delims=" %%i in ('hostname') do set HOSTNAME=%%i
    erl -sname shell_%RANDOM% -remsh smartplanner@%HOSTNAME%
    exit /b 0
)

echo Unknown command: %1
echo Usage: smartplanner.bat [start^|stop^|restart^|shell]
exit /b 1