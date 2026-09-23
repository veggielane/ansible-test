@echo off
rem Fake Windchill launcher for the lab. A real installation has bin\windchill.exe here.
rem Forwards every argument to FakeLoadFromFile.ps1 and passes its exit code back.
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0FakeLoadFromFile.ps1" %*
exit /b %ERRORLEVEL%
