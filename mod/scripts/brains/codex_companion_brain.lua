local INTERVAL = 0.25
local NETWORK_INTERVAL = 0.5
local AREA_INTERVAL = 1.0
local AREA_RELEASE_MARGIN = 8
local ROUTE_STUCK_SECONDS = 20
local FETCH_SEARCH_SECONDS = 20
local COMBAT_SEARCH_RADIUS = 64
local COMBAT_MISSING_GRACE_SECONDS = 4
local DEFAULT_COMBAT_LEASH_DISTANCE = 30
local CAPABILITY_CACHE_SECONDS = 5
local MAX_CRAFTABLE_RECIPES = 60
local COMBAT_STUCK_SECONDS = 25
local CRAFT_ACTION_TIMEOUT_SECONDS = 10
local MAX_KNOWN_RECIPES = 1000
local RECOVERY_CHECK_SECONDS = 60
local RECOVERY_NOTICE_COOLDOWN_SECONDS = 120
local RECOVERY_TENT_SEARCH_RADIUS = 40
local RECOVERY_DANGER_RADIUS = 18
local RECOVERY_SLEEP_DANGER_RADIUS = 15
local RECOVERY_EMERGENCY_SLEEP_SECONDS = 30
local RECOVERY_MIN_SLEEP_SECONDS = 60
local RECOVERY_TRAVEL_TIMEOUT_SECONDS = 45
local RECOVERY_MIN_HEALTH_GAIN = 12
local RECOVERY_MIN_SANITY_GAIN = 8
local RECOVERY_HUNGER_RESERVE_RATIO = 0.12
local RECOVERY_HUNGER_RESERVE_MIN = 10
local EMERGENCY_EVALUATE_SECONDS = 0.75
local EMERGENCY_RESOLVE_GRACE_SECONDS = 6
local EMERGENCY_NOTICE_COOLDOWN_SECONDS = 30
local EMERGENCY_ATTACK_MEMORY_SECONDS = 8
local EMERGENCY_THREAT_RADIUS = 24
local EMERGENCY_WAVE_ENGAGE_RADIUS = 18
local EMERGENCY_NIGHTMARE_ENGAGE_RADIUS = 10
local EMERGENCY_LIGHT_SEARCH_RADIUS = 18
local EMERGENCY_MAX_THREATS = 16
local EMERGENCY_HOUND_MEMORY_SECONDS = 120
local REMOTE_TASK_MODES = {
    move_to = true,
    move_to_landmark = true,
    fetch_item = true,
    collect_loot = true,
    harvest_area = true,
    gather = true,
    operate = true,
}

local SKILL_ACTION_NAMES = {
    "CASTSPELL",
    "CAST_POCKETWATCH",
    "USEITEM",
    "USEITEMON",
    "USEEQUIPPEDITEM",
    "BLINK",
    "SUMMONGUARDIAN",
    "TOGGLEWXSHIELDING",
    "TOGGLEWXSCREECH",
    "READ",
    "MODSLINGSHOT",
    "STOPMODSLINGSHOT",
}

local function Round(value, places)
    local mult = 10 ^ (places or 2)
    return math.floor((value or 0) * mult + 0.5) / mult
end

local function InventoryHasPrefab(inst, prefab)
    local inventory = inst.components.inventory
    if inventory == nil then
        return false
    end
    for _, item in pairs(inventory.itemslots) do
        if item.prefab == prefab then
            return true
        end
    end
    return false
end

local function InventoryCount(inst, prefab)
    local inventory = inst.components.inventory
    if inventory == nil then
        return 0
    end
    local count = 0
    for _, item in pairs(inventory.itemslots) do
        if item.prefab == prefab then
            count = count + (
                item.components.stackable ~= nil
                and item.components.stackable:StackSize()
                or 1
            )
        end
    end
    for _, item in pairs(inventory.equipslots) do
        if item.prefab == prefab then
            count = count + (
                item.components.stackable ~= nil
                and item.components.stackable:StackSize()
                or 1
            )
        end
    end
    return count
end

local function FindInventoryItem(inst, prefab)
    local inventory = inst.components.inventory
    if inventory == nil then
        return nil
    end
    if inventory.FindItem ~= nil then
        return inventory:FindItem(function(item)
            return item.prefab == prefab
        end)
    end
    for _, item in pairs(inventory.itemslots) do
        if item.prefab == prefab then
            return item
        end
    end
end

local function FindInventoryTool(inst, action)
    local inventory = inst.components.inventory
    if inventory == nil then
        return nil
    end
    local best = nil
    local best_effectiveness = 0
    for _, item in pairs(inventory.itemslots) do
        local tool = item.components.tool
        if item.inherentactions ~= nil and item.inherentactions[action] then
            return item
        end
        if tool ~= nil then
            local effectiveness = tool:GetEffectiveness(action) or 0
            if effectiveness > best_effectiveness then
                best = item
                best_effectiveness = effectiveness
            end
        end
    end
    return best
end

local function GetLandmarkParams(intent)
    if type(intent.params) ~= "table" then
        return nil, nil
    end
    local name = intent.params.landmark or intent.params.location_name
    if type(name) ~= "string" or name == "" then
        return nil, nil
    end
    return name, intent.params
end

local function CanBeSeen(entity)
    return entity ~= nil
        and entity:IsValid()
        and not entity:HasTag("INLIMBO")
        and not entity:HasTag("NOCLICK")
        and not entity:HasTag("CLASSIFIED")
        and not entity:HasTag("FX")
end

local function GetPrimaryPlayer(companion)
    if ThePlayer ~= nil and ThePlayer:IsValid() then
        return ThePlayer
    end
    local known_player = TheWorld ~= nil
        and TheWorld._codex_primary_player
        or nil
    if known_player ~= nil and known_player:IsValid() then
        return known_player
    end
    if type(AllPlayers) == "table" then
        for _, player in ipairs(AllPlayers) do
            if player ~= companion
                and player:IsValid()
                and player:HasTag("player")
            then
                return player
            end
        end
    end
    return nil
end

local function IsPlayerMapPointExplored(player, x, z)
    if player == nil
        or player.player_classified == nil
        or player.player_classified.MapExplorer == nil
        or type(player.player_classified.MapExplorer.IsTileSeeable) ~= "function"
    then
        return true
    end
    local tx, ty = TheWorld.Map:GetTileXYAtPoint(x, 0, z)
    return player.player_classified.MapExplorer:IsTileSeeable(tx, ty)
end

local function DescribeEntity(inst, entity)
    local x, y, z = entity.Transform:GetWorldPosition()
    local container_items = nil
    if entity.components.container ~= nil then
        container_items = {}
        for _, item in pairs(entity.components.container.slots) do
            if item ~= nil then
                table.insert(container_items, {
                    prefab = item.prefab,
                    stacksize = item.components.stackable ~= nil
                        and item.components.stackable:StackSize()
                        or 1,
                })
            end
            if #container_items >= 12 then
                break
            end
        end
    end
    return {
        guid = tostring(entity.GUID),
        prefab = entity.prefab,
        name = entity.name,
        x = Round(x),
        z = Round(z),
        distance = Round(inst:GetDistanceSqToPoint(x, 0, z) ^ 0.5),
        health = entity.components.health ~= nil
            and Round(entity.components.health.currenthealth)
            or nil,
        hostile = entity.components.combat ~= nil
            and entity.components.combat:CanTarget(inst)
            or false,
        pickable = entity.components.pickable ~= nil,
        workable = entity.components.workable ~= nil,
        harvestable = entity:HasTag("readyforharvest"),
        inventory_item = entity.components.inventoryitem ~= nil,
        container = entity.components.container ~= nil,
        container_items = container_items,
    }
end

local function SerializeIngredients(ingredients)
    local result = {}
    for _, ingredient in ipairs(ingredients or {}) do
        table.insert(result, {
            type = ingredient.type,
            amount = ingredient.amount,
        })
    end
    return result
end

local function SerializeTechLevel(level)
    local result = {}
    for key, value in pairs(level or {}) do
        if type(value) == "number" and value > 0 then
            result[tostring(key)] = value
        end
    end
    return result
end

local CodexCompanionBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
    self.bridge_url = nil
    self.intent = nil
    self.intent_received_at = 0
    self.pending_request = false
    self.last_action_target = nil
    self.last_action_name = nil
    self.ents = {}
    self.pending_events = {}
    self.seen_messages = {}
    self.speech_queue = {}
    self.last_speech_at = 0
    self.message_cursor = os.time()
    self.area_entities = {}
    self.route = nil
    self.fetch_state = nil
    self.harvest_state = nil
    self.collect_state = nil
    self.blocked_intents = {}
    self.server_non_sleepable_ready = false
    self.active_intent_id = nil
    self.suppressed_intent_id = nil
    self.combat_target = nil
    self.combat_target_guid = nil
    self.combat_missing_since = nil
    self.combat_target_death_listener = nil
    self.last_combat_repath_at = 0
    self.combat_best_distance = nil
    self.combat_last_progress_at = nil
    self.skill_state = nil
    self.craft_state = nil
    self.build_state = nil
    self.capability_cache = nil
    self.capability_cache_at = -math.huge
    self.safety_retreat_until = 0
    self.safety_retreat_reason = nil
    self.survival_eat_started_at = nil
    self.last_map_reveal_at = 0
    self.last_map_reveal_x = nil
    self.last_map_reveal_z = nil
    self.recovery_state = nil
    self.recovery_next_check = 0
    self.recovery_notice_at = {}
    self.emergency_next_check = 0
    self.emergency_state = nil
    self.emergency_notice_at = {}
    self.emergency_attack_memory = nil
    self.emergency_player_listener_target = nil
    self.emergency_native = {
        quake_warning = false,
        quaking = false,
        quake_started_at = nil,
        hound_warning_at = nil,
        nightmare_phase = nil,
    }
    self.requested_companion_character = nil
end)

function CodexCompanionBrain:EnsureAwake()
    if not self.server_non_sleepable_ready
        and self.inst.entity.AddServerNonSleepable ~= nil
    then
        self.inst.entity:AddServerNonSleepable()
        self.server_non_sleepable_ready = true
    end
    self.inst.entity:SetCanSleep(false)
end

function CodexCompanionBrain:ShouldKeepAreaEntity(entity)
    return entity ~= nil
        and entity:IsValid()
        and entity ~= self.inst
        and CanBeSeen(entity)
        and not entity:HasTag("player")
        and not entity:HasTag("structure")
        and not entity:HasTag("irreplaceable")
        and (entity.brain ~= nil or entity.sg ~= nil)
end

function CodexCompanionBrain:KeepAreaLoaded()
    self:EnsureAwake()
    if self.inst:IsAsleep() then
        return
    end

    local radius = tonumber(self.inst._codex_area_radius) or 18
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        y,
        z,
        radius,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local seen = {}
    local activated = 0
    for _, entity in ipairs(entities) do
        if activated >= 24 then
            break
        end
        if self:ShouldKeepAreaEntity(entity) then
            local guid = tostring(entity.GUID)
            seen[guid] = true
            self.area_entities[guid] = entity
            entity.entity:SetCanSleep(false)
            activated = activated + 1
        end
    end

    -- Do not permanently make every mob in the world non-sleepable. Once an
    -- actor is clearly outside the companion's active region, let it sleep
    -- normally again.
    for guid, entity in pairs(self.area_entities) do
        if not seen[guid] then
            if entity:IsValid()
                and self.inst:GetDistanceSqToInst(entity)
                    <= (radius + AREA_RELEASE_MARGIN) ^ 2
            then
                self.area_entities[guid] = entity
            else
                if entity:IsValid() then
                    entity.entity:SetCanSleep(true)
                end
                self.area_entities[guid] = nil
            end
        end
    end
end

function CodexCompanionBrain:RevealSharedMap()
    local player = GetPrimaryPlayer(self.inst)
    if player == nil
        or not player:IsValid()
        or player.player_classified == nil
        or player.player_classified.MapExplorer == nil
        or type(player.player_classified.MapExplorer.RevealArea) ~= "function"
    then
        return
    end
    local now = GetTime()
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local moved = self.last_map_reveal_x == nil
        or math.abs(x - self.last_map_reveal_x) >= 6
        or math.abs(z - self.last_map_reveal_z) >= 6
    if not moved and now - self.last_map_reveal_at < 8 then
        return
    end
    self.last_map_reveal_at = now
    self.last_map_reveal_x = x
    self.last_map_reveal_z = z
    player.player_classified.MapExplorer:RevealArea(x, 0, z)
end

function CodexCompanionBrain:KeepTargetAwake(target)
    if target ~= nil and target:IsValid() and not target:HasTag("player") then
        target.entity:SetCanSleep(false)
    end
end

function CodexCompanionBrain:ResolveLandmark(intent)
    local name = GetLandmarkParams(intent)
    if name == nil then
        return nil
    end
    local landmarks = self.inst._codex_landmarks
    local landmark = type(landmarks) == "table" and landmarks[name] or nil
    if type(landmark) ~= "table"
        or landmark.x == nil
        or landmark.z == nil
    then
        return nil
    end
    return {
        name = name,
        x = tonumber(landmark.x),
        z = tonumber(landmark.z),
        shard = landmark.shard,
    }
end

