from __future__ import annotations

import copy
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CHARACTER_ALIASES = {
    "maxwell": "waxwell",
    "麦斯威尔": "waxwell",
    "老麦": "waxwell",
    "waxwell": "waxwell",
}

CHINESE_DIGITS = {
    "零": 0,
    "一": 1,
    "二": 2,
    "两": 2,
    "三": 3,
    "四": 4,
    "五": 5,
    "六": 6,
    "七": 7,
    "八": 8,
    "九": 9,
}


@dataclass(frozen=True)
class PlaybookMatch:
    playbook_id: str
    task_type: str
    character: str
    confidence: float
    direct: bool
    reply: str
    intent: dict[str, Any] | None
    playbook: dict[str, Any]


def normalize_character(value: Any) -> str:
    text = str(value or "").strip().lower()
    return CHARACTER_ALIASES.get(text, text)


def _parse_number(text: str) -> int | None:
    match = re.search(r"(?<!\d)(\d{1,4})(?!\d)", text)
    if match:
        return int(match.group(1))
    match = re.search(r"[零一二两三四五六七八九十]+", text)
    if match:
        token = match.group(0)
        if token == "一" and ("一些" in text or "一点" in text):
            return None
        if "十" in token:
            tens, _, ones = token.partition("十")
            tens_char = tens[-1:] if tens else ""
            ones_char = ones[:1] if ones else ""
            tens_value = CHINESE_DIGITS.get(tens_char, 1)
            ones_value = CHINESE_DIGITS.get(ones_char, 0)
            return tens_value * 10 + ones_value
        for char in token:
            if char in CHINESE_DIGITS:
                return CHINESE_DIGITS[char]
    return None


class PlaybookMatcher:
    """Character-specific task routing without a model round-trip."""

    def __init__(self, directory: Path) -> None:
        self.directory = directory
        self.playbooks = self._load()

    def _load(self) -> list[dict[str, Any]]:
        result: list[dict[str, Any]] = []
        if not self.directory.exists():
            return result
        for path in sorted(self.directory.glob("*.json")):
            data = json.loads(path.read_text(encoding="utf-8"))
            for playbook in data.get("playbooks") or []:
                if not isinstance(playbook, dict):
                    continue
                item = dict(playbook)
                item.setdefault("character", data.get("character"))
                item["_source"] = path.name
                item["_patterns"] = [
                    re.compile(pattern, re.I)
                    for pattern in item.get("patterns") or []
                ]
                item["_exclude_patterns"] = [
                    re.compile(pattern, re.I)
                    for pattern in item.get("exclude_patterns") or []
                ]
                result.append(item)
        result.sort(key=lambda item: int(item.get("priority") or 0), reverse=True)
        return result

    @staticmethod
    def _character(snapshot: dict[str, Any]) -> str:
        companion = snapshot.get("companion") or {}
        player = snapshot.get("player") or {}
        return normalize_character(
            companion.get("prefab") or player.get("prefab") or ""
        )

    @staticmethod
    def _craftable(snapshot: dict[str, Any], recipe: str) -> bool:
        capabilities = snapshot.get("capabilities") or {}
        for item in capabilities.get("craftable_recipes") or []:
            if not isinstance(item, dict):
                continue
            if recipe in {
                str(item.get("name") or ""),
                str(item.get("product") or ""),
            }:
                return True
        return False

    def _matching_playbooks(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> list[tuple[float, dict[str, Any]]]:
        character = self._character(snapshot)
        matches: list[tuple[float, dict[str, Any]]] = []
        for playbook in self.playbooks:
            required_character = normalize_character(
                playbook.get("character")
            )
            if required_character and required_character != character:
                continue
            if any(
                pattern.search(message)
                for pattern in playbook["_exclude_patterns"]
            ):
                continue
            hit_count = sum(
                1 for pattern in playbook["_patterns"] if pattern.search(message)
            )
            if hit_count == 0:
                continue
            require_craftable = playbook.get("require_craftable")
            if require_craftable and not self._craftable(
                snapshot, str(require_craftable)
            ):
                continue
            score = float(playbook.get("priority") or 0) + hit_count * 10
            matches.append((score, playbook))
        matches.sort(key=lambda item: item[0], reverse=True)
        return matches

    @staticmethod
    def _replace_values(
        value: Any,
        amount: int,
        snapshot: dict[str, Any],
    ) -> Any:
        if value == "$amount":
            return amount
        if value == "$player_position":
            player = snapshot.get("player") or {}
            x = player.get("x")
            z = player.get("z")
            if isinstance(x, (int, float)) and isinstance(z, (int, float)):
                return [x, z]
            return None
        if isinstance(value, list):
            return [
                PlaybookMatcher._replace_values(item, amount, snapshot)
                for item in value
            ]
        if isinstance(value, dict):
            return {
                key: PlaybookMatcher._replace_values(item, amount, snapshot)
                for key, item in value.items()
            }
        return value

    @staticmethod
    def _forces_survival_override(message: str) -> bool:
        return bool(
            re.search(
                r"(?:别管|不要管|不用管|无视).{0,8}"
                r"(?:饥饿|饱食|生命|危险|安全)"
                r"|(?:务必|必须|一定|不管怎样|无论如何).{0,12}"
                r"(?:去|执行|完成|做到)",
                message,
                re.I,
            )
        )

    def match(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PlaybookMatch | None:
        matches = self._matching_playbooks(message, snapshot)
        if not matches:
            return None
        score, playbook = matches[0]
        amount = _parse_number(message) or int(playbook.get("default_amount") or 1)
        intent = copy.deepcopy(playbook.get("intent"))
        if isinstance(intent, dict):
            intent = self._replace_values(intent, amount, snapshot)
            if self._forces_survival_override(message):
                params = intent.setdefault("params", {})
                if isinstance(params, dict):
                    params["ignore_survival_safety"] = True
            intent.setdefault("intent_id", f"playbook-{playbook['id']}")

        response_kind = playbook.get("response_kind")
        reply = str(playbook.get("reply") or "")
        if response_kind == "inventory_status":
            prefab = str(playbook.get("item_prefab") or "")
            count = int((snapshot.get("inventory_counts") or {}).get(prefab, 0))
            reply = str(playbook.get("reply_template") or "现在有 {count} 个。")
            reply = reply.replace("{count}", str(count)).replace(
                "{item}", str(playbook.get("display_name") or prefab)
            )
        else:
            reply = reply.replace("{amount}", str(amount))

        return PlaybookMatch(
            playbook_id=str(playbook.get("id") or ""),
            task_type=str(playbook.get("task_type") or "general"),
            character=self._character(snapshot),
            confidence=min(0.99, score / 100.0),
            direct=bool(playbook.get("direct", True)),
            reply=reply,
            intent=intent if isinstance(intent, dict) else None,
            playbook={
                key: value
                for key, value in playbook.items()
                if not key.startswith("_")
            },
        )

    def candidate_context(
        self,
        message: str,
        snapshot: dict[str, Any],
        limit: int = 4,
    ) -> list[dict[str, Any]]:
        matches = self._matching_playbooks(message, snapshot)[:limit]
        return [
            {
                "score": score,
                "playbook": {
                    key: value
                    for key, value in playbook.items()
                    if not key.startswith("_")
                },
            }
            for score, playbook in matches
        ]
