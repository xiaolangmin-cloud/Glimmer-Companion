from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from controller.characters import CharacterPreferenceStore


class CharacterPreferenceTests(unittest.TestCase):
    def test_defaults_to_maxwell_and_persists_valid_selection(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "companion_character.json"
            store = CharacterPreferenceStore(path)

            self.assertEqual(store.selected(), "waxwell")
            self.assertEqual(store.select("walter"), "walter")

            reloaded = CharacterPreferenceStore(path)
            self.assertEqual(reloaded.selected(), "walter")
            payload = reloaded.payload("walter")
            self.assertEqual(payload["name"], "沃尔特")
            self.assertEqual(payload["active_name"], "沃尔特")

    def test_rejects_unknown_character(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = CharacterPreferenceStore(
                Path(tmp) / "companion_character.json"
            )
            with self.assertRaises(ValueError):
                store.select("not_a_character")


if __name__ == "__main__":
    unittest.main()
