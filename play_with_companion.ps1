$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$stateRoot = Join-Path $projectRoot "state"
$bridgePidPath = Join-Path $stateRoot "companion_bridge.pid"
$bridgeBase = "http://127.0.0.1:8766"
$pythonw = (Get-Command pythonw.exe).Source
$bridgeProcess = $null

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
        return
    }
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
    Start-Bridge
    $game = Get-GameProcess
    if ($game -eq $null) {
        Start-Process "steam://rungameid/322330"
        $deadline = (Get-Date).AddSeconds(90)
        do {
            Start-Sleep -Seconds 1
            $game = Get-GameProcess
        } while ($game -eq $null -and (Get-Date) -lt $deadline)
        if ($game -eq $null) {
            throw "没有检测到《饥荒联机版》启动。"
        }
    }
    while ($true) {
        Start-Sleep -Seconds 2
        if ((Get-GameProcess) -eq $null) {
            break
        }
    }
} catch {
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
