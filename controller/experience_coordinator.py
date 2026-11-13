from __future__ import annotations

import copy
import threading
import time
from dataclasses import dataclass, field
from typing import Any

from .arbiter import Intent


LOCAL_COMPLETION_MODES = {
    "collect_loot",
    "harvest",
    "harvest_area",
    "gather",
    "fetch_item",
    "deliver_item",
}

QUANTITY_COMPLETION_MODES = {
    "collect_loot",
    "harvest_area",
    "gather",
    "fetch_item",
    "deliver_item",
}

ITEM_NAMES = {
    "silk": "蜘蛛丝",
    "monstermeat": "怪物肉",
    "twigs": "树枝",
    "berries": "浆果",
    "carrot": "胡萝卜",
    "goldnugget": "金块",
    "log": "木头",
    "rocks": "石头",
    "flint": "燧石",
}

RECOVERY_THRESHOLDS = {
    "food": {"hunger_percent": 55.0},
    "healing_item": {"health_percent": 65.0},
}


def is_local_completion_event(event: dict[str, Any]) -> bool:
    return (
        str(event.get("type") or "") == "task_complete"
        and str(event.get("mode") or "") in LOCAL_COMPLETION_MODES
    )


@dataclass
class ExperienceOutcome:
    accepted: bool = False
    ignored: bool = False
    handled: bool = False
    lifecycle: str = ""
    transition_intent: dict[str, Any] | None = None
    reply: str | None = None
    reply_key: str = ""
    verified: bool | None = None
    progress_evidence: dict[str, Any] = field(default_factory=dict)
    reason: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "accepted": self.accepted,
            "ignored": self.ignored,
            "handled": self.handled,
            "lifecycle": self.lifecycle,
            "reply_key": self.reply_key,
            "verified": self.verified,
            "progress_evidence": copy.deepcopy(self.progress_evidence),
            "reason": self.reason,
        }


@dataclass
class _RecoveryContext:
    intent: dict[str, Any]
    method: str
    started: dict[str, Any]


