from __future__ import annotations

import tempfile
import time
import unittest
from pathlib import Path

from controller.config import Settings
from controller.service import CompanionService, IMPORTANT_EVENTS, death_report


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
                while time.time() < deadline and not service.state()["messages"]:
                    time.sleep(0.02)
                state = service.state()
                self.assertIn("decision_support", state)
                self.assertIn("combat", state["decision_support"])
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
                service.force_command(
                    {
                        "intent_id": "fetch-1",
                        "mode": "fetch_item",
                        "target_prefab": "goldnugget",
                        "lease_seconds": 60,
                        "params": {"amount": 1},
                    }
                )
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
                                "mode": "fetch_item",
                                "item_prefab": "goldnugget",
                                "amount": 1,
                                "requested_amount": 1,
                                "inventory_before": 0,
                                "inventory_after": 1,
                                "verified": True,
                            }
                        ],
                    }
                )
                text = service.journal.latest_path.read_text(encoding="utf-8")
                self.assertIn("微光确认任务完成", text)
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
                self.assertIn("最后一击不是微光完成的", text)
                self.assertIn("微光离用户超过战斗安全距离，已停止追击", text)
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
                self.assertIn("微光随你切换世界", text)
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
                        "player": {
                            "guid": "1",
                            "prefab": "waxwell",
                            "x": 40,
                            "z": -12,
                        },
                        "world": {"shard": "1", "is_master": True},
                        "nearby": [],
                        "events": [],
                    }
                )
                state = service.message("帮我打些蜘蛛丝")
                self.assertEqual(state["playbook_matched"], "maxwell.collect_spider_silk")
                self.assertEqual(state["intent"]["mode"], "collect_loot")
                self.assertEqual(
                    state["decision_branch"]["id"],
                    "collection",
                )
                self.assertIn("蜘蛛丝", state["messages"][-1]["text"])
                grass = service.message("去采集附近的草")
                self.assertEqual(
                    grass["playbook_matched"],
                    "generic.collect_grass",
                )
                self.assertEqual(grass["intent"]["mode"], "harvest_area")
                self.assertEqual(grass["intent"]["position"], [40, -12])
                self.assertEqual(
                    grass["decision_branch"]["id"],
                    "collection",
                )
                forced = service.message(
                    "别管饱食度，务必去帮我打十个蜘蛛丝"
                )
                self.assertTrue(
                    forced["intent"]["params"]["ignore_survival_safety"]
                )
            finally:
                service.stop()
                service.memory.close()

    def test_unfavorable_frog_group_is_handled_without_deepseek(self) -> None:
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
                        "companion": {
                            "guid": "9",
                            "prefab": "waxwell",
                            "health": 20,
                            "max_health": 75,
                            "hunger": 90,
                            "max_hunger": 150,
                            "sanity": 120,
                            "max_sanity": 200,
                        },
                        "player": {
                            "guid": "1",
                            "prefab": "walter",
                            "x": 2,
                            "z": 1,
                        },
                        "world": {"shard": "1", "is_master": True},
                        "inventory": [],
                        "inventory_counts": {},
                        "equipped": [],
                        "capabilities": {"known_recipes": []},
                        "nearby": [
                            {
                                "guid": str(index),
                                "prefab": "frog",
                                "hostile": True,
                                "distance": index,
                            }
                            for index in range(1, 6)
                        ],
                        "events": [],
                    }
                )
                state = service.message("帮我打一下这些青蛙")
                self.assertEqual(
                    state["local_policy_matched"],
                    "combat.avoid_unfavorable_group",
                )
                self.assertEqual(state["intent"]["mode"], "follow")
                self.assertEqual(state["decision_branch"]["id"], "combat")
                self.assertIn("5 只青蛙", state["messages"][-1]["text"])
                service.tick(
                    {
                        "companion": {
                            "guid": "9",
                            "prefab": "waxwell",
                            "health": 20,
                            "max_health": 75,
                        },
                        "player": {
                            "guid": "1",
                            "prefab": "walter",
                            "x": 2,
                            "z": 1,
                        },
                        "world": {"shard": "1", "is_master": True},
                        "inventory": [],
                        "inventory_counts": {},
                        "equipped": [],
                        "capabilities": {"known_recipes": []},
                        "nearby": [
                            {
                                "guid": str(index),
                                "prefab": "spider",
                                "hostile": True,
                                "distance": index,
                            }
                            for index in range(1, 5)
                        ],
                        "events": [],
                    }
                )
                spider_state = service.message("帮我打些蜘蛛丝")
                self.assertEqual(
                    spider_state["local_policy_matched"],
                    "combat.avoid_unfavorable_group",
                )
                self.assertEqual(spider_state["intent"]["mode"], "follow")
                self.assertEqual(
                    spider_state["decision_branch"]["id"],
                    "combat",
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
                    "params": {"amount": 10},
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
                                "intent_id": "collect-task",
                                "mode": "collect_loot",
                                "item_prefab": "silk",
                                "amount": 10,
                                "requested_amount": 10,
                                "inventory_before": 0,
                                "inventory_after": 0,
                                "companion_delta": 10,
                                "player_before": 0,
                                "player_after": 10,
                                "player_delta": 10,
                                "delivered_to_player": True,
                                "delivered_verified": True,
                                "verified": True,
                            }
                        ],
                    }
                )
                state = service.state()
                self.assertEqual(state["intent"]["mode"], "follow")
                self.assertEqual(state["intent"]["reason"], "experience_complete_follow")
                self.assertEqual(
                    state["messages"][-1]["text"],
                    "蜘蛛丝收集好了，共 10 个。已经交给你。",
                )
            finally:
                service.stop()
                service.memory.close()

    def test_unverified_collect_completion_keeps_original_task(self) -> None:
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
                    "intent_id": "collect-five",
                    "mode": "collect_loot",
                    "target_prefab": "silk",
                    "lease_seconds": 1800,
                    "params": {"amount": 5},
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
                                "event_id": "collect-two-only",
                                "type": "task_complete",
                                "intent_id": "collect-five",
                                "mode": "collect_loot",
                                "item_prefab": "silk",
                                "amount": 2,
                                "requested_amount": 5,
                                "inventory_before": 0,
                                "inventory_after": 2,
                                "companion_delta": 2,
                                "delivered_to_player": False,
                                "verified": True,
                            }
                        ],
                    }
                )
                state = service.state()
                self.assertEqual(state["intent"]["intent_id"], "collect-five")
                self.assertEqual(state["intent"]["mode"], "collect_loot")
                self.assertEqual(state["messages"], [])
                self.assertEqual(
                    state["experience"]["last_outcome"]["reason"],
                    "amount_below_requested",
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
                messages = service.state()["messages"]
                hound_lines = [
                    item["text"]
                    for item in messages
                    if item["source"] == "emergency"
                    and "来狗啦来狗啦" in item["text"]
                ]
                self.assertEqual(len(hound_lines), 1)
                self.assertIn("来狗啦来狗啦", hound_lines[0])
                worm_detected = service._emergency_announcement(
                    {
                        "category": "hound_wave",
                        "action": "fight",
                        "source_prefab": "worm",
                    },
                    "detected",
                )
                self.assertIn("地底", worm_detected)
                self.assertNotIn("狗牙", worm_detected)
                worm_resolved = service._emergency_announcement(
                    {
                        "category": "hound_wave",
                        "action": "fight",
                        "source_prefab": "worm",
                    },
                    "resolved",
                )
                self.assertIn("蠕虫", worm_resolved)
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
                service.force_command(
                    {
                        "intent_id": "recovery-base",
                        "mode": "follow",
                        "lease_seconds": 1800,
                        "reason": "test_recovery_base",
                    }
                )
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
                                "intent_id": "recovery-base",
                                "method": "tent",
                                "health": 40,
                                "health_max": 100,
                                "hunger": 100,
                                "hunger_max": 150,
                                "sanity": 30,
                                "sanity_max": 100,
                                "sleep_seconds": 190,
                                "estimated_hunger_cost": 58,
                                "expected_health_gain": 120,
                                "expected_sanity_gain": 60,
                            },
                            {
                                "event_id": "recovery-complete-tent",
                                "type": "recovery_completed",
                                "intent_id": "recovery-base",
                                "method": "tent",
                                "health": 80,
                                "health_max": 100,
                                "hunger": 70,
                                "hunger_max": 150,
                                "sanity": 60,
                                "sanity_max": 100,
                                "verified": True,
                            },
                            {
                                "event_id": "recovery-food-start-1",
                                "type": "recovery_started",
                                "intent_id": "recovery-base",
                                "method": "food",
                                "health": 80,
                                "health_max": 100,
                                "hunger": 40,
                                "hunger_max": 150,
                                "sanity": 60,
                                "sanity_max": 100,
                            },
                            {
                                "event_id": "recovery-food-complete-1",
                                "type": "recovery_completed",
                                "intent_id": "recovery-base",
                                "method": "food",
                                "health": 80,
                                "health_max": 100,
                                "hunger": 90,
                                "hunger_max": 150,
                                "sanity": 60,
                                "sanity_max": 100,
                                "verified": True,
                            },
                            {
                                "event_id": "recovery-unavailable-1",
                                "type": "recovery_unavailable",
                                "intent_id": "recovery-base",
                                "reason": "not_enough_hunger_for_sleep",
                                "hunger_cost": 92,
                                "hunger_after": 8,
                                "hunger_reserve": 18,
                            },
                            {
                                "event_id": "recovery-unavailable-duplicate",
                                "type": "recovery_unavailable",
                                "intent_id": "recovery-base",
                                "reason": "not_enough_hunger_for_sleep",
                                "hunger_cost": 92,
                                "hunger_after": 8,
                                "hunger_reserve": 18,
                            },
                        ],
                    }
                )
                state = service.state()
                messages = state["messages"]
                self.assertEqual(len(messages), 5)
                self.assertIn("大约睡 190 秒", messages[0]["text"])
                self.assertIn("预计消耗 58 点饥饿", messages[0]["text"])
                self.assertIn("恢复 120 点生命", messages[0]["text"])
                self.assertIn("我休息好了", messages[1]["text"])
                self.assertIn("先吃些随身食物", messages[2]["text"])
                self.assertIn("饥饿 90", messages[3]["text"])
                self.assertIn("只剩 8 点", messages[4]["text"])
                self.assertIn("至少要保留 18 点", messages[4]["text"])
                self.assertEqual(state["intent"]["intent_id"], "recovery-base")
            finally:
                service.stop()
                service.memory.close()

    def test_boss_fight_queues_wheel_work_until_combat_ends(self) -> None:
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
                service.force_command(
                    {
                        "intent_id": "boss-fight",
                        "mode": "combat",
                        "target_guid": "boss-1",
                        "lease_seconds": 1800,
                    }
                )
                queued_state = service.wheel_command(
                    {
                        "schema": 1,
                        "branch_id": "collection",
                        "action": "collect_resource",
                        "target_id": "grass",
                        "amount": 10,
                    }
                )

                self.assertTrue(queued_state["command_queued"])
                self.assertEqual(
                    queued_state["intent"]["intent_id"],
                    "boss-fight",
                )
                self.assertEqual(
                    queued_state["pending_intents"][0]["mode"],
                    "harvest_area",
                )
                self.assertIn(
                    "结束后马上照你说的做",
                    queued_state["messages"][-1]["text"],
                )
                self.assertNotIn(
                    "优先级",
                    queued_state["messages"][-1]["text"],
                )
                self.assertNotIn(
                    "harvest_area",
                    queued_state["messages"][-1]["text"],
                )

                service.tick(
                    {
                        "companion": {"x": 0, "z": 0, "health": 100},
                        "player": {"guid": "1"},
                        "world": {"shard": "1", "is_master": True},
                        "events": [
                            {
                                "event_id": "boss-defeated",
                                "type": "combat_target_defeated",
                                "intent_id": "boss-fight",
                                "target_guid": "boss-1",
                                "target_prefab": "dragonfly",
                                "verified": True,
                            }
                        ],
                    }
                )
                resumed = service.state()
                self.assertEqual(resumed["intent"]["mode"], "harvest_area")
                self.assertEqual(resumed["intent"]["params"]["amount"], 10)
                self.assertEqual(resumed["pending_intents"], [])
                self.assertIn(
                    "继续刚才记下的",
                    resumed["messages"][-1]["text"],
                )
            finally:
                service.stop()
                service.memory.close()

    def test_user_retreat_interrupts_boss_fight(self) -> None:
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
                service.force_command(
                    {
                        "intent_id": "boss-fight",
                        "mode": "combat",
                        "target_guid": "boss-1",
                        "lease_seconds": 1800,
                    }
                )
                state = service.wheel_command(
                    {
                        "schema": 1,
                        "branch_id": "combat",
                        "action": "retreat",
                    }
                )

                self.assertFalse(state["command_queued"])
                self.assertEqual(state["intent"]["mode"], "retreat")
            finally:
                service.stop()
                service.memory.close()

    def test_model_task_during_boss_fight_is_queued(self) -> None:
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
                service.force_command(
                    {
                        "intent_id": "boss-fight",
                        "mode": "combat",
                        "target_guid": "boss-1",
                        "lease_seconds": 1800,
                    }
                )
                service._apply_response(
                    {
                        "reply": {
                            "text": "好，我去收草。",
                            "expects_response": False,
                        },
                        "intent": {
                            "intent_id": "chat-grass",
                            "mode": "harvest_area",
                            "lease_seconds": 600,
                            "params": {"amount": 10},
                        },
                    },
                    force_chat_only=False,
                    instruction="帮我收 10 个草",
                )

                state = service.state()
                self.assertEqual(state["intent"]["intent_id"], "boss-fight")
                self.assertEqual(
                    state["pending_intents"][0]["intent_id"],
                    "chat-grass",
                )
                self.assertIn(
                    "结束后马上照你说的做",
                    state["messages"][-1]["text"],
                )
                self.assertNotIn("优先级", state["messages"][-1]["text"])
            finally:
                service.stop()
                service.memory.close()

    def test_death_report_names_cause_and_vitals(self) -> None:
        self.assertNotIn("companion_dead", IMPORTANT_EVENTS)
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
                service.force_command(
                    {
                        "intent_id": "follow-task",
                        "mode": "follow",
                        "lease_seconds": 600,
                    }
                )
                service.tick(
                    {
                        "companion": {
                            "x": 3,
                            "z": 4,
                            "health": 0,
                            "max_health": 150,
                            "hunger": 41,
                            "max_hunger": 150,
                            "sanity": 60,
                            "max_sanity": 200,
                        },
                        "player": {"guid": "1"},
                        "world": {"shard": "1", "is_master": True},
                        "events": [
                            {
                                "event_id": "death-cold",
                                "type": "companion_dead",
                                "cause": "cold",
                                "health": 0,
                                "health_max": 150,
                                "hunger": 41,
                                "hunger_max": 150,
                                "sanity": 60,
                                "sanity_max": 200,
                                "freezing": True,
                                "active_mode": "follow",
                            }
                        ],
                    }
                )
                state = service.state()
                text = state["messages"][-1]["text"]
                self.assertIn("直接死因：冻死", text)
                self.assertIn("饥饿 41/150", text)
                self.assertIn("当时处于过冷", text)
                self.assertIn("当时任务：跟随你", text)
                self.assertNotIn("状态不好", text)
                self.assertEqual(state["intent"]["reason"], "death_respawn_follow")
            finally:
                service.stop()
                service.memory.close()

    def test_death_while_resident_returns_to_home_and_stays(self) -> None:
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
                service.force_command(
                    {
                        "intent_id": "resident",
                        "mode": "homestead",
                        "lease_seconds": 86400,
                        "params": {
                            "landmark": "家",
                            "stay_home": True,
                            "stop_distance": 4,
                        },
                    }
                )
                service.tick(
                    {
                        "companion": {"x": 3, "z": 4, "health": 0},
                        "player": {"guid": "1"},
                        "world": {"shard": "1", "is_master": True},
                        "events": [
                            {
                                "event_id": "death-at-home",
                                "type": "companion_dead",
                                "cause": "cold",
                                "active_mode": "homestead",
                                "home": {
                                    "name": "家",
                                    "shard": "1",
                                    "x": 100,
                                    "z": -20,
                                },
                            }
                        ],
                    }
                )

                state = service.state()
                self.assertEqual(
                    state["intent"]["reason"],
                    "death_respawn_homestead",
                )
                self.assertEqual(state["intent"]["mode"], "homestead")
                self.assertEqual(
                    state["intent"]["params"]["landmark"],
                    "家",
                )
                self.assertEqual(state["intent"]["position"], [100.0, -20.0])
                self.assertIn("回到“家”继续驻守", state["messages"][-1]["text"])
            finally:
                service.stop()
                service.memory.close()

    def test_low_health_does_not_turn_resident_mode_into_follow(self) -> None:
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
                service.force_command(
                    {
                        "intent_id": "resident",
                        "mode": "homestead",
                        "lease_seconds": 86400,
                        "params": {"landmark": "家", "stay_home": True},
                    }
                )
                service.tick(
                    {
                        "companion": {
                            "x": 100,
                            "z": -20,
                            "health": 8,
                            "max_health": 150,
                        },
                        "player": {"guid": "1"},
                        "world": {"shard": "1", "is_master": True},
                        "events": [
                            {
                                "event_id": "home-low-health",
                                "type": "task_failed",
                                "intent_id": "resident",
                                "mode": "homestead",
                                "reason": "survival_health_low",
                            }
                        ],
                    }
                )

                state = service.state()
                self.assertEqual(state["intent"]["mode"], "homestead")
                self.assertEqual(state["intent"]["intent_id"], "resident")
                self.assertIn("就在基地处理状态", state["messages"][-1]["text"])
            finally:
                service.stop()
                service.memory.close()

    def test_death_report_infers_darkness_when_native_cause_is_missing(
        self,
    ) -> None:
        text = death_report(
            {
                "health": 0,
                "health_max": 75,
                "hunger": 74,
                "hunger_max": 150,
                "sanity": 185,
                "sanity_max": 200,
                "freezing": False,
                "overheating": False,
                "in_light": False,
                "inferred_cause": "darkness",
            }
        )

        self.assertIn("直接死因：被黑暗里的查理杀死", text)
        self.assertNotIn("游戏事件没有提供可识别的直接死因", text)

    def test_schedule_actions_persist_and_complete_glommer_task(self) -> None:
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
                service._apply_response(
                    {
                        "reply": {
                            "text": "记住了，下次满月我去接格罗姆。",
                            "expects_response": False,
                        },
                        "schedule": {
                            "kind": "glommer_pickup",
                            "goal": "满月去格罗姆雕像接回格罗姆",
                            "due_phase": "night",
                            "due_moon_phase": "full",
                            "shard": "1",
                            "x": 42,
                            "z": -18,
                            "details": {
                                "return_landmark": "家",
                                "requires_flower": True,
                            },
                        },
                    },
                    force_chat_only=False,
                )

                saved = service.agent_memory.scheduled_tasks()
                self.assertEqual(len(saved), 1)
                task = saved[0]
                self.assertEqual(task["kind"], "glommer_pickup")
                self.assertEqual(task["due_moon_phase"], "full")
                self.assertEqual(task["details"]["return_landmark"], "家")

                service._apply_response(
                    {
                        "reply": {
                            "text": "格罗姆接回来了。",
                            "expects_response": False,
                        },
                        "schedule_updates": {
                            "schedule_id": task["id"],
                            "status": "completed",
                        },
                    },
                    force_chat_only=False,
                )
                self.assertEqual(service.agent_memory.scheduled_tasks(), [])
                self.assertEqual(
                    len(
                        service.agent_memory.scheduled_tasks(
                            status="completed"
                        )
                    ),
                    1,
                )
            finally:
                service.stop()
                service.memory.close()

    def test_local_glommer_command_persists_schedule_without_model(
        self,
    ) -> None:
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
                        "companion": {
                            "guid": "99",
                            "prefab": "waxwell",
                        },
                        "player": {
                            "guid": "1",
                            "prefab": "wilson",
                            "x": 0,
                            "z": 0,
                        },
                        "home": {
                            "name": "家",
                            "shard": "1",
                            "x": 10,
                            "z": 20,
                        },
                        "world": {
                            "shard": "1",
                            "moon_phase": "quarter",
                        },
                        "nearby": [
                            {
                                "prefab": "statueglommer",
                                "x": 420,
                                "z": -180,
                            }
                        ],
                        "events": [],
                    }
                )

                state = service.instruction("帮我把格罗姆接回来")

                self.assertEqual(
                    state["local_policy_matched"],
                    "exploration.glommer_scheduled",
                )
                tasks = service.agent_memory.scheduled_tasks()
                self.assertEqual(len(tasks), 1)
                self.assertEqual(tasks[0]["kind"], "glommer_pickup")
                self.assertEqual(tasks[0]["due_phase"], "night")
                self.assertEqual(tasks[0]["due_moon_phase"], "full")
                self.assertEqual(tasks[0]["x"], 420)
                self.assertEqual(tasks[0]["z"], -180)
                self.assertEqual(
                    tasks[0]["details"]["return_landmark"],
                    "家",
                )
            finally:
                service.stop()
                service.memory.close()

    def test_due_schedule_waits_for_full_moon_night(self) -> None:
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
                task_id = service.agent_memory.save_scheduled_task(
                    kind="glommer_pickup",
                    goal="满月去格罗姆雕像接回格罗姆",
                    due_day=10,
                    due_phase="night",
                    due_moon_phase="full",
                    shard="1",
                )
                snapshot = {
                    "companion": {},
                    "player": {"guid": "1"},
                    "world": {
                        "shard": "1",
                        "day": 9,
                        "phase": "night",
                        "moon_phase": "full",
                    },
                    "nearby": [],
                    "events": [],
                }
                service.tick(snapshot)
                self.assertIsNone(service._pending_instruction)

                snapshot["world"]["day"] = 10
                snapshot["world"]["phase"] = "dusk"
                service.tick(snapshot)
                self.assertIsNone(service._pending_instruction)

                snapshot["world"]["phase"] = "night"
                service.tick(snapshot)
                self.assertIn(
                    "满月去格罗姆雕像接回格罗姆",
                    service._pending_instruction or "",
                )
                self.assertEqual(service._pending_trigger, "schedule_due")
                triggered = service.agent_memory.scheduled_tasks()[0]
                self.assertEqual(triggered["id"], task_id)
                self.assertIsNotNone(triggered["last_triggered_at"])
            finally:
                service.stop()
                service.memory.close()

    def test_due_schedule_cannot_interrupt_boss_fight(self) -> None:
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
                service.force_command(
                    {
                        "intent_id": "boss-fight",
                        "mode": "combat",
                        "target_guid": "boss-1",
                        "lease_seconds": 1800,
                    }
                )
                service.agent_memory.save_scheduled_task(
                    kind="glommer_pickup",
                    goal="满月去格罗姆雕像接回格罗姆",
                    due_phase="night",
                    due_moon_phase="full",
                    shard="1",
                )
                service.tick(
                    {
                        "companion": {},
                        "player": {"guid": "1"},
                        "world": {
                            "shard": "1",
                            "day": 10,
                            "phase": "night",
                            "moon_phase": "full",
                        },
                        "nearby": [],
                        "events": [],
                    }
                )
                self.assertEqual(
                    service.state()["intent"]["intent_id"],
                    "boss-fight",
                )

                service._apply_response(
                    {
                        "reply": {
                            "text": "等这场战斗结束我就去。",
                            "expects_response": False,
                        },
                        "intent": {
                            "intent_id": "glommer-after-boss",
                            "mode": "fetch_item",
                            "target_prefab": "glommerflower",
                            "lease_seconds": 1800,
                        },
                    },
                    force_chat_only=False,
                    instruction=service._pending_instruction,
                )
                state = service.state()
                self.assertEqual(state["intent"]["intent_id"], "boss-fight")
                self.assertEqual(
                    state["pending_intents"][0]["intent_id"],
                    "glommer-after-boss",
                )
            finally:
                service.stop()
                service.memory.close()

    def test_player_chat_is_compacted_and_internal_sentences_are_removed(
        self,
    ) -> None:
        text = (
            "我的优先级更高，所以先处理基地任务。"
            "你饿了，我去给你做点吃的。"
            "这一步完全完成以后我还会继续检查周围，再决定收什么、"
            "补哪一块地和接下来要做什么。"
        )

        compact = CompanionService._compact_player_reply(text, "task")

        self.assertNotIn("优先级", compact)
        self.assertIn("你饿了，我去给你做点吃的。", compact)
        self.assertLessEqual(len(compact), 96)
        self.assertTrue(compact.endswith("。"))


if __name__ == "__main__":
    unittest.main()
