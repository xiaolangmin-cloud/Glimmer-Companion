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

    def test_explicit_stop_combat_retreats_immediately(self) -> None:
        branches = DecisionBranchRouter(
            ROOT / "config" / "decision_branches.json"
        )
        snapshot = {
            "companion": {"health": 80, "max_health": 150},
            "nearby": [
                {
                    "guid": "frog-1",
                    "prefab": "frog",
                    "hostile": True,
                    "health": 100,
                    "distance": 3,
                }
            ],
        }
        branch = branches.classify("停止战斗，马上回来", snapshot)

        decision = BranchPolicyEngine().decide(
            "停止战斗，马上回来",
            snapshot,
            branch,
        )

        self.assertIsNotNone(decision)
        self.assertEqual(decision.intent["mode"], "retreat")
        self.assertEqual(decision.reason, "explicit_retreat")

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

    def test_branch_policy_counts_head_and_body_armor_together(self) -> None:
        snapshot = self.snapshot()
        snapshot["inventory"] = [
            {"prefab": "spear", "stacksize": 1},
            {
                "prefab": "armorwood",
                "stacksize": 1,
                "condition_percent": 100,
            },
            {
                "prefab": "armorfootball",
                "stacksize": 1,
                "condition_percent": 100,
            },
        ]
        snapshot["nearby"] = [
            {
                "guid": str(index),
                "prefab": "frog",
                "hostile": True,
                "distance": index,
            }
            for index in range(1, 5)
        ]

        decision = self.decide("帮我打一下这些青蛙", snapshot)

        assert decision is not None
        self.assertEqual(decision.intent["mode"], "combat")
        self.assertAlmostEqual(
            decision.intent["params"]["armor_absorb"],
            0.96,
        )

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

    def test_crafting_distinguishes_unknown_recipe_from_missing_materials(
        self,
    ) -> None:
        snapshot = self.snapshot()
        snapshot["capabilities"] = {
            "known_recipes": [
                {
                    "name": "axe",
                    "product": "axe",
                    "known": False,
                    "available": False,
                }
            ]
        }
        decision = self.decide("做一把斧头", snapshot)
        assert decision is not None
        self.assertEqual(decision.intent["mode"], "hold")
        self.assertIn("没学会", decision.reply)

    def test_home_command_returns_and_stays_without_model(self) -> None:
        snapshot = self.snapshot()
        snapshot["landmarks"] = {"家": {"shard": "1", "x": 10, "z": 20}}
        decision = self.decide("带我回家里", snapshot)
        assert decision is not None
        self.assertEqual(decision.intent["mode"], "homestead")
        self.assertEqual(decision.intent["params"]["landmark"], "家")
        self.assertTrue(decision.intent["params"]["stay_home"])

    def test_establish_home_creates_persistent_base_mode(self) -> None:
        decision = self.decide("这里是我的家", self.snapshot())

        assert decision is not None
        self.assertEqual(decision.intent["mode"], "homestead")
        self.assertTrue(decision.intent["params"]["establish_home"])
        self.assertTrue(decision.intent["params"]["stay_home"])
        self.assertEqual(decision.intent["params"]["name"], "家")

    def test_home_chore_request_returns_and_starts_autonomy(self) -> None:
        snapshot = self.snapshot()
        snapshot["home"] = {
            "name": "家",
            "x": 80,
            "z": 80,
            "shard": "1",
        }
        snapshot["landmarks"] = {
            "家": {"x": 80, "z": 80, "shard": "1"}
        }

        decision = self.decide("帮我回家把基地收拾一下", snapshot)

        assert decision is not None
        self.assertEqual(decision.rule_id, "base.run_home_chores")
        self.assertEqual(decision.intent["mode"], "homestead")
        self.assertTrue(decision.intent["params"]["stay_home"])
        self.assertIn("先回“家”", decision.reply)

        snapshot["companion"]["x"] = 78
        snapshot["companion"]["z"] = 79
        decision = self.decide("你看着办，找点家务做", snapshot)
        assert decision is not None
        self.assertIn("先把家里", decision.reply)

        branches = DecisionBranchRouter(
            ROOT / "config" / "decision_branches.json"
        )
        branch = branches.classify("你看着办，找点家务做", snapshot)
        self.assertEqual(branch.branch_id, "base")

    def test_glommer_request_schedules_full_moon_with_known_statue(self) -> None:
        snapshot = self.snapshot()
        snapshot["home"] = {"name": "家", "x": 10, "z": 20, "shard": "1"}
        snapshot["decision_support"] = {
            "calendar": {
                "glommer": {
                    "known_points": [
                        {
                            "prefab": "statueglommer",
                            "x": 420,
                            "z": -180,
                        }
                    ]
                }
            }
        }

        decision = self.decide("帮我把格罗姆接回来", snapshot)

        assert decision is not None
        self.assertEqual(
            decision.rule_id,
            "exploration.glommer_scheduled",
        )
        self.assertEqual(decision.intent["mode"], "homestead")
        self.assertEqual(decision.intent["params"]["landmark"], "家")
        assert isinstance(decision.schedule, dict)
        self.assertEqual(decision.schedule["kind"], "glommer_pickup")
        self.assertEqual(decision.schedule["due_phase"], "night")
        self.assertEqual(decision.schedule["due_moon_phase"], "full")
        self.assertEqual(decision.schedule["x"], 420)
        self.assertEqual(decision.schedule["z"], -180)
        self.assertEqual(
            decision.schedule["details"]["return_landmark"],
            "家",
        )

    def test_glommer_request_without_location_does_not_fake_coordinates(
        self,
    ) -> None:
        decision = self.decide("帮我接格罗姆", self.snapshot())

        assert decision is not None
        self.assertEqual(
            decision.rule_id,
            "exploration.glommer_schedule_needs_location",
        )
        assert isinstance(decision.schedule, dict)
        self.assertIsNone(decision.schedule["x"])
        self.assertIsNone(decision.schedule["z"])
        self.assertFalse(decision.schedule["details"]["statue_known"])
        self.assertIn("还没掌握雕像坐标", decision.reply)


if __name__ == "__main__":
    unittest.main()
