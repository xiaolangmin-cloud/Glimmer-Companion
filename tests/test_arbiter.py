from __future__ import annotations

import time
import unittest

from controller.arbiter import IntentArbiter, MAX_LEASE_SECONDS


class IntentArbiterTests(unittest.TestCase):
    def test_latest_command_replaces_previous(self) -> None:
        arbiter = IntentArbiter(default_lease_seconds=5)
        arbiter.set(
            {
                "intent_id": "fight-1",
                "mode": "combat",
                "target_guid": "42",
                "lease_seconds": 10,
            }
        )
        arbiter.set(
            {
                "intent_id": "retreat-1",
                "mode": "retreat",
                "lease_seconds": 2,
            }
        )
        state = arbiter.snapshot()
        self.assertEqual(state["intent"]["intent_id"], "retreat-1")
        self.assertEqual(state["intent"]["mode"], "retreat")

    def test_unknown_mode_is_rejected(self) -> None:
        arbiter = IntentArbiter()
        with self.assertRaises(ValueError):
            arbiter.set({"mode": "autonomous_flee"})

    def test_capability_modes_are_supported(self) -> None:
        arbiter = IntentArbiter()
        for mode in (
            "use_skill",
            "craft",
            "build",
            "deploy",
            "plant",
            "till",
            "equip",
            "unequip",
        ):
            intent = arbiter.set(
                {
                    "intent_id": f"mode-{mode}",
                    "mode": mode,
                    "lease_seconds": 30,
                }
            )
            self.assertEqual(intent.mode, mode)

    def test_long_job_lease_is_preserved(self) -> None:
        arbiter = IntentArbiter(default_lease_seconds=5)
        arbiter.set(
            {
                "intent_id": "fetch-from-home",
                "mode": "move_to",
                "position": [1200, -800],
                "lease_seconds": 1800,
            }
        )
        intent = arbiter.snapshot()["intent"]
        self.assertEqual(intent["lease_seconds"], 1800)
        self.assertLessEqual(intent["lease_seconds"], MAX_LEASE_SECONDS)

    def test_snapshot_expires_task_to_default_follow(self) -> None:
        arbiter = IntentArbiter(default_lease_seconds=5)
        intent = arbiter.set(
            {
                "intent_id": "short-job",
                "mode": "move_to",
                "position": [10, 10],
                "lease_seconds": 0.5,
            }
        )
        intent.created_at = time.time() - 1
        state = arbiter.snapshot()
        self.assertEqual(state["intent"]["mode"], "follow")
        self.assertEqual(
            state["intent"]["reason"],
            "intent_lease_expired_follow",
        )


if __name__ == "__main__":
    unittest.main()
