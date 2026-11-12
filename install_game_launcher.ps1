$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "Don't Starve Together - 微光.lnk"
$launcherScript = Join-Path $projectRoot "play_with_companion.ps1"
$startup = [Environment]::GetFolderPath("Startup")
$legacyShortcut = Join-Path $startup "Glimmer Companion Bridge.lnk"

function Find-DstExecutable {
    if ($env:DST_GAME_EXECUTABLE -and (Test-Path -LiteralPath $env:DST_GAME_EXECUTABLE)) {
        return $env:DST_GAME_EXECUTABLE
    }
    $libraries = @()
    try {
        $steamPath = Get-ItemPropertyValue `
            -Path "HKCU:\Software\Valve\Steam" `
            -Name "SteamPath"
        if ($steamPath) {
            $libraries += $steamPath.Replace("/", "\")
        }
    } catch {
    }
    foreach ($fallback in @("D:\Steam", "C:\Program Files (x86)\Steam")) {
        if (Test-Path -LiteralPath $fallback) {
            $libraries += $fallback
        }
    }
    if ($libraries.Count -gt 0) {
        $vdf = Join-Path $libraries[0] "steamapps\libraryfolders.vdf"
        if (Test-Path -LiteralPath $vdf) {
            $content = Get-Content -LiteralPath $vdf -Raw
            foreach ($match in [regex]::Matches($content, '"path"\s+"([^"]+)"')) {
                $libraries += $match.Groups[1].Value.Replace("\\", "\")
            }
        }
    }
    foreach ($library in ($libraries | Select-Object -Unique)) {
        foreach ($relative in @(
            "steamapps\common\Don't Starve Together\bin64\dontstarve_steam_x64.exe",
            "steamapps\common\Don't Starve Together\bin\dontstarve_steam.exe"
        )) {
            $candidate = Join-Path $library $relative
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }
    return $null
}

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
$dstExecutable = Find-DstExecutable
if ($dstExecutable) {
    $shortcut.IconLocation = "$dstExecutable,0"
}
$shortcut.Save()

Start-Process `
    -FilePath "$env:WINDIR\System32\ie4uinit.exe" `
    -ArgumentList "-show" `
    -WindowStyle Hidden `
    -Wait `
    -ErrorAction SilentlyContinue

Write-Host "已创建桌面启动快捷方式："
Write-Host $shortcutPath
if ($dstExecutable) {
    Write-Host "快捷方式图标：$dstExecutable"
} else {
    Write-Host "未自动找到联机版程序，快捷方式暂用系统图标。"
}
Write-Host "请以后从这个快捷方式启动游戏。游戏关闭时会同时停止启动桥和控制器。"
