from __future__ import annotations

import threading
import time
import uuid
from dataclasses import asdict, dataclass, field
from typing import Any


ALLOWED_MODES = {
    "hold",
    "follow",
    "move_to",
    "move_to_landmark",
    "remember_location",
    "combat",
    "collect_loot",
    "guard",
    "use_skill",
    "harvest",
    "harvest_area",
    "gather",
    "craft",
    "build",
    "deploy",
    "plant",
    "till",
    "equip",
    "unequip",
    "eat",
    "fetch_item",
    "deliver_item",
    "retreat",
    "operate",
    "speak",
}

MAX_LEASE_SECONDS = 6 * 60 * 60


@dataclass
class Intent:
    intent_id: str
    mode: str = "hold"
    target_guid: str | None = None
    target_prefab: str | None = None
    position: list[float] | None = None
    params: dict[str, Any] = field(default_factory=dict)
    lease_seconds: float = 5.0
    reason: str = ""
    created_at: float = field(default_factory=time.time)

    def remaining(self, now: float | None = None) -> float:
        now = time.time() if now is None else now
        return max(0.0, self.lease_seconds - (now - self.created_at))

    def expired(self, now: float | None = None) -> bool:
        return self.remaining(now) <= 0

    def to_dict(self) -> dict[str, Any]:
        result = asdict(self)
        result["remaining_seconds"] = self.remaining()
        return result


class IntentArbiter:
    """Single-source command state.

    Only this object decides which intent is active. The game-side executor is
    deliberately not allowed to choose a competing behavior.
    """

    def __init__(self, default_lease_seconds: float = 5.0) -> None:
        self.default_lease_seconds = default_lease_seconds
        self._lock = threading.RLock()
        self._revision = 0
        self._intent = Intent(
            intent_id=str(uuid.uuid4()),
            mode="follow",
            lease_seconds=365 * 24 * 3600,
            reason="default_follow",
        )

    @property
    def revision(self) -> int:
        with self._lock:
            return self._revision

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            intent = self._active_locked()
            return {
                "revision": self._revision,
                "intent": intent.to_dict(),
            }

    def set(self, payload: dict[str, Any], source: str = "deepseek") -> Intent:
        mode = str(payload.get("mode", "hold"))
        if mode not in ALLOWED_MODES:
            raise ValueError(f"unsupported intent mode: {mode}")

        lease = float(payload.get("lease_seconds") or self.default_lease_seconds)
        # Long-distance travel and multi-step jobs must survive until the
        # executor reports completion or a new instruction replaces them.
        lease = max(0.5, min(lease, MAX_LEASE_SECONDS))
        intent_id = str(payload.get("intent_id") or uuid.uuid4())
        position = payload.get("position")
        if position is not None:
            if not isinstance(position, list) or len(position) != 2:
                raise ValueError("position must be [x, z]")
            position = [float(position[0]), float(position[1])]

        params = payload.get("params") or {}
        if not isinstance(params, dict):
            raise ValueError("params must be an object")

        intent = Intent(
            intent_id=intent_id,
            mode=mode,
            target_guid=(
                str(payload["target_guid"])
                if payload.get("target_guid") is not None
                else None
            ),
            target_prefab=(
                str(payload["target_prefab"])
                if payload.get("target_prefab") is not None
                else None
            ),
            position=position,
            params=params,
            lease_seconds=lease,
            reason=str(payload.get("reason") or source),
        )
        with self._lock:
            self._intent = intent
            self._revision += 1
        return intent

    def active(self) -> Intent:
        with self._lock:
            return self._active_locked()

    def _active_locked(self) -> Intent:
        if self._intent.mode != "hold" and self._intent.expired():
            self._intent = Intent(
                intent_id=str(uuid.uuid4()),
                mode="follow",
                lease_seconds=365 * 24 * 3600,
                reason="intent_lease_expired_follow",
            )
            self._revision += 1
        return self._intent
