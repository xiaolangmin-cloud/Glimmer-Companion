from __future__ import annotations

import unittest
from pathlib import Path

from controller.decision_branches import DecisionBranchRouter


ROOT = Path(__file__).resolve().parents[1]


class DecisionBranchRouterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.router = DecisionBranchRouter(
            ROOT / "config" / "decision_branches.json"
        )

    def classify(self, text: str) -> str:
        return self.router.classify(text).branch_id

    def test_core_branches_are_classified_locally(self) -> None:
        cases = {
            "帮我打一下这些青蛙": "combat",
            "帮我打些蜘蛛丝": "collection",
            "去采集附近的草": "collection",
            "帮我拿一些草": "collection",
            "做一个建造护符": "crafting",
            "给我做一个背包": "crafting",
            "在火堆旁边建一个箱子": "construction",
            "去家里拿二十个金块": "transport",
            "把成熟作物收了再种胡萝卜": "farming",
            "我快饿死了，先吃点东西": "survival",
            "去东边探索一下，找海象": "exploration",
            "整理一下家里的箱子": "base",
            "去和猪王换金块": "interaction",
            "跟着我": "movement",
            "带我回家里": "movement",
            "现在有多少蜘蛛丝": "information",
        }
        for text, expected in cases.items():
            with self.subTest(text=text):
                self.assertEqual(self.classify(text), expected)

    def test_intent_mode_is_a_strong_fallback(self) -> None:
        match = self.router.classify_intent({"mode": "fetch_item"})
        self.assertEqual(match.branch_id, "transport")

        match = self.router.classify_intent({"mode": "plant"})
        self.assertEqual(match.branch_id, "farming")

        match = self.router.classify_intent(
            {
                "mode": "use_skill",
                "params": {"action": "CAST_SPELLBOOK"},
            }
        )
        self.assertEqual(match.branch_id, "combat")

    def test_information_and_unknown_items_use_safe_branches(self) -> None:
        match = self.router.classify("你觉得今天的月亮怎么样")
        self.assertEqual(match.branch_id, "information")
        self.assertTrue(match.decision["required_checks"])

        unknown = self.router.classify("嗯")
        self.assertEqual(unknown.branch_id, "general")

    def test_branch_context_contains_execution_guardrails(self) -> None:
        match = self.router.classify("去打巨鹿")
        self.assertEqual(match.branch_id, "combat")
        self.assertIn("required_checks", match.context())
        self.assertIn("decision_order", match.context())
        self.assertIn("CAST_SPELLBOOK", match.context()["skill_actions"])
        self.assertTrue(
            any("暗影牢笼" in rule for rule in match.decision["rules"])
        )


if __name__ == "__main__":
    unittest.main()
