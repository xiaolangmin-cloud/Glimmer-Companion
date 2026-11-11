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

    def test_selector_launcher_uses_checked_script_file(self) -> None:
        root = Path(__file__).resolve().parents[1]
        launcher = (root / "open_character_selector.cmd").read_text(
            encoding="utf-8"
        )
        script = (root / "open_character_selector.ps1").read_text(
            encoding="utf-8"
        )

        self.assertIn("open_character_selector.ps1", launcher)
        self.assertIn("if errorlevel 1 pause", launcher)
        self.assertIn("/health", script)
        self.assertIn("/character", script)
        self.assertIn("MessageBox", script)

    def test_game_autostart_watcher_detects_client_and_manages_controller(
        self,
    ) -> None:
        root = Path(__file__).resolve().parents[1]
        watcher = (root / "companion_game_watcher.ps1").read_text(
            encoding="utf-8"
        )
        installer = (root / "install_game_autostart.ps1").read_text(
            encoding="utf-8"
        )
        uninstaller = (root / "uninstall_game_autostart.ps1").read_text(
            encoding="utf-8"
        )

        self.assertIn('"dontstarve_steam_x64"', watcher)
        self.assertIn('"dontstarve_steam"', watcher)
        self.assertIn('"/health"', watcher)
        self.assertIn('"python"', watcher)
        self.assertIn("Start-Sleep -Seconds 3", watcher)
        self.assertIn("Stop-AutoController", watcher)
        self.assertIn("Glimmer Companion Game Watcher.lnk", installer)
        self.assertIn("Glimmer Companion Game Watcher.lnk", uninstaller)


if __name__ == "__main__":
    unittest.main()
