from __future__ import annotations

import json
import unittest
from unittest.mock import patch

from controller.deepseek import DeepSeekPlanner


class _Memory:
    def render_context(self, _query: str, limit: int = 6) -> str:
        return ""


class _AgentMemory:
    def render_skill_context(self, _query: str, limit: int = 8) -> str:
        return ""

    def render_implementation_context(
        self,
        _query: str,
        limit: int = 2,
        max_chars: int = 1600,
    ) -> str:
        return ""

    def active_plan(self) -> None:
        return None

    def recent_chat(self, _room: str, limit: int = 10) -> list[object]:
        return []

    def world_context(
        self,
        _shard: str,
        _query: str,
        limit: int = 30,
    ) -> list[object]:
        return []


class _Response:
    def __enter__(self) -> "_Response":
        return self

    def __exit__(self, *_args: object) -> None:
        return None

    def read(self) -> bytes:
        return json.dumps(
            {
                "choices": [
                    {
                        "message": {
                            "content": (
                                '{"reply":{"text":"收到","expects_response":false}}'
                            )
                        }
                    }
                ]
            },
            ensure_ascii=False,
        ).encode("utf-8")


class DeepSeekParsingTests(unittest.TestCase):
    def test_extracts_json_code_fence(self) -> None:
        payload = """```json
{"intent_id":"abc","mode":"combat","target_guid":"7","lease_seconds":4}
```"""
        result = DeepSeekPlanner._extract_json(payload)
        self.assertEqual(result["mode"], "combat")
        self.assertEqual(result["target_guid"], "7")

    def test_rejects_non_object(self) -> None:
        with self.assertRaises(Exception):
            DeepSeekPlanner._extract_json("[]")

    def test_missing_world_state_does_not_break_prompt_construction(self) -> None:
        planner = DeepSeekPlanner(
            api_key="test",
            base_url="https://api.deepseek.com",
            model="deepseek-chat",
            timeout=2,
            system_prompt="JSON only.",
            memory=_Memory(),
            agent_memory=_AgentMemory(),
        )
        with patch("controller.deepseek.urlopen", return_value=_Response()):
            result = planner.decide(
                {
                    "world": {"phase": None, "season": None},
                    "nearby": [],
                    "capabilities": {},
                },
                {
                    "intent_id": "follow",
                    "mode": "follow",
                    "reason": None,
                },
                "采集附近的草",
                trigger="task",
            )
        self.assertEqual(result["reply"]["text"], "收到")


if __name__ == "__main__":
    unittest.main()
