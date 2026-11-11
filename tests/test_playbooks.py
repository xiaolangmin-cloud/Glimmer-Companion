from __future__ import annotations

import unittest
from pathlib import Path

from controller.playbooks import PlaybookMatcher


ROOT = Path(__file__).resolve().parents[1]


class PlaybookMatcherTests(unittest.TestCase):
    def setUp(self) -> None:
        self.matcher = PlaybookMatcher(ROOT / "config" / "playbooks")
        self.maxwell = {
            "companion": {"prefab": "waxwell"},
            "player": {"prefab": "waxwell", "x": 96, "z": -32},
            "inventory_counts": {"silk": 7},
            "capabilities": {
                "craftable_recipes": [
                    {"name": "axe", "product": "axe"},
                ]
            },
        }

    def test_spider_silk_routes_without_model(self) -> None:
        match = self.matcher.match("帮我打些蜘蛛丝", self.maxwell)
        self.assertIsNotNone(match)
        assert match is not None
        self.assertTrue(match.direct)
        self.assertEqual(match.playbook_id, "maxwell.collect_spider_silk")
        self.assertEqual(match.intent["mode"], "collect_loot")
        self.assertEqual(match.intent["params"]["amount"], 10)
        self.assertTrue(match.intent["params"]["ignore_player_leash"])
        self.assertFalse(match.intent["params"]["progress_reports"])

        match = self.matcher.match("打二十个蜘蛛丝", self.maxwell)
        assert match is not None
        self.assertEqual(match.intent["params"]["amount"], 20)

        forced = self.matcher.match(
            "别管饱食度，务必去帮我打十个蜘蛛丝",
            self.maxwell,
        )
        assert forced is not None
        self.assertTrue(
            forced.intent["params"]["ignore_survival_safety"]
        )

    def test_status_query_does_not_replace_current_task(self) -> None:
        match = self.matcher.match("现在有多少蜘蛛丝", self.maxwell)
        self.assertIsNotNone(match)
        assert match is not None
        self.assertIsNone(match.intent)
        self.assertIn("7", match.reply)

    def test_character_and_craft_preconditions_are_respected(self) -> None:
        wendy = dict(self.maxwell)
        wendy["companion"] = {"prefab": "wendy"}
        self.assertIsNone(self.matcher.match("帮我打些蜘蛛丝", wendy))

        no_axe = dict(self.maxwell)
        no_axe["capabilities"] = {"craftable_recipes": []}
        self.assertIsNone(self.matcher.match("做一把斧头", no_axe))

    def test_generic_local_commands_avoid_model_round_trip(self) -> None:
        wendy = {
            "companion": {"prefab": "wendy"},
            "player": {"prefab": "waxwell", "x": 96, "z": -32},
            "inventory_counts": {},
            "capabilities": {},
        }
        follow = self.matcher.match("跟着我", wendy)
        assert follow is not None
        self.assertTrue(follow.direct)
        self.assertEqual(follow.playbook_id, "generic.follow")
        self.assertEqual(follow.intent["mode"], "follow")

        grass = self.matcher.match("去采集附近的草", wendy)
        assert grass is not None
        self.assertTrue(grass.direct)
        self.assertEqual(grass.playbook_id, "generic.collect_grass")
        self.assertEqual(grass.intent["position"], [96, -32])
        self.assertIn("grass", grass.intent["params"]["target_prefabs"])
        self.assertIsNotNone(
            self.matcher.match("帮我采一些附近的草", wendy)
        )

        sapling = self.matcher.match("帮我把附近的树枝采一下", wendy)
        assert sapling is not None
        self.assertEqual(sapling.intent["mode"], "harvest_area")
        self.assertIn("sapling", sapling.intent["params"]["target_prefabs"])

        twigs = self.matcher.match("捡一些地上的树枝", wendy)
        assert twigs is not None
        self.assertEqual(twigs.intent["mode"], "gather")
        self.assertEqual(twigs.intent["params"]["target_prefabs"], ["twigs"])

    def test_gather_and_boss_candidates(self) -> None:
        gather = self.matcher.match("帮我收一下草和树枝", self.maxwell)
        assert gather is not None
        self.assertEqual(gather.intent["mode"], "harvest_area")
        self.assertIn(
            "grass",
            gather.intent["params"]["target_prefabs"],
        )

        boss = self.matcher.match("去打巨鹿", self.maxwell)
        assert boss is not None
        self.assertFalse(boss.direct)
        self.assertIn("护甲", boss.playbook["strategy"])


if __name__ == "__main__":
    unittest.main()
