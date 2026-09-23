@echo off
rem Fake xconfmanager for the lab. A real installation has bin\xconfmanager.exe here.
rem Forwards every argument to FakeXconfManager.ps1 and passes its exit code back.
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0FakeXconfManager.ps1" %*
exit /b %ERRORLEVEL%
