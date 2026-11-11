from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent.parent
STATE_ROOT = PROJECT_ROOT / "state"
LOG_ROOT = STATE_ROOT / "logs"
CONTROLLER_URL = os.getenv(
    "CODEX_COMPANION_CONTROLLER_URL",
    "http://127.0.0.1:8765",
).rstrip("/")
BRIDGE_HOST = os.getenv("CODEX_COMPANION_BRIDGE_HOST", "127.0.0.1")
BRIDGE_PORT = int(os.getenv("CODEX_COMPANION_BRIDGE_PORT", "8766"))
GAME_PROCESS_NAMES = {
    "dontstarve_steam",
    "dontstarve_steam_x64",
    "dontstarve_dedicated_server_nullrenderer",
    "dontstarve_dedicated_server_nullrenderer_x64",
}


def controller_ready(timeout: float = 0.8) -> bool:
    try:
        with urllib.request.urlopen(
            CONTROLLER_URL + "/health",
            timeout=timeout,
        ) as response:
            return response.status == 200
    except (OSError, urllib.error.URLError):
        return False


def game_running() -> bool:
    if os.name != "nt":
        return False
    import ctypes
    from ctypes import wintypes

    class ProcessEntry32W(ctypes.Structure):
        _fields_ = [
            ("dwSize", wintypes.DWORD),
            ("cntUsage", wintypes.DWORD),
            ("th32ProcessID", wintypes.DWORD),
            ("th32DefaultHeapID", ctypes.c_size_t),
            ("th32ModuleID", wintypes.DWORD),
            ("cntThreads", wintypes.DWORD),
            ("th32ParentProcessID", wintypes.DWORD),
            ("pcPriClassBase", wintypes.LONG),
            ("dwFlags", wintypes.DWORD),
            ("szExeFile", wintypes.WCHAR * 260),
        ]

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateToolhelp32Snapshot.argtypes = [
        wintypes.DWORD,
        wintypes.DWORD,
    ]
    kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel32.Process32FirstW.argtypes = [
        wintypes.HANDLE,
        ctypes.POINTER(ProcessEntry32W),
    ]
    kernel32.Process32FirstW.restype = wintypes.BOOL
    kernel32.Process32NextW.argtypes = [
        wintypes.HANDLE,
        ctypes.POINTER(ProcessEntry32W),
    ]
    kernel32.Process32NextW.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]

    snapshot = kernel32.CreateToolhelp32Snapshot(0x00000002, 0)
    if snapshot == wintypes.HANDLE(-1).value:
        return False
    entry = ProcessEntry32W()
    entry.dwSize = ctypes.sizeof(ProcessEntry32W)
    try:
        found = bool(kernel32.Process32FirstW(snapshot, ctypes.byref(entry)))
        while found:
            name = str(entry.szExeFile).lower()
            if name.endswith(".exe"):
                name = name[:-4]
            if name in GAME_PROCESS_NAMES:
                return True
            found = bool(kernel32.Process32NextW(snapshot, ctypes.byref(entry)))
        return False
    finally:
        kernel32.CloseHandle(snapshot)


class LauncherBridge:
    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._controller: subprocess.Popen[bytes] | None = None
        self._started_by_bridge = False
        self._last_game_seen = 0.0
        self._monitor = threading.Thread(
            target=self._monitor_loop,
            name="companion-bridge-monitor",
            daemon=True,
        )
        self._monitor.start()

    def _controller_alive(self) -> bool:
        with self._lock:
            process = self._controller
            if process is None:
                return False
            if process.poll() is None:
                return True
            self._controller = None
            self._started_by_bridge = False
            return False

    def status(self) -> dict[str, Any]:
        ready = controller_ready()
        with self._lock:
            if ready:
                state = "ready"
            elif self._controller_alive():
                state = "starting"
            else:
                state = "stopped"
        return {
            "ok": True,
            "controller": state,
            "controller_url": CONTROLLER_URL,
        }

    def start_controller(self) -> dict[str, Any]:
        if controller_ready():
            with self._lock:
                self._last_game_seen = time.monotonic()
            return self.status()
        with self._lock:
            if self._controller_alive():
                return self.status()
            STATE_ROOT.mkdir(parents=True, exist_ok=True)
            LOG_ROOT.mkdir(parents=True, exist_ok=True)
            stdout_path = LOG_ROOT / "controller-auto.stdout.log"
            stderr_path = LOG_ROOT / "controller-auto.stderr.log"
            stdout = stdout_path.open("ab")
            stderr = stderr_path.open("ab")
            env = os.environ.copy()
            env["PYTHONUTF8"] = "1"
            env["PYTHONIOENCODING"] = "utf-8"
            creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
            self._controller = subprocess.Popen(
                [sys.executable, "-m", "controller.main"],
                cwd=PROJECT_ROOT,
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=stdout,
                stderr=stderr,
                creationflags=creationflags,
            )
            stdout.close()
            stderr.close()
            self._started_by_bridge = True
            self._last_game_seen = time.monotonic()
        return self.status()

    def stop_owned_controller(self) -> None:
        with self._lock:
            process = self._controller
            owned = self._started_by_bridge
        if not owned or process is None or process.poll() is not None:
            return
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)
        with self._lock:
            self._controller = None
            self._started_by_bridge = False

    def _monitor_loop(self) -> None:
        while True:
            running = game_running()
            now = time.monotonic()
            with self._lock:
                if running:
                    self._last_game_seen = now
                should_stop = (
                    self._started_by_bridge
                    and not running
                    and now - self._last_game_seen > 12
                )
                process = self._controller
            if should_stop and process is not None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
                with self._lock:
                    self._controller = None
                    self._started_by_bridge = False
            time.sleep(3)


class BridgeRequestHandler(BaseHTTPRequestHandler):
    server: "BridgeHTTPServer"

    def log_message(self, fmt: str, *args: Any) -> None:
        return

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path in {"/health", "/status"}:
            self._send_json(200, self.server.bridge.status())
            return
        self._send_json(404, {"ok": False, "error": "not_found"})

    def do_POST(self) -> None:
        if self.path == "/start":
            self._send_json(200, self.server.bridge.start_controller())
            return
        if self.path == "/stop":
            self.server.bridge.stop_owned_controller()
            self._send_json(200, self.server.bridge.status())
            return
        self._send_json(404, {"ok": False, "error": "not_found"})


class BridgeHTTPServer(ThreadingHTTPServer):
    def __init__(self, address: tuple[str, int]) -> None:
        self.bridge = LauncherBridge()
        super().__init__(address, BridgeRequestHandler)


def main() -> None:
    STATE_ROOT.mkdir(parents=True, exist_ok=True)
    pid_path = STATE_ROOT / "companion_bridge.pid"
    pid_path.write_text(str(os.getpid()), encoding="utf-8")
    server = BridgeHTTPServer((BRIDGE_HOST, BRIDGE_PORT))
    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        try:
            pid_path.unlink()
        except OSError:
            pass


if __name__ == "__main__":
    main()
