$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$startup = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startup "Glimmer Companion Bridge.lnk"
$legacyShortcut = Join-Path $startup "Glimmer Companion Game Watcher.lnk"
$stateRoot = Join-Path $projectRoot "state"
$bridgePidPath = Join-Path $stateRoot "companion_bridge.pid"
$legacyWatcherPid = Join-Path $stateRoot "companion_game_watcher.pid"
$bridgeBase = "http://127.0.0.1:8766"
$pythonw = (Get-Command pythonw.exe).Source

if (Test-Path -LiteralPath $legacyShortcut) {
    Remove-Item -LiteralPath $legacyShortcut -Force
}
if (Test-Path -LiteralPath $legacyWatcherPid) {
    try {
        $legacyPid = [int](Get-Content -LiteralPath $legacyWatcherPid -Raw)
        $legacyProcess = Get-Process -Id $legacyPid -ErrorAction Stop
        if ($legacyProcess.ProcessName -match "^powershell") {
            Stop-Process -Id $legacyPid -Force
        }
    } catch {
    }
    Remove-Item -LiteralPath $legacyWatcherPid -Force -ErrorAction SilentlyContinue
}

$bridgeRunning = $false
try {
    Invoke-RestMethod -Uri ($bridgeBase + "/health") -TimeoutSec 2 | Out-Null
    $bridgeRunning = $true
} catch {
}
if (-not $bridgeRunning -and (Test-Path -LiteralPath $bridgePidPath)) {
    try {
        $bridgePid = [int](Get-Content -LiteralPath $bridgePidPath -Raw)
        $bridgeProcess = Get-Process -Id $bridgePid -ErrorAction Stop
        if ($bridgeProcess.ProcessName -match "^pythonw?") {
            $bridgeRunning = $true
        }
    } catch {
    }
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $pythonw
$shortcut.Arguments = "-m controller.launcher_bridge"
$shortcut.WorkingDirectory = $projectRoot
$shortcut.WindowStyle = 7
$shortcut.Description = "微光本地启动桥：进入存档后按需启动控制器"
$shortcut.Save()

if (-not $bridgeRunning) {
    $bridgeArguments = "-m controller.launcher_bridge"
    Start-Process `
        -FilePath $pythonw `
        -ArgumentList $bridgeArguments `
        -WorkingDirectory $projectRoot `
        -WindowStyle Hidden
    Start-Sleep -Seconds 1
}

try {
    $status = Invoke-RestMethod -Uri ($bridgeBase + "/health") -TimeoutSec 3
} catch {
    throw "启动桥未能启动：$($_.Exception.Message)"
}

Write-Host "已安装微光启动桥。"
Write-Host "桥状态：$($status.controller)"
Write-Host "登录启动快捷方式：$shortcutPath"
Write-Host "进入存档后，Mod 才会请求启动完整控制器。"
