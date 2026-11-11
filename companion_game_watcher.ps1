$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$stateRoot = Join-Path $projectRoot "state"
$logRoot = Join-Path $stateRoot "logs"
$watcherPidPath = Join-Path $stateRoot "companion_game_watcher.pid"
$watcherLog = Join-Path $logRoot "companion-game-watcher.log"
$controllerOut = Join-Path $logRoot "controller-auto.stdout.log"
$controllerErr = Join-Path $logRoot "controller-auto.stderr.log"
$controllerBase = "http://127.0.0.1:8765"
$controllerProcess = $null

New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
Set-Content -LiteralPath $watcherPidPath -Value $PID -Encoding utf8

function Write-WatcherLog {
    param([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content `
        -LiteralPath $watcherLog `
        -Value "[$stamp] $Message" `
        -Encoding utf8
}

function Test-ControllerReady {
    try {
        Invoke-RestMethod `
            -Uri ($controllerBase + "/health") `
            -TimeoutSec 2 | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-GameProcess {
    return Get-Process `
        -Name "dontstarve_steam_x64", "dontstarve_steam" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

function Set-UserEnvironment {
    foreach ($name in @(
        "DEEPSEEK_API_KEY",
        "DEEPSEEK_BASE_URL",
        "DEEPSEEK_MODEL",
        "CODEX_COMPANION_CHARACTER"
    )) {
        $processValue = [Environment]::GetEnvironmentVariable($name, "Process")
        if (-not $processValue) {
            $userValue = [Environment]::GetEnvironmentVariable($name, "User")
            if ($userValue) {
                [Environment]::SetEnvironmentVariable(
                    $name,
                    $userValue,
                    "Process"
                )
            }
        }
    }
}

function Start-CompanionController {
    if (Test-ControllerReady) {
        return
    }
    if ($script:controllerProcess -ne $null) {
        try {
            if (-not $script:controllerProcess.HasExited) {
                return
            }
        } catch {
        }
    }

    Set-UserEnvironment
    $env:PYTHONUTF8 = "1"
    $env:PYTHONIOENCODING = "utf-8"
    $script:controllerProcess = Start-Process `
        -FilePath "python" `
        -ArgumentList "-m", "controller.main" `
        -WorkingDirectory $projectRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $controllerOut `
        -RedirectStandardError $controllerErr `
        -PassThru
    Write-WatcherLog (
        "game detected; controller started, pid=" +
        $script:controllerProcess.Id
    )
}

function Stop-AutoController {
    if ($script:controllerProcess -eq $null) {
        return
    }
    try {
        if (-not $script:controllerProcess.HasExited) {
            Stop-Process `
                -Id $script:controllerProcess.Id `
                -Force `
                -ErrorAction SilentlyContinue
            Write-WatcherLog "game closed; auto-started controller stopped"
        }
    } catch {
    }
    $script:controllerProcess = $null
}

Write-WatcherLog "watcher started, pid=$PID"
try {
    while ($true) {
        $game = Get-GameProcess
        if ($game -ne $null) {
            Start-CompanionController
        } elseif ($script:controllerProcess -ne $null) {
            Stop-AutoController
        }
        Start-Sleep -Seconds 3
    }
} finally {
    Stop-AutoController
    Remove-Item -LiteralPath $watcherPidPath -Force -ErrorAction SilentlyContinue
    Write-WatcherLog "watcher stopped"
}
