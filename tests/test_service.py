from __future__ import annotations

import tempfile
import time
import unittest
from pathlib import Path

from controller.config import Settings
from controller.service import CompanionService, IMPORTANT_EVENTS


class FakePlanner:
    def decide(self, snapshot, current_intent, user_instruction=None, trigger="instruction"):
        return {
            "reply": {
                "text": "用户酱，作物收完了。你打算种什么？",
                "expects_response": True,
            },
            "intent": {
                "intent_id": "follow-after-harvest",
                "mode": "follow",
                "lease_seconds": 30,
                "reason": "等待用户选择作物",
            },
        }


class ChatOnlyPlanner:
    def decide(self, snapshot, current_intent, user_instruction=None, trigger="instruction"):
        return {
            "reply": {
                "text": "用户酱，我在呢",
                "expects_response": False,
            }
        }


class CrossWorldPlanner:
    def decide(self, snapshot, current_intent, user_instruction=None, trigger="instruction"):
        return {
            "reply": {
                "text": "好，我现在进入洞穴。",
                "expects_response": False,
            },
            "intent": {
                "intent_id": "cross-world-fetch",
                "mode": "fetch_item",
                "target_prefab": "goldnugget",
                "lease_seconds": 1800,
                "params": {
                    "target_shard": "2",
                },
            },
        }


class ResearchPlanner:
    def __init__(self) -> None:
        self.calls = 0
        self.saw_research = False

    def decide(self, snapshot, current_intent, user_instruction=None, trigger="instruction"):
        self.calls += 1
        if trigger != "research_followup":
            return {
                "research_query": "建造护符配方和制作站",
                "reply": {"text": "我先查一下资料", "expects_response": False},
            }
        self.saw_research = "research_context" in snapshot
        return {
            "reply": {"text": "资料查好了", "expects_response": False},
            "intent": {
                "intent_id": "research-followup",
                "mode": "hold",
                "lease_seconds": 60,
            },
        }


class TriggerRecorderPlanner:
    def __init__(self) -> None:
        self.last_trigger = None

    def decide(self, snapshot, current_intent, user_instruction=None, trigger="instruction"):
        self.last_trigger = trigger
        return {
            "reply": {"text": "我在听", "expects_response": False},
        }


class ExplodingPlanner:
    def decide(self, snapshot, current_intent, user_instruction=None, trigger="instruction"):
        raise AssertionError("direct playbook must not call DeepSeek")


class CapabilityGapPlanner:
    def decide(self, snapshot, current_intent, user_instruction=None, trigger="instruction"):
        return {
            "capability_gap": {
                "feature": "复杂远古机关联动作",
                "request_text": user_instruction or "",
                "missing_capability": "缺少机关交互执行器",
                "suggested_implementation": "增加机关目标解析和动作状态机",
                "message": "这个机关联动目前做不到，我已经记录具体缺口。",
            }
        }


class FakeResearch:
    def research(self, query, context=""):
        return {
            "topic": "建造护符",
            "summary": "需要先准备材料并前往制作站。",
            "steps": ["确认材料", "前往制作站"],
            "ingredients": [{"prefab": "goldnugget", "amount": 2}],
            "station": "对应制作站",
            "sources": [{"title": "test", "url": "https://example.com"}],
        }

    @staticmethod
    def render_skill_note(result):
        return f"{result['summary']} 材料：金块 2"


