$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$startup = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startup "Glimmer Companion Bridge.lnk"
$bridgePidPath = Join-Path $projectRoot "state\companion_bridge.pid"
$bridgeBase = "http://127.0.0.1:8766"

try {
    Invoke-RestMethod `
        -Uri ($bridgeBase + "/stop") `
        -Method Post `
        -ContentType "application/json" `
        -Body "{}" `
        -TimeoutSec 3 | Out-Null
} catch {
}

if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
}
if (Test-Path -LiteralPath $bridgePidPath) {
    try {
        $bridgePid = [int](Get-Content -LiteralPath $bridgePidPath -Raw)
        $process = Get-Process -Id $bridgePid -ErrorAction Stop
        if ($process.ProcessName -match "^pythonw?") {
            Stop-Process -Id $bridgePid -Force
        }
    } catch {
    }
    Remove-Item -LiteralPath $bridgePidPath -Force -ErrorAction SilentlyContinue
}

Write-Host "已移除微光启动桥。"
