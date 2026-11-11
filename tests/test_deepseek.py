from __future__ import annotations

import unittest

from controller.deepseek import DeepSeekPlanner


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


if __name__ == "__main__":
    unittest.main()
