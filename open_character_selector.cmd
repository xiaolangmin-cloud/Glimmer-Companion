@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$base='http://127.0.0.1:8765';" ^
  "try {" ^
  "  Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri ($base + '/health') | Out-Null;" ^
  "  Start-Process ($base + '/character');" ^
  "} catch {" ^
  "  Add-Type -AssemblyName PresentationFramework;" ^
  "  [System.Windows.MessageBox]::Show('控制器尚未启动。请先运行 start_companion.cmd。','微光角色选择') | Out-Null;" ^
  "  exit 1" ^
  "}"
