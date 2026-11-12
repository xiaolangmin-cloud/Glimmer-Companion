from __future__ import annotations

import unittest
from pathlib import Path

from controller.branch_policies import BranchPolicyEngine
from controller.decision_branches import DecisionBranchRouter


ROOT = Path(__file__).resolve().parents[1]


class BranchPolicyEngineTests(unittest.TestCase):
    def setUp(self) -> None:
        self.router = DecisionBranchRouter(
            ROOT / "config" / "decision_branches.json"
        )
        self.engine = BranchPolicyEngine()

    @staticmethod
    def snapshot() -> dict:
        return {
            "companion": {
                "guid": "99",
                "prefab": "waxwell",
                "x": 0,
                "z": 0,
                "health": 62,
                "max_health": 75,
                "hunger": 90,
                "max_hunger": 150,
                "sanity": 140,
                "max_sanity": 200,
            },
            "player": {"guid": "1", "prefab": "walter", "x": 2, "z": 1},
            "inventory_counts": {},
            "inventory": [],
            "equipped": [],
            "nearby": [],
            "capabilities": {"known_recipes": []},
            "landmarks": {},
            "world": {"shard": "1"},
        }

    def decide(self, text: str, snapshot: dict):
        return self.engine.decide(
            text,
            snapshot,
            self.router.classify(text, snapshot),
        )

    def test_unarmed_low_health_character_refuses_frog_group(self) -> None:
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

        decision = self.decide("帮我打一下这些青蛙", snapshot)
        assert decision is not None
        self.assertEqual(decision.intent["mode"], "follow")
        self.assertIn("5 只青蛙", decision.reply)
        self.assertIn("会互相支援", decision.reply)
        self.assertIn("没有可用武器", decision.reply)
        self.assertIn("没有有效护甲", decision.reply)

    def test_explicit_fight_order_overrides_local_caution(self) -> None:
        snapshot = self.snapshot()
        snapshot["companion"]["health"] = 20
        snapshot["nearby"] = [
            {
                "guid": "5",
                "prefab": "frog",
                "hostile": True,
                "distance": 2,
            }
        ]

        decision = self.decide("别管危险，死战到底打青蛙", snapshot)
        assert decision is not None
        self.assertEqual(decision.intent["mode"], "combat")
        self.assertEqual(decision.intent["target_guid"], "5")

    def test_unarmed_character_does_not_box_a_full_health_frog(self) -> None:
        snapshot = self.snapshot()
        snapshot["nearby"] = [
            {
                "guid": "5",
                "prefab": "frog",
                "hostile": True,
                "distance": 2,
                "health": 100,
            }
        ]

        decision = self.decide("打那只青蛙", snapshot)
        assert decision is not None
        self.assertEqual(decision.intent["mode"], "follow")
        self.assertEqual(
            decision.rule_id,
            "combat.avoid_unfavorable_group",
        )

    def test_equipped_character_fights_small_group(self) -> None:
        snapshot = self.snapshot()
        snapshot["inventory_counts"] = {"spear": 1, "armorwood": 1}
        snapshot["equipped"] = [
            {"slot": "hands", "prefab": "spear"},
            {"slot": "body", "prefab": "armorwood"},
        ]
        snapshot["nearby"] = [
            {"guid": "5", "prefab": "frog", "hostile": True, "distance": 2},
            {"guid": "6", "prefab": "frog", "hostile": True, "distance": 4},
        ]

        decision = self.decide("帮我打一下这些青蛙", snapshot)
        assert decision is not None
        self.assertEqual(decision.intent["mode"], "combat")
        self.assertEqual(decision.intent["target_prefab"], "frog")

    def test_collection_farming_transport_and_survival_are_local(self) -> None:
        snapshot = self.snapshot()
        snapshot["nearby"] = [
            {
                "guid": "10",
                "prefab": "grass",
                "pickable": True,
                "distance": 3,
            },
            {
                "guid": "11",
                "prefab": "carrot_planted",
                "harvestable": True,
                "distance": 4,
            },
            {
                "guid": "12",
                "prefab": "treasurechest",
                "container": True,
                "container_items": [
                    {"prefab": "goldnugget", "stacksize": 8}
                ],
                "x": 4,
                "z": 5,
                "distance": 6,
            },
        ]
        snapshot["inventory_counts"] = {"berries": 3}

        grass = self.decide("帮我拿一些草", snapshot)
        assert grass is not None
        self.assertEqual(grass.intent["mode"], "harvest_area")

        mature = self.decide("把成熟作物收了", snapshot)
        assert mature is not None
        self.assertEqual(mature.intent["mode"], "harvest_area")
        self.assertEqual(
            mature.intent["params"]["target_prefabs"],
            ["carrot_planted"],
        )

        transport = self.decide("去箱子拿点金块", snapshot)
        assert transport is not None
        self.assertEqual(transport.intent["mode"], "fetch_item")
        self.assertEqual(transport.intent["target_prefab"], "goldnugget")

        food = self.decide("我快饿死了，先吃点东西", snapshot)
        assert food is not None
        self.assertEqual(food.intent["mode"], "eat")

    def test_crafting_blocks_missing_materials_without_model(self) -> None:
        snapshot = self.snapshot()
        snapshot["capabilities"] = {
            "known_recipes": [
                {"name": "axe", "product": "axe", "available": False}
            ]
        }
        decision = self.decide("做一把斧头", snapshot)
        assert decision is not None
        self.assertEqual(decision.intent["mode"], "hold")
        self.assertIn("材料不足", decision.reply)

    def test_known_landmark_routes_without_model(self) -> None:
        snapshot = self.snapshot()
        snapshot["landmarks"] = {"家": {"shard": "1", "x": 10, "z": 20}}
        decision = self.decide("带我回家里", snapshot)
        assert decision is not None
        self.assertEqual(decision.intent["mode"], "move_to_landmark")
        self.assertEqual(decision.intent["params"]["landmark"], "家")


if __name__ == "__main__":
    unittest.main()
