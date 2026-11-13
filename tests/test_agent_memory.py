from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from controller.agent_memory import AgentMemoryStore
from controller.mod_knowledge import IMPLEMENTATION_NOTES


class AgentMemoryTests(unittest.TestCase):
    def test_skill_chat_plan_and_world_rooms_are_isolated(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            user_file = vault / "private.md"
            user_file.write_text("不要修改", encoding="utf-8")
            database = root / "agent_memory.sqlite3"
            memory = AgentMemoryStore(database)
            try:
                memory.remember_skill(
                    "温蒂对战蜘蛛",
                    "保持距离，合适时使用阿比盖尔技能。",
                    source="codex-web-research",
                    confidence=0.9,
                )
                hits = memory.search_skills("蜘蛛 温蒂")
                self.assertEqual(len(hits), 1)
                self.assertIn("阿比盖尔", hits[0].content)

                memory.record_chat("chat", "user", "今天天气不错")
                memory.record_chat("chat", "companion", "是呀")
                self.assertEqual(memory.recent_chat("chat")[-1]["role"], "companion")
                self.assertEqual(memory.recent_chat("tasks"), [])

                memory.save_plan(
                    "制作建造护符",
                    {
                        "status": "active",
                        "steps": [
                            {"action": "查配方", "status": "active"},
                        ],
                    },
                )
                plan = memory.active_plan()
                self.assertEqual(plan["goal"], "制作建造护符")
                self.assertEqual(plan["steps"][0]["status"], "active")

                memory.remember_world_point(
                    shard="1",
                    prefab="treasurechest",
                    category="container",
                    x=10.5,
                    z=-4.2,
                    details={"container_items": [{"prefab": "goldnugget"}]},
                )
                world = memory.world_context("1", "goldnugget")
                self.assertEqual(world[0]["prefab"], "treasurechest")
                self.assertEqual(user_file.read_text(encoding="utf-8"), "不要修改")
            finally:
                memory.close()

    def test_global_vault_is_not_written(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            before = list(vault.rglob("*"))
            memory = AgentMemoryStore(root / "agent.sqlite3")
            try:
                memory.remember_skill("测试", "独立技能记忆")
                memory.record_chat("chat", "user", "测试聊天")
            finally:
                memory.close()
            self.assertEqual(before, list(vault.rglob("*")))

    def test_chat_context_compacts_results_but_keeps_raw_history(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            memory = AgentMemoryStore(Path(tmp) / "agent.sqlite3")
            try:
                for index in range(30):
                    memory.record_chat(
                        "chat",
                        "user",
                        f"已完成任务 {index}，结果是拿到 {index} 个草",
                    )
                    memory.record_chat(
                        "chat",
                        "companion",
                        f"第 {index} 轮已经完成并汇报",
                    )

                context = memory.chat_context(
                    "chat",
                    recent_limit=8,
                    max_recent_chars=500,
                    max_summary_chars=900,
                )

                self.assertEqual(context["raw_count"], 60)
                self.assertEqual(
                    len(memory.recent_chat("chat", limit=100)),
                    60,
                )
                self.assertLessEqual(len(context["recent"]), 8)
                self.assertLessEqual(
                    sum(len(item["text"]) for item in context["recent"]),
                    500,
                )
                self.assertIn("已完成任务", context["summary"])
                self.assertLessEqual(len(context["summary"]), 900)
                self.assertGreater(context["summarized_through_id"], 0)
                self.assertLess(context["summarized_through_id"], 60)
            finally:
                memory.close()

    def test_project_implementation_memory_is_isolated_and_budgeted(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            before = list(vault.rglob("*"))
            memory = AgentMemoryStore(root / "agent.sqlite3")
            try:
                memory.seed_implementation_notes(IMPLEMENTATION_NOTES)
                context = memory.render_implementation_context(
                    "微光这个mod能否自己启动控制器，选人怎么做",
                    limit=2,
                    max_chars=1600,
                )
                self.assertIn("启动桥", context)
                self.assertLessEqual(len(context), 1600)
                emergency_context = memory.render_implementation_context(
                    "微光遇到猎犬地震和青蛙雨会怎么应急",
                    limit=2,
                    max_chars=1600,
                )
                self.assertIn("0.75", emergency_context)
                self.assertIn("来狗啦来狗啦", emergency_context)
                recovery_context = memory.render_implementation_context(
                    "微光控制器重启后请求卡死和存档解码怎么办",
                    limit=2,
                    max_chars=1600,
                )
                self.assertIn("5 秒超时", recovery_context)
                self.assertIn("KLEI 1", recovery_context)
                self.assertEqual(
                    memory.render_implementation_context("帮我砍几棵树"),
                    "",
                )
            finally:
                memory.close()
            self.assertEqual(before, list(vault.rglob("*")))

    def test_scheduled_tasks_persist_and_only_become_due_on_conditions(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            database = Path(tmp) / "agent.sqlite3"
            memory = AgentMemoryStore(database)
            try:
                task_id = memory.save_scheduled_task(
                    kind="glommer_pickup",
                    goal="满月去格罗姆雕像接回格罗姆",
                    due_phase="night",
                    due_moon_phase="full",
                    shard="1",
                    x=42,
                    z=-18,
                    details={"return_landmark": "家"},
                )
                self.assertGreater(task_id, 0)
                active = memory.scheduled_tasks()
                self.assertEqual(len(active), 1)
                self.assertEqual(active[0]["details"]["return_landmark"], "家")
                self.assertEqual(
                    memory.due_scheduled_tasks(
                        day=9,
                        phase="dusk",
                        moon_phase="full",
                        shard="1",
                    ),
                    [],
                )
                due = memory.due_scheduled_tasks(
                    day=10,
                    phase="night",
                    moon_phase="full",
                    shard="1",
                )
                self.assertEqual([item["id"] for item in due], [task_id])
                memory.update_scheduled_task(task_id, status="completed")
                self.assertEqual(memory.scheduled_tasks(), [])
            finally:
                memory.close()

            reopened = AgentMemoryStore(database)
            try:
                completed = reopened.scheduled_tasks(status="completed")
                self.assertEqual(len(completed), 1)
                self.assertEqual(completed[0]["goal"], "满月去格罗姆雕像接回格罗姆")
            finally:
                reopened.close()


if __name__ == "__main__":
    unittest.main()
