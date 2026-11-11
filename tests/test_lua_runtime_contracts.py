from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class LuaRuntimeContractTests(unittest.TestCase):
    def test_modmain_avoids_unavailable_sandbox_globals(self) -> None:
        source = (ROOT / "mod" / "modmain.lua").read_text(encoding="utf-8")

        self.assertIsNone(re.search(r"\b(?:x?pcall)\b", source))
        self.assertIsNone(re.search(r"\bpairs\s*\(\s*Ents\s*\)", source))
        self.assertIsNone(
            re.search(r"(?<!GLOBAL\.)\bSpawnPrefab\s*\(", source)
        )
        self.assertIn("GLOBAL.AllPlayers", source)
        self.assertIn('inst:RemoveTag("playerghost")', source)
        self.assertIn("ConfigurePlayerLocomotor", source)
        self.assertIn("GetPlayerSkillSelection()", source)
        self.assertIn("SetPlayerSkillSelection(selection)", source)
        self.assertIn("target_builder.recipes = {}", source)
        self.assertIn("table.insert(target_builder.recipes, recipe_name)", source)
        self.assertIn("local tonumber = GLOBAL.tonumber", source)
        self.assertIn("local next = GLOBAL.next", source)
        self.assertIn('AddPrefabPostInit("forest"', source)
        self.assertIn('world:ListenForEvent("ms_playerjoined"', source)
        self.assertIn("local function EnsureMiniMapIcon", source)
        self.assertIn("MiniMapEntity:SetDrawOverFogOfWar(true)", source)

    def test_actual_survivor_character_is_configurable(self) -> None:
        modinfo = (ROOT / "mod" / "modinfo.lua").read_text(encoding="utf-8")

        self.assertIn('name = "微光旅伴"', modinfo)
        self.assertIn('name = "companion_character"', modinfo)
        self.assertIn('name = "combat_leash_distance"', modinfo)
        self.assertIn('data = "wendy"', modinfo)
        self.assertIn('default = "waxwell"', modinfo)

    def test_shard_transition_uses_one_full_companion_record(self) -> None:
        source = (ROOT / "mod" / "modmain.lua").read_text(encoding="utf-8")

        self.assertIn('world:ListenForEvent("ms_playerdespawnandmigrate"', source)
        self.assertIn("companion:GetSaveRecord()", source)
        self.assertIn("GLOBAL.SpawnSaveRecord(record)", source)
        self.assertIn("data._codex_companion_migration", source)
        self.assertIn("_codex_companion_migrating = true", source)
        self.assertIn("PlaceCompanionNearPlayer(companion, player)", source)
        self.assertNotIn("SerializeInventory(inst)", source)
        self.assertNotIn("GetStateFile()", source)

    def test_game_chat_routes_companion_commands(self) -> None:
        source = (ROOT / "mod" / "modmain.lua").read_text(encoding="utf-8")

        self.assertIn("local function ExtractCompanionChat", source)
        self.assertIn("local function PostCompanionChat", source)
        self.assertIn("local function InstallInGameChatHook", source)
        self.assertIn("GLOBAL.Networking_Say = function", source)
        self.assertIn('PostCompanionChat("message", text', source)
        self.assertIn('GetBridgeURL() .. "/" .. route', source)
        self.assertIn(
            "GLOBAL._codex_companion_chat_hook_installed = false",
            source,
        )
        brain = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")
        self.assertIn('TheNet:Announce("[伴侣] " .. message', brain)

    def test_controller_has_no_voice_or_console_input_path(self) -> None:
        main = (ROOT / "controller" / "main.py").read_text(encoding="utf-8")

        self.assertNotIn("WindowsVoiceIO", main)
        self.assertNotIn("input(", main)
        self.assertFalse((ROOT / "controller" / "voice.py").exists())
        self.assertFalse((ROOT / "start_companion_voice.cmd").exists())

    def test_brain_does_not_read_mod_config_without_mod_context(self) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertNotIn("GetModConfigData(", source)
        self.assertNotIn("GLOBAL.", source)
        self.assertNotIn(":IsIdle(", source)
        self.assertIn("_codex_bridge_url", source)
        self.assertIn("_codex_area_radius", source)
        self.assertNotIn("self.bridge_url = (inst.", source)
        self.assertIn("self:BuildSnapshot(sent_events)", source)
        self.assertIn("landmarks = self.inst._codex_landmarks or {}", source)
        self.assertIn("last_event_at = now", source)
        self.assertIn("self.last_combat_event_at = now", source)
        self.assertIn('self.inst:ListenForEvent("death", self.death_listener)', source)
        self.assertIn('self:QueueEvent("companion_dead"', source)
        self.assertIn("function CodexCompanionBrain:PrepareForMigration", source)
        self.assertIn("function CodexCompanionBrain:ResumeAfterMigration", source)
        self.assertIn('reason = "shard_transition"', source)

    def test_combat_keeps_a_live_target_and_has_missing_grace(self) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertIn("local COMBAT_SEARCH_RADIUS = 64", source)
        self.assertIn("local COMBAT_MISSING_GRACE_SECONDS = 4", source)
        self.assertIn("function CodexCompanionBrain:FindCombatTarget", source)
        self.assertIn("self.combat_target = target", source)
        self.assertIn('self.inst:ListenForEvent(\n        "death",', source)
        self.assertIn(
            "now - self.combat_missing_since >= COMBAT_MISSING_GRACE_SECONDS",
            source,
        )
        self.assertIn("combat:CalcAttackRangeSq(target)", source)
        self.assertIn("local credited = data ~= nil and data.afflicter == self.inst", source)
        self.assertIn("verified = credited", source)
        self.assertIn(
            "BufferedAction(self.inst, target, ACTIONS.ATTACK)",
            source,
        )
        self.assertNotIn("combat:TryAttack(target)", source)
        self.assertIn("local DEFAULT_COMBAT_LEASH_DISTANCE = 30", source)
        self.assertIn('reason = "combat_leash_exceeded"', source)
        self.assertIn('reason = "lethal_next_hit"', source)
        self.assertIn("params.retreat_on_lethal ~= false", source)
        self.assertIn("safety_retreat_until", source)
        self.assertIn('"retreat_to_player"', source)
        self.assertIn("self:StopAll()\n        self.active_intent_id", source)
        self.assertIn('mode = "retreat",\n            verified = true', source)
        self.assertIn("local intent = self:GetActiveIntent()", source)
        self.assertIn("if intent == nil then\n        self:Follow()", source)

    def test_character_capabilities_and_production_modes(self) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        for method in (
            "GetCapabilities",
            "UseSkill",
            "CraftItem",
            "BuildAt",
            "DeployItem",
            "TillGround",
            "EquipItem",
            "UnequipItem",
            "EnsureCombatEquipment",
        ):
            self.assertIn(f"function CodexCompanionBrain:{method}", source)
        self.assertIn("GetActivatedSkills()", source)
        self.assertIn("craftable_recipes = craftable_recipes", source)
        self.assertIn("known_recipes = known_recipes", source)
        self.assertIn("SerializeIngredients(recipe.ingredients)", source)
        self.assertIn("inventory_counts = inventory_counts", source)
        self.assertIn("equipped = equipped", source)
        self.assertIn("local CRAFT_ACTION_TIMEOUT_SECONDS = 10", source)
        self.assertIn("self.craft_state = {", source)
        self.assertIn('self:FailAction(intent, "craft_timeout")', source)
        self.assertIn('self.build_state.stage = "crafted"', source)
        self.assertIn('self:FailAction(intent, "build_craft_timeout")', source)
        self.assertIn('intent.mode == "use_skill"', source)
        self.assertIn('intent.mode == "craft"', source)
        self.assertIn('intent.mode == "build"', source)
        self.assertIn("function CodexCompanionBrain:CollectLoot", source)
        self.assertIn("function CodexCompanionBrain:FindLootSource", source)
        self.assertIn("function CodexCompanionBrain:FindLootDrop", source)
        self.assertIn('intent.mode == "collect_loot"', source)
        self.assertIn("params.ignore_player_leash", source)
        self.assertIn("params.progress_reports == true", source)
        self.assertIn("patrol_radius", source)
        self.assertIn("function CodexCompanionBrain:EnsureTaskSurvival", source)
        self.assertIn('reason = "survival_hunger_low"', source)
        self.assertIn("params.ignore_survival_safety", source)
        self.assertIn("and not params.ignore_survival_safety", source)
        self.assertIn("function CodexCompanionBrain:RevealSharedMap", source)
        self.assertIn("MapExplorer:RevealArea", source)
        self.assertIn("local function IsPlayerMapPointExplored", source)
        self.assertIn("MapExplorer:IsTileSeeable", source)
        self.assertIn("player_map_explored_tiles = explored_tiles", source)

    def test_autonomous_recovery_checks_benefit_hunger_danger_and_phase(
        self,
    ) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertIn("local RECOVERY_MIN_SLEEP_SECONDS = 60", source)
        self.assertIn("local RECOVERY_EMERGENCY_SLEEP_SECONDS = 30", source)
        self.assertIn("local RECOVERY_TRAVEL_TIMEOUT_SECONDS = 45", source)
        self.assertIn("function CodexCompanionBrain:CanUseRecoveryTent", source)
        self.assertIn("sleepingbag:GetSleepPhase()", source)
        self.assertIn('clock:GetTimeUntilPhase(wake_phase)', source)
        self.assertIn("FindNearbyDanger(RECOVERY_DANGER_RADIUS)", source)
        self.assertIn("FindNearbyDanger(RECOVERY_SLEEP_DANGER_RADIUS)", source)
        self.assertIn("self.inst:IsNearDanger(self.inst)", source)
        self.assertIn("TUNING.CALORIES_MED", source)
        self.assertGreaterEqual(
            source.count("self.inst:GetBufferedAction() ~= nil"),
            2,
        )
        self.assertIn("sleepingbaguser.health_bonus_mult", source)
        self.assertIn("sleepingbaguser.sanity_bonus_mult", source)
        self.assertIn("sleepingbaguser.hunger_bonus_mult", source)
        self.assertIn("expected_health_gain = health_gain", source)
        self.assertIn("expected_sanity_gain = sanity_gain", source)
        self.assertIn("estimate.hunger_reserve = reserve", source)
        self.assertIn('return false, "not_enough_sleep_time", estimate', source)
        self.assertIn(
            'return false, "not_enough_recovery_benefit", estimate',
            source,
        )
        self.assertIn(
            'return false, "not_enough_hunger_for_sleep", estimate',
            source,
        )
        self.assertNotIn(
            "BufferedAction(self.inst, self.inst, ACTIONS.EAT",
            source,
        )
        self.assertIn(
            "BufferedAction(self.inst, nil, ACTIONS.EAT",
            source,
        )
        self.assertIn("params.ignore_autonomous_recovery == true", source)
        self.assertIn('follow_reason == "default_follow"', source)
        self.assertIn(
            'follow_reason == "intent_lease_expired_follow"',
            source,
        )
        self.assertIn("components.sleepingbaguser:DoWakeUp()", source)
        self.assertIn("Keep polling during tent sleep", source)
        self.assertIn('"recovery_started"', source)
        self.assertIn('"recovery_completed"', source)
        self.assertIn('"recovery_unavailable"', source)
        self.assertIn("fail_on_stuck = false", source)

    def test_runtime_character_selection_is_server_side_and_safe(self) -> None:
        modmain = (ROOT / "mod" / "modmain.lua").read_text(encoding="utf-8")
        brain = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertIn('"/companion-character"', modmain)
        self.assertIn('"/start"', modmain)
        self.assertIn('"/status"', modmain)
        self.assertIn("RequestControllerStart", modmain)
        self.assertIn("已进入存档，正在请求启动本地控制器", modmain)
        self.assertIn("控制器连接成功", modmain)
        self.assertIn("RequestControllerStart(GLOBAL.TheWorld, inst)", modmain)
        self.assertIn("world._codex_selected_character", modmain)
        self.assertIn(
            "world._codex_switch_companion_character = SwitchCompanionCharacter",
            modmain,
        )
        self.assertIn("companion.components.inventory:DropEverything()", modmain)
        self.assertIn('world._codex_pending_character_switch = true', modmain)
        self.assertIn('"[微光] 已切换为" .. display_name', modmain)
        self.assertIn("state.companion_character", brain)
        self.assertIn(
            "TheWorld._codex_switch_companion_character(",
            brain,
        )


if __name__ == "__main__":
    unittest.main()
