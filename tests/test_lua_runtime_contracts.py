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
        self.assertIn(
            "if inst == nil or not inst:IsValid() then\n"
            "        return\n"
            "    end",
            source,
        )
        self.assertNotIn(
            "if inst == nil or not inst:IsValid() "
            "or inst:HasTag(COMPANION_TAG) then",
            source,
        )
        self.assertIn('inst:RemoveTag("playerghost")', source)
        self.assertIn('inst:RemoveTag("player")', source)
        self.assertIn("ConfigurePlayerLocomotor", source)
        self.assertIn("GetPlayerSkillSelection()", source)
        self.assertIn("SetPlayerSkillSelection(selection)", source)
        self.assertIn("CopyOwnerCharacterSkin(companion, player)", source)
        self.assertIn("CopySkinsFromPlayer(player)", source)
        self.assertIn("GetSkinsForCharacter(companion.prefab)", source)
        self.assertIn("companion.AnimState:AssignItemSkins(", source)
        self.assertIn('string.gsub(raw, "^KLEI%s+%d+%s+"', source)
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
        self.assertIn('name = "wheel_key"', modinfo)
        self.assertIn("server_only_mod = false", modinfo)
        self.assertIn('data = "MOUSEBUTTON_5"', modinfo)
        self.assertIn(
            "Mouse 5 / 2nd side button from top (recommended)",
            modinfo,
        )
        self.assertIn('data = "wendy"', modinfo)
        self.assertIn('default = "waxwell"', modinfo)

    def test_command_wheel_is_client_ui_with_server_validation(self) -> None:
        modmain = (ROOT / "mod" / "modmain.lua").read_text(encoding="utf-8")
        widget = (
            ROOT
            / "mod"
            / "scripts"
            / "widgets"
            / "glimmer_command_wheel.lua"
        ).read_text(encoding="utf-8")
        menu = (
            ROOT / "mod" / "scripts" / "glimmer_wheel_menu.lua"
        ).read_text(encoding="utf-8")

        self.assertIn('AddModRPCHandler(\n    "GlimmerWheel"', modmain)
        self.assertIn('GetBridgeURL() .. "/wheel-command"', modmain)
        self.assertIn("#encoded > 2048", modmain)
        self.assertIn('AddClassPostConstruct("widgets/controls"', modmain)
        self.assertIn('GetModConfigData("wheel_key")', modmain)
        self.assertIn('require "widgets/glimmer_command_wheel"', modmain)
        self.assertIn("command wheel initialized", modmain)
        self.assertIn("command wheel key registered", modmain)
        self.assertIn("wheel_key_name", modmain)
        self.assertIn("MOUSEBUTTON_5 = 1006", modmain)
        self.assertIn("MOUSEBUTTON_4 = 1005", modmain)
        self.assertIn("AddMouseButtonHandler", modmain)
        self.assertIn("button == wheel_key", modmain)
        self.assertIn("local wheel_keys = {", modmain)
        self.assertIn("if wheel_key == nil then", modmain)
        self.assertNotIn('if wheel_key_name == "KEY_F6" then', modmain)
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("F6/F7/F8/F9/R/G/V", readme)
        self.assertNotIn("GLOBAL.KEY_F6,", modmain)
        self.assertIn("return BuildItems", widget)
        self.assertIn("controls.commandwheel", modmain)
        self.assertIn("wheel.OnExecute", modmain)
        self.assertIn("hud:CloseCommandWheel()", modmain)
        self.assertIn("node.nestedwheel", widget)
        self.assertIn("tostring(source.quantity)", widget)
        self.assertIn("NEWFONT_OUTLINE", widget)
        self.assertNotIn("SetOutlineColour", widget)
        self.assertIn("amount = amount", menu)
        self.assertIn("images/inventoryimages3.xml", menu)

    def test_command_wheel_toggle_and_rebuild_preserve_glimmer_menu(
        self,
    ) -> None:
        source = (ROOT / "mod" / "modmain.lua").read_text(encoding="utf-8")
        toggle_start = source.index("local function ToggleCompanionWheel()")
        toggle_end = source.index(
            "local function RegisterCompanionWheelKey()",
            toggle_start,
        )
        toggle = source[toggle_start:toggle_end]

        self.assertLess(
            toggle.index("glimmer_command_wheel:IsOpen()"),
            toggle.index("glimmer_controls.spellwheel"),
        )
        self.assertIn("hud:CloseCommandWheel()", toggle)
        self.assertIn("local function ApplyCompanionWheel(controls)", source)
        self.assertIn(
            "local original_build_command_wheel = "
            "controls.BuildCommandWheel",
            source,
        )
        self.assertIn("ApplyCompanionWheel(self)", source)
        self.assertIn(
            "controls._codex_glimmer_build_wheel_hooked = true",
            source,
        )
        self.assertNotIn("wheel hotkey pressed", source)
        self.assertNotIn("command wheel open state", source)
        self.assertNotIn(
            'AddComponentPostInit("playercontroller"',
            source,
        )

    def test_shard_transition_uses_one_full_companion_record(self) -> None:
        source = (ROOT / "mod" / "modmain.lua").read_text(encoding="utf-8")

        self.assertIn('world:ListenForEvent("ms_playerdespawnandmigrate"', source)
        self.assertIn("companion:GetSaveRecord()", source)
        self.assertIn("GLOBAL.SpawnSaveRecord(record)", source)
        self.assertIn("data._codex_companion_migration", source)
        self.assertIn("_codex_companion_migrating = true", source)
        self.assertIn("PlaceCompanionNearPlayer(companion, player)", source)
        self.assertIn(
            "PlaceCompanionNearPlayer(companion, player)\n"
            "    PlayCompanionSpawnEffect(companion)",
            source,
        )
        self.assertIn("local function OnCompanionDeath(inst, data)", source)
        self.assertIn('[微光] " .. message', source)
        self.assertIn("world:DoTaskInTime(5, function()", source)
        self.assertIn("TrySpawnCompanion(player)", source)
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
        self.assertIn('TheNet:Announce("[微光] " .. message', brain)

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
        self.assertIn("GetMasterSessionId()", source)
        self.assertIn("NETWORK_REQUEST_TIMEOUT_SECONDS = 5", source)
        self.assertIn("self.network_request_id", source)
        self.assertIn("self.network_inflight_events", source)
        self.assertIn("if request_id ~= self.network_request_id", source)
        self.assertIn("landmarks = self.inst._codex_landmarks or {}", source)
        self.assertIn("last_event_at = now", source)
        self.assertIn("self.last_combat_event_at = now", source)
        self.assertIn('self.inst:ListenForEvent("death", self.death_listener)', source)
        self.assertIn('self:QueueEvent("companion_dead"', source)
        self.assertIn("local vitals = VitalityEvidence(self.inst)", source)
        self.assertIn("freezing = self.inst:IsFreezing()", source)
        self.assertIn("overheating = self.inst:IsOverheating()", source)
        self.assertIn("in_light = in_light", source)
        self.assertIn("self.last_observed_in_light = nil", source)
        self.assertIn("self.last_observed_in_light = in_light", source)
        self.assertIn("local observed_in_light = self.last_observed_in_light", source)
        self.assertIn("local live_in_light = nil", source)
        self.assertIn(
            "live_in_light = self.inst.LightWatcher:IsInLight()",
            source,
        )
        self.assertNotIn(
            "local live_in_light = self.inst.LightWatcher ~= nil",
            source,
        )
        self.assertIn('in_light_source = live_in_light ~= nil', source)
        self.assertIn("inferred_cause = inferred_cause", source)
        self.assertIn("active_mode = self.intent ~= nil", source)
        self.assertIn('"CAST_SPELLBOOK"', source)
        self.assertIn(
            "FindInventoryItem(self.inst, CODEX_UMBRA_PREFAB)",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:TryCodexUmbraCombatSpell",
            source,
        )
        combat_spell = source[
            source.index(
                "function CodexCompanionBrain:TryCodexUmbraCombatSpell"
            ):
            source.index(
                "function CodexCompanionBrain:TryCodexUmbraWorkerSpell"
            )
        ]
        self.assertIn(
            "if sanity_percent < CODEX_MIN_SANITY_PERCENT then",
            combat_spell,
        )
        self.assertIn('return false, "sanity_low"', combat_spell)
        self.assertLess(
            combat_spell.index(
                "if sanity_percent < CODEX_MIN_SANITY_PERCENT then"
            ),
            combat_spell.index("local spell_index"),
        )
        self.assertIn("spellbook:SelectSpell(spell_index)", source)
        self.assertIn("aoespell:CastSpell(self.inst, pos)", source)
        self.assertIn('self:QueueEvent("tactical_spell"', source)
        self.assertIn("CODEX_GOOD_ARMOR_ABSORB", source)
        self.assertIn("CODEX_GOOD_WEAPON_DAMAGE", source)
        self.assertIn(
            "local CODEX_RECOMMENDED_MAX_PUPPETS = 5",
            source,
        )
        self.assertIn("function CodexCompanionBrain:FindBestArmorBySlot", source)
        self.assertIn("function CodexCompanionBrain:TryHomesteadThermalCare", source)
        self.assertIn("function CodexCompanionBrain:FindNearbyCoolingSource", source)
        self.assertIn("shadow_puppet_counts = puppet_counts", source)
        self.assertIn('return false, "puppet_limit"', source)
        self.assertIn("ambient_temperature =", source)
        self.assertIn("body_temperature =", source)
        self.assertIn("wetness =", source)
        self.assertIn('return false, "gear_sufficient"', source)
        self.assertIn(
            "local CODEX_TARGET_SPELL_COOLDOWN_SECONDS = 30",
            source,
        )
        self.assertIn('return false, "target_cooldown"', source)
        self.assertIn("function CodexCompanionBrain:HasCombatGearSufficient", source)
        self.assertIn("inventory.equipslots or {}", source)
        self.assertIn(
            "local function CountLivePetsForPrefab(petleash, prefab)",
            source,
        )
        self.assertIn(
            "local function IsLiveShadowProtector(pet)",
            source,
        )
        self.assertIn('pet.prefab == "shadowprotector"', source)
        self.assertIn("pet.isprotector == true", source)
        self.assertIn(
            "local function GetLivePetsForPrefab(petleash, prefab)",
            source,
        )
        self.assertIn(
            "CountLivePetsForPrefab(\n        petleash,\n"
            '        "shadowprotector"\n    )',
            source,
        )
        self.assertNotIn(
            'petleash:GetNumPetsForPrefab("shadowprotector")',
            source,
        )
        self.assertNotIn("petleash:GetPetsWithPrefab(", source)
        self.assertIn(
            "function CodexCompanionBrain:GetFirstLiveEmergencyThreat",
            source,
        )
        self.assertIn("local function IsLiveEmergencyThreat(entity)", source)
        self.assertIn(
            "local target, live_threat_count = "
            "self:GetFirstLiveEmergencyThreat(state)",
            source,
        )
        spell_preflight = source[
            source.index('    if category == "lethal_threat"'):
            source.index(
                '    if category == "lethal_threat" then',
                source.index('    if category == "lethal_threat"') + 1,
            )
        ]
        self.assertIn('or category == "hostile_group"', spell_preflight)
        hostile_group = source[
            source.index('elseif category == "hostile_group" then'):
            source.index('elseif category == "nightmare_riot" then')
        ]
        self.assertIn("self:HasCombatGearSufficient(", hostile_group)
        self.assertIn("live_threat_count", hostile_group)
        self.assertIn("self:EmergencyFightTarget(", hostile_group)
        self.assertIn("self:EmergencyRally(state)", hostile_group)
        self.assertIn("local CODEX_SPELL_WORKER = 1", source)
        self.assertIn("local CODEX_SPELL_PROTECTOR = 2", source)
        self.assertIn('spell_name = "shadow_protector"', source)
        self.assertIn('spell_name = "shadow_trap"', source)
        self.assertIn('spell_name = "shadow_pillars"', source)
        self.assertIn(
            "function CodexCompanionBrain:TryCodexUmbraWorkerSpell",
            source,
        )
        self.assertIn('spell = "shadow_worker"', source)
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
        self.assertIn("if known then\n                    local available", source)
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
        self.assertIn("self.area_state", source)
        self.assertIn("RecordAreaHarvest", source)
        self.assertIn("local function IsMatureGrowthStage(entity)", source)
        self.assertIn("local function IsHarvestableNow(entity)", source)
        self.assertIn(
            "matches = entity:HasTag(\"farm_plant\")\n"
            "                and IsHarvestableNow(entity)",
            source,
        )
        self.assertIn("target_prefab_set[requested_prefab] = true", source)
        self.assertIn("function CodexCompanionBrain:EnsureAreaTool", source)
        self.assertIn('"tool_craft_start_failed"', source)
        self.assertIn("farm_hoe = ACTIONS.TILL", source)
        self.assertIn("drop_prefab = params.drop_prefab", source)
        self.assertIn(
            "local product = plant_def ~= nil and plant_def.product or nil",
            source,
        )
        self.assertIn("self.area_state.drop_prefab = product", source)
        self.assertIn(
            "function CodexCompanionBrain:EnsureAreaInventorySpace",
            source,
        )
        self.assertIn("local function InventoryCanStackPrefab", source)
        self.assertIn(
            "if InventoryCanStackPrefab(inventory, drop_prefab) then",
            source,
        )
        self.assertIn('stage = "inventory_space_freed"', source)
        self.assertIn("params.allow_partial == true", source)
        self.assertIn("function CodexCompanionBrain:PickupAreaDrop", source)
        self.assertIn(
            "BufferedAction(self.inst, target, action, invobject)",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:MaybeSummonAreaHelpers",
            source,
        )
        self.assertIn('reason == "petleash_missing"', source)
        self.assertIn("function CodexCompanionBrain:FindFarmSoil", source)
        self.assertIn("function CodexCompanionBrain:FindTillPoint", source)
        self.assertIn(
            "function CodexCompanionBrain:EnsureFarmingTool",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:PlantFarmSeed",
            source,
        )
        self.assertIn("ACTIONS.PLANTSOIL", source)
        self.assertIn("plant_not_verified", source)
        self.assertIn("till_not_verified", source)
        self.assertIn(
            "if entity:HasTag(\"farm_plant\") then\n"
            "        return IsMatureGrowthStage(entity)\n"
            "    end\n"
            "    return true",
            source,
        )
        self.assertIn("local function IsTreeHarvestIntent(intent)", source)
        self.assertIn("local function IsTreeStump(entity)", source)
        self.assertIn('stage = "digging_tree_stump"', source)
        self.assertIn('stage = "tree_stump_dig_verified"', source)
        self.assertIn(
            "self.inst:DoTaskInTime(0.75, function()",
            source,
        )
        self.assertIn('self.inst.sg:GoToState("idle")', source)
        self.assertIn('not self.inst.sg:HasStateTag("busy")', source)
        self.assertIn("self.inst:DoTaskInTime(1.25, function()", source)
        self.assertIn('ACTIONS.DIG,\n                            shovel\n                        ):Do()', source)
        self.assertIn("stump_dig_scheduled", source)
        self.assertIn("stump_dig_notice_sent", source)
        self.assertIn(
            "and item.components.farmplantable ~= nil",
            source,
        )
        self.assertIn("self.till_state = nil", source)
        self.assertIn("self.plant_state = nil", source)
        self.assertIn("success_handler", source)
        self.assertIn("if pickable ~= nil then", source)
        self.assertLess(
            source.index("function CodexCompanionBrain:ActionForTarget"),
            source.index("function CodexCompanionBrain:RecordAreaHarvest"),
        )
        action_start = source.index("function CodexCompanionBrain:ActionForTarget")
        action_end = source.index(
            "function CodexCompanionBrain:RecordAreaHarvest",
            action_start,
        )
        action_source = source[action_start:action_end]
        self.assertLess(
            action_source.index("if target.components.pickable ~= nil then"),
            action_source.index(
                "elseif target.components.workable ~= nil then"
            ),
        )
        area_start = source.index("function CodexCompanionBrain:AreaTask")
        area_source = source[area_start:]
        self.assertLess(
            area_source.index("self.harvest_state ~= nil"),
            area_source.index("local target = self:FindAreaTarget"),
        )
        self.assertIn("final_growth_only = true", source)
        self.assertIn("delivered_verified = verified", source)
        self.assertIn("player_delta = player_delta", source)
        self.assertIn("companion_delta = companion_delta", source)
        self.assertIn("local function IsGivingToPlayer", source)
        self.assertIn("action.action == ACTIONS.GIVETOPLAYER", source)
        self.assertIn("action.action == ACTIONS.GIVEALLTOPLAYER", source)
        self.assertIn("local function GiveToPlayerAction(item)", source)
        self.assertIn("and ACTIONS.GIVEALLTOPLAYER", source)
        self.assertIn("GiveToPlayerAction(item)", source)
        self.assertIn("IsGivingToPlayer(self.inst, player)", source)
        self.assertIn("item = stackable:Get(desired) or item", source)
        self.assertNotIn("stackable:SplitStack(", source)
        self.assertIn("local pickup_stackable = ground_item.components.stackable", source)
        self.assertIn("pickup_stackable:Get(remaining)", source)
        self.assertIn(
            "container_component:RemoveItem(item, false)",
            source,
        )
        self.assertIn("local needed = state.target_amount - before_count", source)
        fetch_start = source.index("function CodexCompanionBrain:FetchItem")
        fetch_end = source.index(
            "function CodexCompanionBrain:Eat",
            fetch_start,
        )
        fetch_source = source[fetch_start:fetch_end]
        self.assertGreaterEqual(
            fetch_source.count("self.fetch_state = nil"),
            2,
        )
        self.assertIn(
            "state.acquired_amount = (state.acquired_amount or 0)",
            fetch_source,
        )
        self.assertIn(
            "companion_delta = state.acquired_amount or 0",
            fetch_source,
        )
        self.assertIn(
            "acquired_amount = state.acquired_amount or 0",
            fetch_source,
        )
        self.assertIn("local best_distance = math.huge", source)
        self.assertIn('"area_travel"', source)
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
        self.assertIn(
            "local RECOVERY_WAKE_EVIDENCE_DELAY_SECONDS = 1",
            source,
        )
        self.assertIn(
            'self.recovery_state.stage = "waking"',
            source,
        )
        self.assertIn(
            "self.recovery_state.wake_started_at = GetTime()",
            source,
        )
        self.assertIn(
            "< RECOVERY_WAKE_EVIDENCE_DELAY_SECONDS",
            source,
        )
        self.assertIn("function CodexCompanionBrain:CanUseRecoveryTent", source)
        self.assertIn("sleepingbag:GetSleepPhase()", source)
        self.assertIn('clock:GetTimeUntilPhase(wake_phase)', source)
        self.assertIn("FindNearbyDanger(RECOVERY_DANGER_RADIUS)", source)
        self.assertIn("FindNearbyDanger(RECOVERY_SLEEP_DANGER_RADIUS)", source)
        self.assertIn("self.inst:IsNearDanger(self.inst)", source)
        self.assertIn("TUNING.CALORIES_MED", source)
        self.assertIn(
            "function CodexCompanionBrain:FindEmergencyGroundTorch",
            source,
        )
        self.assertIn('entity.prefab == "torch"', source)
        self.assertIn('entity.prefab ~= "fireflies"', source)
        self.assertIn(
            "BufferedAction(self.inst, ground_torch, ACTIONS.PICKUP)",
            source,
        )
        self.assertGreaterEqual(
            source.count("self.inst:GetBufferedAction() ~= nil"),
            2,
        )
        act_start = source.index("function CodexCompanionBrain:Act()")
        stale_action_check = source.index(
            "not pending_action.target:IsValid()",
            act_start,
        )
        intent_lookup = source.index(
            "local intent = self:GetActiveIntent()",
            act_start,
        )
        self.assertLess(stale_action_check, intent_lookup)
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
        self.assertIn(
            "pending_action.action == ACTIONS.PICKUP",
            source,
        )
        self.assertIn(
            "pending_action.target.components.inventoryitem.owner ~= nil",
            source,
        )
        self.assertIn("params.ignore_autonomous_recovery == true", source)
        self.assertIn("self.active_intent_created_at", source)
        self.assertIn("params.force_recovery_check == true", source)
        self.assertIn('stage = "recovery_check_forced"', source)
        self.assertIn('follow_reason == "default_follow"', source)
        self.assertIn(
            'follow_reason == "intent_lease_expired_follow"',
            source,
        )
        self.assertIn("local function VitalityEvidence(inst)", source)
        self.assertIn("payload.started_health = state.started_health", source)
        self.assertIn("payload.health_gain = Round(health_gain)", source)
        self.assertIn("payload.sanity_gain = Round(sanity_gain)", source)
        self.assertIn(
            "payload.verified = (payload.hunger_percent or 0) >= 55",
            source,
        )
        self.assertIn(
            "payload.verified = health_gain >= RECOVERY_MIN_HEALTH_GAIN",
            source,
        )
        self.assertIn(
            "or sanity_gain >= RECOVERY_MIN_SANITY_GAIN",
            source,
        )
        self.assertNotIn("(payload.sanity_percent or 0) >= 45", source)
        self.assertIn("original_intent_id = original_intent_id", source)
        self.assertIn("components.sleepingbaguser:DoWakeUp()", source)
        self.assertIn("Keep polling during tent sleep", source)
        self.assertIn('"recovery_started"', source)
        self.assertIn('"recovery_completed"', source)
        self.assertIn('"recovery_unavailable"', source)
        self.assertIn("fail_on_stuck = false", source)
        self.assertIn('"itemget"', source)
        self.assertIn("self.recovery_next_check = 0", source)

    def test_homestead_food_reserve_and_warmth_workflow_are_complete(
        self,
    ) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertIn("local function GetFoodReserveCount", source)
        self.assertIn("params.allow_eat_task_items == true", source)
        self.assertIn("params.preserve_items", source)
        self.assertIn("FindBestFood(self.inst, nil, intent)", source)
        self.assertIn("FindBestFood(self.inst, nil, self.intent)", source)
        self.assertIn("candidate_perish < current_perish", source)
        self.assertIn("BASIC_TOOL_COST[item.prefab] or 15", source)

        self.assertIn("function CodexCompanionBrain:StartEmergencyFire", source)
        self.assertIn('stage = "crafting"', source)
        self.assertIn('stage = "deploying"', source)
        self.assertIn("deployable:CanDeploy(", source)
        self.assertIn("ACTIONS.DEPLOY", source)
        self.assertIn("self.emergency_warmth_state = nil", source)
        self.assertIn("local action = self:TryEmergencyWarmth()", source)

        self.assertIn(
            "and type(self.inst._codex_landmarks) == \"table\"",
            source,
        )
        self.assertIn("self.inst._codex_home = landmark", source)
        self.assertIn("and intent.params.establish_home == true", source)
        self.assertIn("name = intent.params.name", source)
        self.assertIn("home = self.inst._codex_home", source)
        self.assertIn("and self.intent.mode == \"homestead\"", source)
        self.assertIn("local home = self.inst._codex_home", source)
        self.assertIn('elseif intent.mode == "homestead" then', source)

    def test_homestead_autonomy_collects_replants_mines_and_cooks_cheaply(
        self,
    ) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertIn("function CodexCompanionBrain:RunHomeAutonomy", source)
        self.assertIn("function CodexCompanionBrain:TryStoreOneHomeItem", source)
        self.assertIn("function CodexCompanionBrain:TryPickupHomeGroundItem", source)
        self.assertIn("function CodexCompanionBrain:TryReplantHomeTree", source)
        self.assertIn("function CodexCompanionBrain:TryChopHomeTree", source)
        self.assertIn("function CodexCompanionBrain:TryMineHomeMarble", source)
        self.assertIn("function CodexCompanionBrain:TryHomePlayerMeal", source)
        self.assertIn("function CodexCompanionBrain:TryOfferHomeFood", source)
        self.assertIn("function CodexCompanionBrain:TryOfferHomeHealing", source)
        self.assertIn("function CodexCompanionBrain:TryMaintainHomeFire", source)
        self.assertIn("function CodexCompanionBrain:TryHarvestHomePlant", source)
        self.assertIn("function CodexCompanionBrain:FindHomeHarvestable", source)
        self.assertIn(
            "BufferedAction(self.inst, best_chest, ACTIONS.STORE, best_item)",
            source,
        )

    def test_homestead_does_not_cancel_its_own_multitick_action(self) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "A homestead task can span several ticks while the companion walks",
            source,
        )
        self.assertIn("if self.inst:GetBufferedAction() == nil", source)
        self.assertIn('not self.inst.sg:HasStateTag("busy")', source)
        self.assertIn("self:KeepTargetAwake(best_chest)", source)
        self.assertIn("function CodexCompanionBrain:GetHomeStorageCandidate", source)
        self.assertIn(
            "inventory:GiveItem(split, empty_slot)",
            source,
        )
        self.assertIn(
            "and inventory:GetItemInSlot(empty_slot) == split",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:CountHomeMarbleTrees",
            source,
        )
        self.assertIn(
            "HOME_CHORE_MARBLE_ASSIST_MIN_CLUSTER",
            source,
        )
        self.assertIn(
            '"resource_assist"',
            source,
        )
        self.assertIn("self:KeepTargetAwake(pending_action.target)", source)
        self.assertNotIn(
            "pending_action.action == ACTIONS.STORE\n"
            "            and pending_action.target ~= nil\n"
            "            and pending_action.target:IsAsleep()",
            source[source.index("function CodexCompanionBrain:RunHomeAutonomy"):],
            "an asleep target must not cause the pending STORE to be cancelled",
        )
        autonomy_start = source.index(
            "function CodexCompanionBrain:RunHomeAutonomy"
        )
        autonomy_end = source.index(
            "function CodexCompanionBrain:Homestead",
            autonomy_start,
        )
        autonomy = source[autonomy_start:autonomy_end]
        self.assertNotIn(
            "self.inst:ClearBufferedAction()",
            autonomy,
            "base autonomy must let its pending multi-tick action finish",
        )
        self.assertIn(
            "function CodexCompanionBrain:GetHomeStoredItemCandidates",
            source,
        )
        self.assertIn(
            "self:KeepTargetAwake(container)",
            source,
        )
        take_one_start = source.index(
            "function CodexCompanionBrain:TakeOneFromHomeContainer"
        )
        take_one_end = source.index(
            "function CodexCompanionBrain:FindBestHomeStoredFood",
            take_one_start,
        )
        take_one = source[take_one_start:take_one_end]
        self.assertIn(
            "if not container:IsValid() then",
            take_one,
        )
        self.assertNotIn(
            "container:IsAsleep()",
            take_one,
            "server-side container reads must keep working after the entity sleeps",
        )
        self.assertIn(
            "if removed:IsValid() then\n"
            "            container_component:GiveItem(removed)",
            take_one,
        )
        self.assertIn(
            "inventory:GiveItem(\n"
            "        one,",
            source,
        )
        self.assertIn(
            "stackable:SetStackSize(stackable:StackSize() + 1)",
            source,
        )
        self.assertIn("function CodexCompanionBrain:IsDeadOrGhost", source)
        self.assertIn("function CodexCompanionBrain:EnterDeathPassive", source)
        self.assertIn("or #self.speech_queue >= 3", source)
        self.assertIn("local HOME_CHORE_TREE_MIN_CLUSTER = 3", source)
        self.assertIn(
            "local HOME_TREE_REPLANT_MAX_ATTEMPTS = 4",
            source,
        )
        self.assertIn(
            "local HOME_TREE_REPLANT_RETRY_DELAY_SECONDS = 0.35",
            source,
        )
        self.assertIn('NoticeHomeChore("tree_replanted"', source)
        self.assertIn('current.stage = "replant_retry"', source)
        self.assertIn("current.replant_avoid_points", source)
        self.assertIn(
            "self:FindDeployPointNear(\n"
            "        seed,\n"
            "        x,\n"
            "        z,\n"
            "        state ~= nil and state.replant_avoid_points or nil\n"
            "    )",
            source,
        )
        self.assertIn("target_guid = tostring(target.GUID)", source)
        self.assertIn("target_position = {", source)
        self.assertIn("local function HomeSeedForStump", source)
        self.assertIn("local stump_y", source)
        self.assertIn(
            "x, stump_y, z = stump.Transform:GetWorldPosition()",
            source,
        )
        self.assertIn('return "pinecone"', source)
        self.assertIn('return "acorn"', source)
        self.assertIn("local seed_prefab = HomeSeedForStump", source)
        self.assertIn("seed_prefab = seed.prefab", source)
        self.assertIn('stage = "mining_marble"', source)
        self.assertIn(
            "HOME_PLAYER_MEAL_MIN_HUNGER_DEFICIT",
            source,
        )
        self.assertIn("GetFoodReserveCount(", source)
        self.assertIn("local function FindBestCheapFood", source)
        self.assertIn("HOME_PLAYER_FOOD_OFFER_MIN_HUNGER_DEFICIT", source)
        self.assertIn("HOME_PLAYER_HEAL_MIN_RATIO", source)
        self.assertIn("HOME_PLAYER_SANITY_MIN_RATIO", source)
        self.assertIn("local function FindBestSanityFood", source)
        self.assertIn("function CodexCompanionBrain:TryOfferHomeSanity", source)
        self.assertIn("player_sanity_delivered", source)
        self.assertIn("health.currenthealth / health.maxhealth >= 0.5", source)
        self.assertIn("health.currenthealth + health_gain >= 30", source)
        self.assertIn("self:TryOfferHomeSanity()", source)
        self.assertIn(
            "emergency_category = emergency.category",
            source,
        )
        self.assertIn(
            "self:RunHomeAutonomy(intent, emergency)",
            source,
        )

    def test_home_forest_is_aligned_and_returning_player_is_checked_once(
        self,
    ) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "local HOME_FOREST_ALIGN_TOLERANCE = 0.75",
            source,
        )
        self.assertIn("local function HasAlignedForestNeighbors", source)
        self.assertIn("function CodexCompanionBrain:IsHomeForestPoint", source)
        self.assertIn("function CodexCompanionBrain:GetHomeForestTrees", source)
        self.assertIn(
            "and HasAlignedForestNeighbors(x, z, layout)",
            source,
        )
        self.assertIn(
            "if self:IsHomeForestPoint(x, z) then",
            source,
        )
        count_start = source.index(
            "function CodexCompanionBrain:CountMatureHomeTrees"
        )
        count_end = source.index(
            "function CodexCompanionBrain:FindHomeChopTree",
            count_start,
        )
        self.assertIn(
            "self:GetHomeForestTrees()",
            source[count_start:count_end],
        )
        self.assertIn(
            "function CodexCompanionBrain:CheckReturningPlayerCare",
            source,
        )
        self.assertIn(
            "self:CheckReturningPlayerCare(landmark)",
            source,
        )
        self.assertIn(
            "你受伤了，我来给你处理一下。",
            source,
        )
        self.assertIn(
            "你饿了，我去给你做点吃的。",
            source,
        )
        self.assertIn(
            "你精神不太好，我找点能稳住精神的东西。",
            source,
        )
        self.assertIn("payload.announce = false", source)
        self.assertIn("self:EnqueueSpeech(intent.params.text)", source)

    def test_homestead_maintains_drying_rack_and_keeps_emergency_portions(
        self,
    ) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertIn("AUTONOMY_KEEP_LAST_FOOD_PORTION = 1", source)
        self.assertIn("AUTONOMY_KEEP_LAST_FUEL_PORTION = 1", source)
        self.assertIn("local function GetAutonomyFoodReserveCount", source)
        self.assertIn("local function GetAutonomyFuelReserveCount", source)
        self.assertIn(
            "function CodexCompanionBrain:FindHomeDryingRack",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:FindHomeDryableFood",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:TryMaintainHomeDryingRack",
            source,
        )
        self.assertIn("RackCanDryItem(dryer, item)", source)
        self.assertIn("components.dryingrack", source)
        self.assertIn(
            "AUTONOMY_KEEP_LAST_HEALING_PORTION = 1",
            source,
        )
        self.assertIn(
            "HOME_PLAYER_CRITICAL_HEAL_RATIO = 0.2",
            source,
        )
        self.assertIn(
            "GetAutonomyHealingReserveCount",
            source,
        )
        self.assertIn(
            "local healing_reserve = nil",
            source,
        )
        self.assertNotIn(
            "HOME_PLAYER_CRITICAL_HEAL_RATIO\n"
            "            and nil\n"
            "            or GetAutonomyHealingReserveCount",
            source,
        )
        self.assertIn(
            "WouldStoreLastToolCapability",
            source,
        )
        self.assertIn(
            "SplitInventoryItemCount",
            source,
        )
        self.assertIn(
            "state.action_started ~= true",
            source,
        )
        self.assertIn(
            "self.home_chore_state.action_started = true",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:FindHomeStoredItem",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:FindBestHomeStoredFood",
            source,
        )
        self.assertIn(
            "home_food_taken_from_storage",
            source,
        )
        self.assertIn(
            "GetAutonomyFoodReserveCount(self.inst, item.prefab)",
            source,
        )
        self.assertIn(
            "GetAutonomyFuelReserveCount(",
            source,
        )
        self.assertIn('stage = "harvesting_dryer"', source)
        self.assertIn('stage = "loading_dryer"', source)
        self.assertIn("ACTIONS.HARVEST,\n                finished", source)
        self.assertIn("ACTIONS.STORE,\n        portion", source)
        self.assertIn("self:TryMaintainHomeDryingRack()", source)
        self.assertIn("home_fire_last_fuel_kept", source)
        self.assertIn(
            "and entity.components.dryingrack == nil",
            source,
        )
        self.assertIn(
            "self:Homestead(intent, emergency)",
            source,
        )
        self.assertIn("self.home_sanity_offer = nil", source)
        self.assertIn("health.currenthealth / health.maxhealth", source)
        self.assertIn("HOME_CHORE_FIRE_REFUEL_PERCENT", source)
        self.assertIn("player_healing_delivered", source)
        self.assertIn("home_fire_refuelled", source)
        self.assertIn("ACTIONS.ADDFUEL", source)
        self.assertIn("SplitOneInventoryItem(self.inst, fuel)", source)
        self.assertIn("local split = stackable:Get(1)", source)
        self.assertIn("item.components.fuel ~= nil", source)
        self.assertIn("item.components.fueler ~= nil", source)
        self.assertIn("not IsTaskInventoryItem(self.intent, item.prefab)", source)
        self.assertIn("local function IsHomeTidyItem(item)", source)
        self.assertIn("local function IsEquippedInventoryItem(inst, item)", source)
        self.assertIn("IsHomeTidyItem(entity)", source)
        self.assertIn("IsPerishableFood(item)", source)
        self.assertIn("score = score - 10000", source)
        self.assertIn("score = score - 1000", source)
        self.assertIn(
            "not IsTaskInventoryItem(self.intent, item.prefab)",
            source,
        )
        fuel_guard = source.index("item.components.fuel ~= nil")
        accept_guard = source.index("fueled:CanAcceptFuelItem(item)")
        self.assertLess(
            fuel_guard,
            accept_guard,
            "fuel components must be checked before Fueled dereferences them",
        )
        self.assertIn("player_food_delivered", source)
        self.assertIn("home_plant_harvested", source)
        self.assertIn(
            "GiveToPlayerAction(portion),",
            source,
        )
        self.assertIn(
            "GiveToPlayerAction(meal),",
            source,
        )
        self.assertIn(
            "GiveToPlayerAction(item),",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:GetHomeCookingPortions",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:CountHomeCookingPortions",
            source,
        )
        self.assertIn(
            "self:GetHomeCookingPortions(HOME_MEAT_PREFABS, 1)",
            source,
        )
        self.assertIn(
            "self:GetHomeCookingPortions(HOME_FILLER_PREFABS, 3)",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:FindBestPlayerInventoryFood",
            source,
        )
        self.assertIn(
            "function CodexCompanionBrain:FindBestPlayerHomeStoredFood",
            source,
        )
        self.assertIn("IsBetterPlayerFood(item, best, player, deficit)", source)
        food_compare_start = source.index(
            "local function PlayerFoodEfficiency"
        )
        food_compare_end = source.index(
            "local function GetFoodReserveCount",
            food_compare_start,
        )
        food_compare = source[food_compare_start:food_compare_end]
        self.assertIn("local covered = math.min(gain, math.max(0, deficit))", food_compare)
        self.assertIn(
            "return covered / math.max(1, value)",
            food_compare,
        )
        self.assertIn("local candidate_urgent = candidate_perish <= 20", food_compare)
        self.assertLess(
            food_compare.index("candidate_wasteful ~= current_wasteful"),
            food_compare.index("candidate_urgent ~= current_urgent"),
        )
        self.assertLess(
            food_compare.index("candidate_urgent ~= current_urgent"),
            food_compare.index("candidate_efficiency - current_efficiency"),
        )
        self.assertIn("home_storage", source)
        self.assertIn(
            "BufferedAction(\n"
            "            self.inst,\n"
            "            player,\n"
            "            GiveToPlayerAction(portion),",
            source,
        )
        self.assertIn("stewer:StartCooking(self.inst)", source)
        self.assertIn("stewer:Harvest(self.inst)", source)
        meal_start = source.index(
            "function CodexCompanionBrain:TryHomePlayerMeal"
        )
        meal_end = source.index(
            "function CodexCompanionBrain:RunHomeAutonomy",
            meal_start,
        )
        meal = source[meal_start:meal_end]
        self.assertLess(
            meal.index("if not stewer:CanCook() then"),
            meal.index("self:CountHomeCookingPortions(HOME_MEAT_PREFABS)"),
            "an unusable pot must be rejected before ingredients are consumed",
        )
        self.assertNotIn(
            "if not stewer:CanCook() then\n"
            "        return false\n"
            "    end\n"
            "    stewer:StartCooking(self.inst)",
            meal,
        )
        self.assertIn(
            "if not self:SeekHomeFood() then\n"
            "            self:RunHomeAutonomy(intent, emergency)",
            source,
        )

        awake = source[
            source.index("function CodexCompanionBrain:KeepTargetAwake"):
            source.index(
                "function CodexCompanionBrain:EnsureAreaInventorySpace"
            )
        ]
        self.assertIn("target:IsAsleep()", awake)
        self.assertIn("target:SetAwake(true)", awake)
        self.assertIn("BufferedAction(self.inst, target, ACTIONS.PICKUP)", awake)
        self.assertLess(
            awake.index("target.entity:SetCanSleep(false)"),
            awake.index("local action = BufferedAction"),
        )
        self.assertIn("entity.components.inventoryitem ~= nil", source)
        self.assertIn("player = {\n            guid = tostring(player.GUID)", source)
        self.assertIn("food_hunger = edible ~= nil", source)
        self.assertIn("moon_phase = TheWorld.state.moonphase", source)

    def test_home_storage_helpers_are_top_level_and_do_not_split_every_stack(
        self,
    ) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        candidate_start = source.index(
            "function CodexCompanionBrain:GetHomeStorageCandidate"
        )
        stored_start = source.index(
            "function CodexCompanionBrain:FindHomeStoredItem",
            candidate_start,
        )
        storage_start = source.index(
            "function CodexCompanionBrain:FindHomeStorage",
            stored_start,
        )
        candidate = source[candidate_start:stored_start]
        stored_item = source[stored_start:storage_start]

        self.assertIn(
            "return nil\nend\n\n"
            "function CodexCompanionBrain:GetHomeStoredItemCandidates",
            source[candidate_start:stored_start + 100],
        )
        self.assertIn(
            "local inventory = self.inst.components.inventory",
            candidate,
        )
        self.assertIn(
            "local candidates = self:GetHomeStoredItemCandidates(can_use)",
            stored_item,
        )

        store_start = source.index(
            "function CodexCompanionBrain:TryStoreOneHomeItem"
        )
        store_end = source.index(
            "function CodexCompanionBrain:FindHomeGroundStorageItem",
            store_start,
        )
        store = source[store_start:store_end]
        self.assertIn("local best_raw_item = nil", store)
        self.assertIn(
            "local best_item = self:GetHomeStorageCandidate(best_raw_item)",
            store,
        )
        self.assertNotIn(
            "self:GetHomeStorageCandidate(item)",
            store,
        )
        self.assertIn("HomeStorageCategory(item)", source)
        self.assertIn("score = score - 250", source)

    def test_home_harvest_includes_renewable_base_plants(self) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")
        renewable_start = source.index(
            "local function IsHomeRenewablePlant"
        )
        harvest_start = source.index(
            "local function IsHomeHarvestable",
            renewable_start,
        )
        harvest_end = source.index(
            "function CodexCompanionBrain:FindHomeHarvestable",
            harvest_start,
        )
        renewable = source[renewable_start:harvest_start]
        harvest = source[harvest_start:harvest_end]

        self.assertIn('entity:HasTag("grass")', renewable)
        self.assertIn('prefab == "grass"', renewable)
        self.assertIn('prefab == "grass_tall"', renewable)
        self.assertIn('prefab == "grass_moon"', renewable)
        self.assertIn('prefab == "sapling"', renewable)
        self.assertIn('prefab == "sapling_moon"', renewable)
        self.assertIn('prefab == "reeds"', renewable)
        self.assertIn('prefab == "reeds_water"', renewable)
        self.assertIn("or IsHomeRenewablePlant(entity)", harvest)
        self.assertIn("pickable:CanBePicked()", harvest)
        self.assertIn(
            "基地成熟的作物或可再生资源已经收下来了",
            source,
        )

    def test_home_chores_wait_for_tool_equip_animation(self) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertIn('return false, "tool_equipping"', source)
        self.assertIn(
            'if reason == "tool_crafting" or reason == "tool_equipping" then',
            source,
        )
        self.assertIn(
            "if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= shovel\n"
            "                or self.inst.sg:HasStateTag(\"busy\")\n"
            "            then",
            source,
        )
        self.assertIn(
            "Equipping the shovel enters an item-out animation.",
            source,
        )

    def test_missing_resource_does_not_craft_an_unused_tool(self) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")
        area_task = source.index("function CodexCompanionBrain:AreaTask(intent, mode)")
        target_check = source.index(
            "local target = self:FindAreaTarget(intent, mode)\n"
            "    if target == nil then",
            area_task,
        )
        tool_check = source.index(
            "if not self:EnsureAreaTool(intent, mode) then",
            target_check,
        )
        self.assertIn(
            "A stale resource command must fail without crafting an unused tool.",
            source[target_check:tool_check],
        )

    def test_native_emergency_layer_covers_world_hazards_locally(self) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertIn("local EMERGENCY_EVALUATE_SECONDS = 0.75", source)
        self.assertIn("local EMERGENCY_RESOLVE_GRACE_SECONDS = 6", source)
        self.assertIn("function CodexCompanionBrain:UpdateEmergency", source)
        self.assertIn("function CodexCompanionBrain:HandleEmergency", source)
        self.assertIn("function CodexCompanionBrain:CollectEmergencyThreats", source)
        self.assertIn("function CodexCompanionBrain:TryEmergencyLight", source)
        self.assertIn("function CodexCompanionBrain:EquipAcidProtection", source)
        self.assertIn("function CodexCompanionBrain:EquipThermalProtection", source)
        self.assertIn("function CodexCompanionBrain:EmergencyFightTarget", source)
        self.assertIn("TheWorld.components.hounded", source)
        self.assertIn("hounded:GetWarning()", source)
        self.assertIn("hounded:GetAttacking()", source)
        self.assertIn(
            "self.emergency_native.hound_wave_seen = false",
            source,
        )
        self.assertIn(
            "elseif not hound_warning and not hound_attacking then",
            source,
        )
        self.assertIn(
            "self.emergency_native.hound_wave_seen = true",
            source,
        )
        self.assertLess(
            source.index("local hound_count = 0"),
            source.index(
                "local hound_wave = hound_attacking",
                source.index("function CodexCompanionBrain:EvaluateEmergencyState"),
            ),
        )
        self.assertIn(
            'elseif hound_warning and not self.emergency_native.hound_wave_seen then',
            source,
        )
        self.assertIn("source_prefab = current.source_prefab", source)
        self.assertIn("source_prefab = state.source_prefab", source)
        self.assertIn("TheWorld.components.quaker", source)
        self.assertIn("quaker:IsQuaking()", source)
        self.assertIn('"warnquake"', source)
        self.assertIn('"startquake"', source)
        self.assertIn('"endquake"', source)
        self.assertIn('"nightmarephasechanged"', source)
        self.assertIn("TheWorld.state.isacidraining", source)
        self.assertIn('inventory:EquipHasTag("acidrainimmune")', source)
        self.assertIn("EMERGENCY_WAVE_ENGAGE_RADIUS", source)
        self.assertIn("EMERGENCY_NIGHTMARE_ENGAGE_RADIUS", source)
        self.assertIn(
            "function CodexCompanionBrain:TrackFrogRainDrops",
            source,
        )
        self.assertIn(
            "EMERGENCY_FROG_RAIN_MIN_DROPS = 2",
            source,
        )
        self.assertIn(
            "EMERGENCY_FROG_RAIN_VERTICAL_SEARCH_RADIUS = 40",
            source,
        )
        self.assertIn(
            "EMERGENCY_FROG_RAIN_OBSERVE_SECONDS = 0.1",
            source,
        )
        self.assertIn("self.frog_rain_task = self.inst:DoPeriodicTask(", source)
        self.assertIn("self.frog_rain_task:Cancel()", source)
        self.assertIn(
            "frog_y >= EMERGENCY_FROG_RAIN_FALL_HEIGHT",
            source,
        )
        self.assertIn("drops[guid] = now", source)
        self.assertIn(
            "frog_rain_baseline_ready = false",
            source,
        )
        self.assertIn(
            "and known[guid] ~= true",
            source,
        )
        self.assertIn(
            "EMERGENCY_FROG_RAIN_SCAN_RADIUS",
            source,
        )
        self.assertIn("horizontal_sq", source)
        self.assertIn(
            "frog_rain_drop_count >= EMERGENCY_FROG_RAIN_MIN_DROPS",
            source,
        )
        self.assertIn("and frog_rain_nearby_count >= 2", source)
        self.assertNotIn("elseif frog_count >= 2", source)
        self.assertIn('category = "frog_rain"', source)
        self.assertIn("and TheWorld.state.isspring", source)
        self.assertIn("and TheWorld.state.israining", source)
        self.assertIn('elseif category == "hostile_group" then', source)
        self.assertIn('category = "darkness"', source)
        self.assertIn('category = "earthquake"', source)
        self.assertIn('category = "nightmare_riot"', source)
        self.assertIn("GetEmergencySafetyOverride(intent)", source)
        self.assertIn('"continue_task_override"', source)
        self.assertIn("emergency_detected", source)
        self.assertIn("emergency_resolved", source)
        self.assertIn("self:BuildEmergencySnapshot()", source)
        self.assertIn("isacidraining = TheWorld.state.isacidraining == true", source)

    def test_neutral_birds_are_not_reported_as_combat_targets(self) -> None:
        source = (
            ROOT / "mod" / "scripts" / "brains" / "codex_companion_brain.lua"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "local function IsActivelyHostileToCompanion",
            source,
        )
        self.assertIn(
            "hostile = IsActivelyHostileToCompanion(inst, entity, player)",
            source,
        )
        self.assertIn(
            "return IsActivelyHostileToCompanion(companion, entity, player)",
            source,
        )

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
        self.assertIn('GLOBAL.SpawnPrefab("spawn_fx_medium_static")', modmain)
        self.assertIn("PlayCompanionSpawnEffect(companion)", modmain)
        self.assertIn("companion.components.colourtweener:StartTween", modmain)
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
