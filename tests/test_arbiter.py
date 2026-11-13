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

    def test_combat_keeps_lower_priority_user_command_queued(self) -> None:
        arbiter = IntentArbiter()
        arbiter.submit(
            {
                "intent_id": "boss-fight",
                "mode": "combat",
                "target_guid": "99",
                "lease_seconds": 1800,
            },
            source="wheel",
        )
        active, queued = arbiter.submit(
            {
                "intent_id": "collect-grass",
                "mode": "harvest_area",
                "lease_seconds": 600,
                "params": {"amount": 10},
            },
            source="wheel",
        )

        self.assertTrue(queued)
        self.assertEqual(active.intent_id, "boss-fight")
        state = arbiter.snapshot()
        self.assertEqual(state["intent"]["intent_id"], "boss-fight")
        self.assertEqual(
            state["pending_intents"][0]["intent_id"],
            "collect-grass",
        )
        self.assertEqual(state["pending_intents"][0]["remaining_seconds"], 600)

    def test_finishing_combat_resumes_best_queued_command(self) -> None:
        arbiter = IntentArbiter()
        arbiter.submit(
            {
                "intent_id": "boss-fight",
                "mode": "combat",
                "lease_seconds": 1800,
            }
        )
        arbiter.submit(
            {
                "intent_id": "collect-grass",
                "mode": "harvest_area",
                "lease_seconds": 600,
            }
        )
        arbiter.submit(
            {
                "intent_id": "eat-food",
                "mode": "eat",
                "lease_seconds": 60,
            }
        )

        current, resumed = arbiter.finish(
            {
                "intent_id": "combat-follow",
                "mode": "follow",
                "lease_seconds": 120,
            }
        )

        self.assertTrue(resumed)
        self.assertEqual(current.intent_id, "eat-food")
        state = arbiter.snapshot()
        self.assertEqual(state["intent"]["intent_id"], "eat-food")
        self.assertEqual(
            state["pending_intents"][0]["intent_id"],
            "collect-grass",
        )

    def test_user_retreat_immediately_interrupts_combat(self) -> None:
        arbiter = IntentArbiter()
        arbiter.submit(
            {
                "intent_id": "boss-fight",
                "mode": "combat",
                "lease_seconds": 1800,
            }
        )
        current, queued = arbiter.submit(
            {
                "intent_id": "user-retreat",
                "mode": "retreat",
                "lease_seconds": 120,
            }
        )

        self.assertFalse(queued)
        self.assertEqual(current.intent_id, "user-retreat")
        self.assertEqual(current.mode, "retreat")

    def test_queued_command_resumes_after_combat_lease_expires(self) -> None:
        arbiter = IntentArbiter()
        combat, _ = arbiter.submit(
            {
                "intent_id": "boss-fight",
                "mode": "combat",
                "lease_seconds": 0.5,
            }
        )
        arbiter.submit(
            {
                "intent_id": "collect-grass",
                "mode": "harvest_area",
                "lease_seconds": 600,
            }
        )
        combat.created_at = time.time() - 1

        state = arbiter.snapshot()

        self.assertEqual(state["intent"]["intent_id"], "collect-grass")
        self.assertAlmostEqual(
            state["intent"]["remaining_seconds"],
            600,
            delta=1,
        )
        self.assertEqual(state["pending_intents"], [])

    def test_system_transition_can_clear_old_session_queue(self) -> None:
        arbiter = IntentArbiter()
        arbiter.submit(
            {
                "intent_id": "boss-fight",
                "mode": "combat",
                "lease_seconds": 1800,
            }
        )
        arbiter.submit(
            {
                "intent_id": "collect-grass",
                "mode": "harvest_area",
                "lease_seconds": 600,
            }
        )

        arbiter.set(
            {
                "intent_id": "new-session-follow",
                "mode": "follow",
                "lease_seconds": 86400,
            },
            source="session_boundary",
            clear_pending=True,
        )

        self.assertEqual(arbiter.snapshot()["pending_intents"], [])

    def test_homestead_does_not_block_a_plain_new_command(self) -> None:
        arbiter = IntentArbiter()
        arbiter.submit(
            {
                "intent_id": "stay-home",
                "mode": "homestead",
                "lease_seconds": 86400,
                "params": {"landmark": "家", "stay_home": True},
            }
        )

        current, queued = arbiter.submit(
            {
                "intent_id": "collect-grass",
                "mode": "harvest_area",
                "lease_seconds": 600,
                "params": {"amount": 10},
            }
        )

        self.assertFalse(queued)
        self.assertEqual(current.intent_id, "collect-grass")
        self.assertEqual(arbiter.snapshot()["pending_intents"], [])

    def test_boss_fight_queues_home_and_resumes_it_afterward(self) -> None:
        arbiter = IntentArbiter()
        arbiter.submit(
            {
                "intent_id": "boss-fight",
                "mode": "combat",
                "target_guid": "boss-1",
                "lease_seconds": 1800,
            }
        )
        active, queued = arbiter.submit(
            {
                "intent_id": "go-home",
                "mode": "homestead",
                "lease_seconds": 86400,
                "params": {"landmark": "家", "stay_home": True},
            }
        )

        self.assertTrue(queued)
        self.assertEqual(active.intent_id, "boss-fight")
        self.assertEqual(
            arbiter.snapshot()["pending_intents"][0]["intent_id"],
            "go-home",
        )

        resumed, from_queue = arbiter.finish(
            {
                "intent_id": "combat-finished",
                "mode": "follow",
                "lease_seconds": 120,
            }
        )

        self.assertTrue(from_queue)
        self.assertEqual(resumed.intent_id, "go-home")
        self.assertEqual(resumed.mode, "homestead")


if __name__ == "__main__":
    unittest.main()
