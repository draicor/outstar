@echo off
:: Change to the directory where this batch is
cd /d "%~dp0"

:: Find the first .exe file in this directory
set "exefile="
for %%i in (*.exe) do (
    if not defined exefile set "exefile=%%i"
)

:: Check if we found an executable
if not defined exefile (
    echo ERROR: No game executable found in this folder!
    timeout /t 5
    exit /b 1
)

:: Launch the game with OpenGL3
echo Launching: %exefile%
start "" "%exefile%" --rendering-driver opengl3