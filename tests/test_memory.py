from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from controller.memory import MemoryStore


class MemoryStoreTests(unittest.TestCase):
    def test_indexes_and_finds_markdown_notes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "index").mkdir()
            (root / "chats" / "facts").mkdir(parents=True)
            (root / "index" / "总览.md").write_text(
                "---\ntitle: 总览\ntype: note\n---\n- 游戏内容索引\n",
                encoding="utf-8",
            )
            (root / "chats" / "facts" / "用户-游戏偏好.md").write_text(
                "---\ntitle: 用户 - 游戏偏好\ntype: note\n---\n"
                "- [preference] 用户希望助手自然使用游戏知识\n",
                encoding="utf-8",
            )
            store = MemoryStore(root, root / "memory.sqlite3")
            try:
                hits = store.search("游戏 助手", limit=5)
                self.assertTrue(hits)
                self.assertEqual(hits[0].section, "index")
                self.assertTrue(any("游戏偏好" in hit.title for hit in hits))
            finally:
                store.close()


if __name__ == "__main__":
    unittest.main()
