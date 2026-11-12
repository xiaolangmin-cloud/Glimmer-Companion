$ErrorActionPreference = "Stop"
$base = "http://127.0.0.1:8765"

try {
    Invoke-WebRequest `
        -UseBasicParsing `
        -TimeoutSec 2 `
        -Uri ($base + "/health") | Out-Null
    Start-Process ($base + "/character")
} catch {
    Add-Type -AssemblyName PresentationFramework
    $message = (
        "控制器尚未启动，或角色窗口服务不可用。`n`n" +
        "请先运行 start_companion.cmd，并保持控制器窗口开启。`n`n" +
        "错误信息：$($_.Exception.Message)"
    )
    [System.Windows.MessageBox]::Show(
        $message,
        "微光角色选择",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    ) | Out-Null
    exit 1
}
