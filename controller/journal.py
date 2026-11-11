from __future__ import annotations

import json
import threading
from collections import deque
from datetime import datetime
from pathlib import Path
from typing import Any


class CompanionJournal:
    """Thread-safe, human-readable and machine-readable companion log."""

    def __init__(self, log_dir: Path, recent_limit: int = 300) -> None:
        self.log_dir = log_dir
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.latest_path = self.log_dir / "companion-latest.log"
        self._events: deque[dict[str, Any]] = deque(maxlen=recent_limit)
        self._lock = threading.RLock()
        self._sequence = 0

    @staticmethod
    def _now() -> datetime:
        return datetime.now().astimezone()

    def _rotate_latest_if_needed(self, path: Path, incoming: int) -> None:
        if not path.exists() or path.stat().st_size + incoming <= 5 * 1024 * 1024:
            return
        rotated = path.with_name(
            f"{path.stem}-{self._now().strftime('%Y%m%d-%H%M%S')}.log"
        )
        path.replace(rotated)

    def record(
        self,
        kind: str,
        message: str,
        *,
        level: str = "info",
        data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        now = self._now()
        with self._lock:
            self._sequence += 1
            event: dict[str, Any] = {
                "seq": self._sequence,
                "time": now.isoformat(timespec="seconds"),
                "level": level,
                "kind": kind,
                "message": message,
            }
            if data:
                event["data"] = data

            daily_path = self.log_dir / f"companion-{now:%Y-%m-%d}.jsonl"
            payload = json.dumps(event, ensure_ascii=False, separators=(",", ":"))
            with daily_path.open("a", encoding="utf-8", newline="\n") as handle:
                handle.write(payload + "\n")

            readable = (
                f"{now:%Y-%m-%d %H:%M:%S} [{level.upper()}] "
                f"[{kind}] {message}\n"
            )
            encoded_size = len(readable.encode("utf-8"))
            self._rotate_latest_if_needed(self.latest_path, encoded_size)
            with self.latest_path.open("a", encoding="utf-8", newline="\n") as handle:
                handle.write(readable)

            self._events.append(event)
            return event

    def recent(self, limit: int = 30) -> list[dict[str, Any]]:
        with self._lock:
            if limit <= 0:
                return []
            return list(self._events)[-limit:]

    def context(self, limit: int = 20) -> list[dict[str, Any]]:
        """Return compact facts suitable for a model prompt."""
        result: list[dict[str, Any]] = []
        for event in self.recent(limit):
            item = {
                "time": event["time"],
                "kind": event["kind"],
                "message": event["message"],
            }
            data = event.get("data")
            if isinstance(data, dict):
                preserved = {
                    key: data[key]
                    for key in (
                        "intent_id",
                        "mode",
                        "reason",
                        "item_prefab",
                        "distance",
                        "shard",
                        "position",
                    )
                    if key in data
                }
                if preserved:
                    item["data"] = preserved
            result.append(item)
        return result
