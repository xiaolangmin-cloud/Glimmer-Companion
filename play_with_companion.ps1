$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$stateRoot = Join-Path $projectRoot "state"
$bridgePidPath = Join-Path $stateRoot "companion_bridge.pid"
$bridgeBase = "http://127.0.0.1:8766"
$pythonw = (Get-Command pythonw.exe).Source
$bridgeProcess = $null
$launcherLog = Join-Path $stateRoot "logs\launcher-latest.log"

function Write-LauncherLog {
    param([string]$Message)
    $logDirectory = Split-Path -Parent $launcherLog
    if (-not (Test-Path -LiteralPath $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }
    $line = "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $Message
    Add-Content -LiteralPath $launcherLog -Value $line -Encoding utf8
}

function Test-BridgeReady {
    try {
        Invoke-RestMethod -Uri ($bridgeBase + "/health") -TimeoutSec 2 | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Start-Bridge {
    if (Test-BridgeReady) {
        Write-LauncherLog "已有启动桥正在运行"
        return
    }
    Write-LauncherLog "正在启动本地启动桥"
    $script:bridgeProcess = Start-Process `
        -FilePath $pythonw `
        -ArgumentList "-m controller.launcher_bridge" `
        -WorkingDirectory $projectRoot `
        -WindowStyle Hidden `
        -PassThru
    $deadline = (Get-Date).AddSeconds(12)
    do {
        Start-Sleep -Milliseconds 300
        if (Test-BridgeReady) {
            Write-LauncherLog "本地启动桥已就绪"
            return
        }
    } while ((Get-Date) -lt $deadline)
    throw "微光启动桥未能就绪。"
}

function Get-GameProcess {
    return Get-Process `
        -Name "dontstarve_steam_x64", "dontstarve_steam" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

function Find-GameExecutable {
    $candidates = New-Object System.Collections.Generic.List[string]
    try {
        $steamRoot = (Get-ItemProperty `
            -Path "HKCU:\Software\Valve\Steam" `
            -ErrorAction Stop).SteamPath
        if (-not [string]::IsNullOrWhiteSpace($steamRoot)) {
            $candidates.Add((Join-Path `
                $steamRoot `
                "steamapps\common\Don't Starve Together\bin64\dontstarve_steam_x64.exe"))
            $foldersFile = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
            if (Test-Path -LiteralPath $foldersFile) {
                $foldersText = Get-Content -LiteralPath $foldersFile -Raw
                foreach ($match in [regex]::Matches(
                    $foldersText,
                    '"path"\s+"([^"]+)"'
                )) {
                    $libraryRoot = $match.Groups[1].Value.Replace("\\", "\")
                    $candidates.Add((Join-Path `
                        $libraryRoot `
                        "steamapps\common\Don't Starve Together\bin64\dontstarve_steam_x64.exe"))
                }
            }
        }
    } catch {
        Write-LauncherLog "读取 Steam 安装路径失败：$($_.Exception.Message)"
    }
    $candidates.Add(
        "D:\Steam\steamapps\common\Don't Starve Together\bin64\dontstarve_steam_x64.exe"
    )
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }
    return $null
}

function Start-Game {
    $game = Get-GameProcess
    if ($game -ne $null) {
        Write-LauncherLog "检测到游戏已经在运行"
        return $game
    }

    Write-LauncherLog "正在通过 Steam 启动游戏"
    try {
        Start-Process "steam://rungameid/322330"
    } catch {
        Write-LauncherLog "Steam 协议启动失败：$($_.Exception.Message)"
    }
    $deadline = (Get-Date).AddSeconds(20)
    do {
        Start-Sleep -Seconds 1
        $game = Get-GameProcess
    } while ($game -eq $null -and (Get-Date) -lt $deadline)

    if ($game -eq $null) {
        $gameExecutable = Find-GameExecutable
        if ($gameExecutable -ne $null) {
            Write-LauncherLog "Steam 未启动游戏，改为直接启动：$gameExecutable"
            Start-Process `
                -FilePath $gameExecutable `
                -WorkingDirectory (Split-Path -Parent $gameExecutable)
        } else {
            Write-LauncherLog "没有找到联机版可执行文件"
        }
    }

    $deadline = (Get-Date).AddSeconds(90)
    do {
        Start-Sleep -Seconds 1
        $game = Get-GameProcess
    } while ($game -eq $null -and (Get-Date) -lt $deadline)
    if ($game -eq $null) {
        throw "没有检测到《饥荒联机版》启动。请检查 Steam 是否正常登录。"
    }
    Write-LauncherLog "游戏进程已启动"
    return $game
}

function Stop-Bridge {
    try {
        Invoke-RestMethod `
            -Uri ($bridgeBase + "/stop") `
            -Method Post `
            -ContentType "application/json" `
            -Body "{}" `
            -TimeoutSec 3 | Out-Null
    } catch {
    }
    if ($script:bridgeProcess -ne $null) {
        try {
            if (-not $script:bridgeProcess.HasExited) {
                Start-Sleep -Milliseconds 300
                Stop-Process `
                    -Id $script:bridgeProcess.Id `
                    -Force `
                    -ErrorAction SilentlyContinue
            }
        } catch {
        }
    }
    if (Test-Path -LiteralPath $bridgePidPath) {
        try {
            $bridgePid = [int](Get-Content -LiteralPath $bridgePidPath -Raw)
            $process = Get-Process -Id $bridgePid -ErrorAction SilentlyContinue
            if ($process -ne $null -and $process.ProcessName -match "^pythonw?") {
                Stop-Process -Id $bridgePid -Force -ErrorAction SilentlyContinue
            }
        } catch {
        }
    }
    if (Test-Path -LiteralPath $bridgePidPath) {
        Remove-Item `
            -LiteralPath $bridgePidPath `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

try {
    Write-LauncherLog "启动快捷方式"
    Start-Bridge
    $game = Start-Game
    while ($true) {
        Start-Sleep -Seconds 2
        if ((Get-GameProcess) -eq $null) {
            break
        }
    }
} catch {
    Write-LauncherLog "启动失败：$($_.Exception.Message)"
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        $_.Exception.Message,
        "微光游戏启动器",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
} finally {
    Stop-Bridge
}
