$ErrorActionPreference = "Stop"
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Set-Location -LiteralPath $PSScriptRoot

if (-not $env:DEEPSEEK_API_KEY) {
    $env:DEEPSEEK_API_KEY = [Environment]::GetEnvironmentVariable(
        "DEEPSEEK_API_KEY",
        "User"
    )
}
if (-not $env:DEEPSEEK_BASE_URL) {
    $env:DEEPSEEK_BASE_URL = [Environment]::GetEnvironmentVariable(
        "DEEPSEEK_BASE_URL",
        "User"
    )
}
if (-not $env:DEEPSEEK_MODEL) {
    $env:DEEPSEEK_MODEL = [Environment]::GetEnvironmentVariable(
        "DEEPSEEK_MODEL",
        "User"
    )
}

if (-not $env:DEEPSEEK_API_KEY) {
    Write-Host "DEEPSEEK_API_KEY 未设置，控制器会保持 hold 模式"
}

python -m controller.main @args
