from __future__ import annotations

import json
import tempfile
import threading
import unittest
from pathlib import Path
from urllib.request import Request, urlopen

from controller.config import Settings
from controller.server import create_server
from controller.service import CompanionService


class ServerTests(unittest.TestCase):
    def test_health_and_tick_endpoints(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            vault = root / "vault"
            vault.mkdir()
            prompt = root / "prompt.md"
            prompt.write_text("Return JSON only.", encoding="utf-8")
            settings = Settings(
                host="127.0.0.1",
                port=0,
                deepseek_api_key=None,
                deepseek_base_url="https://api.deepseek.com",
                deepseek_model="deepseek-chat",
                memory_vault=vault,
                memory_index_db=root / "memory.sqlite3",
                prompt_path=prompt,
                decision_interval=1.0,
                replan_interval=0.0,
                ambient_chat_min_seconds=3600.0,
                ambient_chat_max_seconds=7200.0,
                request_timeout=2.0,
                default_lease_seconds=5.0,
            )
            service = CompanionService(settings)
            server = create_server(settings, service)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                base = f"http://127.0.0.1:{server.server_address[1]}"
                with urlopen(base + "/health", timeout=2) as response:
                    health = json.loads(response.read())
                self.assertTrue(health["ok"])
                with urlopen(base + "/gaps", timeout=2) as response:
                    gaps = json.loads(response.read())
                self.assertEqual(gaps["gaps"], [])
                with urlopen(base + "/character", timeout=2) as response:
                    page = response.read().decode("utf-8")
                self.assertIn("微光旅伴", page)
                with urlopen(
                    base + "/companion-character",
                    timeout=2,
                ) as response:
                    character = json.loads(response.read())
                self.assertEqual(character["prefab"], "waxwell")

                character_payload = json.dumps({"prefab": "walter"}).encode(
                    "utf-8"
                )
                request = Request(
                    base + "/companion-character",
                    data=character_payload,
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                with urlopen(request, timeout=2) as response:
                    selected = json.loads(response.read())
                self.assertEqual(selected["prefab"], "walter")

                payload = json.dumps(
                    {"companion": {}, "world": {}, "nearby": [], "events": []}
                ).encode("utf-8")
                request = Request(
                    base + "/tick",
                    data=payload,
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                with urlopen(request, timeout=2) as response:
                    tick = json.loads(response.read())
                self.assertEqual(tick["intent"]["mode"], "follow")
                self.assertEqual(tick["observed_revision"], 1)
                self.assertEqual(tick["companion_character"], "walter")

                message = json.dumps({"text": "跟着我"}).encode("utf-8")
                request = Request(
                    base + "/message",
                    data=message,
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                with urlopen(request, timeout=2) as response:
                    message_state = json.loads(response.read())
                self.assertTrue(message_state["message_received"])

                service.journal.record("test.event", "日志接口测试")
                with urlopen(base + "/logs?limit=5", timeout=2) as response:
                    logs = json.loads(response.read())
                self.assertEqual(logs["events"][-1]["kind"], "test.event")
                self.assertTrue(Path(logs["path"]).exists())
            finally:
                server.shutdown()
                server.server_close()
                service.stop()
                service.memory.close()


if __name__ == "__main__":
    unittest.main()
