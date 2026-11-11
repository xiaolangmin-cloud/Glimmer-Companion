from __future__ import annotations

import threading
import time

from .config import Settings
from .server import create_server
from .service import CompanionService


def _message_loop(service: CompanionService) -> None:
    seen: set[str] = set()
    while True:
        for message in service.state().get("messages", []):
            message_id = message.get("id")
            if message_id in seen:
                continue
            seen.add(message_id)
            print(f"[伴侣] {message.get('text', '')}")
        time.sleep(0.4)

def _log_loop(service: CompanionService) -> None:
    last_seq = max(
        (event.get("seq", 0) for event in service.journal.recent(1)),
        default=0,
    )
    while True:
        for event in service.journal.recent(50):
            if event.get("seq", 0) <= last_seq:
                continue
            last_seq = event["seq"]
            kind = str(event.get("kind", ""))
            if not kind.startswith("game.") and kind != "model.error":
                continue
            stamp = str(event.get("time", ""))[11:19]
            print(f"[日志 {stamp}] {event.get('message', '')}")
        time.sleep(0.5)


def main() -> None:
    settings = Settings.from_env()
    service = CompanionService(settings)
    service.start()
    server = create_server(settings, service)
    threading.Thread(
        target=_message_loop,
        args=(service,),
        name="companion-console-messages",
        daemon=True,
    ).start()
    threading.Thread(
        target=_log_loop,
        args=(service,),
        name="companion-console-log",
        daemon=True,
    ).start()
    print(
        f"[companion] listening on http://{settings.host}:{settings.port} "
        f"model={settings.deepseek_model}; input is in-game chat"
    )
    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        pass
    finally:
        server.shutdown()
        server.server_close()
        service.stop()


if __name__ == "__main__":
    main()
