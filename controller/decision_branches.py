from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


MODE_BRANCH_OVERRIDES = {
    "combat": "combat",
    "guard": "combat",
    "retreat": "combat",
    "collect_loot": "collection",
    "harvest": "collection",
    "harvest_area": "collection",
    "gather": "collection",
    "craft": "crafting",
    "build": "construction",
    "deploy": "construction",
    "plant": "farming",
    "till": "farming",
    "fetch_item": "transport",
    "move_to": "exploration",
    "move_to_landmark": "exploration",
    "follow": "movement",
    "hold": "movement",
    "remember_location": "movement",
    "speak": "information",
    "eat": "survival",
    "operate": "base",
}

SKILL_ACTION_BRANCH_OVERRIDES = {
    "CASTSPELL": "combat",
    "CAST_SPELLBOOK": "combat",
    "BLINK": "movement",
    "SUMMONGUARDIAN": "combat",
    "TOGGLEWXSHIELDING": "combat",
    "TOGGLEWXSCREECH": "combat",
    "MODSLINGSHOT": "combat",
    "STOPMODSLINGSHOT": "combat",
}


@dataclass(frozen=True)
class BranchMatch:
    branch_id: str
    name: str
    confidence: float
    reason: str
    task_type: str | None
    decision: dict[str, Any]

    def context(self) -> dict[str, Any]:
        return {
            "id": self.branch_id,
            "name": self.name,
            "confidence": self.confidence,
            "reason": self.reason,
            "task_type": self.task_type,
            **self.decision,
        }


class DecisionBranchRouter:
    """Fast, deterministic task classification before model planning."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.default_branch = "general"
        self.branches: list[dict[str, Any]] = []
        self.by_id: dict[str, dict[str, Any]] = {}
        self._load()

    def _load(self) -> None:
        data = json.loads(self.path.read_text(encoding="utf-8"))
        self.default_branch = str(data.get("default_branch") or "general")
        for raw in data.get("branches") or []:
            if not isinstance(raw, dict):
                continue
            branch = dict(raw)
            branch["_patterns"] = [
                (
                    re.compile(
                        str(rule.get("pattern") or ""),
                        re.IGNORECASE,
                    ),
                    float(rule.get("weight") or 1),
                )
                for rule in branch.get("patterns") or []
                if isinstance(rule, dict) and rule.get("pattern")
            ]
            self.branches.append(branch)
            self.by_id[str(branch.get("id") or "")] = branch
        self.branches.sort(
            key=lambda item: float(item.get("priority") or 0),
            reverse=True,
        )
    @staticmethod
    def _mode_for_intent(intent: dict[str, Any] | None) -> str | None:
        if not isinstance(intent, dict):
            return None
        mode = str(intent.get("mode") or "").strip()
        return mode or None

    def _score(
        self,
        branch: dict[str, Any],
        message: str,
        mode: str | None,
        task_type: str | None,
    ) -> tuple[float, list[str]]:
        score = 0.0
        reasons: list[str] = []
        branch_id = str(branch.get("id") or "")
        mode_branch = MODE_BRANCH_OVERRIDES.get(mode or "")
        if mode_branch == branch_id:
            score += 70
            reasons.append(f"mode:{mode}")
        if mode is not None and mode in set(branch.get("modes") or []):
            score += 40
            reasons.append(f"mode_alias:{mode}")
        if task_type is not None and task_type in set(
            branch.get("task_types") or []
        ):
            score += 55
            reasons.append(f"task_type:{task_type}")
        for pattern, weight in branch["_patterns"]:
            if pattern.search(message):
                score += weight
                reasons.append(f"pattern:{pattern.pattern}")
        if score > 0:
            score += min(9.0, float(branch.get("priority") or 0) / 10.0)
        return score, reasons

    def classify(
        self,
        message: str,
        snapshot: dict[str, Any] | None = None,
        intent: dict[str, Any] | None = None,
        task_type: str | None = None,
    ) -> BranchMatch:
        del snapshot  # Reserved for future world-state routing.
        text = str(message or "").strip()
        mode = self._mode_for_intent(intent)
        skill_action = None
        if isinstance(intent, dict) and mode == "use_skill":
            params = intent.get("params")
            if isinstance(params, dict):
                skill_action = str(params.get("action") or "").strip() or None
        skill_branch = SKILL_ACTION_BRANCH_OVERRIDES.get(skill_action or "")
        best_branch: dict[str, Any] | None = None
        best_score = -1.0
        best_reasons: list[str] = []
        for branch in self.branches:
            score, reasons = self._score(
                branch,
                text,
                mode,
                task_type,
            )
            if skill_branch == str(branch.get("id") or ""):
                score += 75
                reasons.append(f"skill_action:{skill_action}")
            if score > best_score:
                best_branch = branch
                best_score = score
                best_reasons = reasons

        if best_branch is None or best_score <= 0:
            best_branch = self.by_id.get(self.default_branch)
            best_score = 1.0
            best_reasons = ["default"]
        if best_branch is None:
            best_branch = {
                "id": "general",
                "name": "综合任务",
                "objective": "先识别真实目标，再选择可执行子分支。",
                "required_checks": [],
                "decision_order": [],
                "rules": [],
                "completion_signals": [],
                "sources": [],
            }

        decision = {
            "objective": str(best_branch.get("objective") or ""),
            "skill_actions": list(best_branch.get("skill_actions") or []),
            "required_checks": list(best_branch.get("required_checks") or []),
            "decision_order": list(best_branch.get("decision_order") or []),
            "rules": list(best_branch.get("rules") or []),
            "completion_signals": list(
                best_branch.get("completion_signals") or []
            ),
            "sources": list(best_branch.get("sources") or []),
        }
        confidence = (
            0.1
            if best_reasons == ["default"]
            else min(0.99, 0.45 + best_score / 40.0)
        )
        return BranchMatch(
            branch_id=str(best_branch.get("id") or "general"),
            name=str(best_branch.get("name") or "综合任务"),
            confidence=round(confidence, 2),
            reason=", ".join(best_reasons) or "default",
            task_type=task_type,
            decision=decision,
        )

    def classify_intent(
        self,
        intent: dict[str, Any] | None,
        snapshot: dict[str, Any] | None = None,
    ) -> BranchMatch:
        return self.classify("", snapshot=snapshot, intent=intent)

    def context_for(
        self,
        branch_id: str,
        task_type: str | None = None,
        reason: str = "explicit_branch",
    ) -> BranchMatch:
        branch = self.by_id.get(branch_id) or self.by_id.get(
            self.default_branch
        )
        if branch is None:
            branch = {
                "id": "general",
                "name": "综合任务",
                "objective": "先识别真实目标，再选择可执行子分支。",
                "required_checks": [],
                "decision_order": [],
                "rules": [],
                "completion_signals": [],
                "sources": [],
            }
        decision = {
            "objective": str(branch.get("objective") or ""),
            "skill_actions": list(branch.get("skill_actions") or []),
            "required_checks": list(branch.get("required_checks") or []),
            "decision_order": list(branch.get("decision_order") or []),
            "rules": list(branch.get("rules") or []),
            "completion_signals": list(
                branch.get("completion_signals") or []
            ),
            "sources": list(branch.get("sources") or []),
        }
        return BranchMatch(
            branch_id=str(branch.get("id") or "general"),
            name=str(branch.get("name") or "综合任务"),
            confidence=0.99,
            reason=reason,
            task_type=task_type,
            decision=decision,
        )
