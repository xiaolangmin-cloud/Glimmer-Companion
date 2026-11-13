from __future__ import annotations

import os
import unittest
from unittest.mock import patch

from controller.config import Settings


class ConfigTests(unittest.TestCase):
    def test_deepseek_key_falls_back_to_windows_user_environment(self) -> None:
        with patch.dict(os.environ):
            os.environ.pop("DEEPSEEK_API_KEY", None)
            with patch(
                "controller.config._windows_user_env",
                return_value="user-scope-key",
            ):
                settings = Settings.from_env()

        self.assertEqual(settings.deepseek_api_key, "user-scope-key")

    def test_blank_process_key_does_not_mask_windows_user_environment(
        self,
    ) -> None:
        with patch.dict(os.environ, {"DEEPSEEK_API_KEY": "   "}), patch(
            "controller.config._windows_user_env",
            return_value="user-scope-key",
        ):
            settings = Settings.from_env()

        self.assertEqual(settings.deepseek_api_key, "user-scope-key")


if __name__ == "__main__":
    unittest.main()
