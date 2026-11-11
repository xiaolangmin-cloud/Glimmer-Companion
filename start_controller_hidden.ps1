$ErrorActionPreference = "Stop"

$env:PYTHONUTF8 = "1"
$env:DEEPSEEK_API_KEY = [Environment]::GetEnvironmentVariable(
    "DEEPSEEK_API_KEY",
    "User"
)
$env:DEEPSEEK_BASE_URL = [Environment]::GetEnvironmentVariable(
    "DEEPSEEK_BASE_URL",
    "User"
)
$env:DEEPSEEK_MODEL = [Environment]::GetEnvironmentVariable(
    "DEEPSEEK_MODEL",
    "User"
)

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = (Get-Command python).Source

Start-Process `
    -FilePath $python `
    -ArgumentList "-m", "controller.main" `
    -WorkingDirectory $projectRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $projectRoot "state\controller-stdout.log") `
    -RedirectStandardError (Join-Path $projectRoot "state\controller-stderr.log")
