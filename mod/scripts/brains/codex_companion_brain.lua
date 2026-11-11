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
    if not builder:KnowsRecipe(recipe) then
        self:FailAction(intent, "recipe_not_known")
        return
    end
    if not builder:HasIngredients(recipe) then
        self:FailAction(intent, "ingredients_missing")
        return
    end

    local started = builder:MakeRecipe(
        recipe,
        self.inst:GetPosition(),
        nil,
        nil,
        function()
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
    if not builder:KnowsRecipe(recipe) then
        self:FailAction(intent, "recipe_not_known")
        return
    end
    if not builder:HasIngredients(recipe) then
        self:FailAction(intent, "ingredients_missing")
        return
    end

    local position = self:GetActionPosition(intent)
        or self.inst:GetPosition()
    if recipe.placer == nil then
        local started = builder:MakeRecipe(
            recipe,
            position,
            nil,
            nil,
            function()
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
            self:FailAction(intent, "build_start_failed")
        end
        return
    end

    local item = FindInventoryItem(self.inst, recipe.product)
    if item == nil then
        if self.build_state == nil
            or self.build_state.intent_id ~= intent.intent_id
        then
            self.build_state = {
                intent_id = intent.intent_id,
                crafted = false,
            }
        end
        if self.build_state.crafted then
            self:FailAction(intent, "crafted_placer_missing")
            return
        end
        local started = builder:MakeRecipe(
            recipe,
            self.inst:GetPosition(),
            nil,
            nil,
            function()
                self.build_state.crafted = true
            end
        )
        if not started then
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
                BufferedAction(self.inst, self.inst, ACTIONS.EAT, food),
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
    if item == nil
        or self.inst.sg == nil
        or self.inst.sg:HasStateTag("busy")
    then
        return false
    end
    self:StopAll()
    self.inst.components.locomotor:PushAction(
        BufferedAction(self.inst, self.inst, ACTIONS.EAT, item),
        true
    )
    return true
end

function CodexCompanionBrain:TryRecoveryHealing()
    local inventory = self.inst.components.inventory
    if inventory == nil or self.inst.components.health == nil then
        return false
    end
    for _, item in pairs(inventory.itemslots) do
        if item.components.healer ~= nil or item.components.maxhealer ~= nil then
            if self.inst.sg == nil
                or not self.inst.sg:HasStateTag("busy")
            then
                self:StopAll()
                self.inst.components.locomotor:PushAction(
                    BufferedAction(self.inst, self.inst, ACTIONS.HEAL, item),
                    true
                )
                return true
            end
            return false
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
                BufferedAction(self.inst, self.inst, ACTIONS.EAT, item),
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
    if self.safety_retreat_until > GetTime() then
        self:Follow()
        return
    elseif self.safety_retreat_reason ~= nil then
        self.safety_retreat_until = 0
        self.safety_retreat_reason = nil
    end
    local intent = self:GetActiveIntent()
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
