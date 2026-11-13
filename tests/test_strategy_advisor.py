from __future__ import annotations

import unittest

from controller.strategy_advisor import StrategyAdvisor


class StrategyAdvisorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.advisor = StrategyAdvisor()

    @staticmethod
    def snapshot() -> dict:
        return {
            "companion": {
                "prefab": "waxwell",
                "health": 75,
                "max_health": 75,
                "hunger": 140,
                "max_hunger": 150,
                "sanity": 180,
                "max_sanity": 200,
                "in_light": True,
            },
            "world": {
                "day": 8,
                "season": "autumn",
                "phase": "day",
                "body_temperature": 30,
            },
            "inventory": [],
            "inventory_counts": {},
            "equipped": [],
            "nearby": [],
        }

    def test_combat_uses_multiplicative_head_and_body_armor(self) -> None:
        snapshot = self.snapshot()
        snapshot["inventory"] = [
            {"prefab": "spear", "stacksize": 1},
            {"prefab": "armorwood", "stacksize": 1, "condition_percent": 100},
            {
                "prefab": "armorfootball",
                "stacksize": 1,
                "condition_percent": 50,
            },
        ]
        snapshot["nearby"] = [
            {"guid": "1", "prefab": "frog", "hostile": True, "distance": 2},
            {"guid": "2", "prefab": "frog", "hostile": True, "distance": 3},
        ]

        combat = self.advisor.analyze(snapshot)["combat"]

        self.assertEqual(combat["weapon"], "spear")
        self.assertAlmostEqual(combat["armor"]["effective_absorb"], 0.88)
        self.assertEqual(combat["armor"]["pieces"], 2)
        self.assertLess(combat["incoming_damage_per_hit"], 2)
        self.assertNotEqual(combat["stance"], "retreat")

    def test_unarmed_low_health_group_is_a_retreat(self) -> None:
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

        combat = self.advisor.analyze(snapshot)["combat"]

        self.assertEqual(combat["stance"], "retreat")
        self.assertGreaterEqual(combat["risk_score"], 70)
        self.assertIn("没有可用武器", combat["warnings"])
        self.assertIn("双层护甲覆盖不足", combat["warnings"])

    def test_winter_readiness_flags_missing_heat_resources(self) -> None:
        snapshot = self.snapshot()
        snapshot["world"].update(
            {
                "day": 25,
                "season": "winter",
                "body_temperature": 8,
            }
        )

        survival = self.advisor.analyze(snapshot)["survival"]

        self.assertEqual(survival["season"], "winter")
        self.assertFalse(survival["preparedness"]["fuel"])
        self.assertFalse(survival["preparedness"]["food"])
        self.assertIn("冬夜前准备可用燃料", survival["priorities"])
        self.assertIn("冬季食物储备不足", survival["priorities"])

    def test_spring_readiness_flags_missing_lightning_rod(self) -> None:
        snapshot = self.snapshot()
        snapshot["world"].update({"season": "spring", "israining": True})

        survival = self.advisor.analyze(snapshot)["survival"]

        self.assertFalse(survival["preparedness"]["lightning_protection"])
        self.assertIn(
            "基地缺少避雷针，雷雨时不要守在建物密集处",
            survival["priorities"],
        )

        snapshot["nearby"] = [{"prefab": "lightning_rod"}]
        survival = self.advisor.analyze(snapshot)["survival"]
        self.assertTrue(survival["preparedness"]["lightning_protection"])

    def test_late_world_autumn_does_not_claim_the_first_winter(self) -> None:
        snapshot = self.snapshot()
        snapshot["world"].update(
            {
                "day": 263,
                "season": "autumn",
                "remaining_days_in_season": 12,
            }
        )

        survival = self.advisor.analyze(snapshot)["survival"]

        self.assertFalse(survival["preparedness"]["winter_imminent"])
        self.assertNotIn(
            "冬季将至，提前补足食物、燃料和保暖",
            survival["priorities"],
        )

    def test_world_countdown_warns_near_winter_in_late_years(self) -> None:
        snapshot = self.snapshot()
        snapshot["world"].update(
            {
                "day": 263,
                "season": "autumn",
                "remaining_days_in_season": 5,
            }
        )

        survival = self.advisor.analyze(snapshot)["survival"]

        self.assertEqual(survival["remaining_days_in_season"], 5)
        self.assertTrue(survival["preparedness"]["winter_imminent"])
        self.assertIn(
            "冬季将至，提前补足食物、燃料和保暖",
            survival["priorities"],
        )

    def test_fifth_shadow_puppet_blocks_more_preemptive_summoning(self) -> None:
        snapshot = self.snapshot()
        snapshot["companion"]["shadow_puppet_counts"] = {
            "shadowworker": 4,
            "shadowprotector": 1,
        }

        maxwell = self.advisor.analyze(snapshot)["maxwell"]

        self.assertEqual(maxwell["total_puppets"], 5)
        self.assertEqual(maxwell["recommended_max_puppets"], 5)
        self.assertTrue(
            any("停止继续召唤" in warning for warning in maxwell["warnings"])
        )

    def test_fire_hound_wave_warns_about_stunlock_and_fire(self) -> None:
        snapshot = self.snapshot()
        snapshot["inventory"] = [{"prefab": "spear", "stacksize": 1}]
        snapshot["nearby"] = [
            {
                "guid": str(index),
                "prefab": "firehound",
                "hostile": True,
                "distance": index,
            }
            for index in range(1, 4)
        ]

        combat = self.advisor.analyze(snapshot)["combat"]

        self.assertEqual(
            combat["tactics"]["approach"],
            "kite_away_from_flammables",
        )
        self.assertTrue(combat["tactics"]["stunlock_risk"])
        self.assertIn("目标死亡会引燃附近物体", combat["warnings"])
        self.assertIn("多目标连续攻击可能造成硬直", combat["warnings"])

    def test_actual_modded_armor_values_override_builtin_profile(self) -> None:
        snapshot = self.snapshot()
        snapshot["inventory"] = [
            {
                "prefab": "custom_body_armor",
                "slot": "body",
                "condition_percent": 50,
                "armor_absorb_percent": 90,
            }
        ]
        snapshot["nearby"] = [
            {"guid": "1", "prefab": "frog", "hostile": True, "distance": 2}
        ]

        combat = self.advisor.analyze(snapshot)["combat"]

        self.assertEqual(combat["armor"]["pieces"], 1)
        self.assertAlmostEqual(combat["armor"]["effective_absorb"], 0.45)

    def test_farming_support_tracks_growth_and_giant_crop_rules(self) -> None:
        snapshot = self.snapshot()
        snapshot["inventory_counts"] = {"carrot_seeds": 6}
        snapshot["nearby"] = [
            {
                "prefab": "farm_plant_carrot",
                "harvestable": False,
                "distance": 3,
            },
            {
                "prefab": "farm_plant_carrot",
                "harvestable": True,
                "distance": 4,
            },
        ]

        farming = self.advisor.analyze(snapshot)["farming"]

        self.assertEqual(farming["visible_plants"], 2)
        self.assertEqual(farming["mature_plants"], 1)
        self.assertEqual(farming["seed_count"], 6)
        self.assertTrue(farming["check_every_growth_stage"])

    def test_player_care_avoids_expensive_cooking_for_small_hunger(
        self,
    ) -> None:
        snapshot = self.snapshot()
        snapshot["player"] = {
            "health": 150,
            "max_health": 150,
            "hunger": 138,
            "max_hunger": 150,
            "sanity": 190,
            "max_sanity": 200,
        }
        snapshot["inventory_counts"] = {
            "monstermeat": 2,
            "berries": 8,
        }
        snapshot["inventory"] = [
            {
                "prefab": "monstermeat",
                "edible": True,
                "food_hunger": 18.8,
                "stacksize": 2,
            },
            {
                "prefab": "berries",
                "edible": True,
                "food_hunger": 9.4,
                "stacksize": 8,
            },
        ]
        snapshot["nearby"] = [{"prefab": "cookpot", "container": True}]

        care = self.advisor.analyze(snapshot)["player_care"]

        self.assertFalse(care["needs_cooking"])
        self.assertNotEqual(care["action"], "cook_meatballs")

    def test_player_care_matches_existing_food_to_real_hunger_gap(
        self,
    ) -> None:
        snapshot = self.snapshot()
        snapshot["player"] = {
            "health": 150,
            "max_health": 150,
            "hunger": 122,
            "max_hunger": 150,
            "sanity": 190,
            "max_sanity": 200,
        }
        snapshot["inventory"] = [
            {
                "prefab": "meatballs",
                "edible": True,
                "food_hunger": 62.5,
                "perish_percent": 90,
            },
            {
                "prefab": "berries",
                "edible": True,
                "food_hunger": 9.4,
                "perish_percent": 40,
            },
        ]
        snapshot["nearby"] = []

        care = self.advisor.analyze(snapshot)["player_care"]

        self.assertEqual(
            care["best_existing_food"]["prefab"],
            "berries",
        )
        self.assertTrue(
            next(
                item
                for item in care["existing_food"]
                if item["prefab"] == "meatballs"
            )["wasteful"]
        )
        self.assertEqual(care["action"], "offer_existing_food")

    def test_player_care_prefers_efficient_meal_for_large_gap(
        self,
    ) -> None:
        snapshot = self.snapshot()
        snapshot["player"] = {
            "health": 150,
            "max_health": 150,
            "hunger": 70,
            "max_hunger": 150,
            "sanity": 190,
            "max_sanity": 200,
        }
        snapshot["inventory"] = [
            {
                "prefab": "meatballs",
                "edible": True,
                "food_hunger": 62.5,
                "perish_percent": 90,
            },
            {
                "prefab": "berries",
                "edible": True,
                "food_hunger": 9.4,
                "perish_percent": 40,
            },
        ]
        snapshot["nearby"] = []

        care = self.advisor.analyze(snapshot)["player_care"]

        self.assertEqual(
            care["best_existing_food"]["prefab"],
            "meatballs",
        )
        self.assertEqual(care["action"], "offer_existing_food")

    def test_player_care_uses_meatballs_only_for_real_large_deficit(
        self,
    ) -> None:
        snapshot = self.snapshot()
        snapshot["player"] = {
            "health": 150,
            "max_health": 150,
            "hunger": 82,
            "max_hunger": 150,
            "sanity": 190,
            "max_sanity": 200,
        }
        snapshot["inventory_counts"] = {
            "monstermeat": 1,
            "berries": 4,
        }
        snapshot["inventory"] = []
        snapshot["nearby"] = [{"prefab": "cookpot", "container": True}]

        care = self.advisor.analyze(snapshot)["player_care"]

        self.assertTrue(care["needs_cooking"])
        self.assertTrue(care["should_cook_now"])
        self.assertEqual(care["action"], "cook_meatballs")
        self.assertEqual(care["meatballs_plan"]["product"], "meatballs")
        self.assertEqual(
            care["meatballs_plan"]["meat"],
            "monstermeat",
        )

    def test_homestead_reports_ready_crops_as_a_chore(self) -> None:
        snapshot = {
            "home": {"name": "家"},
            "nearby": [
                {
                    "prefab": "farm_plant_carrot",
                    "pickable": True,
                    "mature": True,
                }
            ],
        }

        homestead = self.advisor.analyze(snapshot)["homestead"]

        self.assertEqual(homestead["ready_crops"], 1)
        self.assertIn(
            "收下成熟作物、浆果以及长成的草、树枝和芦苇",
            homestead["suggested_chores"],
        )
        self.assertEqual(
            homestead["chore_plan"][0]["id"],
            "harvest_renewables",
        )

    def test_homestead_tracks_drying_rack_state_and_reserves(self) -> None:
        snapshot = self.snapshot()
        snapshot["home"] = {"name": "家"}
        snapshot["nearby"] = [
            {
                "prefab": "meatrack",
                "drying": True,
                "drying_done": True,
            },
            {
                "prefab": "meatrack",
                "drying": True,
                "drying_active": False,
                "drying_done": False,
            },
        ]
        snapshot["inventory"] = [
            {
                "prefab": "smallmeat",
                "edible": True,
                "perish_percent": 15,
            }
        ]

        support = self.advisor.analyze(snapshot)
        homestead = support["homestead"]
        consumption = support["consumption"]

        self.assertEqual(homestead["drying_racks"], 2)
        self.assertEqual(homestead["drying_ready"], 1)
        self.assertEqual(homestead["empty_drying_racks"], 1)
        self.assertIn(
            "先收晾肉架上的成品",
            homestead["suggested_chores"],
        )
        self.assertEqual(
            homestead["chore_plan"][0]["id"],
            "collect_drying",
        )
        self.assertEqual(
            consumption["keep_last_emergency_portions"],
            {"food": 1, "fuel": 1, "healing": 1},
        )
        self.assertIn("preserve_tool_capabilities", consumption)

    def test_homestead_prioritizes_safe_affordable_upkeep(self) -> None:
        snapshot = self.snapshot()
        snapshot["home"] = {"name": "家", "x": 0, "z": 0}
        snapshot["world"]["phase"] = "dusk"
        snapshot["world"]["israining"] = True
        snapshot["inventory_counts"].update(
            {
                "axe": 1,
                "pickaxe": 0,
                "shovel": 1,
                "pinecone": 3,
            }
        )
        snapshot["nearby"] = [
            {"prefab": "treasurechest", "container": True},
            {"prefab": "log", "ground_item": True},
            {"prefab": "evergreen", "mature": True, "x": 0, "z": 8},
            {"prefab": "evergreen", "mature": True, "x": 2, "z": 8},
            {"prefab": "evergreen", "mature": True, "x": 4, "z": 8},
            {"prefab": "marbletree", "workable": True},
            {
                "prefab": "meatrack",
                "drying": True,
                "drying_active": False,
            },
        ]

        homestead = self.advisor.analyze(snapshot)["homestead"]
        ids = [chore["id"] for chore in homestead["chore_plan"]]

        self.assertTrue(homestead["tool_readiness"]["axe"])
        self.assertTrue(homestead["tool_readiness"]["shovel"])
        self.assertFalse(homestead["tool_readiness"]["pickaxe"])
        self.assertEqual(homestead["routine"]["mode"], "evening_refuel_and_storage")
        self.assertIn("不新上晾肉架", homestead["routine"]["rain_policy"])
        self.assertNotIn("load_drying", ids)
        self.assertIn("mine_marble", ids)
        self.assertGreater(
            homestead["chore_plan"][ids.index("mine_marble")]["priority"],
            homestead["chore_plan"][ids.index("collect_ground_items")][
                "priority"
            ],
        )

    def test_homestead_does_not_treat_scattered_wild_trees_as_forest(
        self,
    ) -> None:
        snapshot = self.snapshot()
        snapshot["home"] = {"name": "家", "x": 0, "z": 0}
        snapshot["inventory_counts"].update({"axe": 1, "pinecone": 3})
        snapshot["nearby"] = [
            {"prefab": "evergreen", "mature": True, "x": 1, "z": 1},
            {"prefab": "evergreen", "mature": True, "x": 7, "z": -4},
            {"prefab": "evergreen", "mature": True, "x": -9, "z": 6},
        ]

        homestead = self.advisor.analyze(snapshot)["homestead"]

        self.assertEqual(homestead["mature_trees"], 0)
        self.assertNotIn(
            "chop_replant",
            [chore["id"] for chore in homestead["chore_plan"]],
        )
        self.assertIn("行列对齐的自家林区", " ".join(homestead["rules"]))

    def test_calendar_and_glommer_state_are_explicit(self) -> None:
        snapshot = self.snapshot()
        snapshot["world"].update(
            {
                "day": 11,
                "phase": "dusk",
                "moon_phase": "full",
                "is_full_moon": False,
            }
        )
        snapshot["nearby"] = [
            {
                "prefab": "statueglommer",
                "x": 30,
                "z": -20,
                "workable": True,
            }
        ]

        calendar = self.advisor.analyze(snapshot)["calendar"]

        self.assertTrue(calendar["full_moon_later_today"])
        self.assertEqual(calendar["days_until_full_moon"], 0)
        self.assertEqual(calendar["glommer"]["state"], "statue_visible")
        self.assertTrue(calendar["glommer"]["statue_known"])

    def test_life_knowledge_includes_sources_and_home_maintenance(
        self,
    ) -> None:
        advisor = StrategyAdvisor()
        support = advisor.analyze(
            {
                "companion": {"prefab": "waxwell"},
                "home": {"name": "家"},
                "world": {"is_raining": True, "is_winter": True},
                "nearby": [
                    {"prefab": "evergreen", "mature": True},
                    {"prefab": "marbletree"},
                    {"prefab": "icebox"},
                    {"prefab": "meatrack"},
                    {"prefab": "firepit"},
                    {"prefab": "berrybush"},
                    {"prefab": "hound", "hostile": True},
                ],
            }
        )

        knowledge = {
            item["id"]: item for item in support["life_knowledge"]
        }
        self.assertIn("glommer_full_moon", knowledge)
        self.assertIn("tree_renewal", knowledge)
        self.assertIn("shadow_worker_density", knowledge)
        self.assertIn("icebox_preservation", knowledge)
        self.assertIn("drying_rack_preservation", knowledge)
        self.assertIn("rain_fire_consumption", knowledge)
        self.assertIn("berry_bush_winter", knowledge)
        self.assertIn("hound_wave_escalation", knowledge)
        self.assertTrue(
            all(
                item["source"].startswith("https://dontstarve.wiki.gg/")
                for item in knowledge.values()
            )
        )


if __name__ == "__main__":
    unittest.main()
