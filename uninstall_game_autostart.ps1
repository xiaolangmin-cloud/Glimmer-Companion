$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$startup = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startup "Glimmer Companion Game Watcher.lnk"
$watcherPidPath = Join-Path $projectRoot "state\companion_game_watcher.pid"

if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
}

if (Test-Path -LiteralPath $watcherPidPath) {
    try {
        $watcherPid = [int](Get-Content -LiteralPath $watcherPidPath -Raw)
        $process = Get-Process -Id $watcherPid -ErrorAction Stop
        if ($process.ProcessName -match "^powershell") {
            Stop-Process -Id $watcherPid -Force
        }
    } catch {
    }
    Remove-Item -LiteralPath $watcherPidPath -Force -ErrorAction SilentlyContinue
}

Write-Host "已移除微光游戏启动监视器。"