class CompanionServiceTests(unittest.TestCase):
    def test_instruction_returns_reply_and_next_intent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            service.planner = FakePlanner()
            service.start()
            try:
                service.tick(
                    {
                        "companion": {},
                        "player": {},
                        "world": {},
                        "nearby": [],
                        "events": [],
                    }
                )
                service.instruction("你收完作物后告诉我")
                deadline = time.time() + 2
                while time.time() < deadline and service.state()["revision"] == 0:
                    time.sleep(0.02)
                state = service.state()
                self.assertEqual(state["intent"]["mode"], "follow")
                self.assertEqual(
                    state["messages"][-1]["text"],
                    "用户酱，作物收完了。你打算种什么？",
                )
                self.assertTrue(state["messages"][-1]["expects_response"])
            finally:
                service.stop()
                service.memory.close()

    def test_chat_only_reply_preserves_current_task(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            service.planner = ChatOnlyPlanner()
            service.force_command(
                {
                    "intent_id": "harvest-1",
                    "mode": "harvest_area",
                    "lease_seconds": 30,
                }
            )
            service.start()
            try:
                service.tick(
                    {
                        "companion": {},
                        "player": {"guid": "1"},
                        "world": {},
                        "nearby": [],
                        "events": [],
                    }
                )
                service.instruction("你在干嘛")
                deadline = time.time() + 2
                while time.time() < deadline and not service.state()["messages"]:
                    time.sleep(0.02)
                state = service.state()
                self.assertEqual(state["intent"]["mode"], "harvest_area")
                self.assertEqual(state["messages"][-1]["text"], "用户酱，我在呢")
            finally:
                service.stop()
                service.memory.close()

    def test_chat_channel_discards_model_intent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            service.planner = FakePlanner()
            service.force_command(
                {
                    "intent_id": "combat-1",
                    "mode": "combat",
                    "target_guid": "42",
                    "lease_seconds": 1800,
                }
            )
            service.start()
            try:
                service.tick(
                    {
                        "companion": {},
                        "player": {"guid": "1"},
                        "world": {},
                        "nearby": [],
                        "events": [],
                    }
                )
                service.chat("你在干嘛")
                deadline = time.time() + 2
                while time.time() < deadline and not service.state()["messages"]:
                    time.sleep(0.02)
                state = service.state()
                self.assertEqual(state["intent"]["mode"], "combat")
                self.assertEqual(state["intent"]["intent_id"], "combat-1")
                self.assertEqual(
                    state["messages"][-1]["text"],
                    "用户酱，作物收完了。你打算种什么？",
                )
            finally:
                service.stop()
                service.memory.close()

    def test_verified_task_event_is_written_to_log(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            try:
                service.tick(
                    {
                        "companion": {"x": 20, "z": -30},
                        "player": {"guid": "1", "distance": 80},
                        "world": {"shard": "1"},
                        "inventory": [{"prefab": "goldnugget"}],
                        "nearby": [],
                        "events": [
                            {
                                "event_id": "complete-1",
                                "type": "task_complete",
                                "intent_id": "fetch-1",
                                "item_prefab": "goldnugget",
                                "verified": True,
                            }
                        ],
                    }
                )
                text = service.journal.latest_path.read_text(encoding="utf-8")
                self.assertIn("伴侣确认任务完成", text)
                self.assertIn("game.task_complete", text)
                self.assertEqual(
                    service.state()["log_path"],
                    str(service.journal.latest_path),
                )
            finally:
                service.stop()
                service.memory.close()

    def test_uncredited_combat_death_is_not_reported_as_kill(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            try:
                service._record_snapshot_events(
                    {
                        "companion": {"x": 1, "z": 2},
                        "world": {"shard": "1"},
                        "events": [
                            {
                                "type": "combat_target_defeated",
                                "intent_id": "combat-1",
                                "verified": False,
                            },
                            {
                                "type": "task_failed",
                                "intent_id": "combat-2",
                                "reason": "combat_leash_exceeded",
                            },
                        ],
                    }
                )
                text = service.journal.latest_path.read_text(encoding="utf-8")
                self.assertIn("最后一击不是伴侣完成的", text)
                self.assertIn("伴侣离用户超过战斗安全距离，已停止追击", text)
            finally:
                service.stop()
                service.memory.close()

    def test_shard_transition_cancels_stale_task_and_follows(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            service.force_command(
                {
                    "intent_id": "ruins-combat",
                    "mode": "combat",
                    "target_guid": "42",
                    "lease_seconds": 1800,
                }
            )
            try:
                service.tick(
                    {
                        "companion": {"identity_id": "primary"},
                        "player": {"guid": "1"},
                        "world": {"shard": "2"},
                        "nearby": [],
                        "events": [
                            {
                                "event_id": "transition-1",
                                "type": "task_failed",
                                "intent_id": "ruins-combat",
                                "reason": "shard_transition",
                                "from_shard": "1",
                                "to_shard": "2",
                            }
                        ],
                    }
                )
                intent = service.state()["intent"]
                self.assertEqual(intent["mode"], "follow")
                self.assertEqual(intent["reason"], "shard_transition_follow")
                text = service.journal.latest_path.read_text(encoding="utf-8")
                self.assertIn("伴侣随你切换世界", text)
                self.assertIn("shard_transition", text)
            finally:
                service.stop()
                service.memory.close()

    def test_model_cross_world_intent_is_blocked_before_game_execution(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            service.planner = CrossWorldPlanner()
            service.start()
            try:
                service.tick(
                    {
                        "companion": {"x": 0, "z": 0},
                        "player": {"guid": "1"},
                        "world": {"shard": "1", "is_master": True},
                        "landmarks": {},
                        "nearby": [],
                        "events": [],
                    }
                )
                service.instruction("你去洞穴拿点金子")
                deadline = time.time() + 2
                while time.time() < deadline and not service.state()["messages"]:
                    time.sleep(0.02)
                state = service.state()
                self.assertEqual(state["intent"]["mode"], "hold")
                self.assertEqual(
                    state["intent"]["reason"],
                    "cross_world_forbidden",
                )
                self.assertIn("不能进入另一个世界", state["messages"][-1]["text"])
                self.assertNotIn(
                    "我现在进入洞穴",
                    state["messages"][-1]["text"],
                )
                text = service.journal.latest_path.read_text(encoding="utf-8")
                self.assertIn("controller.cross_world_blocked", text)
            finally:
                service.stop()
                service.memory.close()

    def test_direct_command_and_foreign_landmark_are_blocked(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            try:
                service.tick(
                    {
                        "companion": {},
                        "player": {"guid": "1"},
                        "world": {"shard": "1", "is_master": True},
                        "landmarks": {
                            "cave-home": {
                                "shard": "2",
                                "x": 10,
                                "z": 20,
                            }
                        },
                        "nearby": [],
                        "events": [],
                    }
                )
                state = service.force_command(
                    {
                        "intent_id": "manual-cross-world",
                        "mode": "fetch_item",
                        "params": {"target_shard": "2"},
                    }
                )
                self.assertEqual(state["intent"]["mode"], "hold")
                self.assertEqual(
                    state["intent"]["reason"],
                    "cross_world_forbidden",
                )

                state = service.force_command(
                    {
                        "intent_id": "foreign-landmark",
                        "mode": "move_to_landmark",
                        "params": {"landmark": "cave-home"},
                    }
                )
                self.assertEqual(state["intent"]["mode"], "hold")
                self.assertEqual(
                    state["intent"]["reason"],
                    "cross_world_forbidden",
                )

                state = service.force_command(
                    {
                        "intent_id": "same-world-fetch",
                        "mode": "fetch_item",
                        "params": {"target_shard": "1"},
                    }
                )
                self.assertEqual(state["intent"]["mode"], "fetch_item")
            finally:
                service.stop()
                service.memory.close()

    def test_lethal_hit_forces_safe_follow(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            service.force_command(
                {
                    "intent_id": "boss-fight",
                    "mode": "combat",
                    "target_guid": "99",
                    "lease_seconds": 1800,
                }
            )
            try:
                service.tick(
                    {
                        "companion": {"x": 0, "z": 0, "health": 8},
                        "player": {"guid": "1"},
                        "world": {"shard": "1", "is_master": True},
                        "nearby": [
                            {
                                "prefab": "treasurechest",
                                "x": 3,
                                "z": 4,
                                "container": True,
                                "container_items": [
                                    {"prefab": "goldnugget", "stacksize": 5}
                                ],
                            }
                        ],
                        "events": [
                            {
                                "event_id": "lethal-1",
                                "type": "task_failed",
                                "intent_id": "boss-fight",
                                "reason": "lethal_next_hit",
                                "current_health": 8,
                                "estimated_damage": 12,
                            }
                        ],
                    }
                )
                state = service.state()
                self.assertEqual(state["intent"]["mode"], "follow")
                self.assertEqual(
                    state["intent"]["reason"],
                    "lethal_retreat_follow",
                )
                self.assertIn("下一次受击", state["messages"][-1]["text"])
                world = service.agent_memory.world_context("1", "goldnugget")
                self.assertEqual(world[0]["prefab"], "treasurechest")
            finally:
                service.stop()
                service.memory.close()

    def test_research_result_is_saved_in_isolated_skill_memory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            planner = ResearchPlanner()
            service.planner = planner
            service.research = FakeResearch()
            service.start()
            try:
                service.tick(
                    {
                        "companion": {},
                        "player": {"guid": "1"},
                        "world": {"shard": "1", "is_master": True},
                        "nearby": [],
                        "events": [],
                    }
                )
                service.instruction("帮我查一下建造护符怎么做")
                deadline = time.time() + 2
                while time.time() < deadline and not service.state()["messages"]:
                    time.sleep(0.02)
                self.assertEqual(planner.calls, 2)
                self.assertTrue(planner.saw_research)
                hits = service.agent_memory.search_skills("建造护符")
                self.assertEqual(len(hits), 1)
                self.assertIn("金块", hits[0].content)
            finally:
                service.stop()
                service.memory.close()

    def test_in_game_message_can_be_chat_or_task(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            planner = TriggerRecorderPlanner()
            service.planner = planner
            service.start()
            try:
                service.tick(
                    {
                        "companion": {},
                        "player": {"guid": "1"},
                        "world": {"shard": "1", "is_master": True},
                        "nearby": [],
                        "events": [],
                    }
                )
                service.message("今天怎么样")
                deadline = time.time() + 2
                while time.time() < deadline and not service.state()["messages"]:
                    time.sleep(0.02)
                self.assertEqual(planner.last_trigger, "chat_or_task")
                self.assertEqual(
                    service.agent_memory.recent_chat("chat")[0]["text"],
                    "今天怎么样",
                )
            finally:
                service.stop()
                service.memory.close()

    def test_direct_playbook_bypasses_deepseek(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            service.planner = ExplodingPlanner()
            try:
                service.tick(
                    {
                        "companion": {"prefab": "waxwell"},
                        "player": {"guid": "1", "prefab": "waxwell"},
                        "world": {"shard": "1", "is_master": True},
                        "nearby": [],
                        "events": [],
                    }
                )
                state = service.message("帮我打些蜘蛛丝")
                self.assertEqual(state["playbook_matched"], "maxwell.collect_spider_silk")
                self.assertEqual(state["intent"]["mode"], "collect_loot")
                self.assertIn("蜘蛛丝", state["messages"][-1]["text"])
                forced = service.message(
                    "别管饱食度，务必去帮我打十个蜘蛛丝"
                )
                self.assertTrue(
                    forced["intent"]["params"]["ignore_survival_safety"]
                )
            finally:
                service.stop()
                service.memory.close()

    def test_unimplemented_capability_is_reported_and_recorded(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            service.planner = CapabilityGapPlanner()
            service.start()
            try:
                service.tick(
                    {
                        "companion": {"prefab": "wendy"},
                        "player": {"guid": "1", "prefab": "wendy"},
                        "world": {"shard": "1", "is_master": True},
                        "nearby": [],
                        "events": [],
                    }
                )
                service.message("帮我启动远古机关")
                deadline = time.time() + 2
                while time.time() < deadline and not service.state()["messages"]:
                    time.sleep(0.02)
                state = service.state()
                self.assertEqual(state["intent"]["mode"], "hold")
                self.assertEqual(state["intent"]["reason"], "capability_gap")
                self.assertIn("做不到", state["messages"][-1]["text"])
                self.assertEqual(len(service.agent_memory.open_capability_gaps()), 1)
            finally:
                service.stop()
                service.memory.close()

    def test_collect_completion_reports_directly_and_follows(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            service.force_command(
                {
                    "intent_id": "collect-task",
                    "mode": "collect_loot",
                    "target_prefab": "silk",
                    "lease_seconds": 1800,
                }
            )
            try:
                service.tick(
                    {
                        "companion": {"prefab": "waxwell"},
                        "player": {"guid": "1", "prefab": "waxwell"},
                        "world": {"shard": "1", "is_master": True},
                        "nearby": [],
                        "events": [
                            {
                                "event_id": "collect-done",
                                "type": "task_complete",
                                "mode": "collect_loot",
                                "item_prefab": "silk",
                                "amount": 10,
                                "delivered_to_player": True,
                            }
                        ],
                    }
                )
                state = service.state()
                self.assertEqual(state["intent"]["mode"], "follow")
                self.assertEqual(state["intent"]["reason"], "collect_complete_follow")
                self.assertEqual(
                    state["messages"][-1]["text"],
                    "蜘蛛丝收集好了，共 10 个。已经交给你。",
                )
            finally:
                service.stop()
                service.memory.close()

    def test_low_hunger_cancels_remote_task_and_reports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            service.force_command(
                {
                    "intent_id": "far-task",
                    "mode": "collect_loot",
                    "target_prefab": "silk",
                    "lease_seconds": 1800,
                }
            )
            try:
                service.tick(
                    {
                        "companion": {
                            "prefab": "waxwell",
                            "hunger": 20,
                            "max_hunger": 150,
                        },
                        "player": {"guid": "1", "prefab": "waxwell"},
                        "world": {"shard": "1", "is_master": True},
                        "nearby": [],
                        "events": [
                            {
                                "event_id": "hungry-1",
                                "type": "task_failed",
                                "mode": "collect_loot",
                                "reason": "survival_hunger_low",
                                "hunger_percent": 13,
                            }
                        ],
                    }
                )
                state = service.state()
                self.assertEqual(state["intent"]["mode"], "follow")
                self.assertEqual(state["intent"]["reason"], "survival_return_follow")
                self.assertIn("饱食度", state["messages"][-1]["text"])
            finally:
                service.stop()
                service.memory.close()

    def test_native_emergency_events_report_without_waking_model(self) -> None:
        self.assertFalse(
            {
                "emergency_detected",
                "emergency_action",
                "emergency_resolved",
            }
            & IMPORTANT_EVENTS
        )
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            try:
                service.tick(
                    {
                        "companion": {
                            "prefab": "waxwell",
                            "emergency": {
                                "active": True,
                                "category": "darkness",
                                "action": "equipped_torch",
                            },
                        },
                        "player": {"guid": "1", "prefab": "waxwell"},
                        "world": {
                            "shard": "2",
                            "is_master": False,
                            "isacidraining": False,
                        },
                        "nearby": [],
                        "events": [
                            {
                                "event_id": "emergency-dark-1",
                                "type": "emergency_detected",
                                "category": "darkness",
                                "severity": "high",
                                "action": "equipped_torch",
                            },
                            {
                                "event_id": "emergency-quake-1",
                                "type": "emergency_detected",
                                "category": "earthquake",
                                "severity": "high",
                                "action": "brace",
                            },
                            {
                                "event_id": "emergency-resolved-1",
                                "type": "emergency_resolved",
                                "category": "earthquake",
                                "action": "brace",
                            },
                        ],
                    }
                )
                messages = service.state()["messages"]
                self.assertEqual(len(messages), 3)
                self.assertIn("周围突然变黑", messages[0]["text"])
                self.assertIn("火把点亮", messages[0]["text"])
                self.assertIn("地震", messages[1]["text"])
                self.assertIn("先站稳", messages[1]["text"])
                self.assertIn("地面安静下来", messages[2]["text"])
                self.assertTrue(all(item["source"] == "emergency" for item in messages))
                service.tick(
                    {
                        "companion": {"prefab": "waxwell"},
                        "player": {"guid": "1", "prefab": "waxwell"},
                        "world": {"shard": "1", "is_master": True},
                        "nearby": [],
                        "events": [
                            {
                                "event_id": f"emergency-hound-{index}",
                                "type": "emergency_detected",
                                "category": "hound_wave",
                                "severity": "high",
                                "action": "fight",
                            }
                            for index in range(4)
                        ],
                    }
                )
                hound_lines = [
                    item["text"]
                    for item in service.state()["messages"][-4:]
                ]
                self.assertEqual(len(set(hound_lines)), 4)
                self.assertIn("来狗啦来狗啦", hound_lines[0])
            finally:
                service.stop()
                service.memory.close()

    def test_new_master_session_clears_stale_task(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            service.force_command(
                {
                    "intent_id": "old-world-task",
                    "mode": "collect_loot",
                    "target_prefab": "silk",
                    "lease_seconds": 1800,
                }
            )
            base_snapshot = {
                "companion": {"prefab": "waxwell"},
                "player": {"guid": "1", "prefab": "waxwell"},
                "nearby": [],
                "events": [],
            }
            try:
                service.tick(
                    {
                        **base_snapshot,
                        "world": {
                            "shard": "1",
                            "is_master": True,
                            "session_id": "session-a",
                        },
                    }
                )
                self.assertEqual(
                    service.state()["intent"]["intent_id"],
                    "old-world-task",
                )
                service.tick(
                    {
                        **base_snapshot,
                        "world": {
                            "shard": "1",
                            "is_master": True,
                            "session_id": "session-b",
                        },
                    }
                )
                state = service.state()
                self.assertEqual(state["intent"]["mode"], "follow")
                self.assertEqual(
                    state["intent"]["reason"],
                    "session_started_follow",
                )
            finally:
                service.stop()
                service.memory.close()

    def test_recovery_events_report_estimates_without_waking_model(self) -> None:
        self.assertFalse(
            {
                "recovery_started",
                "recovery_completed",
                "recovery_unavailable",
            }
            & IMPORTANT_EVENTS
        )
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=20.0,
            )
            service = CompanionService(settings)
            try:
                service.tick(
                    {
                        "companion": {"prefab": "waxwell"},
                        "player": {"guid": "1", "prefab": "waxwell"},
                        "world": {"shard": "1", "is_master": True},
                        "nearby": [],
                        "events": [
                            {
                                "event_id": "recovery-start-1",
                                "type": "recovery_started",
                                "method": "tent",
                                "sleep_seconds": 190,
                                "estimated_hunger_cost": 58,
                                "expected_health_gain": 120,
                                "expected_sanity_gain": 60,
                            },
                            {
                                "event_id": "recovery-unavailable-1",
                                "type": "recovery_unavailable",
                                "reason": "not_enough_hunger_for_sleep",
                                "hunger_cost": 92,
                                "hunger_after": 8,
                                "hunger_reserve": 18,
                            },
                            {
                                "event_id": "recovery-food-1",
                                "type": "recovery_started",
                                "method": "food",
                                "hunger_percent": 40,
                            },
                            {
                                "event_id": "recovery-heal-1",
                                "type": "recovery_completed",
                                "method": "healing_item",
                                "health": 80,
                            },
                        ],
                    }
                )
                messages = service.state()["messages"]
                self.assertEqual(len(messages), 4)
                self.assertIn("大约睡 190 秒", messages[0]["text"])
                self.assertIn("预计消耗 58 点饥饿", messages[0]["text"])
                self.assertIn("恢复 120 点生命", messages[0]["text"])
                self.assertIn("只剩 8 点", messages[1]["text"])
                self.assertIn("至少要保留 18 点", messages[1]["text"])
                self.assertIn("先吃些随身食物", messages[2]["text"])
                self.assertIn("治疗物品用完了", messages[3]["text"])
                self.assertIn("生命 80", messages[3]["text"])
            finally:
                service.stop()
                service.memory.close()


if __name__ == "__main__":
    unittest.main()