class ExperienceCoordinator:
    """Validate local experience outcomes without becoming an intent source."""

    def __init__(self) -> None:
        self._lock = threading.RLock()
        self._recovery: _RecoveryContext | None = None
        self._emergency_cycles: dict[str, dict[str, Any]] = {}
        self._progress: dict[str, dict[str, Any]] = {}
        self._recovery_notices: dict[tuple[str, str], float] = {}
        self._last_outcome = ExperienceOutcome()
        self._last_event_at: float | None = None

    def observe_event(
        self,
        event: dict[str, Any],
        intent: Intent | None,
        snapshot: dict[str, Any],
        now: float | None = None,
    ) -> ExperienceOutcome:
        observed_at = time.monotonic() if now is None else float(now)
        with self._lock:
            self._last_event_at = observed_at
            event_type = str(event.get("type") or "")
            if event_type == "task_started":
                self._record_task_baseline(event, intent, snapshot)
                outcome = ExperienceOutcome(ignored=True, reason="baseline_recorded")
            elif event_type == "item_acquired":
                self._record_item_progress(event, intent)
                outcome = ExperienceOutcome(
                    accepted=True,
                    verified=self._event_delta(event) > 0,
                    progress_evidence=self._progress_for(intent),
                )
            elif event_type == "task_complete":
                outcome = self._complete_task(event, intent)
            elif event_type == "recovery_started":
                outcome = self._start_recovery(event, intent, snapshot)
            elif event_type == "recovery_completed":
                outcome = self._complete_recovery(event, intent)
            elif event_type == "recovery_unavailable":
                outcome = self._handle_recovery_unavailable(
                    event,
                    intent,
                    observed_at,
                )
            elif event_type in {
                "emergency_detected",
                "emergency_action",
                "emergency_resolved",
            }:
                outcome = self._handle_emergency(event)
            else:
                outcome = ExperienceOutcome(ignored=True, reason="not_managed")
            self._last_outcome = outcome
            return outcome

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return {
                "last_event_at": self._last_event_at,
                "last_outcome": self._last_outcome.to_dict(),
                "recovery": (
                    {
                        "method": self._recovery.method,
                        "intent_id": self._recovery.intent.get("intent_id"),
                        "started": copy.deepcopy(self._recovery.started),
                    }
                    if self._recovery is not None
                    else None
                ),
                "emergency_cycles": copy.deepcopy(self._emergency_cycles),
                "tracked_tasks": copy.deepcopy(self._progress),
            }

    def _record_task_baseline(
        self,
        event: dict[str, Any],
        intent: Intent | None,
        snapshot: dict[str, Any],
    ) -> None:
        intent_id = str(event.get("intent_id") or (intent.intent_id if intent else ""))
        if not intent_id:
            return
        inventory = {
            str(key): int(value)
            for key, value in (snapshot.get("inventory_counts") or {}).items()
            if int(value) >= 0
        }
        if not inventory and isinstance(snapshot.get("inventory"), list):
            for item in snapshot["inventory"]:
                if not isinstance(item, dict):
                    continue
                prefab = str(item.get("prefab") or "")
                if prefab:
                    inventory[prefab] = inventory.get(prefab, 0) + int(
                        item.get("amount") or 1
                    )
        self._progress[intent_id] = {
            "mode": str(event.get("mode") or (intent.mode if intent else "")),
            "target_prefab": (
                event.get("target_prefab")
                or (intent.target_prefab if intent else None)
            ),
            "baseline_inventory": inventory,
            "max_after": {},
            "deltas": {},
        }

    def _record_item_progress(
        self,
        event: dict[str, Any],
        intent: Intent | None,
    ) -> None:
        intent_id = str(event.get("intent_id") or (intent.intent_id if intent else ""))
        if not intent_id:
            return
        record = self._progress.setdefault(
            intent_id,
            {
                "mode": str(event.get("mode") or (intent.mode if intent else "")),
                "target_prefab": (
                    event.get("item_prefab")
                    or event.get("target_prefab")
                    or (intent.target_prefab if intent else None)
                ),
                "baseline_inventory": {},
                "max_after": {},
                "deltas": {},
            },
        )
        prefab = str(
            event.get("item_prefab")
            or event.get("target_prefab")
            or record.get("target_prefab")
            or ""
        )
        if not prefab:
            return
        delta = self._event_delta(event)
        after = self._integer_value(
            event,
            "after_amount",
            "current_amount",
            "amount",
        )
        if delta > 0:
            record["deltas"][prefab] = int(record["deltas"].get(prefab, 0)) + delta
        if after is not None:
            record["max_after"][prefab] = max(
                int(record["max_after"].get(prefab, 0)),
                after,
            )

    def _complete_task(
        self,
        event: dict[str, Any],
        intent: Intent | None,
    ) -> ExperienceOutcome:
        if intent is None:
            return ExperienceOutcome(
                handled=True,
                ignored=True,
                verified=False,
                reason="no_active_intent",
            )
        event_intent_id = str(event.get("intent_id") or "")
        if event_intent_id != intent.intent_id:
            return ExperienceOutcome(
                handled=True,
                ignored=True,
                verified=False,
                reason="intent_mismatch",
            )
        event_mode = str(event.get("mode") or intent.mode)
        if event_mode != intent.mode:
            return ExperienceOutcome(
                handled=True,
                ignored=True,
                verified=False,
                reason="mode_mismatch",
                progress_evidence={"event_mode": event_mode, "intent_mode": intent.mode},
            )
        if event.get("verified") is not True:
            return ExperienceOutcome(
                handled=True,
                verified=False,
                reason="completion_unverified",
            )

        evidence = self._completion_evidence(event, intent)
        verified, reason = self._verify_completion(event, intent, evidence)
        if not verified:
            return ExperienceOutcome(
                handled=True,
                verified=False,
                reason=reason,
                progress_evidence=evidence,
            )

        self._progress.pop(intent.intent_id, None)
        return ExperienceOutcome(
            accepted=True,
            handled=True,
            lifecycle="task_completed",
            transition_intent={
                "intent_id": (
                    "experience-complete-follow-"
                    f"{event.get('event_id') or event.get('id') or intent.intent_id}"
                ),
                "mode": "follow",
                "lease_seconds": 24 * 60 * 60,
                "reason": "experience_complete_follow",
            },
            reply=self._completion_reply(event, intent, evidence),
            reply_key="task_complete",
            verified=True,
            progress_evidence=evidence,
        )

    def _completion_evidence(
        self,
        event: dict[str, Any],
        intent: Intent,
    ) -> dict[str, Any]:
        prefab = str(
            event.get("item_prefab")
            or event.get("target_prefab")
            or intent.target_prefab
            or ""
        )
        amount = self._integer_value(
            event,
            "amount",
            "current_amount",
            "count",
        )
        before = self._integer_value(
            event,
            "inventory_before",
            "companion_before",
            "before_amount",
        )
        after = self._integer_value(
            event,
            "inventory_after",
            "companion_after",
            "after_amount",
        )
        companion_delta = self._integer_value(event, "companion_delta", "held_delta")
        if companion_delta is None and before is not None and after is not None:
            companion_delta = max(0, after - before)
        player_before = self._integer_value(event, "player_before")
        player_after = self._integer_value(event, "player_after")
        player_delta = self._integer_value(event, "player_delta")
        if player_delta is None and player_before is not None and player_after is not None:
            player_delta = max(0, player_after - player_before)
        tracked = self._progress.get(intent.intent_id, {})
        tracked_after = int((tracked.get("max_after") or {}).get(prefab, 0))
        tracked_delta = int((tracked.get("deltas") or {}).get(prefab, 0))
        desired = self._requested_amount(event, intent)
        return {
            "intent_id": intent.intent_id,
            "mode": intent.mode,
            "item_prefab": prefab or None,
            "amount": amount,
            "requested_amount": desired,
            "inventory_before": before,
            "inventory_after": after,
            "companion_delta": companion_delta,
            "player_before": player_before,
            "player_after": player_after,
            "player_delta": player_delta,
            "tracked_after": tracked_after,
            "tracked_delta": tracked_delta,
            "delivered_to_player": event.get("delivered_to_player") is True,
            "delivered_verified": event.get("delivered_verified") is True,
            "final_growth_only": event.get("final_growth_only") is True,
            "partial": event.get("partial") is True,
        }

    def _verify_completion(
        self,
        event: dict[str, Any],
        intent: Intent,
        evidence: dict[str, Any],
    ) -> tuple[bool, str]:
        mode = intent.mode
        desired = int(evidence.get("requested_amount") or 0)
        amount = evidence.get("amount")
        after = evidence.get("inventory_after")
        companion_delta = int(evidence.get("companion_delta") or 0)
        player_delta = int(evidence.get("player_delta") or 0)
        tracked_after = int(evidence.get("tracked_after") or 0)
        tracked_delta = int(evidence.get("tracked_delta") or 0)

        if mode in QUANTITY_COMPLETION_MODES:
            partial = evidence["partial"] and amount is not None and amount > 0
            if amount is not None and amount < desired and not partial:
                return False, "amount_below_requested"
            if mode in {"harvest_area", "gather"}:
                actual = max(
                    int(amount or 0),
                    tracked_after,
                    tracked_delta,
                )
                minimum = min(1, desired) if partial else desired
                if actual < minimum:
                    return False, "quantity_evidence_insufficient"
                if not evidence["final_growth_only"]:
                    return False, "growth_stage_not_verified"
            elif mode == "collect_loot":
                actual = max(
                    int(after or 0),
                    tracked_after,
                    tracked_delta,
                    int(amount or 0),
                )
                if actual < desired:
                    return False, "quantity_evidence_insufficient"
                if evidence["delivered_to_player"]:
                    if (
                        not evidence["delivered_verified"]
                        or player_delta < desired
                        or companion_delta <= 0
                    ):
                        return False, "delivery_evidence_insufficient"
                elif after is not None and after < desired:
                    return False, "held_amount_below_requested"
            elif mode == "deliver_item":
                if companion_delta < desired or player_delta < desired:
                    return False, "two_sided_delivery_evidence_insufficient"
                if not evidence["delivered_verified"]:
                    return False, "delivery_not_verified"
            elif mode == "fetch_item":
                if evidence["delivered_to_player"]:
                    if (
                        player_delta < desired
                        or companion_delta <= 0
                        or not evidence["delivered_verified"]
                    ):
                        return False, "fetch_delivery_evidence_insufficient"
                elif max(int(after or 0), tracked_after) < desired:
                    return False, "fetched_item_not_held"
        return True, ""

    def _completion_reply(
        self,
        event: dict[str, Any],
        intent: Intent,
        evidence: dict[str, Any],
    ) -> str | None:
        prefab = str(evidence.get("item_prefab") or "")
        item_name = ITEM_NAMES.get(prefab, prefab or "物品")
        amount = evidence.get("amount")
        if intent.mode == "collect_loot":
            text = f"{item_name}收集好了，共 {amount} 个。"
            if evidence.get("delivered_to_player"):
                text += "已经交给你。"
            return text
        if intent.mode == "deliver_item":
            return f"{item_name}已经交付 {amount} 个。"
        if intent.mode == "fetch_item":
            if evidence.get("delivered_to_player"):
                return f"{item_name}取到了，已经交给你。"
            return f"{item_name}取到了。"
        if intent.mode in {"harvest", "harvest_area", "gather"}:
            if amount is not None:
                if evidence.get("partial"):
                    return (
                        f"成熟作物收完了，共 {amount} 个；"
                        "附近没有更多成熟的了。"
                    )
                return f"{item_name}收获完成，共 {amount} 个。"
            return f"{item_name}收获完成。"
        return None

    def _start_recovery(
        self,
        event: dict[str, Any],
        intent: Intent | None,
        snapshot: dict[str, Any],
    ) -> ExperienceOutcome:
        if intent is None:
            return ExperienceOutcome(
                handled=True,
                ignored=True,
                reason="no_active_intent",
            )
        event_intent_id = str(event.get("intent_id") or "")
        if event_intent_id and event_intent_id != intent.intent_id:
            return ExperienceOutcome(
                handled=True,
                ignored=True,
                reason="intent_mismatch",
            )
        method = str(event.get("method") or "tent")
        if (
            self._recovery is not None
            and self._recovery.intent.get("intent_id") == intent.intent_id
            and self._recovery.method == method
        ):
            return ExperienceOutcome(
                handled=True,
                ignored=True,
                reason="recovery_already_active",
            )
        companion = snapshot.get("companion") or {}
        started = self._vitality(event, companion)
        self._recovery = _RecoveryContext(
            intent=self._intent_payload(intent),
            method=method,
            started=started,
        )
        if method == "food":
            text = "我有点饿了，先吃些随身食物。"
        elif method == "healing_item":
            text = "我生命偏低，先用背包里的治疗物品。"
        else:
            text = (
                "我状态有些低，先去附近帐篷休息。"
                f"大约睡 {event.get('sleep_seconds')} 秒，"
                f"预计消耗 {event.get('estimated_hunger_cost')} 点饥饿，"
                f"恢复 {event.get('expected_health_gain')} 点生命和 "
                f"{event.get('expected_sanity_gain')} 点精神。"
            )
        return ExperienceOutcome(
            accepted=True,
            handled=True,
            lifecycle="recovery_started",
            reply=text,
            reply_key="recovery_started",
            progress_evidence={
                "intent_id": intent.intent_id,
                "method": method,
                "started": started,
            },
        )

    def _complete_recovery(
        self,
        event: dict[str, Any],
        intent: Intent | None,
    ) -> ExperienceOutcome:
        context = self._recovery
        if context is None:
            return ExperienceOutcome(
                handled=True,
                ignored=True,
                verified=False,
                reason="recovery_context_missing",
            )
        active_intent_id = intent.intent_id if intent is not None else ""
        expected_intent_id = str(context.intent.get("intent_id") or "")
        event_intent_id = str(event.get("intent_id") or expected_intent_id)
        if event_intent_id != expected_intent_id or active_intent_id != expected_intent_id:
            return ExperienceOutcome(
                handled=True,
                ignored=True,
                verified=False,
                reason="intent_mismatch",
            )
        current = self._vitality(event, {})
        verified, reason = self._verify_recovery(context, event, current)
        if not verified:
            return ExperienceOutcome(
                handled=True,
                verified=False,
                reason=reason,
                progress_evidence={
                    "method": context.method,
                    "started": context.started,
                    "current": current,
                },
            )
        self._recovery = None
        method = context.method
        if method == "food":
            text = f"我吃完东西了，现在饥饿 {current.get('hunger')}。"
        elif method == "healing_item":
            text = f"治疗物品用完了，现在生命 {current.get('health')}。"
        else:
            text = (
                "我休息好了。"
                f"当前生命 {current.get('health')}，"
                f"饥饿 {current.get('hunger')}，"
                f"精神 {current.get('sanity')}。"
            )
        return ExperienceOutcome(
            accepted=True,
            handled=True,
            lifecycle="recovery_completed",
            transition_intent=context.intent,
            reply=text,
            reply_key="recovery_completed",
            verified=True,
            progress_evidence={
                "method": method,
                "started": context.started,
                "current": current,
            },
        )

    def _verify_recovery(
        self,
        context: _RecoveryContext,
        event: dict[str, Any],
        current: dict[str, Any],
    ) -> tuple[bool, str]:
        if event.get("verified") is False:
            return False, "recovery_marked_unverified"
        if context.method == "tent" and event.get("verified") is not True:
            return False, "recovery_marked_unverified"
        thresholds = RECOVERY_THRESHOLDS.get(context.method, {})
        for metric, threshold in thresholds.items():
            value = current.get(metric)
            if value is None:
                if event.get("verified") is True:
                    continue
                return False, f"{metric}_missing"
            if float(value) < threshold:
                return False, f"{metric}_below_threshold"
        improvements = 0.0
        for metric in ("health", "hunger", "sanity"):
            before = context.started.get(metric)
            after = current.get(metric)
            if before is not None and after is not None and float(after) > float(before):
                improvements += float(after) - float(before)
        if improvements <= 0 and event.get("verified") is not True:
            return False, "recovery_change_not_observed"
        return True, ""

    def _handle_recovery_unavailable(
        self,
        event: dict[str, Any],
        intent: Intent | None,
        now: float,
    ) -> ExperienceOutcome:
        reason = str(event.get("reason") or "recovery_unavailable")
        intent_id = str(
            event.get("intent_id")
            or (
                self._recovery.intent.get("intent_id")
                if self._recovery is not None
                else intent.intent_id if intent is not None else ""
            )
        )
        notice_key = (intent_id, reason)
        previous = self._recovery_notices.get(notice_key)
        # Recovery retries can repeat for as long as a follow or homestead
        # intent lives. Report the same blocker at most once every five
        # minutes; the journal still keeps every attempt for diagnostics.
        if previous is not None and now - previous < 300:
            return ExperienceOutcome(
                handled=True,
                ignored=True,
                reason="recovery_notice_duplicate",
            )
        self._recovery_notices[notice_key] = now
        transition = None
        if reason == "recovery_food_missing":
            self._recovery = None
            # Missing food is a temporary condition. The executor already
            # throttles retries, and an inventory itemget resets that retry
            # immediately. Keep the active follow/homestead intent so a later
            # pickup can still trigger autonomous recovery.
        return ExperienceOutcome(
            accepted=True,
            handled=True,
            lifecycle="recovery_unavailable",
            transition_intent=transition,
            reply_key="recovery_unavailable",
            verified=False,
            reason=reason,
        )

    def _handle_emergency(self, event: dict[str, Any]) -> ExperienceOutcome:
        event_type = str(event.get("type") or "")
        category = str(event.get("category") or "unknown")
        cycle = self._emergency_cycles.get(category)
        if event_type == "emergency_detected":
            if cycle is not None and not cycle.get("resolved"):
                return ExperienceOutcome(
                    handled=True,
                    ignored=True,
                    lifecycle="emergency_detected",
                    reason="emergency_already_reported",
                )
            cycle = {
                "reported_detected": True,
                "reported_actions": [],
                "resolved": False,
                "threat_count": event.get("threat_count"),
            }
            self._emergency_cycles[category] = cycle
            return ExperienceOutcome(
                accepted=True,
                handled=True,
                lifecycle="emergency_detected",
                reply_key="emergency_detected",
                progress_evidence={"category": category},
            )
        if cycle is None:
            return ExperienceOutcome(
                handled=True,
                ignored=True,
                lifecycle=event_type.removeprefix("emergency_"),
                reason="emergency_cycle_missing",
            )
        if event_type == "emergency_action":
            action = str(event.get("action") or "unknown")
            if action in cycle["reported_actions"]:
                return ExperienceOutcome(
                    handled=True,
                    ignored=True,
                    lifecycle="emergency_action",
                    reason="emergency_action_already_reported",
                )
            cycle["reported_actions"].append(action)
            return ExperienceOutcome(
                accepted=True,
                handled=True,
                lifecycle="emergency_action",
                reply_key="emergency_action",
                progress_evidence={"category": category, "action": action},
            )
        if cycle.get("resolved"):
            return ExperienceOutcome(
                handled=True,
                ignored=True,
                lifecycle="emergency_resolved",
                reason="emergency_resolution_already_reported",
            )
        cycle["resolved"] = True
        return ExperienceOutcome(
            accepted=True,
            handled=True,
            lifecycle="emergency_resolved",
            reply_key="emergency_resolved",
            progress_evidence={"category": category},
        )

    @staticmethod
    def _intent_payload(intent: Intent) -> dict[str, Any]:
        return {
            "intent_id": intent.intent_id,
            "mode": intent.mode,
            "target_guid": intent.target_guid,
            "target_prefab": intent.target_prefab,
            "position": copy.deepcopy(intent.position),
            "params": copy.deepcopy(intent.params),
            "lease_seconds": intent.lease_seconds,
            "reason": intent.reason,
        }

    @staticmethod
    def _vitality(
        event: dict[str, Any],
        companion: dict[str, Any],
    ) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for metric in ("health", "hunger", "sanity"):
            value = event.get(metric, companion.get(metric))
            maximum = event.get(f"{metric}_max", companion.get(f"max_{metric}"))
            percent = event.get(f"{metric}_percent")
            if percent is None and value is not None and maximum not in {None, 0}:
                percent = float(value) / float(maximum) * 100.0
            if value is not None:
                result[metric] = float(value)
            if maximum is not None:
                result[f"{metric}_max"] = float(maximum)
            if percent is not None:
                result[f"{metric}_percent"] = float(percent)
        return result

    @staticmethod
    def _integer_value(event: dict[str, Any], *keys: str) -> int | None:
        for key in keys:
            value = event.get(key)
            if value is None:
                continue
            try:
                return int(value)
            except (TypeError, ValueError):
                continue
        return None

    @staticmethod
    def _event_delta(event: dict[str, Any]) -> int:
        delta = ExperienceCoordinator._integer_value(
            event,
            "delta",
            "held_delta",
            "companion_delta",
        )
        if delta is not None:
            return max(0, delta)
        before = ExperienceCoordinator._integer_value(
            event,
            "before_amount",
            "inventory_before",
            "companion_before",
        )
        after = ExperienceCoordinator._integer_value(
            event,
            "after_amount",
            "inventory_after",
            "companion_after",
        )
        if before is not None and after is not None:
            return max(0, after - before)
        return 0

    @staticmethod
    def _requested_amount(
        event: dict[str, Any],
        intent: Intent,
    ) -> int:
        params = intent.params or {}
        configured = params.get("amount")
        try:
            if configured is not None:
                return max(1, int(configured))
        except (TypeError, ValueError):
            pass
        explicit = ExperienceCoordinator._integer_value(
            event,
            "requested_amount",
            "desired_amount",
        )
        if explicit is not None:
            return max(1, explicit)
        return 10 if intent.mode == "collect_loot" else 1

    def _progress_for(self, intent: Intent | None) -> dict[str, Any]:
        if intent is None:
            return {}
        return copy.deepcopy(self._progress.get(intent.intent_id, {}))
