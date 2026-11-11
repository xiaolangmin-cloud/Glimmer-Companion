$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$startup = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startup "Glimmer Companion Game Watcher.lnk"
$watcherScript = Join-Path $projectRoot "companion_game_watcher.ps1"
$stateRoot = Join-Path $projectRoot "state"
$watcherPidPath = Join-Path $stateRoot "companion_game_watcher.pid"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = (
    "-NoProfile -WindowStyle Hidden " +
    "-ExecutionPolicy Bypass " +
    "-File `"$watcherScript`""
)
$shortcut.WorkingDirectory = $projectRoot
$shortcut.WindowStyle = 7
$shortcut.Description = "当饥荒联机版启动时自动启动微光控制器"
$shortcut.Save()

$running = $false
if (Test-Path -LiteralPath $watcherPidPath) {
    try {
        $watcherPid = [int](Get-Content -LiteralPath $watcherPidPath -Raw)
        $process = Get-Process -Id $watcherPid -ErrorAction Stop
        if ($process.ProcessName -match "^powershell") {
            $running = $true
        }
    } catch {
    }
}

if (-not $running) {
    $watcherArguments = (
        "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass " +
        "-File `"$watcherScript`""
    )
    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList $watcherArguments `
        -WorkingDirectory $projectRoot `
        -WindowStyle Hidden
}

Write-Host "已安装微光游戏启动监视器。"
Write-Host "监视器：$watcherScript"
Write-Host "登录启动快捷方式：$shortcutPath"
