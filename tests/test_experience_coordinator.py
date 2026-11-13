from __future__ import annotations

import unittest

from controller.arbiter import Intent
from controller.experience_coordinator import ExperienceCoordinator


class ExperienceCoordinatorTests(unittest.TestCase):
    def make_intent(self, intent_id: str, mode: str, **params):
        return Intent(
            intent_id=intent_id,
            mode=mode,
            target_prefab=params.pop("target_prefab", None),
            params=params,
            lease_seconds=1800,
            reason="test",
        )

    def test_food_recovery_restores_original_task_after_threshold(self) -> None:
        coordinator = ExperienceCoordinator()
        intent = self.make_intent(
            "collect-before-recovery",
            "collect_loot",
            target_prefab="silk",
            amount=5,
        )
        started = coordinator.observe_event(
            {
                "type": "recovery_started",
                "event_id": "recovery-start",
                "intent_id": intent.intent_id,
                "method": "food",
                "hunger": 30,
                "hunger_max": 150,
                "hunger_percent": 20,
            },
            intent,
            {"companion": {}},
            now=10,
        )
        self.assertTrue(started.accepted)
        completed = coordinator.observe_event(
            {
                "type": "recovery_completed",
                "event_id": "recovery-finish",
                "intent_id": intent.intent_id,
                "method": "food",
                "hunger": 90,
                "hunger_max": 150,
                "hunger_percent": 60,
                "verified": True,
            },
            intent,
            {"companion": {}},
            now=20,
        )
        self.assertTrue(completed.accepted)
        self.assertTrue(completed.verified)
        self.assertEqual(completed.transition_intent["intent_id"], intent.intent_id)
        self.assertEqual(completed.transition_intent["mode"], "collect_loot")

    def test_tent_recovery_accepts_measured_fixed_gains(self) -> None:
        coordinator = ExperienceCoordinator()
        intent = self.make_intent("tent-recovery", "follow")
        coordinator.observe_event(
            {
                "type": "recovery_started",
                "event_id": "tent-start",
                "intent_id": intent.intent_id,
                "method": "tent",
                "health": 15,
                "health_max": 75,
                "health_percent": 20,
                "hunger": 150,
                "hunger_max": 150,
                "sanity": 20,
                "sanity_max": 200,
                "sanity_percent": 10,
            },
            intent,
            {"companion": {}},
            now=10,
        )
        completed = coordinator.observe_event(
            {
                "type": "recovery_completed",
                "event_id": "tent-finish",
                "intent_id": intent.intent_id,
                "method": "tent",
                "health": 75,
                "health_max": 75,
                "health_percent": 100,
                "hunger": 110.84,
                "hunger_max": 150,
                "sanity": 59.03,
                "sanity_max": 200,
                "sanity_percent": 29.52,
                "health_gain": 60,
                "sanity_gain": 39.03,
                "verified": True,
            },
            intent,
            {"companion": {}},
            now=50,
        )
        self.assertTrue(completed.accepted)
        self.assertTrue(completed.verified)
        self.assertEqual(completed.transition_intent["intent_id"], intent.intent_id)
        self.assertEqual(completed.transition_intent["mode"], "follow")

    def test_missing_food_keeps_resident_mode_without_repeated_recovery(
        self,
    ) -> None:
        coordinator = ExperienceCoordinator()
        intent = Intent(
            intent_id="home-task",
            mode="homestead",
            lease_seconds=60,
            params={"establish_home": True, "name": "家"},
        )
        event = {
            "type": "recovery_unavailable",
            "event_id": "food-missing",
            "intent_id": intent.intent_id,
            "reason": "recovery_food_missing",
        }
        first = coordinator.observe_event(
            event,
            intent,
            {"companion": {}},
            now=30,
        )
        second = coordinator.observe_event(
            {**event, "event_id": "food-missing-2"},
            intent,
            {"companion": {}},
            now=31,
        )
        self.assertTrue(first.accepted)
        self.assertIsNone(first.transition_intent)
        self.assertTrue(second.ignored)
        self.assertEqual(second.reason, "recovery_notice_duplicate")

    def test_collection_waits_for_verified_requested_quantity(self) -> None:
        coordinator = ExperienceCoordinator()
        intent = self.make_intent(
            "collect-five",
            "collect_loot",
            target_prefab="silk",
            amount=5,
        )
        for current in (2, 5):
            coordinator.observe_event(
                {
                    "type": "item_acquired",
                    "event_id": f"item-{current}",
                    "intent_id": intent.intent_id,
                    "item_prefab": "silk",
                    "before_amount": 0 if current == 2 else 2,
                    "after_amount": current,
                    "delta": 2 if current == 2 else 3,
                },
                intent,
                {"companion": {}},
                now=current,
            )
        early = coordinator.observe_event(
            {
                "type": "task_complete",
                "event_id": "collect-early",
                "intent_id": intent.intent_id,
                "mode": "collect_loot",
                "item_prefab": "silk",
                "amount": 2,
                "requested_amount": 2,
                "inventory_before": 0,
                "inventory_after": 2,
                "companion_delta": 2,
                "delivered_to_player": False,
                "verified": True,
            },
            intent,
            {"companion": {}},
            now=6,
        )
        self.assertFalse(early.accepted)
        self.assertEqual(early.reason, "amount_below_requested")
        complete = coordinator.observe_event(
            {
                "type": "task_complete",
                "event_id": "collect-five-done",
                "intent_id": intent.intent_id,
                "mode": "collect_loot",
                "item_prefab": "silk",
                "amount": 5,
                "requested_amount": 5,
                "inventory_before": 0,
                "inventory_after": 5,
                "companion_delta": 5,
                "delivered_to_player": False,
                "verified": True,
            },
            intent,
            {"companion": {}},
            now=7,
        )
        self.assertTrue(complete.accepted)
        self.assertEqual(complete.transition_intent["mode"], "follow")

    def test_area_harvest_requires_requested_count_and_mature_growth(self) -> None:
        coordinator = ExperienceCoordinator()
        intent = self.make_intent(
            "harvest-five",
            "harvest_area",
            target_prefab="carrot",
            amount=5,
        )
        coordinator.observe_event(
            {
                "type": "item_acquired",
                "event_id": "harvest-2",
                "intent_id": intent.intent_id,
                "item_prefab": "carrot",
                "before_amount": 0,
                "after_amount": 2,
                "delta": 2,
            },
            intent,
            {"companion": {}},
        )
        rejected = coordinator.observe_event(
            {
                "type": "task_complete",
                "event_id": "harvest-2-done",
                "intent_id": intent.intent_id,
                "mode": "harvest_area",
                "target_prefab": "carrot",
                "amount": 2,
                "desired_amount": 5,
                "final_growth_only": True,
                "verified": True,
            },
            intent,
            {"companion": {}},
        )
        self.assertFalse(rejected.accepted)
        self.assertEqual(rejected.reason, "amount_below_requested")
        invalid_growth = coordinator.observe_event(
            {
                "type": "task_complete",
                "event_id": "harvest-five-wrong-stage",
                "intent_id": intent.intent_id,
                "mode": "harvest_area",
                "target_prefab": "carrot",
                "amount": 5,
                "desired_amount": 5,
                "final_growth_only": False,
                "verified": True,
            },
            intent,
            {"companion": {}},
        )
        self.assertEqual(invalid_growth.reason, "growth_stage_not_verified")
        complete = coordinator.observe_event(
            {
                "type": "task_complete",
                "event_id": "harvest-five-done",
                "intent_id": intent.intent_id,
                "mode": "harvest_area",
                "target_prefab": "carrot",
                "amount": 5,
                "desired_amount": 5,
                "final_growth_only": True,
                "verified": True,
            },
            intent,
            {"companion": {}},
        )
        self.assertTrue(complete.accepted)

    def test_gold_harvest_rejects_destroyed_rocks_without_gold(self) -> None:
        coordinator = ExperienceCoordinator()
        intent = self.make_intent(
            "gold-five",
            "harvest_area",
            target_prefab="rock2",
            amount=5,
            drop_prefab="goldnugget",
        )
        coordinator.observe_event(
            {
                "type": "task_progress",
                "event_id": "rock-cleared",
                "intent_id": intent.intent_id,
                "mode": "harvest_area",
                "stage": "target_cleared",
                "target_prefab": "rock2",
                "targets_cleared": 1,
            },
            intent,
            {"companion": {}},
        )
        outcome = coordinator.observe_event(
            {
                "type": "task_complete",
                "event_id": "gold-not-collected",
                "intent_id": intent.intent_id,
                "mode": "harvest_area",
                "target_prefab": "rock2",
                "item_prefab": "goldnugget",
                "amount": 0,
                "desired_amount": 5,
                "targets_cleared": 1,
                "final_growth_only": True,
                "verified": True,
            },
            intent,
            {"companion": {}},
        )
        self.assertFalse(outcome.accepted)
        self.assertEqual(outcome.reason, "amount_below_requested")

        partial = coordinator.observe_event(
            {
                "type": "task_complete",
                "event_id": "mature-crops-partial",
                "intent_id": intent.intent_id,
                "mode": "harvest_area",
                "item_prefab": "carrot",
                "amount": 3,
                "desired_amount": 5,
                "targets_cleared": 3,
                "final_growth_only": True,
                "partial": True,
                "verified": True,
            },
            intent,
            {"companion": {}},
        )
        self.assertTrue(partial.accepted)
        self.assertIn("共 3 个", partial.reply)

    def test_delivery_requires_two_sided_quantity_evidence(self) -> None:
        coordinator = ExperienceCoordinator()
        intent = self.make_intent(
            "deliver-five",
            "deliver_item",
            item_prefab="twigs",
            amount=5,
        )
        rejected = coordinator.observe_event(
            {
                "type": "task_complete",
                "event_id": "deliver-three",
                "intent_id": intent.intent_id,
                "mode": "deliver_item",
                "item_prefab": "twigs",
                "amount": 5,
                "requested_amount": 5,
                "inventory_before": 8,
                "inventory_after": 5,
                "companion_delta": 3,
                "player_before": 0,
                "player_after": 3,
                "player_delta": 3,
                "delivered_to_player": True,
                "delivered_verified": False,
                "verified": True,
            },
            intent,
            {"companion": {}},
        )
        self.assertFalse(rejected.accepted)
        self.assertEqual(
            rejected.reason,
            "two_sided_delivery_evidence_insufficient",
        )
        complete = coordinator.observe_event(
            {
                "type": "task_complete",
                "event_id": "deliver-five-done",
                "intent_id": intent.intent_id,
                "mode": "deliver_item",
                "item_prefab": "twigs",
                "amount": 5,
                "requested_amount": 5,
                "inventory_before": 8,
                "inventory_after": 3,
                "companion_delta": 5,
                "player_before": 0,
                "player_after": 5,
                "player_delta": 5,
                "delivered_to_player": True,
                "delivered_verified": True,
                "verified": True,
            },
            intent,
            {"companion": {}},
        )
        self.assertTrue(complete.accepted)

    def test_completion_without_verification_does_not_transition(self) -> None:
        coordinator = ExperienceCoordinator()
        intent = self.make_intent("fetch-one", "fetch_item", amount=1)
        outcome = coordinator.observe_event(
            {
                "type": "task_complete",
                "event_id": "unverified",
                "intent_id": intent.intent_id,
                "mode": "fetch_item",
                "item_prefab": "goldnugget",
                "amount": 1,
                "verified": False,
            },
            intent,
            {"companion": {}},
        )
        self.assertTrue(outcome.handled)
        self.assertFalse(outcome.accepted)
        self.assertIsNone(outcome.transition_intent)
        self.assertEqual(outcome.reason, "completion_unverified")

    def test_emergency_reports_once_per_stage_and_supports_new_cycle(self) -> None:
        coordinator = ExperienceCoordinator()
        detected = {
            "type": "emergency_detected",
            "event_id": "hound-1",
            "category": "hound_wave",
            "action": "fight",
        }
        first = coordinator.observe_event(detected, None, {}, now=1)
        duplicate = coordinator.observe_event(
            {**detected, "event_id": "hound-2"},
            None,
            {},
            now=2,
        )
        action = coordinator.observe_event(
            {
                "type": "emergency_action",
                "event_id": "hound-action",
                "category": "hound_wave",
                "action": "fight",
            },
            None,
            {},
            now=3,
        )
        action_duplicate = coordinator.observe_event(
            {
                "type": "emergency_action",
                "event_id": "hound-action-2",
                "category": "hound_wave",
                "action": "fight",
            },
            None,
            {},
            now=4,
        )
        resolved = coordinator.observe_event(
            {
                "type": "emergency_resolved",
                "event_id": "hound-resolved",
                "category": "hound_wave",
                "action": "fight",
            },
            None,
            {},
            now=5,
        )
        new_cycle = coordinator.observe_event(
            {**detected, "event_id": "hound-new-cycle"},
            None,
            {},
            now=6,
        )
        self.assertTrue(first.accepted)
        self.assertTrue(duplicate.ignored)
        self.assertTrue(action.accepted)
        self.assertTrue(action_duplicate.ignored)
        self.assertTrue(resolved.accepted)
        self.assertTrue(new_cycle.accepted)


if __name__ == "__main__":
    unittest.main()