function CodexCompanionBrain:RememberLocation(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local name = params.name or params.landmark
    if type(name) ~= "string" or name == "" then
        self:QueueEvent("task_failed", {
            intent_id = intent.intent_id,
            mode = "remember_location",
            reason = "landmark_name_missing",
        })
        self:SuppressIntent(intent)
        return
    end
    local player = GetPrimaryPlayer(self.inst)
    if player == nil or not player:IsValid() then
        self:QueueEvent("task_failed", {
            intent_id = intent.intent_id,
            mode = "remember_location",
            reason = "player_missing",
        })
        self:SuppressIntent(intent)
        return
    end

    local x, y, z = player.Transform:GetWorldPosition()
    self.inst._codex_landmarks = self.inst._codex_landmarks or {}
    self.inst._codex_landmarks[name] = {
        name = name,
        shard = TheShard:GetShardId(),
        x = Round(x),
        z = Round(z),
        saved_at = GetTime(),
    }
    if self.inst._codex_save_state ~= nil then
        self.inst._codex_save_state()
    end
    self:QueueEvent("task_complete", {
        intent_id = intent.intent_id,
        mode = "remember_location",
        landmark = name,
        position = { Round(x), Round(z) },
        shard = TheShard:GetShardId(),
        verified = true,
    })
    self:SuppressIntent(intent)
end

function CodexCompanionBrain:ReleaseArea()
    for _, entity in pairs(self.area_entities) do
        if entity:IsValid() then
            entity.entity:SetCanSleep(true)
        end
    end
    self.area_entities = {}
end

function CodexCompanionBrain:GetAvailableSkillActions()
    local actions = {}
    for _, name in ipairs(SKILL_ACTION_NAMES) do
        if ACTIONS[name] ~= nil then
            table.insert(actions, name)
        end
    end
    return actions
end

function CodexCompanionBrain:GetCapabilities()
    local now = GetTime()
    if self.capability_cache ~= nil
        and now - self.capability_cache_at < CAPABILITY_CACHE_SECONDS
    then
        return self.capability_cache
    end

    local skills = {}
    local updater = self.inst.components.skilltreeupdater
    if updater ~= nil then
        for skill, active in pairs(updater:GetActivatedSkills() or {}) do
            if active then
                table.insert(skills, skill)
            end
        end
        table.sort(skills)
    end

    local craftable_recipes = {}
    local known_recipes = {}
    local builder = self.inst.components.builder
    if builder ~= nil then
        local recipe_names = {}
        for recipe_name in pairs(AllRecipes) do
            table.insert(recipe_names, recipe_name)
        end
        table.sort(recipe_names)
        for _, recipe_name in ipairs(recipe_names) do
            local recipe = AllRecipes[recipe_name]
            if recipe ~= nil then
                local known = builder:KnowsRecipe(recipe)
                local available = known and builder:HasIngredients(recipe)
                local recipe_data = {
                    name = recipe_name,
                    product = recipe.product,
                    placer = recipe.placer,
                    known = known,
                    available = available,
                    ingredients = SerializeIngredients(recipe.ingredients),
                    character_ingredients = SerializeIngredients(
                        recipe.character_ingredients
                    ),
                    tech_ingredients = SerializeIngredients(
                        recipe.tech_ingredients
                    ),
                    tech = SerializeTechLevel(recipe.level),
                    builder_tag = recipe.builder_tag,
                    builder_skill = recipe.builder_skill,
                    numtogive = recipe.numtogive,
                }
                table.insert(known_recipes, recipe_data)
                if available then
                    if #craftable_recipes < MAX_CRAFTABLE_RECIPES then
                        table.insert(craftable_recipes, recipe_data)
                    end
                end
            end
            if #known_recipes >= MAX_KNOWN_RECIPES then
                break
            end
        end
    end

    self.capability_cache = {
        skills = skills,
        skill_actions = self:GetAvailableSkillActions(),
        craftable_recipes = craftable_recipes,
        known_recipes = known_recipes,
    }
    self.capability_cache_at = now
    return self.capability_cache
end

function CodexCompanionBrain:BuildSnapshot(events)
    self.ents = {}
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        y,
        z,
        22,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local nearby = {}
    for _, entity in ipairs(entities) do
        if entity ~= self.inst and CanBeSeen(entity) then
            self.ents[tostring(entity.GUID)] = entity
            table.insert(nearby, DescribeEntity(self.inst, entity))
        end
    end
    table.sort(nearby, function(a, b)
        return (a.distance or 9999) < (b.distance or 9999)
    end)
    while #nearby > 40 do
        table.remove(nearby)
    end

    local inventory = {}
    local inventory_counts = {}
    if self.inst.components.inventory ~= nil then
        for _, item in pairs(self.inst.components.inventory.itemslots) do
            local stacksize = item.components.stackable ~= nil
                and item.components.stackable:StackSize()
                or 1
            inventory_counts[item.prefab] =
                (inventory_counts[item.prefab] or 0) + stacksize
            table.insert(inventory, {
                guid = tostring(item.GUID),
                prefab = item.prefab,
                edible = item.components.edible ~= nil,
                equippable = item.components.equippable ~= nil,
                stacksize = stacksize,
            })
        end
    end
    local equipped = {}
    if self.inst.components.inventory ~= nil then
        for slot, item in pairs(self.inst.components.inventory.equipslots) do
            local stacksize = item.components.stackable ~= nil
                and item.components.stackable:StackSize()
                or 1
            inventory_counts[item.prefab] =
                (inventory_counts[item.prefab] or 0) + stacksize
            table.insert(equipped, {
                slot = slot,
                guid = tostring(item.GUID),
                prefab = item.prefab,
                stacksize = stacksize,
            })
        end
    end

    local player = GetPrimaryPlayer(self.inst)
    local px, _, pz = player.Transform:GetWorldPosition()
    local capabilities = self:GetCapabilities()
    local explored_tiles = nil
    if player.player_classified ~= nil
        and player.player_classified.MapExplorer ~= nil
        and type(player.player_classified.MapExplorer.GetSeeableTileCount)
            == "function"
    then
        explored_tiles =
            player.player_classified.MapExplorer:GetSeeableTileCount()
    end
    return {
        companion = {
            guid = tostring(self.inst.GUID),
            identity_id = self.inst._codex_companion_identity,
            prefab = self.inst.prefab,
            x = Round(x),
            z = Round(z),
            health = self.inst.components.health ~= nil
                and Round(self.inst.components.health.currenthealth)
                or 0,
            max_health = self.inst.components.health ~= nil
                and Round(self.inst.components.health.maxhealth)
                or 0,
            hunger = self.inst.components.hunger ~= nil
                and Round(self.inst.components.hunger.current)
                or 0,
            max_hunger = self.inst.components.hunger ~= nil
                and Round(self.inst.components.hunger.max)
                or 0,
            sanity = self.inst.components.sanity ~= nil
                and Round(self.inst.components.sanity.current)
                or 0,
            max_sanity = self.inst.components.sanity ~= nil
                and Round(self.inst.components.sanity.max)
                or 0,
            freezing = self.inst:IsFreezing(),
            overheating = self.inst:IsOverheating(),
            in_light = self.inst.LightWatcher:IsInLight(),
            busy = self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy") or false,
            awake = not self.inst:IsAsleep(),
            safety_retreating = self.safety_retreat_until > GetTime(),
            safety_retreat_reason = self.safety_retreat_reason,
            sheltered = self.inst.components.sheltered ~= nil
                and self.inst.components.sheltered.sheltered
                or false,
            rain_immune = self.inst.components.rainimmunity ~= nil,
            emergency = self:BuildEmergencySnapshot(),
            area_radius = tonumber(self.inst._codex_area_radius) or 18,
            route = self.route ~= nil and {
                intent_id = self.route.intent_id,
                stage = self.route.stage,
                distance = self.route.distance,
                best_distance = self.route.best_distance,
                elapsed = Round(GetTime() - self.route.started_at),
            } or nil,
            loot_collection = self.collect_state ~= nil and {
                intent_id = self.collect_state.intent_id,
                stage = self.collect_state.stage,
                desired_amount = self.collect_state.amount,
                kills = self.collect_state.kills,
                elapsed = Round(GetTime() - self.collect_state.started_at),
            } or nil,
            combat_target = self.combat_target ~= nil
                and self.combat_target:IsValid()
                and {
                    guid = tostring(self.combat_target.GUID),
                    prefab = self.combat_target.prefab,
                    health = self.combat_target.components.health ~= nil
                        and Round(self.combat_target.components.health.currenthealth)
                        or nil,
                    distance = Round(
                        self.inst:GetDistanceSqToInst(self.combat_target) ^ 0.5
                    ),
                    missing_for = self.combat_missing_since ~= nil
                        and Round(GetTime() - self.combat_missing_since, 1)
                        or nil,
                }
                or nil,
        },
        player = {
            guid = tostring(player.GUID),
            prefab = player.prefab,
            x = Round(px),
            z = Round(pz),
            distance = Round(self.inst:GetDistanceSqToPoint(px, 0, pz) ^ 0.5),
        },
        world = {
            shard = TheShard:GetShardId(),
            is_master = not TheShard:IsSecondary(),
            day = TheWorld.state.cycles,
            phase = TheWorld.state.phase,
            season = TheWorld.state.season,
            raining = TheWorld.state.israining,
            snowing = TheWorld.state.issnowing,
            isacidraining = TheWorld.state.isacidraining == true,
            quake_warning = self.emergency_native.quake_warning,
            quaking = self.emergency_native.quaking,
            hound_warning = self.emergency_native.hound_warning_at ~= nil
                and GetTime() - self.emergency_native.hound_warning_at
                    <= EMERGENCY_HOUND_MEMORY_SECONDS
                or false,
            nightmare_phase = self.emergency_native.nightmare_phase,
            player_map_explored_tiles = explored_tiles,
        },
        inventory = inventory,
        inventory_counts = inventory_counts,
        equipped = equipped,
        landmarks = self.inst._codex_landmarks or {},
        capabilities = capabilities,
        nearby = nearby,
        events = events or {},
    }
end

function CodexCompanionBrain:OnBridgeResponse(result, success, http_code, sent_events)
    self.pending_request = false
    if not success or result == nil or result == "" then
        for _, event in ipairs(sent_events or {}) do
            table.insert(self.pending_events, event)
        end
        return
    end
    local state = json.decode(result)
    local selected_character = type(state) == "table"
        and state.companion_character
        or nil
    if type(selected_character) == "string"
        and selected_character ~= ""
        and selected_character ~= self.requested_companion_character
    then
        self.requested_companion_character = selected_character
        local inst = self.inst
        inst:DoTaskInTime(0, function()
            if inst:IsValid()
                and type(TheWorld._codex_switch_companion_character)
                    == "function"
            then
                TheWorld._codex_switch_companion_character(
                    selected_character
                )
            end
        end)
    end
    if type(state) == "table" and type(state.intent) == "table" then
        if tostring(state.intent.intent_id) == tostring(self.suppressed_intent_id) then
            self.intent = nil
        else
            self.suppressed_intent_id = nil
            self.intent = state.intent
            self.intent_received_at = GetTime()
        end
        for _, message in ipairs(state.messages or {}) do
            local message_id = message.id ~= nil and tostring(message.id) or nil
            local created_at = tonumber(message.created_at) or 0
            if message_id ~= nil
                and not self.seen_messages[message_id]
                and created_at >= self.message_cursor
                and type(message.text) == "string"
            then
                self.seen_messages[message_id] = true
                table.insert(self.speech_queue, message.text)
            end
        end
    end
end

function CodexCompanionBrain:QueueEvent(event_type, payload)
    local event = payload or {}
    event.type = event_type
    event.event_id = table.concat({
        tostring(self.inst.GUID),
        tostring(math.floor(GetTime() * 1000)),
        tostring(math.random(1000, 9999)),
    }, ":")
    table.insert(self.pending_events, event)
end

function CodexCompanionBrain:SuppressIntent(intent)
    if intent ~= nil then
        self.suppressed_intent_id = tostring(intent.intent_id)
    end
    self.intent = nil
    self:StopAll()
end

function CodexCompanionBrain:NetworkTick()
    if self.inst:IsAsleep() then
        self:EnsureAwake()
    end
    -- Keep polling during tent sleep so a new chat instruction can wake the
    -- companion immediately instead of waiting for daybreak.
    if self.pending_request then
        return
    end
    self.pending_request = true
    local sent_events = self.pending_events
    self.pending_events = {}
    TheSim:QueryServer(
        self.bridge_url,
        function(result, success, http_code)
            self:OnBridgeResponse(result, success, http_code, sent_events)
        end,
        "POST",
        json.encode(self:BuildSnapshot(sent_events))
    )
end

function CodexCompanionBrain:GetActiveIntent()
    if self.intent == nil then
        return nil
    end
    local target_shard = type(self.intent.params) == "table"
        and self.intent.params.target_shard
        or nil
    if target_shard == nil then
        local landmark = self:ResolveLandmark(self.intent)
        target_shard = landmark ~= nil and landmark.shard or nil
    end
    if target_shard ~= nil and target_shard ~= TheShard:GetShardId() then
        local blocked_key = tostring(self.intent.intent_id) .. ":" .. tostring(target_shard)
        if not self.blocked_intents[blocked_key] then
            self.blocked_intents[blocked_key] = true
            self:QueueEvent("task_blocked", {
                intent_id = self.intent.intent_id,
                reason = "target_shard_not_active",
                current_shard = TheShard:GetShardId(),
                target_shard = target_shard,
            })
        end
        self.suppressed_intent_id = tostring(self.intent.intent_id)
        self.intent = nil
        self:StopAll()
        return nil
    end
    local lease = tonumber(self.intent.lease_seconds) or 5
    if GetTime() - self.intent_received_at > lease then
        return nil
    end
    if self.active_intent_id ~= self.intent.intent_id then
        self:StopAll()
        self.active_intent_id = self.intent.intent_id
        self.route = nil
        self.fetch_state = nil
        self.harvest_state = nil
        self.collect_state = nil
        self.skill_state = nil
        self.craft_state = nil
        self.build_state = nil
        self.combat_started_at = nil
        self.last_combat_event_at = nil
        self:ClearCombatTarget()
        self.combat_missing_since = nil
        self.last_combat_repath_at = 0
        self.combat_best_distance = nil
        self.combat_last_progress_at = nil
        if self.intent.mode ~= "hold" then
            self:QueueEvent("task_started", {
                intent_id = self.intent.intent_id,
                mode = self.intent.mode,
                target_guid = self.intent.target_guid,
                target_prefab = self.intent.target_prefab,
                position = self.intent.position,
                shard = TheShard:GetShardId(),
            })
        end
    end
    return self.intent
end

function CodexCompanionBrain:StopAll()
    if self.inst.components.locomotor ~= nil then
        self.inst.components.locomotor:Stop()
    end
    if self.inst.components.combat ~= nil then
        self.inst.components.combat:SetTarget(nil)
    end
    self.inst:ClearBufferedAction()
    self.route = nil
    self.last_action_target = nil
    self.last_action_name = nil
    self:ClearCombatTarget()
    self.combat_missing_since = nil
end

function CodexCompanionBrain:ClearCombatTarget()
    if self.combat_target ~= nil
        and self.combat_target_death_listener ~= nil
    then
        self.inst:RemoveEventCallback(
            "death",
            self.combat_target_death_listener,
            self.combat_target
        )
    end
    self.combat_target = nil
    self.combat_target_guid = nil
    self.combat_target_death_listener = nil
end

function CodexCompanionBrain:IsCombatTargetValid(target, intent)
    if target == nil
        or not target:IsValid()
        or target == self.inst
        or not CanBeSeen(target)
    then
        return false
    end
    if target.components.health ~= nil
        and target.components.health:IsDead()
    then
        return false
    end
    if intent.target_prefab ~= nil
        and target.prefab ~= intent.target_prefab
    then
        return false
    end
    if intent.target_guid ~= nil
        and intent.target_prefab == nil
        and tostring(target.GUID) ~= tostring(intent.target_guid)
    then
        return false
    end
    local combat = self.inst.components.combat
    return combat ~= nil and combat:IsValidTarget(target)
end

function CodexCompanionBrain:OnCombatTargetDeath(target, data)
    if self.combat_target ~= target then
        return
    end
    local intent = self.intent
    if intent == nil
        or intent.mode ~= "combat"
        or (intent.target_prefab == nil
            and intent.target_guid ~= nil
            and tostring(intent.target_guid) ~= tostring(target.GUID))
        or (intent.target_prefab ~= nil
            and target.prefab ~= intent.target_prefab)
    then
        return
    end

    local credited = data ~= nil and data.afflicter == self.inst
    self:QueueEvent("combat_target_defeated", {
        intent_id = intent.intent_id,
        target_guid = tostring(target.GUID),
        target_prefab = target.prefab,
        verified = credited,
        credited = credited,
        afflicter = data ~= nil
            and data.afflicter ~= nil
            and data.afflicter.prefab
            or nil,
    })
    self:SuppressIntent(intent)
end

function CodexCompanionBrain:BindCombatTarget(target)
    if target == self.combat_target then
        return target
    end
    self:ClearCombatTarget()
    self.combat_target = target
    self.combat_target_guid = tostring(target.GUID)
    self.combat_missing_since = nil
    self.combat_target_death_listener = function(_, data)
        self:OnCombatTargetDeath(target, data)
    end
    self.inst:ListenForEvent(
        "death",
        self.combat_target_death_listener,
        target
    )
    self:KeepTargetAwake(target)
    return target
end

function CodexCompanionBrain:FindCombatTarget(intent)
    if self:IsCombatTargetValid(self.combat_target, intent) then
        return self.combat_target
    end

    local target = nil
    if intent.target_guid ~= nil then
        local wanted_guid = tostring(intent.target_guid)
        target = self.ents[wanted_guid]
        if not self:IsCombatTargetValid(target, intent) then
            local combat = self.inst.components.combat
            target = FindEntity(
                self.inst,
                COMBAT_SEARCH_RADIUS,
                function(entity)
                    return tostring(entity.GUID) == wanted_guid
                        and combat ~= nil
                        and combat:IsValidTarget(entity)
                end,
                nil,
                { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
            )
        end
    end

    -- A task such as "attack the nearest bird" may continue on another target
    -- of the same prefab if the original flew away or died.
    if not self:IsCombatTargetValid(target, intent)
        and intent.target_prefab ~= nil
    then
        local combat = self.inst.components.combat
        target = FindEntity(
            self.inst,
            COMBAT_SEARCH_RADIUS,
            function(entity)
                return entity.prefab == intent.target_prefab
                    and combat ~= nil
                    and combat:IsValidTarget(entity)
            end,
            nil,
            { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
        )
    end

    if self:IsCombatTargetValid(target, intent) then
        return self:BindCombatTarget(target)
    end
    return nil
end

function CodexCompanionBrain:FindTarget(intent)
    if intent.mode == "combat" or intent.mode == "guard" then
        return self:FindCombatTarget(intent)
    end

    local target = nil
    if intent.target_guid ~= nil then
        target = self.ents[tostring(intent.target_guid)]
    end
    if target == nil and intent.target_prefab ~= nil then
        target = FindEntity(
            self.inst,
            COMBAT_SEARCH_RADIUS,
            function(entity)
                return entity.prefab == intent.target_prefab and CanBeSeen(entity)
            end,
            nil,
            { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
        )
    end
    self:KeepTargetAwake(target)
    return target
end

function CodexCompanionBrain:FindActionTarget(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    if params.on_self then
        return self.inst
    end

    local target = nil
    if intent.target_guid ~= nil then
        target = self.ents[tostring(intent.target_guid)]
    end
    if target == nil and intent.target_prefab ~= nil then
        target = FindEntity(
            self.inst,
            tonumber(params.search_radius) or 32,
            function(entity)
                return entity.prefab == intent.target_prefab and CanBeSeen(entity)
            end,
            nil,
            { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
        )
    end
    return target
end

function CodexCompanionBrain:GetActionItem(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local prefab = params.item_prefab or params.invobject_prefab
    if type(prefab) ~= "string" then
        return nil
    end
    return FindInventoryItem(self.inst, prefab)
end

function CodexCompanionBrain:GetActionPosition(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local position = intent.position or params.position
    if position == nil then
        return nil
    end
    return Vector3(tonumber(position[1]) or 0, 0, tonumber(position[2]) or 0)
end

function CodexCompanionBrain:FailAction(intent, reason, extra)
    local payload = {
        intent_id = intent.intent_id,
        mode = intent.mode,
        reason = reason,
    }
    if type(extra) == "table" then
        for key, value in pairs(extra) do
            payload[key] = value
        end
    end
    self:QueueEvent("task_failed", payload)
    self:SuppressIntent(intent)
end

function CodexCompanionBrain:QueueIntentAction(
    intent,
    action,
    target,
    invobject,
    position,
    event_kind,
    extra
)
    if action == nil then
        self:FailAction(intent, "action_missing")
        return false
    end
    if self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy") then
        return false
    end
    if self.inst:GetBufferedAction() ~= nil then
        return true
    end

    self.inst:ClearBufferedAction()
    local buffered_action = BufferedAction(
        self.inst,
        target,
        action,
        invobject,
        position
    )
    buffered_action:AddSuccessAction(function()
        if self.intent == nil
            or tostring(self.intent.intent_id) ~= tostring(intent.intent_id)
        then
            return
        end
        local payload = {
            intent_id = intent.intent_id,
            mode = intent.mode,
            action = action.id,
            target_prefab = target ~= nil and target.prefab or nil,
            item_prefab = invobject ~= nil and invobject.prefab or nil,
            position = intent.position,
            verified = true,
        }
        if type(extra) == "table" then
            for key, value in pairs(extra) do
                payload[key] = value
            end
        end
        self:QueueEvent(event_kind or "task_complete", payload)
        self:SuppressIntent(intent)
    end)
    buffered_action:AddFailAction(function()
        if self.intent ~= nil
            and tostring(self.intent.intent_id) == tostring(intent.intent_id)
        then
            self:FailAction(intent, "action_failed", {
                action = action.id,
            })
        end
    end)
    self.inst.components.locomotor:PushAction(buffered_action, true)
    return true
end

function CodexCompanionBrain:UseSkill(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local action_name = params.action
    if type(action_name) ~= "string" then
        self:FailAction(intent, "skill_action_missing")
        return
    end

    local allowed = false
    for _, name in ipairs(SKILL_ACTION_NAMES) do
        if name == action_name then
            allowed = true
            break
        end
    end
    if not allowed or ACTIONS[action_name] == nil then
        self:FailAction(intent, "skill_action_not_supported")
        return
    end

    local item = self:GetActionItem(intent)
    if (params.item_prefab or params.invobject_prefab) and item == nil then
        self:FailAction(intent, "skill_item_not_found")
        return
    end
    local target = self:FindActionTarget(intent)
    if (intent.target_guid or intent.target_prefab)
        and not params.on_self
        and target == nil
    then
        self:FailAction(intent, "skill_target_not_found")
        return
    end

    self:QueueIntentAction(
        intent,
        ACTIONS[action_name],
        target,
        item,
        self:GetActionPosition(intent),
        "task_complete"
    )
end

function CodexCompanionBrain:GetRecipe(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local recipe_name = params.recipe
        or params.recipe_name
        or intent.target_prefab
    if type(recipe_name) ~= "string" then
        return nil
    end
    return AllRecipes[recipe_name], recipe_name
end

function CodexCompanionBrain:CraftItem(intent)
    local recipe, recipe_name = self:GetRecipe(intent)
    local builder = self.inst.components.builder
    if recipe == nil then
        self:FailAction(intent, "recipe_not_found")
        return
    end
    if builder == nil then
        self:FailAction(intent, "builder_missing")
        return
    end
    if self.craft_state ~= nil
        and tostring(self.craft_state.intent_id) == tostring(intent.intent_id)
    then
        if GetTime() - (self.craft_state.started_at or GetTime())
            > CRAFT_ACTION_TIMEOUT_SECONDS
        then
            self.craft_state = nil
            self:FailAction(intent, "craft_timeout")
        end
        return
    end
    if self.craft_state ~= nil
        and tostring(self.craft_state.intent_id) ~= tostring(intent.intent_id)
    then
        self.craft_state = nil
    end
    if not builder:KnowsRecipe(recipe) then
        self:FailAction(intent, "recipe_not_known")
        return
    end
    if not builder:HasIngredients(recipe) then
        self:FailAction(intent, "ingredients_missing")
        return
    end

    self.craft_state = {
        intent_id = intent.intent_id,
        started_at = GetTime(),
    }
    local started = builder:MakeRecipe(
        recipe,
        self.inst:GetPosition(),
        nil,
        nil,
        function()
            if self.craft_state ~= nil
                and tostring(self.craft_state.intent_id)
                    == tostring(intent.intent_id)
            then
                self.craft_state = nil
            end
            if self.intent ~= nil
                and tostring(self.intent.intent_id) == tostring(intent.intent_id)
            then
                self.capability_cache_at = -math.huge
                self:QueueEvent("task_complete", {
                    intent_id = intent.intent_id,
                    mode = "craft",
                    recipe = recipe_name,
                    item_prefab = recipe.product,
                    verified = true,
                })
                self:SuppressIntent(intent)
            end
        end
    )
    if not started then
        self.craft_state = nil
        self:FailAction(intent, "craft_start_failed")
    end
end

function CodexCompanionBrain:DeployItem(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local item = self:GetActionItem(intent)
    if item == nil and intent.target_prefab ~= nil then
        item = FindInventoryItem(self.inst, intent.target_prefab)
    end
    if item == nil then
        self:FailAction(intent, "deploy_item_not_found")
        return
    end
    local deployable = item.components.deployable
    if deployable == nil then
        self:FailAction(intent, "item_not_deployable")
        return
    end
    local position = self:GetActionPosition(intent)
    if position == nil then
        self:FailAction(intent, "deploy_position_missing")
        return
    end
    local can_deploy, reason = deployable:CanDeploy(
        position,
        nil,
        self.inst,
        params.rotation
    )
    if not can_deploy then
        self:FailAction(intent, reason or "deploy_invalid_position")
        return
    end
    self:QueueIntentAction(
        intent,
        ACTIONS.DEPLOY,
        nil,
        item,
        position,
        "task_complete"
    )
end

function CodexCompanionBrain:BuildAt(intent)
    local recipe, recipe_name = self:GetRecipe(intent)
    local builder = self.inst.components.builder
    if recipe == nil then
        self:FailAction(intent, "recipe_not_found")
        return
    end
    if builder == nil then
        self:FailAction(intent, "builder_missing")
        return
    end
    if self.build_state ~= nil
        and tostring(self.build_state.intent_id) == tostring(intent.intent_id)
        and self.build_state.stage == "crafting"
    then
        if GetTime() - (self.build_state.started_at or GetTime())
            > CRAFT_ACTION_TIMEOUT_SECONDS
        then
            self.build_state = nil
            self:FailAction(intent, "build_craft_timeout")
        end
        return
    end
    if self.build_state ~= nil
        and tostring(self.build_state.intent_id) ~= tostring(intent.intent_id)
    then
        self.build_state = nil
    end
    if not builder:KnowsRecipe(recipe) then
        self:FailAction(intent, "recipe_not_known")
        return
    end

    local position = self:GetActionPosition(intent)
        or self.inst:GetPosition()
    if recipe.placer == nil then
        if not builder:HasIngredients(recipe) then
            self:FailAction(intent, "ingredients_missing")
            return
        end
        self.build_state = {
            intent_id = intent.intent_id,
            stage = "crafting",
            started_at = GetTime(),
        }
        local started = builder:MakeRecipe(
            recipe,
            position,
            nil,
            nil,
            function()
                if self.build_state ~= nil
                    and tostring(self.build_state.intent_id)
                        == tostring(intent.intent_id)
                then
                    self.build_state = nil
                end
                if self.intent ~= nil
                    and tostring(self.intent.intent_id) == tostring(intent.intent_id)
                then
                    self.capability_cache_at = -math.huge
                    self:QueueEvent("task_complete", {
                        intent_id = intent.intent_id,
                        mode = "build",
                        recipe = recipe_name,
                        item_prefab = recipe.product,
                        position = intent.position,
                        verified = true,
                    })
                    self:SuppressIntent(intent)
                end
            end
        )
        if not started then
            self.build_state = nil
            self:FailAction(intent, "build_start_failed")
        end
        return
    end

    local item = FindInventoryItem(self.inst, recipe.product)
    if item == nil then
        if self.build_state ~= nil and self.build_state.crafted then
            self:FailAction(intent, "crafted_placer_missing")
            return
        end
        if not builder:HasIngredients(recipe) then
            self:FailAction(intent, "ingredients_missing")
            return
        end
        self.build_state = {
            intent_id = intent.intent_id,
            stage = "crafting",
            started_at = GetTime(),
            crafted = false,
        }
        local started = builder:MakeRecipe(
            recipe,
            self.inst:GetPosition(),
            nil,
            nil,
            function()
                if self.build_state ~= nil
                    and tostring(self.build_state.intent_id)
                        == tostring(intent.intent_id)
                then
                    self.build_state.stage = "crafted"
                    self.build_state.crafted = true
                end
            end
        )
        if not started then
            self.build_state = nil
            self:FailAction(intent, "build_craft_start_failed")
        end
        return
    end

    local deployable = item.components.deployable
    local can_deploy = false
    local reason = nil
    if deployable ~= nil then
        can_deploy, reason = deployable:CanDeploy(
            position,
            nil,
            self.inst,
            type(intent.params) == "table" and intent.params.rotation or nil
        )
    end
    if not can_deploy then
        self:FailAction(intent, reason or "deploy_invalid_position")
        return
    end
    self:QueueIntentAction(
        intent,
        ACTIONS.DEPLOY,
        nil,
        item,
        position,
        "task_complete",
        { recipe = recipe_name }
    )
end

function CodexCompanionBrain:TillGround(intent)
    local position = self:GetActionPosition(intent)
    if position == nil then
        self:FailAction(intent, "till_position_missing")
        return
    end
    local tool = FindInventoryTool(self.inst, ACTIONS.TILL)
    if tool == nil then
        self:FailAction(intent, "till_tool_not_found")
        return
    end
    self:QueueIntentAction(
        intent,
        ACTIONS.TILL,
        nil,
        tool,
        position,
        "task_complete"
    )
end

function CodexCompanionBrain:EquipItem(intent)
    local item = self:GetActionItem(intent)
    if item == nil and intent.target_prefab ~= nil then
        item = FindInventoryItem(self.inst, intent.target_prefab)
    end
    if item == nil then
        self:FailAction(intent, "equip_item_not_found")
        return
    end
    local equippable = item.components.equippable
    if equippable == nil then
        self:FailAction(intent, "item_not_equippable")
        return
    end
    self.inst.components.inventory:Equip(item)
    if self.inst.components.inventory:GetEquippedItem(equippable.equipslot) == item then
        self:QueueEvent("task_complete", {
            intent_id = intent.intent_id,
            mode = "equip",
            item_prefab = item.prefab,
            slot = equippable.equipslot,
            verified = true,
        })
        self:SuppressIntent(intent)
    else
        self:FailAction(intent, "equip_failed")
    end
end

function CodexCompanionBrain:UnequipItem(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local inventory = self.inst.components.inventory
    local slot = params.slot
    local item = nil
    if intent.target_prefab ~= nil then
        for _, equipped in pairs(inventory.equipslots) do
            if equipped.prefab == intent.target_prefab then
                item = equipped
                break
            end
        end
    elseif slot ~= nil then
        item = inventory:GetEquippedItem(slot)
    end
    if item == nil then
        self:FailAction(intent, "equipped_item_not_found")
        return
    end
    slot = item.components.equippable.equipslot
    inventory:Unequip(slot)
    if inventory:GetEquippedItem(slot) == nil then
        self:QueueEvent("task_complete", {
            intent_id = intent.intent_id,
            mode = "unequip",
            item_prefab = item.prefab,
            slot = slot,
            verified = true,
        })
        self:SuppressIntent(intent)
    else
        self:FailAction(intent, "unequip_failed")
    end
end

function CodexCompanionBrain:MoveDirect(x, z)
    local locomotor = self.inst.components.locomotor
    if locomotor ~= nil and not locomotor:HasDestination() then
        locomotor:GoToPoint(Vector3(x, 0, z), nil, 2)
    end
end

function CodexCompanionBrain:FailRoute(intent, reason)
    self:QueueEvent("task_failed", {
        intent_id = intent.intent_id,
        mode = intent.mode,
        reason = reason,
        position = intent.position,
    })
    self:SuppressIntent(intent)
end

function CodexCompanionBrain:NavigateTo(intent, x, z, stop_distance, stage)
    local locomotor = self.inst.components.locomotor
    if locomotor == nil then
        self:FailRoute(intent, "locomotor_missing")
        return false
    end

    local cx, _, cz = self.inst.Transform:GetWorldPosition()
    local dx = x - cx
    local dz = z - cz
    local distance = math.sqrt(dx * dx + dz * dz)
    stop_distance = tonumber(stop_distance) or 2
    if distance <= stop_distance then
        self.route = nil
        return true
    end

    local now = GetTime()
    stage = stage or "move"
    if self.route == nil
        or self.route.intent_id ~= intent.intent_id
        or self.route.stage ~= stage
        or math.abs((self.route.target_x or x) - x) > 0.5
        or math.abs((self.route.target_z or z) - z) > 0.5
    then
        self.route = {
            intent_id = intent.intent_id,
            stage = stage,
            target_x = x,
            target_z = z,
            distance = Round(distance),
            best_distance = distance,
            last_progress_at = now,
            last_event_at = now,
            started_at = now,
        }
    end

    self.route.distance = Round(distance)
    if distance < self.route.best_distance - 1 then
        self.route.best_distance = distance
        self.route.last_progress_at = now
    end

    local params = type(intent.params) == "table" and intent.params or {}
    if now - (self.route.last_event_at or self.route.started_at) >= 20 then
        self.route.last_event_at = now
        self:QueueEvent("task_progress", {
            intent_id = intent.intent_id,
            mode = intent.mode,
            stage = stage,
            distance = Round(distance),
            best_distance = Round(self.route.best_distance),
            elapsed = Round(now - self.route.started_at),
            position = intent.position or { Round(x), Round(z) },
            shard = TheShard:GetShardId(),
        })
    end
    local stuck_seconds = tonumber(params.stuck_seconds) or ROUTE_STUCK_SECONDS
    if params.fail_on_stuck ~= false
        and now - self.route.last_progress_at > stuck_seconds
        and not locomotor:HasDestination()
    then
        self:FailRoute(intent, "path_stuck")
        return false
    end

    if not locomotor:HasDestination() then
        locomotor:GoToPoint(Vector3(x, 0, z), nil, params.run ~= false)
    end
    return false
end

function CodexCompanionBrain:Follow()
    local player = GetPrimaryPlayer(self.inst)
    if player == nil or not player:IsValid() then
        self:StopAll()
        return
    end
    local locomotor = self.inst.components.locomotor
    if locomotor == nil then
        self:FailRoute({ intent_id = self.intent and self.intent.intent_id }, "locomotor_missing")
        return
    end
    if self.inst:GetDistanceSqToInst(player) > 16
        and not locomotor:HasDestination()
    then
        locomotor:GoToEntity(player, nil, 2)
    end
end

function CodexCompanionBrain:FindBestEquipment(target)
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return nil, nil
    end

    local best_weapon = nil
    local best_weapon_score = -math.huge
    local best_armor = nil
    local best_armor_score = -math.huge
    for _, item in pairs(inventory.itemslots) do
        local weapon = item.components.weapon
        if weapon ~= nil then
            local damage = weapon:GetDamage(self.inst, target)
            if type(damage) == "number" and damage > best_weapon_score then
                best_weapon = item
                best_weapon_score = damage
            end
        end
        local armor = item.components.armor
        if armor ~= nil then
            local condition_percent = armor.maxcondition ~= nil
                and armor.maxcondition > 0
                and (armor.condition or armor.maxcondition) / armor.maxcondition
                or 1
            local score = (armor.absorb_percent or 0) * condition_percent
            if score > best_armor_score then
                best_armor = item
                best_armor_score = score
            end
        end
    end
    return best_weapon, best_armor
end

local function EstimateIncomingDamage(attacker, target)
    if attacker == nil
        or target == nil
        or not attacker:IsValid()
        or not target:IsValid()
        or attacker.components.combat == nil
    then
        return nil
    end
    local weapon = nil
    if attacker.components.inventory ~= nil then
        weapon = attacker.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    end
    local damage = attacker.components.combat:CalcDamage(target, weapon, 1)
    if type(damage) ~= "number" or damage <= 0 then
        return nil
    end
    if target.components.inventory ~= nil then
        for _, armor_item in pairs(target.components.inventory.equipslots) do
            local armor = armor_item.components.armor
            if armor ~= nil and type(armor.absorb_percent) == "number" then
                damage = damage * (1 - math.max(0, math.min(armor.absorb_percent, 1)))
            end
        end
    end
    return math.max(0, damage)
end

function CodexCompanionBrain:EnsureCombatEquipment(target)
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return
    end
    local best_weapon, best_armor = self:FindBestEquipment(target)
    local weapon_slot = best_weapon ~= nil
        and best_weapon.components.equippable.equipslot
        or nil
    if best_weapon ~= nil
        and inventory:GetEquippedItem(weapon_slot) ~= best_weapon
    then
        inventory:Equip(best_weapon)
    end
    local armor_slot = best_armor ~= nil
        and best_armor.components.equippable.equipslot
        or nil
    if best_armor ~= nil
        and inventory:GetEquippedItem(armor_slot) ~= best_armor
    then
        inventory:Equip(best_armor)
    end
end

function CodexCompanionBrain:Combat(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local player = GetPrimaryPlayer(self.inst)
    local leash_distance = tonumber(self.inst._codex_combat_leash_distance)
        or DEFAULT_COMBAT_LEASH_DISTANCE
    if not params.ignore_player_leash
        and player ~= nil
        and player:IsValid()
    then
        local player_distance = self.inst:GetDistanceSqToInst(player) ^ 0.5
        if player_distance > leash_distance then
            self:QueueEvent("task_failed", {
                intent_id = intent.intent_id,
                mode = "combat",
                reason = "combat_leash_exceeded",
                player_distance = Round(player_distance),
                leash_distance = leash_distance,
            })
            self:SuppressIntent(intent)
            return
        end
    end

    local target = self:FindCombatTarget(intent)
    local combat = self.inst.components.combat
    if target == nil or not target:IsValid() then
        local now = GetTime()
        if self.combat_missing_since == nil then
            self.combat_missing_since = now
        end
        if now - self.combat_missing_since >= COMBAT_MISSING_GRACE_SECONDS then
            self:QueueEvent("combat_target_lost", {
                intent_id = intent.intent_id,
                target_guid = intent.target_guid,
                target_prefab = intent.target_prefab,
                reason = "target_unavailable",
            })
            self:SuppressIntent(intent)
        end
        return
    end
    self.combat_missing_since = nil
    if target.components.health ~= nil and target.components.health:IsDead() then
        self:QueueEvent("combat_target_defeated", {
            intent_id = intent.intent_id,
            target_guid = tostring(target.GUID),
            target_prefab = target.prefab,
            verified = false,
            credited = false,
        })
        self:SuppressIntent(intent)
        return
    end

    local now = GetTime()
    if self.combat_started_at == nil then
        self.combat_started_at = now
        self.last_combat_event_at = now
    end
    if now - self.last_combat_event_at >= 20 then
        self.last_combat_event_at = now
        self:QueueEvent("task_progress", {
            intent_id = intent.intent_id,
            mode = "combat",
            stage = "fighting",
            target_guid = tostring(target.GUID),
            target_prefab = target.prefab,
            target_health = target.components.health ~= nil
                and Round(target.components.health.currenthealth)
                or nil,
            distance = Round(self.inst:GetDistanceSqToInst(target) ^ 0.5),
            elapsed = Round(now - self.combat_started_at),
            shard = TheShard:GetShardId(),
        })
    end

    local retreat_allowed = params.retreat_on_lethal ~= false
        and params.retreat_policy ~= "never"
        and not params.fight_to_death
        and not params.hold_ground
        and not params.ignore_survival_safety
    local current_health = self.inst.components.health ~= nil
        and self.inst.components.health.currenthealth
        or nil
    local incoming_damage = EstimateIncomingDamage(target, self.inst)
    if retreat_allowed
        and current_health ~= nil
        and incoming_damage ~= nil
        and current_health <= incoming_damage
    then
        local player = GetPrimaryPlayer(self.inst)
        self:QueueEvent("task_failed", {
            intent_id = intent.intent_id,
            mode = "combat",
            reason = "lethal_next_hit",
            current_health = Round(current_health),
            estimated_damage = Round(incoming_damage),
            target_guid = tostring(target.GUID),
            target_prefab = target.prefab,
            retreating_to_player = player ~= nil and player:IsValid() or false,
        })
        self:SuppressIntent(intent)
        self.safety_retreat_until = GetTime() + 10
        self.safety_retreat_reason = "lethal_next_hit"
        if player ~= nil
            and player:IsValid()
            and self.inst.components.locomotor ~= nil
        then
            self.inst.components.locomotor:GoToEntity(player, nil, 3)
        end
        return
    end

    combat:SetTarget(target)
    local distance_sq = self.inst:GetDistanceSqToInst(target)
    local locomotor = self.inst.components.locomotor
    if locomotor == nil then
        self:FailRoute(intent, "locomotor_missing")
        return
    end
    local auto_dodge = type(intent.params) == "table" and intent.params.auto_dodge
    if type(intent.params) ~= "table"
        or intent.params.auto_equip ~= false
    then
        self:EnsureCombatEquipment(target)
    end
    local target_is_attacking = target.sg ~= nil
        and target.sg:HasStateTag("attack")
    local attack_range_sq = combat:CalcAttackRangeSq(target)
    local distance = math.sqrt(distance_sq)
    if self.combat_best_distance == nil
        or distance < self.combat_best_distance - 1
    then
        self.combat_best_distance = distance
        self.combat_last_progress_at = now
    end
    if distance_sq > attack_range_sq
        and now - (self.combat_last_progress_at or now) > COMBAT_STUCK_SECONDS
    then
        self:FailAction(intent, "combat_path_stuck", {
            target_guid = tostring(target.GUID),
            best_distance = Round(self.combat_best_distance or distance),
            current_distance = Round(distance),
        })
        return
    end
    local busy = self.inst.sg ~= nil
        and (self.inst.sg:HasStateTag("busy")
            or self.inst.sg:HasStateTag("attack"))
    if distance_sq > attack_range_sq then
        if not locomotor:HasDestination() then
            locomotor:GoToEntity(target, nil, 2)
            self.last_combat_repath_at = now
        end
        return
    end

    if combat:CanAttack(target)
        and not busy
        and self.inst:GetBufferedAction() == nil
    then
        self.inst:ClearBufferedAction()
        locomotor:PushAction(
            BufferedAction(self.inst, target, ACTIONS.ATTACK),
            true
        )
    elseif auto_dodge
        and target_is_attacking
        and distance_sq <= 6.25
        and not busy
        and not locomotor:HasDestination()
    then
        local x, _, z = self.inst.Transform:GetWorldPosition()
        local tx, _, tz = target.Transform:GetWorldPosition()
        local dx = x - tx
        local dz = z - tz
        local length = math.max(0.1, math.sqrt(dx * dx + dz * dz))
        self:MoveDirect(x + dx / length * 3, z + dz / length * 3)
    end
end

function CodexCompanionBrain:FailCollect(intent, reason, extra)
    local payload = {
        intent_id = intent.intent_id,
        mode = "collect_loot",
        reason = reason,
        item_prefab = intent.target_prefab,
        current_amount = InventoryCount(self.inst, intent.target_prefab),
    }
    for key, value in pairs(extra or {}) do
        payload[key] = value
    end
    self:QueueEvent("task_failed", payload)
    self:SuppressIntent(intent)
    self.collect_state = nil
end

function CodexCompanionBrain:FindLootSource(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local source_prefab = params.source_prefab
    local source_tag = params.source_tag
    local source_tags = type(params.source_tags) == "table"
        and params.source_tags
        or nil
    local combat = self.inst.components.combat
    if source_prefab == nil and source_tag == nil and source_tags == nil then
        return nil
    end
    return FindEntity(
        self.inst,
        tonumber(params.source_search_radius) or COMBAT_SEARCH_RADIUS,
        function(entity)
            if entity == self.inst
                or not CanBeSeen(entity)
                or entity.components.health == nil
                or entity.components.health:IsDead()
            then
                return false
            end
            local matches = source_prefab ~= nil and entity.prefab == source_prefab
            if not matches and source_tag ~= nil then
                matches = entity:HasTag(source_tag)
            end
            if not matches and source_tags ~= nil then
                for _, tag in ipairs(source_tags) do
                    if entity:HasTag(tag) then
                        matches = true
                        break
                    end
                end
            end
            return matches and combat ~= nil and combat:IsValidTarget(entity)
        end,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
end

function CodexCompanionBrain:FindLootDrop(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local prefab = intent.target_prefab
    return FindEntity(
        self.inst,
        tonumber(params.loot_search_radius) or 24,
        function(entity)
            return entity.prefab == prefab
                and entity.components.inventoryitem ~= nil
                and CanBeSeen(entity)
        end,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
end

function CodexCompanionBrain:CollectLootCombat(intent, target)
    local combat = self.inst.components.combat
    local locomotor = self.inst.components.locomotor
    if combat == nil or locomotor == nil then
        self:FailCollect(intent, "combat_system_missing")
        return
    end

    local params = type(intent.params) == "table" and intent.params or {}
    local player = GetPrimaryPlayer(self.inst)
    local leash_distance = tonumber(self.inst._codex_combat_leash_distance)
        or DEFAULT_COMBAT_LEASH_DISTANCE
    if not params.ignore_player_leash
        and player ~= nil
        and player:IsValid()
    then
        local player_distance = self.inst:GetDistanceSqToInst(player) ^ 0.5
        if player_distance > leash_distance then
            self:FailCollect(intent, "combat_leash_exceeded", {
                player_distance = Round(player_distance),
                leash_distance = leash_distance,
            })
            return
        end
    end

    local retreat_allowed = params.retreat_on_lethal ~= false
        and params.retreat_policy ~= "never"
        and not params.fight_to_death
        and not params.hold_ground
        and not params.ignore_survival_safety
    local current_health = self.inst.components.health ~= nil
        and self.inst.components.health.currenthealth
        or nil
    local incoming_damage = EstimateIncomingDamage(target, self.inst)
    if retreat_allowed
        and current_health ~= nil
        and incoming_damage ~= nil
        and current_health <= incoming_damage
    then
        self:FailCollect(intent, "lethal_next_hit", {
            current_health = Round(current_health),
            estimated_damage = Round(incoming_damage),
            target_guid = tostring(target.GUID),
            target_prefab = target.prefab,
        })
        self.safety_retreat_until = GetTime() + 10
        self.safety_retreat_reason = "lethal_next_hit"
        if player ~= nil
            and player:IsValid()
            and locomotor ~= nil
        then
            locomotor:GoToEntity(player, nil, 3)
        end
        return
    end

    combat:SetTarget(target)
    if params.auto_equip ~= false then
        self:EnsureCombatEquipment(target)
    end
    local distance_sq = self.inst:GetDistanceSqToInst(target)
    local distance = math.sqrt(distance_sq)
    local attack_range_sq = combat:CalcAttackRangeSq(target)
    local now = GetTime()
    local state = self.collect_state
    if state ~= nil then
        if state.combat_best_distance == nil
            or distance < state.combat_best_distance - 1
        then
            state.combat_best_distance = distance
            state.combat_last_progress_at = now
        end
        if distance_sq > attack_range_sq
            and now - (state.combat_last_progress_at or now)
                > COMBAT_STUCK_SECONDS
            and not locomotor:HasDestination()
        then
            self:FailCollect(intent, "combat_path_stuck", {
                target_guid = tostring(target.GUID),
                target_prefab = target.prefab,
                best_distance = Round(state.combat_best_distance or distance),
                current_distance = Round(distance),
            })
            return
        end
    end
    local busy = self.inst.sg ~= nil
        and (self.inst.sg:HasStateTag("busy")
            or self.inst.sg:HasStateTag("attack"))
    if distance_sq > attack_range_sq then
        if not locomotor:HasDestination() then
            locomotor:GoToEntity(target, nil, 2)
        end
        return
    end
    if combat:CanAttack(target)
        and not busy
        and self.inst:GetBufferedAction() == nil
    then
        self.inst:ClearBufferedAction()
        locomotor:PushAction(
            BufferedAction(self.inst, target, ACTIONS.ATTACK),
            true
        )
    end
end

function CodexCompanionBrain:EnsureTaskSurvival(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    if params.ignore_survival_safety
        or params.survival_policy == "force"
    then
        return true
    end
    local hunger = self.inst.components.hunger
    local health = self.inst.components.health
    local health_percent = health ~= nil and health.maxhealth > 0
        and health.currenthealth / health.maxhealth
        or 1
    if health_percent < (tonumber(params.minimum_health_percent) or 0.2) then
        self:QueueEvent("task_failed", {
            intent_id = intent.intent_id,
            mode = intent.mode,
            reason = "survival_health_low",
            health_percent = Round(health_percent * 100),
        })
        self:SuppressIntent(intent)
        return false
    end
    if hunger == nil or hunger.max <= 0 then
        return true
    end
    local hunger_percent = hunger.current / hunger.max
    local threshold = tonumber(params.survival_hunger_percent) or 0.35
    if hunger_percent > threshold then
        self.survival_eat_started_at = nil
        return true
    end

    local eater = self.inst.components.eater
    local inventory = self.inst.components.inventory
    local food = nil
    if eater ~= nil and inventory ~= nil then
        for _, item in pairs(inventory.itemslots) do
            if item.components.edible ~= nil and eater:CanEat(item) then
                food = item
                break
            end
        end
    end
    if food ~= nil then
        self.survival_eat_started_at = self.survival_eat_started_at or GetTime()
        if self.inst.sg == nil or not self.inst.sg:HasStateTag("busy") then
            self.inst.components.locomotor:Stop()
            self.inst:ClearBufferedAction()
            self.inst.components.locomotor:PushAction(
                BufferedAction(self.inst, nil, ACTIONS.EAT, food),
                true
            )
        end
        return false
    end

    self:QueueEvent("task_failed", {
        intent_id = intent.intent_id,
        mode = intent.mode,
        reason = "survival_hunger_low",
        hunger_percent = Round(hunger_percent * 100),
        hunger_threshold_percent = Round(threshold * 100),
        needs = "food",
    })
    self:SuppressIntent(intent)
    return false
end

function CodexCompanionBrain:NotifyRecoveryUnavailable(reason, extra)
    local now = GetTime()
    if now - (
        self.recovery_notice_at[reason] or -math.huge
    ) < RECOVERY_NOTICE_COOLDOWN_SECONDS then
        return
    end
    self.recovery_notice_at[reason] = now
    local payload = {
        reason = reason,
    }
    for key, value in pairs(extra or {}) do
        payload[key] = value
    end
    self:QueueEvent("recovery_unavailable", payload)
end

function CodexCompanionBrain:FindRecoveryTent()
    local player = GetPrimaryPlayer(self.inst)
    local origin = player ~= nil and player:IsValid() and player or self.inst
    local x, _, z = origin.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        0,
        z,
        RECOVERY_TENT_SEARCH_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        local sleepingbag = entity.components.sleepingbag
        if sleepingbag ~= nil
            and not sleepingbag:InUse()
            and not entity:HasTag("hassleeper")
        then
            local distance = self.inst:GetDistanceSqToInst(entity)
            if distance < best_distance then
                best = entity
                best_distance = distance
            end
        end
    end
    return best
end

function CodexCompanionBrain:FindNearbyDanger(radius)
    return FindEntity(
        self.inst,
        radius,
        function(entity)
            return entity ~= self.inst
                and entity.components.health ~= nil
                and not entity.components.health:IsDead()
                and entity.components.combat ~= nil
                and entity.components.combat:CanTarget(self.inst)
        end,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
end

local function IsEmergencyThreat(entity, companion, player)
    if entity == nil
        or entity == companion
        or not CanBeSeen(entity)
        or entity.components.health == nil
        or entity.components.health:IsDead()
        or entity.components.combat == nil
    then
        return false
    end
    local combat = entity.components.combat
    local target = combat.target
    return target == companion
        or target == player
        or entity:HasTag("hound")
        or entity:HasTag("worm")
        or entity:HasTag("shadowcreature")
        or entity:HasTag("nightmarecreature")
end

local function GetEmergencySafetyOverride(intent)
    local params = intent ~= nil
        and type(intent.params) == "table"
        and intent.params
        or {}
    return params.ignore_survival_safety == true
        or params.survival_policy == "force"
end

function CodexCompanionBrain:EnsureEmergencyPlayerListener()
    local player = GetPrimaryPlayer(self.inst)
    if player == self.emergency_player_listener_target then
        return
    end
    local previous = self.emergency_player_listener_target
    if previous ~= nil and self.emergency_attacked_listener ~= nil then
        self.inst:RemoveEventCallback(
            "attacked",
            self.emergency_attacked_listener,
            previous
        )
        self.inst:RemoveEventCallback(
            "houndwarning",
            self.emergency_hound_warning_listener,
            previous
        )
    end
    self.emergency_player_listener_target = player
    if player == nil or not player:IsValid() then
        return
    end
    self.emergency_attacked_listener = function(source, data)
        local attacker = data ~= nil and data.attacker or nil
        if attacker == nil
            or not attacker:IsValid()
            or attacker == self.inst
        then
            return
        end
        self.emergency_attack_memory = {
            attacker = attacker,
            victim = source,
            at = GetTime(),
        }
    end
    self.emergency_hound_warning_listener = function()
        self.emergency_native.hound_warning_at = GetTime()
    end
    self.inst:ListenForEvent(
        "attacked",
        self.emergency_attacked_listener,
        player
    )
    self.inst:ListenForEvent(
        "houndwarning",
        self.emergency_hound_warning_listener,
        player
    )
end

function CodexCompanionBrain:BuildEmergencySnapshot()
    local state = self.emergency_state
    if state == nil then
        return {
            active = false,
            quake_warning = self.emergency_native.quake_warning,
            quaking = self.emergency_native.quaking,
            hound_warning = self.emergency_native.hound_warning_at ~= nil
                and GetTime() - self.emergency_native.hound_warning_at
                    <= EMERGENCY_HOUND_MEMORY_SECONDS
                or false,
            nightmare_phase = self.emergency_native.nightmare_phase,
        }
    end
    return {
        active = true,
        category = state.category,
        severity = state.severity,
        action = state.action,
        source_prefab = state.source_prefab,
        threat_count = state.threat_count,
        started_at = Round(state.started_at or GetTime(), 1),
        elapsed = Round(GetTime() - (state.started_at or GetTime()), 1),
        target_guid = state.target_guid,
        target_prefab = state.target_prefab,
        player_distance = state.target ~= nil
            and CanBeSeen(state.target)
            and Round(self.inst:GetDistanceSqToInst(state.target) ^ 0.5)
            or nil,
        quake_warning = self.emergency_native.quake_warning,
        quaking = self.emergency_native.quaking,
        hound_warning = self.emergency_native.hound_warning_at ~= nil
            and GetTime() - self.emergency_native.hound_warning_at
                <= EMERGENCY_HOUND_MEMORY_SECONDS
            or false,
        nightmare_phase = self.emergency_native.nightmare_phase,
    }
end

function CodexCompanionBrain:CollectEmergencyThreats(radius)
    local player = GetPrimaryPlayer(self.inst)
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        0,
        z,
        radius or EMERGENCY_THREAT_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local threats = {}
    for _, entity in ipairs(entities) do
        if IsEmergencyThreat(entity, self.inst, player) then
            table.insert(threats, {
                entity = entity,
                distance_sq = self.inst:GetDistanceSqToInst(entity),
            })
        end
    end
    table.sort(threats, function(a, b)
        return a.distance_sq < b.distance_sq
    end)
    while #threats > EMERGENCY_MAX_THREATS do
        table.remove(threats)
    end
    return threats
end

function CodexCompanionBrain:IsAcidProtected()
    if self.inst.components.rainimmunity ~= nil
        or (
            self.inst.components.sheltered ~= nil
            and self.inst.components.sheltered.sheltered
        )
    then
        return true
    end
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return false
    end
    if type(inventory.EquipHasTag) == "function"
        and inventory:EquipHasTag("acidrainimmune")
    then
        return true
    end
    for _, item in pairs(inventory.equipslots) do
        if item:HasTag("acidrainimmune") then
            return true
        end
        local waterproofer = item.components.waterproofer
        if waterproofer ~= nil
            and type(waterproofer.GetEffectiveness) == "function"
            and (waterproofer:GetEffectiveness() or 0) > 0
        then
            return true
        end
    end
    return false
end

function CodexCompanionBrain:EquipBestArmor()
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return false
    end
    local best = nil
    local best_score = 0
    for _, item in pairs(inventory.itemslots) do
        local armor = item.components.armor
        if armor ~= nil and item.components.equippable ~= nil then
            local percent = armor.maxcondition ~= nil
                and armor.maxcondition > 0
                and (armor.condition or armor.maxcondition) / armor.maxcondition
                or 1
            local score = (armor.absorb_percent or 0) * percent
            if score > best_score then
                best = item
                best_score = score
            end
        end
    end
    if best == nil then
        return false
    end
    local slot = best.components.equippable.equipslot
    if inventory:GetEquippedItem(slot) ~= best then
        inventory:Equip(best)
    end
    return inventory:GetEquippedItem(slot) == best
end

function CodexCompanionBrain:EquipAcidProtection()
    if self:IsAcidProtected() then
        return true
    end
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return false
    end
    local best = nil
    local best_score = 0
    for _, item in pairs(inventory.itemslots) do
        if item.components.equippable ~= nil then
            local score = item:HasTag("acidrainimmune") and 100 or 0
            local waterproofer = item.components.waterproofer
            if waterproofer ~= nil
                and type(waterproofer.GetEffectiveness) == "function"
            then
                score = math.max(
                    score,
                    waterproofer:GetEffectiveness() or 0
                )
            end
            if score > best_score then
                best = item
                best_score = score
            end
        end
    end
    if best == nil then
        return false
    end
    inventory:Equip(best)
    return self:IsAcidProtected()
end

function CodexCompanionBrain:EquipThermalProtection(freezing)
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return false
    end
    local wanted_type = freezing and SEASONS.WINTER or SEASONS.SUMMER
    local best = nil
    local best_score = 0
    for _, item in pairs(inventory.itemslots) do
        local insulator = item.components.insulator
        if insulator ~= nil and item.components.equippable ~= nil then
            local value, insulation_type = insulator:GetInsulation()
            if insulation_type == wanted_type and (value or 0) > best_score then
                best = item
                best_score = value
            end
        end
    end
    if best == nil then
        return false
    end
    inventory:Equip(best)
    return true
end

function CodexCompanionBrain:FindEmergencyLight()
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        0,
        z,
        EMERGENCY_LIGHT_SEARCH_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        local light = entity ~= self.inst and entity.Light or nil
        local enabled = light ~= nil
            and (
                type(light.IsEnabled) ~= "function"
                or light:IsEnabled()
            )
        local radius = enabled
            and type(light.GetCalculatedRadius) == "function"
            and (light:GetCalculatedRadius() or 0)
            or 0
        if enabled and radius > 0 then
            local distance = self.inst:GetDistanceSqToInst(entity)
            if distance < best_distance then
                best = entity
                best_distance = distance
            end
        end
    end
    return best
end

function CodexCompanionBrain:EmergencyFollowPlayer(force)
    local player = GetPrimaryPlayer(self.inst)
    if player == nil or not player:IsValid() then
        return false
    end
    local locomotor = self.inst.components.locomotor
    if force then
        if self.inst.components.combat ~= nil then
            self.inst.components.combat:SetTarget(nil)
        end
        self:ClearCombatTarget()
        if locomotor ~= nil then
            locomotor:Stop()
        end
    end
    if locomotor ~= nil and self.inst:GetDistanceSqToInst(player) > 16 then
        if force or not locomotor:HasDestination() then
            locomotor:GoToEntity(player, nil, 2)
        end
    elseif force and locomotor ~= nil then
        locomotor:Stop()
    end
    return true
end

function CodexCompanionBrain:EmergencyRally(state, extra)
    local force = state.action == "fight"
    self:EquipBestArmor()
    self:SetEmergencyAction(state, "rally", extra)
    self:EmergencyFollowPlayer(force)
end

function CodexCompanionBrain:TryEmergencyLight()
    local light_watcher = self.inst.LightWatcher
    if light_watcher ~= nil and light_watcher:IsInLight() then
        return "already_lit"
    end
    local inventory = self.inst.components.inventory
    if inventory ~= nil then
        for _, item in pairs(inventory.itemslots) do
            if item.prefab == "torch"
                and (
                    item.components.fueled == nil
                    or not item.components.fueled:IsEmpty()
                )
            then
                inventory:Equip(item)
                return "equipped_torch"
            end
        end
    end
    local light = self:FindEmergencyLight()
    if light ~= nil then
        local x, _, z = light.Transform:GetWorldPosition()
        self:MoveDirect(x, z)
        return "moving_to_light"
    end
    if self:EmergencyFollowPlayer() then
        return "following_player"
    end
    return "no_light_available"
end

function CodexCompanionBrain:FindEmergencyShelter()
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        0,
        z,
        24,
        { "shelter" },
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX", "burnt" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        local distance = self.inst:GetDistanceSqToInst(entity)
        if distance < best_distance then
            best = entity
            best_distance = distance
        end
    end
    return best
end

function CodexCompanionBrain:EmergencyRetreat(reason, target)
    local player = GetPrimaryPlayer(self.inst)
    self.safety_retreat_until = GetTime() + 10
    self.safety_retreat_reason = reason
    if self.inst.components.combat ~= nil then
        self.inst.components.combat:SetTarget(nil)
    end
    self.inst:ClearBufferedAction()
    if player ~= nil
        and player:IsValid()
        and self.inst.components.locomotor ~= nil
    then
        self.inst.components.locomotor:Stop()
        self.inst.components.locomotor:GoToEntity(player, nil, 3)
    end
    local state = self.emergency_state
    if state ~= nil then
        state.target = target
        state.target_guid = target ~= nil and tostring(target.GUID) or nil
        state.target_prefab = target ~= nil and target.prefab or nil
        self:SetEmergencyAction(state, "retreat", {
            reason = reason,
        })
    end
end

function CodexCompanionBrain:EmergencyFightTarget(state, target, params)
    if target == nil
        or not target:IsValid()
        or target.components.health == nil
        or target.components.health:IsDead()
    then
        return false
    end
    local health = self.inst.components.health
    local current_health = health ~= nil and health.currenthealth or nil
    local incoming_damage = EstimateIncomingDamage(target, self.inst)
    local retreat_allowed = params == nil
        or (
            params.retreat_on_lethal ~= false
            and params.retreat_policy ~= "never"
            and not params.fight_to_death
        )
    if retreat_allowed
        and current_health ~= nil
        and incoming_damage ~= nil
        and current_health <= incoming_damage
    then
        self:EmergencyRetreat("lethal_next_hit", target)
        return true
    end

    local player = GetPrimaryPlayer(self.inst)
    if player ~= nil and player:IsValid() then
        local player_distance = self.inst:GetDistanceSqToInst(player) ^ 0.5
        local target_player_distance =
            player:GetDistanceSqToInst(target) ^ 0.5
        if target_player_distance > EMERGENCY_WAVE_ENGAGE_RADIUS + 8
            and target_player_distance > player_distance
        then
            self:EmergencyRally(state, {
                reason = "wave_target_too_far_from_player",
            })
            return true
        end
    end

    local combat = self.inst.components.combat
    local locomotor = self.inst.components.locomotor
    if combat == nil or locomotor == nil then
        return false
    end
    self:EnsureCombatEquipment(target)
    combat:SetTarget(target)
    state.target = target
    state.target_guid = tostring(target.GUID)
    state.target_prefab = target.prefab
    self:SetEmergencyAction(state, "fight")
    local distance_sq = self.inst:GetDistanceSqToInst(target)
    local attack_range_sq = combat:CalcAttackRangeSq(target)
    local busy = self.inst.sg ~= nil
        and (
            self.inst.sg:HasStateTag("busy")
            or self.inst.sg:HasStateTag("attack")
        )
    if distance_sq > attack_range_sq then
        if not locomotor:HasDestination() then
            locomotor:GoToEntity(target, nil, 2)
        end
    elseif combat:CanAttack(target)
        and not busy
        and self.inst:GetBufferedAction() == nil
    then
        self.inst:ClearBufferedAction()
        locomotor:PushAction(
            BufferedAction(self.inst, target, ACTIONS.ATTACK),
            true
        )
    end
    return true
end

function CodexCompanionBrain:SetEmergencyAction(state, action, extra)
    if state.action == action then
        return
    end
    local previous = state.action
    state.action = action
    if previous ~= nil then
        local key = tostring(state.category) .. ":" .. tostring(action)
        local now = GetTime()
        if now - (self.emergency_notice_at[key] or -math.huge)
            < EMERGENCY_NOTICE_COOLDOWN_SECONDS
        then
            return
        end
        self.emergency_notice_at[key] = now
        self:QueueEvent("emergency_action", {
            category = state.category,
            severity = state.severity,
            action = action,
            previous_action = previous,
            threat_count = state.threat_count,
            target_guid = state.target_guid,
            target_prefab = state.target_prefab,
            reason = extra ~= nil and extra.reason or nil,
        })
    end
end

function CodexCompanionBrain:NotifyEmergency(state)
    if state.notice_sent then
        return
    end
    state.notice_sent = true
    self.emergency_notice_at[state.category] = GetTime()
    self:QueueEvent("emergency_detected", {
        category = state.category,
        severity = state.severity,
        action = state.action,
        threat_count = state.threat_count,
        source_prefab = state.source_prefab,
        target_guid = state.target_guid,
        target_prefab = state.target_prefab,
        health_percent = state.health_percent,
        hunger_percent = state.hunger_percent,
        sanity_percent = state.sanity_percent,
        in_light = state.in_light,
        acid_rain = state.acid_rain,
        quaking = state.quaking,
        quake_warning = state.quake_warning,
        hound_warning = state.hound_warning,
        hound_attacking = state.hound_attacking,
        nightmare_phase = state.nightmare_phase,
        force_task_override = state.force_task_override,
    })
end

function CodexCompanionBrain:EvaluateEmergencyState(intent)
    local now = GetTime()
    local player = GetPrimaryPlayer(self.inst)
    local threats = self:CollectEmergencyThreats()
    local attack = self.emergency_attack_memory
    if attack ~= nil
        and (
            attack.attacker == nil
            or not attack.attacker:IsValid()
            or now - attack.at > EMERGENCY_ATTACK_MEMORY_SECONDS
        )
    then
        self.emergency_attack_memory = nil
        attack = nil
    end

    local health = self.inst.components.health
    local hunger = self.inst.components.hunger
    local sanity = self.inst.components.sanity
    local health_percent = health ~= nil and health.maxhealth > 0
        and health.currenthealth / health.maxhealth
        or 1
    local hunger_percent = hunger ~= nil and hunger.max > 0
        and hunger.current / hunger.max
        or 1
    local sanity_percent = sanity ~= nil and sanity.max > 0
        and sanity.current / sanity.max
        or 1
    local in_light = self.inst.LightWatcher == nil
        or self.inst.LightWatcher:IsInLight()
    local quaker = TheWorld.components.quaker
    local quaking = self.emergency_native.quaking
        or (
            quaker ~= nil
            and type(quaker.IsQuaking) == "function"
            and quaker:IsQuaking()
        )
    local quake_warning = self.emergency_native.quake_warning and not quaking
    local hounded = TheWorld.components.hounded
    local hound_warning = (
        hounded ~= nil
        and type(hounded.GetWarning) == "function"
        and hounded:GetWarning()
    ) or (
        self.emergency_native.hound_warning_at ~= nil
        and now - self.emergency_native.hound_warning_at
            <= EMERGENCY_HOUND_MEMORY_SECONDS
    )
    local hound_attacking = hounded ~= nil
        and type(hounded.GetAttacking) == "function"
        and hounded:GetAttacking()
    local acid_rain = TheWorld.state.isacidraining == true
    local acid_protected = self:IsAcidProtected()
    local nightmare_phase = self.emergency_native.nightmare_phase

    local hound_count = 0
    local frog_count = 0
    local shadow_count = 0
    for _, threat in ipairs(threats) do
        local entity = threat.entity
        if entity:HasTag("hound") or entity:HasTag("worm") then
            hound_count = hound_count + 1
        end
        if entity:HasTag("frog") then
            frog_count = frog_count + 1
        end
        if entity:HasTag("shadowcreature")
            or entity:HasTag("nightmarecreature")
        then
            shadow_count = shadow_count + 1
        end
    end

    local params = intent ~= nil
        and type(intent.params) == "table"
        and intent.params
        or {}
    local safety_override = GetEmergencySafetyOverride(intent)
    local lethal_allowed = not safety_override
        and params.retreat_on_lethal ~= false
        and params.retreat_policy ~= "never"
        and not params.fight_to_death
    local lethal_target = attack ~= nil and attack.attacker or nil
    if lethal_target == nil or not lethal_target:IsValid() then
        lethal_target = threats[1] ~= nil and threats[1].entity or nil
    end
    local incoming_damage = lethal_target ~= nil
        and EstimateIncomingDamage(lethal_target, self.inst)
        or nil

    local state = nil
    local first_threat = threats[1] ~= nil and threats[1].entity or nil
    if lethal_allowed
        and health ~= nil
        and incoming_damage ~= nil
        and health.currenthealth <= incoming_damage
    then
        state = {
            category = "lethal_threat",
            severity = "critical",
            threat_count = #threats,
            source_prefab = lethal_target.prefab,
            target_prefab = lethal_target.prefab,
        }
    elseif quaking then
        state = {
            category = "earthquake",
            severity = "high",
            threat_count = #threats,
        }
    elseif hound_attacking or (hound_warning and hound_count > 0) then
        state = {
            category = "hound_wave",
            severity = "high",
            threat_count = #threats,
            source_prefab = hound_count > 0 and threats[1].entity.prefab or nil,
            target_prefab = hound_count > 0 and threats[1].entity.prefab or nil,
        }
    elseif frog_count >= 2 then
        state = {
            category = "frog_rain",
            severity = "high",
            threat_count = #threats,
            source_prefab = "frog",
        }
    elseif shadow_count > 0
        and (
            sanity_percent < 0.35
            or nightmare_phase == "wild"
            or nightmare_phase == "warn"
        )
    then
        state = {
            category = "nightmare_riot",
            severity = "high",
            threat_count = #threats,
            source_prefab = threats[1].entity.prefab,
        }
    elseif attack ~= nil then
        state = {
            category = "attacked",
            severity = "high",
            threat_count = #threats,
            source_prefab = attack.attacker ~= nil
                and attack.attacker.prefab
                or (first_threat ~= nil and first_threat.prefab or nil),
        }
    elseif #threats >= 2 then
        state = {
            category = "hostile_group",
            severity = "high",
            threat_count = #threats,
            source_prefab = first_threat.prefab,
        }
    elseif quake_warning then
        state = {
            category = "quake_warning",
            severity = "medium",
            threat_count = #threats,
        }
    elseif hound_warning then
        state = {
            category = "hound_warning",
            severity = "medium",
            threat_count = #threats,
        }
    elseif acid_rain and not acid_protected then
        state = {
            category = "acid_rain",
            severity = "medium",
            threat_count = #threats,
        }
    elseif not in_light then
        state = {
            category = "darkness",
            severity = "high",
            threat_count = #threats,
        }
    elseif self.inst:IsFreezing() then
        state = {
            category = "freezing",
            severity = "high",
            threat_count = #threats,
        }
    elseif self.inst:IsOverheating() then
        state = {
            category = "overheating",
            severity = "high",
            threat_count = #threats,
        }
    end

    if state ~= nil then
        state.health_percent = Round(health_percent * 100)
        state.hunger_percent = Round(hunger_percent * 100)
        state.sanity_percent = Round(sanity_percent * 100)
        state.in_light = in_light
        state.acid_rain = acid_rain
        state.quaking = quaking
        state.quake_warning = quake_warning
        state.hound_warning = hound_warning
        state.hound_attacking = hound_attacking
        state.nightmare_phase = nightmare_phase
        state.force_task_override = safety_override
        state.threats = threats
        state.target = nil
        state.target_guid = nil
        state.target_prefab = state.target_prefab
        state.first_seen_at = now
        state.last_seen_at = now
        state.notice_sent = false
    end
    return state, player
end

function CodexCompanionBrain:UpdateEmergency(intent)
    local now = GetTime()
    self:EnsureEmergencyPlayerListener()
    if now < self.emergency_next_check then
        return self.emergency_state
    end
    self.emergency_next_check = now + EMERGENCY_EVALUATE_SECONDS

    local detected, player = self:EvaluateEmergencyState(intent)
    local current = self.emergency_state
    if detected ~= nil then
        if current ~= nil and current.category == detected.category then
            detected.started_at = current.started_at
            detected.action = current.action
            detected.notice_sent = current.notice_sent
        else
            detected.started_at = now
            detected.action = nil
            if not detected.force_task_override then
                if self.inst.sleepingbag ~= nil
                    and self.inst.components.sleepingbaguser ~= nil
                then
                    self.inst.components.sleepingbaguser:DoWakeUp()
                end
                self.recovery_state = nil
                self:StopAll()
            end
        end
        self.emergency_state = detected
    elseif current ~= nil then
        current.last_seen_at = current.last_seen_at or now
        if now - current.last_seen_at >= EMERGENCY_RESOLVE_GRACE_SECONDS then
            self:QueueEvent("emergency_resolved", {
                category = current.category,
                action = current.action,
                duration = Round(now - (current.started_at or now), 1),
            })
            self.emergency_state = nil
        end
    end
    return self.emergency_state
end

function CodexCompanionBrain:HandleEmergency(state, intent)
    if state == nil then
        return false
    end
    local params = intent ~= nil
        and type(intent.params) == "table"
        and intent.params
        or {}
    local safety_override = GetEmergencySafetyOverride(intent)
    if safety_override then
        self:SetEmergencyAction(state, "continue_task_override")
        self:NotifyEmergency(state)
        return false
    end

    local category = state.category
    local threats = state.threats or {}
    if category == "lethal_threat" then
        local target = threats[1] ~= nil and threats[1].entity or nil
        self:EmergencyRetreat("lethal_next_hit", target)
    elseif category == "earthquake" or category == "quake_warning" then
        self:EquipBestArmor()
        self:SetEmergencyAction(
            state,
            category == "earthquake" and "brace" or "prepare_rally"
        )
        self:EmergencyFollowPlayer()
    elseif category == "hound_warning" then
        self:EquipBestArmor()
        self:SetEmergencyAction(state, "prepare_rally")
        self:EmergencyFollowPlayer()
    elseif category == "hound_wave"
        or category == "frog_rain"
        or category == "hostile_group"
    then
        local target = threats[1] ~= nil and threats[1].entity or nil
        if target ~= nil
            and self.inst:GetDistanceSqToInst(target)
                <= EMERGENCY_WAVE_ENGAGE_RADIUS ^ 2
        then
            if not self:EmergencyFightTarget(state, target, params) then
                self:EmergencyRally(state)
            end
        else
            self:EmergencyRally(state)
        end
    elseif category == "nightmare_riot" then
        local target = threats[1] ~= nil and threats[1].entity or nil
        if target ~= nil
            and self.inst:GetDistanceSqToInst(target)
                <= EMERGENCY_NIGHTMARE_ENGAGE_RADIUS ^ 2
        then
            if not self:EmergencyFightTarget(state, target, params) then
                self:EmergencyRally(state)
            end
        else
            self:EmergencyRally(state)
        end
    elseif category == "attacked" then
        local target = threats[1] ~= nil and threats[1].entity or nil
        if target ~= nil then
            self:EmergencyFightTarget(state, target, params)
        else
            self:EmergencyRally(state)
        end
    elseif category == "acid_rain" then
        if self:EquipAcidProtection() then
            self:SetEmergencyAction(state, "equipped_protection")
        else
            local shelter = self:FindEmergencyShelter()
            if shelter ~= nil then
                local x, _, z = shelter.Transform:GetWorldPosition()
                self:MoveDirect(x, z)
                self:SetEmergencyAction(state, "seek_shelter", {
                    reason = "no_acid_protection",
                })
            else
                self:EmergencyRally(state, {
                    reason = "no_acid_protection",
                })
            end
        end
    elseif category == "darkness" then
        local action = self:TryEmergencyLight()
        self:SetEmergencyAction(state, action)
    elseif category == "freezing" or category == "overheating" then
        if self:EquipThermalProtection(category == "freezing") then
            self:SetEmergencyAction(state, "equipped_protection")
        else
            self:EmergencyRally(state)
        end
    else
        self:EmergencyRally(state)
    end
    self:NotifyEmergency(state)
    return true
end

function CodexCompanionBrain:CanUseRecoveryTent(tent)
    if tent == nil or not tent:IsValid() or tent.components.sleepingbag == nil then
        return false, "sleepingbag_missing"
    end
    local sleepingbag = tent.components.sleepingbag
    if sleepingbag:InUse() or tent:HasTag("hassleeper") then
        return false, "sleepingbag_in_use"
    end
    if tent:HasTag("burnt")
        or (
            tent.components.burnable ~= nil
            and tent.components.burnable:IsBurning()
        )
    then
        return false, "tent_burning"
    end
    if self.inst.components.sleepingbaguser == nil then
        return false, "sleepingbaguser_missing"
    end
    local can_sleep, sleep_reason =
        self.inst.components.sleepingbaguser:ShouldSleep()
    if not can_sleep then
        return false, sleep_reason or "cannot_sleep"
    end
    if tent.components.finiteuses ~= nil
        and tent.components.finiteuses:GetPercent() <= 0
    then
        return false, "tent_empty"
    end

    local phase = TheWorld.state.phase
    local sleep_phase = sleepingbag:GetSleepPhase()
    local valid_phase = sleep_phase == "day"
        and phase == "day"
        or sleep_phase == "night"
            and (phase == "dusk" or phase == "night")
    if not valid_phase then
        return false, "wrong_time_of_day"
    end
    if (
        type(self.inst.IsNearDanger) == "function"
        and self.inst:IsNearDanger(self.inst)
    ) or self:FindNearbyDanger(RECOVERY_DANGER_RADIUS) ~= nil then
        return false, "danger_nearby"
    end

    local clock = TheWorld.net ~= nil
        and TheWorld.net.components.clock
        or nil
    if clock == nil then
        return false, "clock_missing"
    end
    local wake_phase = sleep_phase == "day" and "dusk" or "day"
    local sleep_seconds = clock:GetTimeUntilPhase(wake_phase)

    local health = self.inst.components.health
    local hunger = self.inst.components.hunger
    local sanity = self.inst.components.sanity
    local sleepingbaguser = self.inst.components.sleepingbaguser
    local tick_period = math.max(0.1, sleepingbag.tick_period or 1)
    local tick_count = math.floor(sleep_seconds / tick_period)
    local health_percent = health ~= nil and health.maxhealth > 0
        and health.currenthealth / health.maxhealth
        or 1
    local sanity_percent = sanity ~= nil and sanity.max > 0
        and sanity.current / sanity.max
        or 1
    local emergency = health_percent < 0.35 or sanity_percent < 0.2
    local min_sleep_seconds = emergency
        and RECOVERY_EMERGENCY_SLEEP_SECONDS
        or RECOVERY_MIN_SLEEP_SECONDS
    local health_gain = 0
    if health ~= nil and sleepingbag.healthsleep ~= false then
        health_gain = math.min(
            math.max(0, health.maxhealth - health.currenthealth),
            tick_count
                * math.max(0, sleepingbag.health_tick or 0)
                * (sleepingbaguser.health_bonus_mult or 1)
        )
    end
    local sanity_gain = 0
    if sanity ~= nil then
        sanity_gain = math.min(
            math.max(0, sanity.max - sanity.current),
            tick_count
                * math.max(0, sleepingbag.sanity_tick or 0)
                * (sleepingbaguser.sanity_bonus_mult or 1)
        )
    end
    local hunger_cost = tick_count
        * math.abs(sleepingbag.hunger_tick or 0)
        * (sleepingbaguser.hunger_bonus_mult or 1)
    local estimate = {
        sleep_seconds = sleep_seconds,
        minimum_sleep_seconds = min_sleep_seconds,
        hunger_cost = hunger_cost,
        expected_health_gain = health_gain,
        expected_sanity_gain = sanity_gain,
    }
    if sleep_seconds < min_sleep_seconds then
        return false, "not_enough_sleep_time", estimate
    end
    if health_gain < RECOVERY_MIN_HEALTH_GAIN
        and sanity_gain < RECOVERY_MIN_SANITY_GAIN
    then
        return false, "not_enough_recovery_benefit", estimate
    end
    if hunger == nil then
        return true, estimate
    end
    local reserve = math.max(
        RECOVERY_HUNGER_RESERVE_MIN,
        hunger.max * RECOVERY_HUNGER_RESERVE_RATIO,
        (TUNING ~= nil and TUNING.CALORIES_MED) or 0
    )
    estimate.hunger_after = hunger.current - hunger_cost
    estimate.hunger_reserve = reserve
    if hunger.current - hunger_cost < reserve then
        return false, "not_enough_hunger_for_sleep", estimate
    end
    return true, estimate
end

function CodexCompanionBrain:FindRecoveryFood()
    local inventory = self.inst.components.inventory
    local eater = self.inst.components.eater
    if inventory == nil or eater == nil then
        return nil
    end
    for _, item in pairs(inventory.itemslots) do
        if item.components.edible ~= nil and eater:CanEat(item) then
            return item
        end
    end
end

function CodexCompanionBrain:QueueRecoveryEat(item)
    if item == nil or self.inst.sg == nil then
        return false
    end
    if self.inst:GetBufferedAction() ~= nil
        or self.inst.sg:HasStateTag("busy")
    then
        return true
    end
    self:StopAll()
    self.inst.components.locomotor:PushAction(
        BufferedAction(self.inst, nil, ACTIONS.EAT, item),
        true
    )
    return true
end

function CodexCompanionBrain:TryRecoveryHealing()
    local inventory = self.inst.components.inventory
    if inventory == nil or self.inst.components.health == nil then
        return false
    end
    if self.inst:GetBufferedAction() ~= nil
        or (
            self.inst.sg ~= nil
            and self.inst.sg:HasStateTag("busy")
        )
    then
        return true
    end
    for _, item in pairs(inventory.itemslots) do
        if item.components.healer ~= nil or item.components.maxhealer ~= nil then
            self:StopAll()
            self.inst.components.locomotor:PushAction(
                BufferedAction(self.inst, self.inst, ACTIONS.HEAL, item),
                true
            )
            return true
        end
    end
    return false
end

function CodexCompanionBrain:NotifyRecoveryCompleted(method)
    self:QueueEvent("recovery_completed", {
        method = method,
        health = self.inst.components.health ~= nil
            and Round(self.inst.components.health.currenthealth)
            or nil,
        hunger = self.inst.components.hunger ~= nil
            and Round(self.inst.components.hunger.current)
            or nil,
        sanity = self.inst.components.sanity ~= nil
            and Round(self.inst.components.sanity.current)
            or nil,
    })
end

function CodexCompanionBrain:StartRecovery(intent)
    local health = self.inst.components.health
    local hunger = self.inst.components.hunger
    local sanity = self.inst.components.sanity
    local health_percent = health ~= nil and health.maxhealth > 0
        and health.currenthealth / health.maxhealth
        or 1
    local hunger_percent = hunger ~= nil and hunger.max > 0
        and hunger.current / hunger.max
        or 1
    local sanity_percent = sanity ~= nil and sanity.max > 0
        and sanity.current / sanity.max
        or 1

    if health_percent < 0.45 and self:TryRecoveryHealing() then
        self.recovery_state = {
            stage = "heal",
            started_at = GetTime(),
        }
        self:QueueEvent("recovery_started", {
            method = "healing_item",
            health_percent = Round(health_percent * 100),
        })
        return true
    end
    if hunger_percent < 0.55 then
        if self:QueueRecoveryEat(self:FindRecoveryFood()) then
            self.recovery_state = {
                stage = "eat",
                started_at = GetTime(),
            }
        self:QueueEvent("recovery_started", {
            method = "food",
            hunger_percent = Round(hunger_percent * 100),
        })
            return true
        end
        self:NotifyRecoveryUnavailable("recovery_food_missing", {
            hunger_percent = Round(hunger_percent * 100),
        })
        self.recovery_next_check = GetTime() + RECOVERY_CHECK_SECONDS
    end

    if health_percent >= 0.65 and sanity_percent >= 0.45 then
        return false
    end
    local tent = self:FindRecoveryTent()
    if tent == nil then
        self:NotifyRecoveryUnavailable("recovery_tent_missing", {
            health_percent = Round(health_percent * 100),
            sanity_percent = Round(sanity_percent * 100),
        })
        self.recovery_next_check = GetTime() + RECOVERY_CHECK_SECONDS
        return false
    end
    local can_sleep, estimate_or_reason, details =
        self:CanUseRecoveryTent(tent)
    if not can_sleep then
        local extra = {
            tent_prefab = tent.prefab,
            health_percent = Round(health_percent * 100),
            hunger_percent = Round(hunger_percent * 100),
            sanity_percent = Round(sanity_percent * 100),
        }
        for key, value in pairs(details or {}) do
            extra[key] = value
        end
        self:NotifyRecoveryUnavailable(
            estimate_or_reason or "tent_unavailable",
            extra
        )
        self.recovery_next_check = GetTime() + RECOVERY_CHECK_SECONDS
        return false
    end

    self.recovery_state = {
        stage = "travel",
        started_at = GetTime(),
        follow_intent_id = intent ~= nil and intent.intent_id or nil,
        tent = tent,
        estimate = estimate_or_reason,
    }
    self:QueueEvent("recovery_started", {
        method = "tent",
        tent_prefab = tent.prefab,
        health_percent = Round(health_percent * 100),
        hunger_percent = Round(hunger_percent * 100),
        sanity_percent = Round(sanity_percent * 100),
        sleep_seconds = Round(estimate_or_reason.sleep_seconds),
        estimated_hunger_cost = Round(estimate_or_reason.hunger_cost),
        expected_health_gain = Round(
            estimate_or_reason.expected_health_gain
        ),
        expected_sanity_gain = Round(
            estimate_or_reason.expected_sanity_gain
        ),
        hunger_after = estimate_or_reason.hunger_after ~= nil
            and Round(estimate_or_reason.hunger_after)
            or nil,
    })
    return true
end

function CodexCompanionBrain:UpdateRecovery(intent)
    local params = intent ~= nil
        and type(intent.params) == "table"
        and intent.params
        or {}
    local recovery_override = params.ignore_autonomous_recovery == true
        or params.ignore_survival_safety == true
    local new_follow_intent = self.recovery_state ~= nil
        and self.recovery_state.follow_intent_id ~= nil
        and intent ~= nil
        and intent.mode == "follow"
        and tostring(intent.intent_id)
            ~= tostring(self.recovery_state.follow_intent_id)
    local follow_reason = intent ~= nil
        and tostring(intent.reason or "")
        or ""
    local default_follow_replacement = new_follow_intent
        and (
            follow_reason == "default_follow"
            or follow_reason == "intent_lease_expired_follow"
        )
    if default_follow_replacement then
        self.recovery_state.follow_intent_id = intent.intent_id
    end
    if recovery_override
        or (
            intent ~= nil
            and intent.mode ~= "follow"
        )
        or (new_follow_intent and not default_follow_replacement)
    then
        if self.inst.sleepingbag ~= nil
            and self.inst.components.sleepingbaguser ~= nil
        then
            self.inst.components.sleepingbaguser:DoWakeUp()
        end
        if self.recovery_state ~= nil then
            self:StopAll()
        end
        self.recovery_state = nil
        return false
    end
    if self.inst.sleepingbag ~= nil then
        if self:FindNearbyDanger(RECOVERY_SLEEP_DANGER_RADIUS) ~= nil then
            self.inst.components.sleepingbaguser:DoWakeUp()
            self.recovery_state = nil
            self.recovery_next_check = GetTime() + 5
            self:QueueEvent("recovery_unavailable", {
                reason = "danger_during_sleep",
            })
            return true
        end
        self.recovery_state = self.recovery_state or {
            stage = "sleeping",
            started_at = GetTime(),
        }
        self.recovery_state.stage = "sleeping"
        return true
    end
    if self.recovery_state ~= nil
        and self.recovery_state.stage == "sleeping"
    then
        self:NotifyRecoveryCompleted("tent")
        self.recovery_state = nil
        self.recovery_next_check = GetTime() + 5
        return false
    end
    if GetTime() < self.recovery_next_check then
        return false
    end
    if self.recovery_state == nil and self:StartRecovery(intent) then
        return true
    end
    local state = self.recovery_state
    if state == nil then
        return false
    end

    if state.stage == "eat" then
        local hunger = self.inst.components.hunger
        if hunger == nil or hunger.current / hunger.max >= 0.55 then
            self:NotifyRecoveryCompleted("food")
            self.recovery_state = nil
            self.recovery_next_check = GetTime() + 1
            return false
        end
        if not self:QueueRecoveryEat(self:FindRecoveryFood()) then
            self:NotifyRecoveryUnavailable("recovery_food_missing", {
                hunger_percent = Round(hunger.current / hunger.max * 100),
            })
            self.recovery_state = nil
            self.recovery_next_check = GetTime() + RECOVERY_CHECK_SECONDS
        end
        return true
    end

    if state.stage == "heal" then
        local health = self.inst.components.health
        if health == nil or health.currenthealth / health.maxhealth >= 0.65 then
            self:NotifyRecoveryCompleted("healing_item")
            self.recovery_state = nil
            self.recovery_next_check = GetTime() + 1
            return false
        end
        if not self:TryRecoveryHealing() then
            self.recovery_state = nil
            self.recovery_next_check = GetTime() + 1
            return false
        end
        return true
    end

    local tent = state.tent
    local can_sleep, reason, details = self:CanUseRecoveryTent(tent)
    if state.stage == "travel" then
        if not can_sleep then
            self:NotifyRecoveryUnavailable(
                reason or "tent_unavailable",
                details
            )
            self.recovery_state = nil
            self.recovery_next_check = GetTime() + RECOVERY_CHECK_SECONDS
            return false
        end
        state.travel_started_at = state.travel_started_at or GetTime()
        if GetTime() - state.travel_started_at
            > RECOVERY_TRAVEL_TIMEOUT_SECONDS
        then
            self:NotifyRecoveryUnavailable("recovery_tent_unreachable", {
                tent_prefab = tent ~= nil and tent.prefab or nil,
            })
            self.recovery_state = nil
            self.recovery_next_check = GetTime() + RECOVERY_CHECK_SECONDS
            self:StopAll()
            return false
        end
        local tx, _, tz = tent.Transform:GetWorldPosition()
        local recovery_intent = {
            intent_id = "local-recovery-" .. tostring(state.started_at),
            params = {
                fail_on_stuck = false,
            },
        }
        if self:NavigateTo(recovery_intent, tx, tz, 2, "recovery_travel") then
            state.stage = "entering"
            state.enter_started_at = GetTime()
            self.inst:ClearBufferedAction()
            self.inst.components.locomotor:PushAction(
                BufferedAction(self.inst, tent, ACTIONS.SLEEPIN),
                true
            )
        end
        return true
    end

    if state.stage == "entering" then
        if GetTime() - (state.enter_started_at or GetTime()) > 8 then
            self:NotifyRecoveryUnavailable("tent_enter_failed", {
                tent_prefab = tent ~= nil and tent.prefab or nil,
            })
            self.recovery_state = nil
            self.recovery_next_check = GetTime() + RECOVERY_CHECK_SECONDS
            return false
        end
        return true
    end
    return true
end

function CodexCompanionBrain:CollectLoot(intent)
    local prefab = intent.target_prefab
        or (type(intent.params) == "table" and intent.params.item_prefab)
        or nil
    if type(prefab) ~= "string" or prefab == "" then
        self:FailCollect(intent, "item_prefab_missing")
        return
    end
    local params = type(intent.params) == "table" and intent.params or {}
    local desired = math.max(1, tonumber(params.amount) or 10)
    if self.collect_state == nil
        or self.collect_state.intent_id ~= intent.intent_id
    then
        self.collect_state = {
            intent_id = intent.intent_id,
            amount = desired,
            kills = 0,
            stage = "collect",
            started_at = GetTime(),
            no_progress_since = GetTime(),
            last_count = InventoryCount(self.inst, prefab),
            last_patrol_at = 0,
        }
    end
    local state = self.collect_state
    local current = InventoryCount(self.inst, prefab)
    if current > (state.last_count or 0) then
        self:QueueEvent("item_acquired", {
            intent_id = intent.intent_id,
            item_prefab = prefab,
            source = "loot",
            amount = current,
            desired_amount = desired,
            kills = state.kills,
        })
        state.last_count = current
    end
    if current < desired
        and self.inst.components.inventory ~= nil
        and self.inst.components.inventory:IsFull()
    then
        self:FailCollect(intent, "inventory_full")
        return
    end
    if current >= desired then
        state.stage = "return"
    end

    if state.stage == "collect" then
        local target = state.target
        if target ~= nil
            and (not target:IsValid()
                or target.components.health == nil
                or target.components.health:IsDead())
        then
            state.kills = state.kills + 1
            state.target = nil
            state.no_progress_since = GetTime()
            if params.progress_reports == true then
                self:QueueEvent("task_progress", {
                    intent_id = intent.intent_id,
                    mode = "collect_loot",
                    stage = "loot",
                    kills = state.kills,
                    current_amount = current,
                    desired_amount = desired,
                })
            end
            target = nil
        end

        local loot = self:FindLootDrop(intent)
        if loot ~= nil then
            if self.inst.sg == nil or not self.inst.sg:HasStateTag("busy") then
                self:KeepTargetAwake(loot)
                self.inst:ClearBufferedAction()
                self.inst.components.locomotor:PushAction(
                    BufferedAction(self.inst, loot, ACTIONS.PICKUP),
                    true
                )
            end
            return
        end

        if target == nil then
            target = self:FindLootSource(intent)
            state.target = target
            if target ~= nil then
                state.combat_best_distance = nil
                state.combat_last_progress_at = GetTime()
            end
        end
        if target ~= nil then
            state.no_progress_since = GetTime()
            self:CollectLootCombat(intent, target)
            return
        end

        local now = GetTime()
        local patrol_radius = tonumber(params.patrol_radius) or 36
        if now - (state.last_patrol_at or 0) >= 4 then
            state.last_patrol_at = now
            local px, _, pz = self.inst.Transform:GetWorldPosition()
            local player = GetPrimaryPlayer(self.inst)
            local offset = nil
            for _ = 1, 8 do
                local candidate = FindWalkableOffset(
                    Vector3(px, 0, pz),
                    math.random() * TWOPI,
                    patrol_radius,
                    8
                )
                if candidate ~= nil then
                    offset = candidate
                    if not IsPlayerMapPointExplored(
                        player,
                        px + candidate.x,
                        pz + candidate.z
                    ) then
                        break
                    end
                end
            end
            if offset ~= nil then
                self:MoveDirect(px + offset.x, pz + offset.z)
            end
        end
        local no_progress_timeout = tonumber(params.no_source_timeout) or 60
        if GetTime() - (state.no_progress_since or GetTime())
            >= no_progress_timeout
        then
            self:FailCollect(intent, "loot_source_not_found", {
                kills = state.kills,
                desired_amount = desired,
            })
        end
        return
    end

    if state.stage == "return" then
        local player = GetPrimaryPlayer(self.inst)
        if player == nil or not player:IsValid() then
            self:FailCollect(intent, "player_missing")
            return
        end
        local px, _, pz = player.Transform:GetWorldPosition()
        if not self:NavigateTo(intent, px, pz, 4, "collect_return") then
            return
        end
        if params.give_to_player ~= false then
            local item = self.inst.components.inventory:FindItem(function(candidate)
                return candidate ~= nil and candidate.prefab == prefab
            end)
            if item ~= nil then
                state.give_started_at = state.give_started_at or GetTime()
                if GetTime() - state.give_started_at > 8 then
                    self:FailCollect(intent, "player_inventory_full")
                    return
                end
                if self.inst.sg == nil or not self.inst.sg:HasStateTag("busy") then
                    self.inst:ClearBufferedAction()
                    self.inst.components.locomotor:PushAction(
                        BufferedAction(self.inst, player, ACTIONS.GIVETOPLAYER, item),
                        true
                    )
                end
                return
            end
            state.give_started_at = nil
        end
        self:QueueEvent("task_complete", {
            intent_id = intent.intent_id,
            mode = "collect_loot",
            item_prefab = prefab,
            amount = current,
            kills = state.kills,
            delivered_to_player = params.give_to_player ~= false,
            verified = true,
        })
        self:SuppressIntent(intent)
        self.collect_state = nil
    end
end

function CodexCompanionBrain:Guard(intent)
    local target = FindEntity(
        self.inst,
        22,
        function(entity)
            return CanBeSeen(entity)
                and entity.components.health ~= nil
                and not entity.components.health:IsDead()
                and entity.components.combat ~= nil
                and entity.components.combat:CanTarget(self.inst)
        end,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    if target ~= nil then
        local guarded = {}
        for key, value in pairs(intent) do
            guarded[key] = value
        end
        guarded.target_guid = tostring(target.GUID)
        self:Combat(guarded)
    else
        self:Follow()
    end
end

function CodexCompanionBrain:ActionForTarget(target)
    if target.components.workable ~= nil then
        return target.components.workable:GetWorkAction()
    elseif target.components.pickable ~= nil then
        return ACTIONS.PICK
    elseif target:HasTag("readyforharvest") then
        return ACTIONS.HARVEST
    elseif target.components.inventoryitem ~= nil then
        return ACTIONS.PICKUP
    elseif target.components.activatable ~= nil then
        return ACTIONS.ACTIVATE
    end
end

function CodexCompanionBrain:Harvest(intent)
    if self.harvest_state == nil
        or self.harvest_state.intent_id ~= intent.intent_id
    then
        self.harvest_state = {
            intent_id = intent.intent_id,
            started_at = GetTime(),
            target_guid = intent.target_guid,
            acted = false,
        }
    end
    local target = self:FindTarget(intent)
    if target == nil or not target:IsValid() then
        if self.harvest_state.acted then
            self:QueueEvent("task_complete", {
                intent_id = intent.intent_id,
                mode = intent.mode,
                target_prefab = intent.target_prefab,
                verified = true,
            })
        else
            self:QueueEvent("task_failed", {
                intent_id = intent.intent_id,
                mode = intent.mode,
                reason = "target_not_found",
                target_prefab = intent.target_prefab,
            })
        end
        self:SuppressIntent(intent)
        return
    end
    local action = self:ActionForTarget(target)
    local unsupported = action == nil and not self.harvest_state.acted
    local finished = (action == nil and self.harvest_state.acted)
        or (action ~= nil and target.components.pickable ~= nil
            and not target.components.pickable:CanBePicked())
        or (action ~= nil and target.components.workable ~= nil
            and not target.components.workable:CanBeWorked())
    if unsupported then
        self:QueueEvent("task_failed", {
            intent_id = intent.intent_id,
            mode = intent.mode,
            reason = "unsupported_target",
            target_prefab = target.prefab,
        })
        self:SuppressIntent(intent)
        return
    end
    if finished then
        self:QueueEvent("task_complete", {
            intent_id = intent.intent_id,
            mode = intent.mode,
            target_prefab = target.prefab,
            verified = true,
        })
        self:SuppressIntent(intent)
        return
    end

    local busy = self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy")
    if not busy and self.inst:GetBufferedAction() == nil then
        self.inst:ClearBufferedAction()
        self.harvest_state.acted = true
        self.inst.components.locomotor:PushAction(
            BufferedAction(self.inst, target, action),
            true
        )
    end
end

function CodexCompanionBrain:FindAreaTarget(intent, mode)
    local radius = type(intent.params) == "table"
        and tonumber(intent.params.radius)
        or 18
    local target_prefabs = type(intent.params) == "table"
        and type(intent.params.target_prefabs) == "table"
        and intent.params.target_prefabs
        or nil
    local target_prefab_set = nil
    if target_prefabs ~= nil then
        target_prefab_set = {}
        for _, prefab in ipairs(target_prefabs) do
            target_prefab_set[prefab] = true
        end
    end
    local crop_only = mode == "harvest_area"
        and not (type(intent.params) == "table" and intent.params.all_plants)
    local target = FindEntity(
        self.inst,
        radius,
        function(entity)
            if entity == self.inst or not CanBeSeen(entity) then
                return false
            end
            if target_prefab_set ~= nil
                and not target_prefab_set[entity.prefab]
            then
                return false
            end
            if crop_only then
                return entity:HasTag("farm_plant")
                    and entity.components.pickable ~= nil
                    and entity.components.pickable:CanBePicked()
            elseif mode == "harvest_area" then
                return (entity.components.pickable ~= nil
                        and entity.components.pickable:CanBePicked())
                    or entity:HasTag("readyforharvest")
                    or entity.components.workable ~= nil
            elseif mode == "gather" then
                return entity.components.inventoryitem ~= nil
                    and entity.components.inventoryitem.canbepickedup
                    and not entity:HasTag("heavy")
            end
            return false
        end,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    self:KeepTargetAwake(target)
    return target
end

function CodexCompanionBrain:AreaTask(intent, mode)
    local target = self:FindAreaTarget(intent, mode)
    if target == nil then
        self:QueueEvent("task_complete", {
            intent_id = intent.intent_id,
            mode = mode,
            verified = true,
        })
        self:SuppressIntent(intent)
        return
    end
    local narrowed = {}
    for key, value in pairs(intent) do
        narrowed[key] = value
    end
    narrowed.target_guid = tostring(target.GUID)
    self:Harvest(narrowed)
end

function CodexCompanionBrain:FindContainingItem(prefab, radius)
    local x, y, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        y,
        z,
        radius,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX", "player" }
    )
    for _, entity in ipairs(entities) do
        local container = entity.components.container
        if entity ~= self.inst and container ~= nil then
            local item = container:FindItem(function(candidate)
                return candidate ~= nil and candidate.prefab == prefab
            end)
            if item ~= nil then
                return entity, item
            end
        end
    end
end

function CodexCompanionBrain:FailFetch(intent, reason)
    self:QueueEvent("task_failed", {
        intent_id = intent.intent_id,
        mode = "fetch_item",
        reason = reason,
        item_prefab = intent.target_prefab,
    })
    self:SuppressIntent(intent)
end

function CodexCompanionBrain:FetchItem(intent)
    local prefab = intent.target_prefab
        or (type(intent.params) == "table" and intent.params.item_prefab)
        or nil
    if type(prefab) ~= "string" or prefab == "" then
        self:FailFetch(intent, "item_prefab_missing")
        return
    end

    local landmark = intent.position == nil
        and self:ResolveLandmark(intent)
        or nil
    if intent.position == nil and landmark == nil then
        self:FailFetch(intent, "landmark_not_found")
        return
    end

    if self.fetch_state == nil
        or self.fetch_state.intent_id ~= intent.intent_id
    then
        self.fetch_state = {
            intent_id = intent.intent_id,
            stage = "travel",
            started_at = GetTime(),
            prefab = prefab,
            destination_x = intent.position ~= nil and intent.position[1] or landmark.x,
            destination_z = intent.position ~= nil and intent.position[2] or landmark.z,
        }
    end
    local state = self.fetch_state
    local params = type(intent.params) == "table" and intent.params or {}

    if state.stage == "travel" then
        if state.destination_x ~= nil and state.destination_z ~= nil then
            local arrived = self:NavigateTo(
                intent,
                state.destination_x,
                state.destination_z,
                tonumber(params.arrive_distance) or 6,
                "fetch_travel"
            )
            if not arrived then
                return
            end
        end
        state.stage = "search"
        state.search_started_at = GetTime()
    end

    if state.stage == "search" then
        if InventoryHasPrefab(self.inst, prefab) then
            state.stage = "return"
        else
            local inventory = self.inst.components.inventory
            if inventory == nil then
                self:FailFetch(intent, "inventory_missing")
                return
            end
            if inventory:IsFull() then
                self:FailFetch(intent, "inventory_full")
                return
            end

            local radius = tonumber(params.search_radius) or 18
            local ground_item = FindEntity(
                self.inst,
                radius,
                function(entity)
                    return entity.prefab == prefab
                        and entity.components.inventoryitem ~= nil
                        and CanBeSeen(entity)
                end,
                nil,
                { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
            )
            if ground_item ~= nil then
                self:KeepTargetAwake(ground_item)
                state.stage = "pickup"
                state.pickup_target = ground_item
                state.pickup_started_at = GetTime()
                self.inst:ClearBufferedAction()
                self.inst.components.locomotor:PushAction(
                    BufferedAction(self.inst, ground_item, ACTIONS.PICKUP),
                    true
                )
                return
            end

            local container, item = self:FindContainingItem(prefab, radius)
            if container ~= nil and item ~= nil then
                local removed = container.components.container:RemoveItem(item, true)
                if removed == nil
                    or not inventory:GiveItem(removed, nil, self.inst:GetPosition())
                then
                    if removed ~= nil and removed:IsValid() then
                        container.components.container:GiveItem(removed)
                    end
                    self:FailFetch(intent, "item_transfer_failed")
                    return
                end
                self:QueueEvent("item_acquired", {
                    intent_id = intent.intent_id,
                    item_prefab = prefab,
                    source = "container",
                    container_prefab = container.prefab,
                })
                state.stage = "return"
            elseif GetTime() - (state.search_started_at or GetTime())
                > (tonumber(params.search_timeout) or FETCH_SEARCH_SECONDS)
            then
                self:FailFetch(intent, "item_not_found")
                return
            end
        end
    end

    if state.stage == "pickup" then
        if InventoryHasPrefab(self.inst, prefab) then
            self:QueueEvent("item_acquired", {
                intent_id = intent.intent_id,
                item_prefab = prefab,
                source = "ground",
            })
            state.stage = "return"
        elseif state.pickup_target == nil
            or not state.pickup_target:IsValid()
            or not CanBeSeen(state.pickup_target)
        then
            self:FailFetch(intent, "item_disappeared")
            return
        elseif GetTime() - (state.pickup_started_at or GetTime()) > 8 then
            state.stage = "search"
            state.search_started_at = GetTime()
        end
    end

    if state.stage == "return" then
        local player = GetPrimaryPlayer(self.inst)
        if player == nil or not player:IsValid() then
            self:FailFetch(intent, "player_missing")
            return
        end
        local px, _, pz = player.Transform:GetWorldPosition()
        local arrived = self:NavigateTo(intent, px, pz, 4, "fetch_return")
        if not arrived then
            return
        end

        if params.give_to_player then
            local item = self.inst.components.inventory:FindItem(function(candidate)
                return candidate ~= nil and candidate.prefab == prefab
            end)
            if item ~= nil and state.give_started_at == nil then
                state.give_started_at = GetTime()
                self.inst:ClearBufferedAction()
                self.inst.components.locomotor:PushAction(
                    BufferedAction(self.inst, player, ACTIONS.GIVETOPLAYER, item),
                    true
                )
                return
            end
            if not InventoryHasPrefab(self.inst, prefab)
                and InventoryHasPrefab(player, prefab)
            then
                self:QueueEvent("task_complete", {
                    intent_id = intent.intent_id,
                    mode = "fetch_item",
                    item_prefab = prefab,
                    delivered_to_player = true,
                })
                self:SuppressIntent(intent)
                return
            end
            if state.give_started_at ~= nil
                and GetTime() - state.give_started_at > 8
            then
                self:FailFetch(intent, "player_inventory_full")
            end
            return
        end

        self:QueueEvent("task_complete", {
            intent_id = intent.intent_id,
            mode = "fetch_item",
            item_prefab = prefab,
            delivered_to_player = false,
        })
        self:SuppressIntent(intent)
    end
end

function CodexCompanionBrain:Eat()
    local inventory = self.inst.components.inventory
    if inventory == nil or self.inst.sg:HasStateTag("busy") then
        return
    end
    for _, item in pairs(inventory.itemslots) do
        if item.components.edible ~= nil and self.inst.components.eater:CanEat(item) then
            self.inst:ClearBufferedAction()
            self.inst.components.locomotor:PushAction(
                BufferedAction(self.inst, nil, ACTIONS.EAT, item),
                true
            )
            return
        end
    end
end

function CodexCompanionBrain:Retreat(intent)
    local arrived = false
    if intent.position ~= nil then
        arrived = self:NavigateTo(
            intent,
            intent.position[1],
            intent.position[2],
            2,
            "retreat"
        )
    else
        local player = GetPrimaryPlayer(self.inst)
        if player == nil or not player:IsValid() then
            self:QueueEvent("task_failed", {
                intent_id = intent.intent_id,
                mode = "retreat",
                reason = "player_missing",
            })
            self:SuppressIntent(intent)
            return
        end
        local px, _, pz = player.Transform:GetWorldPosition()
        arrived = self:NavigateTo(
            intent,
            px,
            pz,
            3,
            "retreat_to_player"
        )
    end

    if arrived then
        self:QueueEvent("task_complete", {
            intent_id = intent.intent_id,
            mode = "retreat",
            verified = true,
            position = intent.position,
            returned_to_player = intent.position == nil,
        })
        self:SuppressIntent(intent)
    end
end

function CodexCompanionBrain:SpeechTick()
    if #self.speech_queue == 0
        or GetTime() - self.last_speech_at < 3
    then
        return
    end
    local message = table.remove(self.speech_queue, 1)
    if self.inst.components.talker ~= nil and message ~= nil then
        self.inst.components.talker:Say(message, 4)
        if TheNet ~= nil then
            TheNet:Announce("[伴侣] " .. message, nil, nil, "default")
        end
        self.last_speech_at = GetTime()
    end
end

function CodexCompanionBrain:Act()
    if not self.inst:IsValid() then
        return
    end
    local intent = self:GetActiveIntent()
    if self.safety_retreat_until > GetTime() then
        self:Follow()
        return
    elseif self.safety_retreat_reason ~= nil then
        self.safety_retreat_until = 0
        self.safety_retreat_reason = nil
    end
    local emergency = self:UpdateEmergency(intent)
    if self:HandleEmergency(emergency, intent) then
        return
    end
    if self:UpdateRecovery(intent) then
        return
    end
    if intent == nil then
        self:Follow()
        return
    end
    if intent.mode == "hold" then
        self:StopAll()
        return
    end
    if REMOTE_TASK_MODES[intent.mode]
        and not self:EnsureTaskSurvival(intent)
    then
        return
    end

    if intent.mode == "follow" then
        self:Follow()
    elseif intent.mode == "move_to" and intent.position ~= nil then
        local params = type(intent.params) == "table" and intent.params or {}
        local arrived = self:NavigateTo(
            intent,
            intent.position[1],
            intent.position[2],
            tonumber(params.stop_distance) or 2,
            "move"
        )
        if arrived then
            self:QueueEvent("task_complete", {
                intent_id = intent.intent_id,
                mode = "move_to",
                position = intent.position,
            })
            self:SuppressIntent(intent)
        end
    elseif intent.mode == "combat" then
        self:Combat(intent)
    elseif intent.mode == "collect_loot" then
        self:CollectLoot(intent)
    elseif intent.mode == "guard" then
        self:Guard(intent)
    elseif intent.mode == "use_skill" then
        self:UseSkill(intent)
    elseif intent.mode == "craft" then
        self:CraftItem(intent)
    elseif intent.mode == "build" then
        self:BuildAt(intent)
    elseif intent.mode == "deploy" or intent.mode == "plant" then
        self:DeployItem(intent)
    elseif intent.mode == "till" then
        self:TillGround(intent)
    elseif intent.mode == "equip" then
        self:EquipItem(intent)
    elseif intent.mode == "unequip" then
        self:UnequipItem(intent)
    elseif intent.mode == "harvest" or intent.mode == "operate" then
        self:Harvest(intent)
    elseif intent.mode == "harvest_area" or intent.mode == "gather" then
        self:AreaTask(intent, intent.mode)
    elseif intent.mode == "eat" then
        self:Eat()
    elseif intent.mode == "remember_location" then
        self:RememberLocation(intent)
    elseif intent.mode == "fetch_item" then
        self:FetchItem(intent)
    elseif intent.mode == "move_to_landmark" then
        local landmark = self:ResolveLandmark(intent)
        if landmark == nil then
            self:QueueEvent("task_failed", {
                intent_id = intent.intent_id,
                mode = "move_to_landmark",
                reason = "landmark_not_found",
            })
            self:SuppressIntent(intent)
        else
            local params = type(intent.params) == "table" and intent.params or {}
            local arrived = self:NavigateTo(
                intent,
                landmark.x,
                landmark.z,
                tonumber(params.stop_distance) or 4,
                "landmark"
            )
            if arrived then
                self:QueueEvent("task_complete", {
                    intent_id = intent.intent_id,
                    mode = "move_to_landmark",
                    landmark = landmark.name,
                    position = { landmark.x, landmark.z },
                    verified = true,
                })
                self:SuppressIntent(intent)
            end
        end
    elseif intent.mode == "retreat" then
        self:Retreat(intent)
    elseif intent.mode == "speak" then
        if self.inst.components.talker ~= nil
            and type(intent.params) == "table"
            and type(intent.params.text) == "string"
        then
            self.inst.components.talker:Say(intent.params.text)
        end
    end
end

function CodexCompanionBrain:PrepareForMigration(from_shard, to_shard)
    local interrupted = nil
    if self.intent ~= nil then
        interrupted = {
            intent_id = self.intent.intent_id,
            mode = self.intent.mode,
            target_guid = self.intent.target_guid,
            target_prefab = self.intent.target_prefab,
            from_shard = from_shard,
            to_shard = to_shard,
        }
        self.suppressed_intent_id = tostring(self.intent.intent_id)
    end
    self.intent = nil
    self.intent_received_at = 0
    self.active_intent_id = nil
    if self.inst.sleepingbag ~= nil
        and self.inst.components.sleepingbaguser ~= nil
    then
        self.inst.components.sleepingbaguser:DoWakeUp()
    end
    self.recovery_state = nil
    self:StopAll()
    return interrupted
end

function CodexCompanionBrain:ResumeAfterMigration(migration_state)
    if migration_state == nil then
        return
    end
    local interrupted_id = migration_state.interrupted_intent_id
    if interrupted_id ~= nil then
        self.suppressed_intent_id = tostring(interrupted_id)
        self:QueueEvent("task_failed", {
            intent_id = interrupted_id,
            mode = migration_state.interrupted_mode,
            reason = "shard_transition",
            from_shard = migration_state.from_shard,
            to_shard = migration_state.to_shard,
            interrupted = true,
        })
    else
        self:QueueEvent("world_transition", {
            reason = "shard_transition",
            from_shard = migration_state.from_shard,
            to_shard = migration_state.to_shard,
        })
    end
end

function CodexCompanionBrain:OnStart()
    self.bridge_url =
        (self.inst._codex_bridge_url or "http://127.0.0.1:8765") .. "/tick"
    if self.inst.components.locomotor == nil then
        self.inst:AddComponent("locomotor")
        require("prefabs/player_common_extensions").ConfigurePlayerLocomotor(self.inst)
    end
    self:EnsureAwake()
    self.death_listener = function(_, data)
        self.recovery_state = nil
        self:QueueEvent("companion_dead", {
            cause = data ~= nil and data.cause or nil,
            afflicter = data ~= nil
                and data.afflicter ~= nil
                and data.afflicter.prefab
                or nil,
        })
        if self.intent ~= nil then
            self:SuppressIntent(self.intent)
        end
    end
    self.inst:ListenForEvent("death", self.death_listener)
    self.emergency_self_attacked_listener = function(_, data)
        local attacker = data ~= nil and data.attacker or nil
        if attacker == nil
            or not attacker:IsValid()
            or attacker == self.inst
        then
            return
        end
        self.emergency_attack_memory = {
            attacker = attacker,
            victim = self.inst,
            at = GetTime(),
        }
    end
    self.inst:ListenForEvent(
        "attacked",
        self.emergency_self_attacked_listener
    )
    self.emergency_quake_warning_listener = function()
        self.emergency_native.quake_warning = true
        self.emergency_native.quaking = false
    end
    self.emergency_quake_start_listener = function(_, data)
        self.emergency_native.quake_warning = false
        self.emergency_native.quaking = true
        self.emergency_native.quake_started_at = GetTime()
        self.emergency_native.quake_duration = data ~= nil
            and data.duration
            or nil
    end
    self.emergency_quake_end_listener = function()
        self.emergency_native.quake_warning = false
        self.emergency_native.quaking = false
        self.emergency_native.quake_started_at = nil
        self.emergency_native.quake_duration = nil
    end
    self.emergency_nightmare_phase_listener = function(_, phase)
        self.emergency_native.nightmare_phase =
            type(phase) == "table" and phase.phase or phase
    end
    self.inst:ListenForEvent(
        "warnquake",
        self.emergency_quake_warning_listener,
        TheWorld
    )
    self.inst:ListenForEvent(
        "startquake",
        self.emergency_quake_start_listener,
        TheWorld
    )
    self.inst:ListenForEvent(
        "endquake",
        self.emergency_quake_end_listener,
        TheWorld
    )
    self.inst:ListenForEvent(
        "nightmarephasechanged",
        self.emergency_nightmare_phase_listener,
        TheWorld
    )
    self:EnsureEmergencyPlayerListener()
    self.network_task = self.inst:DoPeriodicTask(NETWORK_INTERVAL, function()
        self:NetworkTick()
    end, 0)
    self.act_task = self.inst:DoPeriodicTask(INTERVAL, function()
        self:Act()
    end, 0)
    self.speech_task = self.inst:DoPeriodicTask(0.5, function()
        self:SpeechTick()
    end, 0)
    self.area_task = self.inst:DoPeriodicTask(AREA_INTERVAL, function()
        self:KeepAreaLoaded()
    end, 0)
    self.map_task = self.inst:DoPeriodicTask(2, function()
        self:RevealSharedMap()
    end, 0)
    self.bt = BT(self.inst, PriorityNode({}, 1))
end

function CodexCompanionBrain:OnStop()
    if self.death_listener ~= nil then
        self.inst:RemoveEventCallback("death", self.death_listener)
        self.death_listener = nil
    end
    if self.emergency_self_attacked_listener ~= nil then
        self.inst:RemoveEventCallback(
            "attacked",
            self.emergency_self_attacked_listener
        )
        self.emergency_self_attacked_listener = nil
    end
    if self.emergency_quake_warning_listener ~= nil then
        self.inst:RemoveEventCallback(
            "warnquake",
            self.emergency_quake_warning_listener,
            TheWorld
        )
    end
    if self.emergency_quake_start_listener ~= nil then
        self.inst:RemoveEventCallback(
            "startquake",
            self.emergency_quake_start_listener,
            TheWorld
        )
    end
    if self.emergency_quake_end_listener ~= nil then
        self.inst:RemoveEventCallback(
            "endquake",
            self.emergency_quake_end_listener,
            TheWorld
        )
    end
    if self.emergency_nightmare_phase_listener ~= nil then
        self.inst:RemoveEventCallback(
            "nightmarephasechanged",
            self.emergency_nightmare_phase_listener,
            TheWorld
        )
    end
    if self.emergency_player_listener_target ~= nil then
        if self.emergency_attacked_listener ~= nil then
            self.inst:RemoveEventCallback(
                "attacked",
                self.emergency_attacked_listener,
                self.emergency_player_listener_target
            )
        end
        if self.emergency_hound_warning_listener ~= nil then
            self.inst:RemoveEventCallback(
                "houndwarning",
                self.emergency_hound_warning_listener,
                self.emergency_player_listener_target
            )
        end
        self.emergency_player_listener_target = nil
    end
    if self.network_task ~= nil then
        self.network_task:Cancel()
        self.network_task = nil
    end
    if self.act_task ~= nil then
        self.act_task:Cancel()
        self.act_task = nil
    end
    if self.speech_task ~= nil then
        self.speech_task:Cancel()
        self.speech_task = nil
    end
    if self.area_task ~= nil then
        self.area_task:Cancel()
        self.area_task = nil
    end
    if self.map_task ~= nil then
        self.map_task:Cancel()
        self.map_task = nil
    end
    if self.inst.sleepingbag ~= nil
        and self.inst.components.sleepingbaguser ~= nil
    then
        self.inst.components.sleepingbaguser:DoWakeUp()
    end
    self.recovery_state = nil
    self:ReleaseArea()
    self:StopAll()
end

return CodexCompanionBrain
