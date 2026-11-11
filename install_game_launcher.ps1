$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "Don't Starve Together - 微光.lnk"
$launcherScript = Join-Path $projectRoot "play_with_companion.ps1"
$startup = [Environment]::GetFolderPath("Startup")
$legacyShortcut = Join-Path $startup "Glimmer Companion Bridge.lnk"

if (Test-Path -LiteralPath $legacyShortcut) {
    Remove-Item -LiteralPath $legacyShortcut -Force
}

$arguments = (
    "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden " +
    "-File `"$launcherScript`""
)
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = $arguments
$shortcut.WorkingDirectory = $projectRoot
$shortcut.WindowStyle = 7
$shortcut.Description = "启动饥荒联机版；进入存档后自动启动微光控制器"
$shortcut.Save()

Write-Host "已创建桌面启动快捷方式："
Write-Host $shortcutPath
Write-Host "请以后从这个快捷方式启动游戏。游戏关闭时会同时停止启动桥和控制器。"
