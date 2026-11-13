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
    "homestead",
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

PRIORITY_MIN = 0
PRIORITY_MAX = 1000

PRIORITY_LEVELS = {
    "hold": 20,
    "follow": 30,
    "move_to": 40,
    "move_to_landmark": 40,
    "remember_location": 20,
    # A established home is a persistent idle baseline, not ordinary work.
    # It must yield immediately to any new user command while still ranking
    # below combat and deliberate survival recovery.
    "homestead": 30,
    "combat": 90,
    "guard": 90,
    "collect_loot": 50,
    "use_skill": 55,
    "harvest": 50,
    "harvest_area": 50,
    "gather": 50,
    "craft": 50,
    "build": 50,
    "deploy": 50,
    "plant": 50,
    "till": 50,
    "equip": 45,
    "unequip": 45,
    "eat": 70,
    "fetch_item": 50,
    "deliver_item": 50,
    "retreat": 110,
    "operate": 50,
    "speak": 20,
}


def intent_priority(payload: dict[str, Any]) -> int:
    """Return a stable priority for an intent payload.

    Explicit retreat is the only normal user action allowed to interrupt a
    combat task. Survival recovery is ranked above ordinary work but below
    combat, so a tent or food request waits while a boss is still active.
    """

    mode = str(payload.get("mode") or "hold")
    requested = payload.get("priority")
    if requested is not None:
        try:
            return max(PRIORITY_MIN, min(PRIORITY_MAX, int(requested)))
        except (TypeError, ValueError):
            pass

    params = payload.get("params") or {}
    if isinstance(params, dict):
        requested = params.get("priority")
        if requested is not None:
            try:
                return max(PRIORITY_MIN, min(PRIORITY_MAX, int(requested)))
            except (TypeError, ValueError):
                pass
        if params.get("force_recovery_check"):
            return 70

    reason = str(payload.get("reason") or "").lower()
    if mode == "retreat":
        return 110
    if mode in {"combat", "guard"}:
        return 90
    if mode in {"eat"}:
        return 70
    if mode == "use_skill" and any(
        word in reason for word in ("combat", "spell", "attack")
    ):
        return 90
    return PRIORITY_LEVELS.get(mode, 50)


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
    priority: int = 50
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
        self._pending: dict[str, Intent] = {}
        self._intent = Intent(
            intent_id=str(uuid.uuid4()),
            mode="follow",
            lease_seconds=365 * 24 * 3600,
            reason="default_follow",
            priority=30,
        )

    @property
    def revision(self) -> int:
        with self._lock:
            return self._revision

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            intent = self._active_locked()
            pending = [
                {
                    **queued.to_dict(),
                    "remaining_seconds": queued.lease_seconds,
                    "queued": True,
                }
                for queued in sorted(
                    self._pending.values(),
                    key=lambda item: (item.priority, item.created_at),
                    reverse=True,
                )
            ]
            return {
                "revision": self._revision,
                "intent": intent.to_dict(),
                "pending_intents": pending,
            }

    def _build(
        self,
        payload: dict[str, Any],
        source: str,
        priority: int,
    ) -> Intent:
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
            priority=max(PRIORITY_MIN, min(PRIORITY_MAX, int(priority))),
        )
        return intent

    def set(
        self,
        payload: dict[str, Any],
        source: str = "deepseek",
        *,
        clear_pending: bool = False,
    ) -> Intent:
        intent = self._build(payload, source, intent_priority(payload))
        with self._lock:
            if clear_pending:
                self._pending.clear()
            self._intent = intent
            self._revision += 1
        return intent

    def submit(
        self,
        payload: dict[str, Any],
        source: str = "user",
    ) -> tuple[Intent, bool]:
        """Submit a user command through priority arbitration.

        The returned boolean is true when the command is queued behind a
        higher-priority active task. Queued intents do not consume their lease
        until they become active.
        """

        intent = self._build(payload, source, intent_priority(payload))
        with self._lock:
            active = self._active_locked()
            baseline_follow = (
                active.mode == "homestead"
                or (
                    active.mode == "follow"
                    and active.reason in {
                        "default_follow",
                        "intent_lease_expired_follow",
                    }
                )
            )
            if active.priority > intent.priority and not baseline_follow:
                self._pending = {
                    key: queued
                    for key, queued in self._pending.items()
                    if queued.priority != intent.priority
                }
                self._pending[intent.intent_id] = intent
                return active, True

            # Accepting a new command supersedes older queued work that is no
            # more important. Higher-priority queued work remains preserved.
            self._pending = {
                key: queued
                for key, queued in self._pending.items()
                if queued.priority > intent.priority
            }
            self._intent = intent
            self._revision += 1
            return intent, False

    def finish(
        self,
        payload: dict[str, Any],
        source: str = "system",
    ) -> tuple[Intent, bool]:
        """Finish the active task and resume the best queued user command."""

        fallback = self._build(payload, source, intent_priority(payload))
        with self._lock:
            queued = self._promote_pending_locked()
            if queued is not None:
                self._revision += 1
                return queued, True
            self._intent = fallback
            self._revision += 1
            return fallback, False

    def active(self) -> Intent:
        with self._lock:
            return self._active_locked()

    def _active_locked(self) -> Intent:
        if (
            self._intent.mode not in {"hold", "homestead"}
            and self._intent.expired()
        ):
            queued = self._promote_pending_locked()
            if queued is not None:
                self._intent = queued
            else:
                self._intent = Intent(
                    intent_id=str(uuid.uuid4()),
                    mode="follow",
                    lease_seconds=365 * 24 * 3600,
                    reason="intent_lease_expired_follow",
                    priority=30,
                )
            self._revision += 1
        return self._intent

    def _promote_pending_locked(self) -> Intent | None:
        if not self._pending:
            return None
        queued = max(
            self._pending.values(),
            key=lambda item: (item.priority, item.created_at),
        )
        del self._pending[queued.intent_id]
        queued.created_at = time.time()
        self._intent = queued
        return queued
