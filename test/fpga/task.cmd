@echo off
setlocal
verify >nul
C:\Users\pauli\.apio\bin\apio.exe api echo -t "Project / make / upload" -s EMPH3
echo.
 
echo $ chdir /d "c:\Users\pauli\.apio\tmp\apio-FPGA_Testing"
chdir /d "c:\Users\pauli\.apio\tmp\apio-FPGA_Testing"
set "ERR=%errorlevel%"
if %ERR% neq 0 (
  echo.
  C:\Users\pauli\.apio\bin\apio.exe api echo -t "Task failed." -s ERROR
  exit /b 0
)
 
echo $ C:\Users\pauli\.apio\bin\apio.exe upload 
C:\Users\pauli\.apio\bin\apio.exe upload 
set "ERR=%errorlevel%"
if %ERR% neq 0 (
  echo.
  C:\Users\pauli\.apio\bin\apio.exe api echo -t "Task failed." -s ERROR
  exit /b 0
)
 
echo.
C:\Users\pauli\.apio\bin\apio.exe api echo -t "Task completed successfully." -s OK
exit /b 0
