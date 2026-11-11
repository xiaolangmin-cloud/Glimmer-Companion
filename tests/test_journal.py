from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from controller.journal import CompanionJournal


class JournalTests(unittest.TestCase):
    def test_writes_readable_and_jsonl_logs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            journal = CompanionJournal(Path(tmp))
            event = journal.record(
                "game.task_complete",
                "微光确认任务完成",
                data={"intent_id": "fetch-1", "item_prefab": "goldnugget"},
            )

            self.assertIn("微光确认任务完成", journal.latest_path.read_text("utf-8"))
            daily = next(Path(tmp).glob("companion-*.jsonl"))
            line = json.loads(daily.read_text("utf-8").strip())
            self.assertEqual(line["seq"], event["seq"])
            self.assertEqual(line["data"]["item_prefab"], "goldnugget")

            context = journal.context(1)
            self.assertEqual(context[0]["kind"], "game.task_complete")
            self.assertEqual(context[0]["data"]["intent_id"], "fetch-1")


if __name__ == "__main__":
    unittest.main()
