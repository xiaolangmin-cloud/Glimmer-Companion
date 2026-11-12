from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from controller.config import Settings
from controller.service import CompanionService
from controller.wheel_commands import (
    AMOUNTS,
    WHEEL_BRANCH_IDS,
    WheelCommandError,
    normalize_selection,
)


ROOT = Path(__file__).resolve().parents[1]


class ExplodingPlanner:
    def decide(self, *args, **kwargs):
        raise AssertionError("wheel commands must not call DeepSeek")


class WheelCommandTests(unittest.TestCase):
    def make_service(self, root: Path) -> CompanionService:
        vault = root / "vault"
        vault.mkdir()
        prompt = root / "prompt.md"
        prompt.write_text("JSON only.", encoding="utf-8")
        return CompanionService(
            Settings(
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
        )

    @staticmethod
    def snapshot() -> dict:
        return {
            "companion": {
                "guid": "99",
                "prefab": "waxwell",
                "x": 0,
                "z": 0,
                "health": 70,
                "max_health": 75,
                "hunger": 110,
                "max_hunger": 150,
                "sanity": 180,
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
            "landmarks": {
                "家": {"shard": "1", "x": 100, "z": -40},
            },
            "nearby": [],
            "events": [],
        }

    def test_wheel_catalog_has_exactly_twelve_executable_branches(self) -> None:
        self.assertEqual(len(WHEEL_BRANCH_IDS), 12)
        self.assertNotIn("general", WHEEL_BRANCH_IDS)
        self.assertEqual(AMOUNTS, (5, 10, 15, 20, 30, 50))

        source = (
            ROOT / "mod" / "scripts" / "glimmer_wheel_menu.lua"
        ).read_text(encoding="utf-8")
        for branch_id in WHEEL_BRANCH_IDS:
            with self.subTest(branch_id=branch_id):
                self.assertIn(f'Item("{branch_id}"', source)
        self.assertNotIn('Item("general"', source)
        self.assertIn("images/inventoryimages.xml", source)
        self.assertIn("cutgrass.tex", source)
        self.assertIn("twigs.tex", source)

    def test_validation_rejects_unknown_or_cross_world_fields(self) -> None:
        normalized = normalize_selection(
            {
                "schema": 1,
                "branch_id": "collection",
                "action": "collect_resource",
                "target_id": "grass",
                "amount": 10,
            }
        )
        self.assertEqual(normalized.amount, 10)

        for payload in (
            {
                "schema": 1,
                "branch_id": "general",
                "action": "follow",
            },
            {
                "schema": 1,
                "branch_id": "collection",
                "action": "collect_resource",
                "target_id": "grass",
                "amount": 7,
            },
        ):
            with self.subTest(payload=payload):
                with self.assertRaises(WheelCommandError):
                    normalize_selection(payload)

        movement = normalize_selection(
            {
                "schema": 1,
                "branch_id": "movement",
                "action": "follow",
                "mode": "change_shard",
                "target_shard": "2",
            }
        )
        self.assertNotIn("mode", movement.context())
        self.assertNotIn("target_shard", movement.context())

    def test_wheel_commands_are_local_and_respect_amount(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            service = self.make_service(Path(tmp))
            service.planner = ExplodingPlanner()
            try:
                service.tick(self.snapshot())
                state = service.wheel_command(
                    {
                        "schema": 1,
                        "branch_id": "collection",
                        "action": "collect_resource",
                        "target_id": "grass",
                        "amount": 10,
                    }
                )
                self.assertTrue(state["wheel_command_received"])
                self.assertEqual(state["intent"]["mode"], "harvest_area")
                self.assertEqual(state["intent"]["params"]["amount"], 10)
                self.assertEqual(state["decision_branch"]["id"], "collection")
                self.assertIn("草", state["messages"][-1]["text"])

                before = state["intent"]["intent_id"]
                status = service.wheel_command(
                    {
                        "schema": 1,
                        "branch_id": "information",
                        "action": "status",
                    }
                )
                self.assertEqual(status["intent"]["intent_id"], before)
                self.assertIn("生命 70/75", status["messages"][-1]["text"])
            finally:
                service.stop()
                service.memory.close()

    def test_unfavorable_wheel_combat_uses_safety_preflight(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            service = self.make_service(Path(tmp))
            service.planner = ExplodingPlanner()
            snapshot = self.snapshot()
            snapshot["companion"]["health"] = 20
            snapshot["nearby"] = [
                {
                    "guid": str(index),
                    "prefab": "frog",
                    "hostile": True,
                    "distance": index,
                }
                for index in range(1, 6)
            ]
            try:
                service.tick(snapshot)
                state = service.wheel_command(
                    {
                        "schema": 1,
                        "branch_id": "combat",
                        "action": "guard",
                    }
                )
                self.assertEqual(
                    state["local_policy_matched"],
                    "combat.avoid_unfavorable_group",
                )
                self.assertEqual(state["intent"]["mode"], "follow")
                self.assertIn("5 只青蛙", state["messages"][-1]["text"])
            finally:
                service.stop()
                service.memory.close()

    def test_wheel_crafting_blocks_missing_materials_locally(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            service = self.make_service(Path(tmp))
            service.planner = ExplodingPlanner()
            snapshot = self.snapshot()
            snapshot["capabilities"] = {
                "known_recipes": [
                    {
                        "name": "axe",
                        "product": "axe",
                        "available": False,
                    }
                ]
            }
            try:
                service.tick(snapshot)
                state = service.wheel_command(
                    {
                        "schema": 1,
                        "branch_id": "crafting",
                        "action": "craft",
                        "target_id": "axe",
                    }
                )
                self.assertEqual(
                    state["local_policy_matched"],
                    "crafting.wheel_recipe_blocked",
                )
                self.assertEqual(state["intent"]["mode"], "hold")
                self.assertIn("材料不足", state["messages"][-1]["text"])
            finally:
                service.stop()
                service.memory.close()

    def test_transport_and_delivery_need_real_locations_or_inventory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            service = self.make_service(Path(tmp))
            service.planner = ExplodingPlanner()
            snapshot = self.snapshot()
            snapshot["inventory_counts"] = {"silk": 8}
            try:
                service.tick(snapshot)
                transport = service.wheel_command(
                    {
                        "schema": 1,
                        "branch_id": "transport",
                        "action": "fetch",
                        "target_id": "goldnugget",
                        "amount": 10,
                    }
                )
                self.assertEqual(transport["intent"]["mode"], "fetch_item")
                self.assertEqual(transport["intent"]["position"], [100, -40])

                delivery = service.wheel_command(
                    {
                        "schema": 1,
                        "branch_id": "interaction",
                        "action": "deliver_item",
                        "target_id": "silk",
                        "amount": 5,
                    }
                )
                self.assertEqual(delivery["intent"]["mode"], "deliver_item")
                self.assertEqual(delivery["intent"]["params"]["amount"], 5)
            finally:
                service.stop()
                service.memory.close()


if __name__ == "__main__":
    unittest.main()
