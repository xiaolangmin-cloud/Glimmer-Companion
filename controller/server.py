from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlparse

from .config import Settings
from .service import CompanionService


class CompanionRequestHandler(BaseHTTPRequestHandler):
    server: "CompanionHTTPServer"

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"[http] {self.address_string()} {fmt % args}")

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        value = json.loads(raw.decode("utf-8"))
        if not isinstance(value, dict):
            raise ValueError("request body must be a JSON object")
        return value

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, {"ok": True, "state": self.server.service.state()})
            return
        if self.path == "/command":
            self._send_json(200, self.server.service.state())
            return
        if self.path == "/gaps":
            self._send_json(
                200,
                {
                    "gaps": self.server.service.agent_memory.open_capability_gaps()
                },
            )
            return
        parsed = urlparse(self.path)
        if parsed.path == "/logs":
            query = parse_qs(parsed.query)
            try:
                limit = int(query.get("limit", ["100"])[0])
            except ValueError as exc:
                raise ValueError("limit must be an integer") from exc
            limit = max(1, min(limit, 300))
            self._send_json(
                200,
                {
                    "path": str(self.server.service.journal.latest_path),
                    "events": self.server.service.journal.recent(limit),
                },
            )
            return
        self._send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        try:
            payload = self._read_json()
            if self.path in {"/tick", "/observe"}:
                state = self.server.service.tick(payload)
                self._send_json(200, state)
                return
            if self.path == "/instruction":
                text = payload.get("text")
                if not isinstance(text, str):
                    raise ValueError("instruction text is required")
                state = self.server.service.instruction(text)
                self._send_json(200, state)
                return
            if self.path == "/message":
                text = payload.get("text")
                if not isinstance(text, str):
                    raise ValueError("message text is required")
                state = self.server.service.message(text)
                self._send_json(200, state)
                return
            if self.path == "/chat":
                text = payload.get("text")
                if not isinstance(text, str):
                    raise ValueError("chat text is required")
                state = self.server.service.chat(text)
                self._send_json(200, state)
                return
            if self.path == "/command":
                state = self.server.service.force_command(payload)
                self._send_json(200, state)
                return
            self._send_json(404, {"error": "not_found"})
        except (ValueError, json.JSONDecodeError) as exc:
            self._send_json(400, {"error": str(exc)})


class CompanionHTTPServer(ThreadingHTTPServer):
    def __init__(
        self,
        address: tuple[str, int],
        service: CompanionService,
    ) -> None:
        self.service = service
        super().__init__(address, CompanionRequestHandler)


def create_server(settings: Settings, service: CompanionService) -> CompanionHTTPServer:
    return CompanionHTTPServer((settings.host, settings.port), service)
