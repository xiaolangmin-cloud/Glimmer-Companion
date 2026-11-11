local COMPANION_TAG = "codex_companion"
local spawning_companion = false
GLOBAL._codex_companion_chat_hook_installed = false
local recent_chat_posts = {}
local tonumber = GLOBAL.tonumber
local next = GLOBAL.next
local COMPANION_CHARACTER_NAMES = {
    player = "玩家当前角色",
    waxwell = "麦斯威尔",
    walter = "沃尔特",
    wendy = "温蒂",
    wilson = "威尔逊",
    willow = "薇洛",
    wolfgang = "沃尔夫冈",
    wx78 = "WX-78",
    wickerbottom = "薇克巴顿",
    woodie = "伍迪",
    wes = "韦斯",
    wathgrithr = "薇格弗德",
    webber = "韦伯",
    warly = "沃利",
    wormwood = "沃姆伍德",
    winona = "薇诺娜",
    wortox = "沃拓克斯",
    wurt = "沃特",
    wanda = "旺达",
    wonkey = "猴子",
}
local GetBridgeURL
local GetLauncherURL
local TrySpawnCompanion
local AnnounceControllerStatus

local function GetCompanionCharacterPrefab(player)
    local world = GLOBAL.TheWorld
    local configured = world ~= nil
        and world._codex_selected_character
        or nil
    configured = configured
        or GetModConfigData("companion_character")
        or "player"
    if COMPANION_CHARACTER_NAMES[configured] == nil then
        configured = "player"
    end
    if configured == "player" then
        if player ~= nil and player.prefab ~= nil and player.prefab ~= "" then
            return player.prefab
        end
        return "wendy"
    end
    return configured
end

local function FetchControllerCompanionCharacter(world, player, callback)
    if world == nil or player == nil or not player:IsValid() then
        callback(nil)
        return
    end
    local finished = false
    local function finish(prefab)
        if finished then
            return
        end
        finished = true
        callback(prefab)
    end
    GLOBAL.TheSim:QueryServer(
        GetBridgeURL() .. "/companion-character",
        function(result, success)
            if not success or result == nil or result == "" then
                finish(nil)
                return
            end
            local decoded = GLOBAL.json.decode(result)
            local prefab = type(decoded) == "table"
                and decoded.prefab
                or nil
            finish(
                type(prefab) == "string"
                    and COMPANION_CHARACTER_NAMES[prefab] ~= nil
                    and prefab
                    or nil
            )
        end,
        "GET"
    )
    world:DoTaskInTime(1, function()
        finish(nil)
    end)
end

local function MarkControllerReady(world, player)
    if world == nil or world._codex_controller_connection_ready then
        return
    end
    world._codex_controller_connection_ready = true
    world._codex_controller_connection_in_progress = false
    AnnounceControllerStatus("控制器连接成功，正在初始化微光和记忆。")
    if player ~= nil and player:IsValid() then
        TrySpawnCompanion(player)
    end
end

local function WaitForControllerReady(world, player, attempt)
    if world == nil
        or world ~= GLOBAL.TheWorld
        or player == nil
        or not player:IsValid()
    then
        return
    end
    if world._codex_controller_connection_ready then
        return
    end
    attempt = attempt or 1
    if attempt > 24 then
        world._codex_controller_connection_in_progress = false
        AnnounceControllerStatus(
            "控制器连接超时。请检查 state/logs/controller-auto.stderr.log。"
        )
        return
    end
    GLOBAL.TheSim:QueryServer(
        GetLauncherURL() .. "/status",
        function(result, success)
            if not success or result == nil or result == "" then
                world:DoTaskInTime(0.5, function()
                    WaitForControllerReady(world, player, attempt + 1)
                end)
                return
            end
            local decoded = GLOBAL.json.decode(result)
            local state = type(decoded) == "table"
                and decoded.controller
                or nil
            if state == "ready" then
                MarkControllerReady(world, player)
            elseif state == "starting" then
                world:DoTaskInTime(0.5, function()
                    WaitForControllerReady(world, player, attempt + 1)
                end)
            else
                world._codex_controller_connection_in_progress = false
                AnnounceControllerStatus(
                    "控制器未能启动。请检查启动桥日志和控制器错误日志。"
                )
            end
        end,
        "GET"
    )
end

local function RequestControllerStart(world, player)
    if world == nil or player == nil or not player:IsValid() then
        return
    end
    if world._codex_controller_connection_ready
        or world._codex_controller_connection_in_progress
    then
        return
    end
    world._codex_controller_connection_in_progress = true
    AnnounceControllerStatus("已进入存档，正在请求启动本地控制器。")

    GLOBAL.TheSim:QueryServer(
        GetBridgeURL() .. "/health",
        function(_, already_running)
            if already_running then
                AnnounceControllerStatus("检测到控制器已在运行，正在建立连接。")
                MarkControllerReady(world, player)
                return
            end
            GLOBAL.TheSim:QueryServer(
                GetLauncherURL() .. "/start",
                function(result, success)
                    if not success or result == nil or result == "" then
                        world._codex_controller_connection_in_progress = false
                        AnnounceControllerStatus(
                            "无法调用本地启动桥。请先运行一次 " ..
                            "install_companion_bridge.cmd。"
                        )
                        return
                    end
                    local decoded = GLOBAL.json.decode(result)
                    if type(decoded) == "table"
                        and decoded.controller == "ready"
                    then
                        MarkControllerReady(world, player)
                    elseif type(decoded) == "table"
                        and decoded.controller == "starting"
                    then
                        AnnounceControllerStatus(
                            "启动桥已接受请求，控制器正在启动并等待接口就绪。"
                        )
                        WaitForControllerReady(world, player, 1)
                    else
                        world._codex_controller_connection_in_progress = false
                        AnnounceControllerStatus(
                            "启动桥返回异常，完整控制器没有成功启动。"
                        )
                    end
                end,
                "POST",
                "{}"
            )
        end,
        "GET"
    )
end

local function GetPrimaryPlayer(companion)
    local global_player = GLOBAL.ThePlayer
    if global_player ~= nil and global_player:IsValid() then
        return global_player
    end
    local known_player = GLOBAL.TheWorld ~= nil
        and GLOBAL.TheWorld._codex_primary_player
        or nil
    if known_player ~= nil and known_player:IsValid() then
        return known_player
    end
    if type(GLOBAL.AllPlayers) == "table" then
        for _, player in ipairs(GLOBAL.AllPlayers) do
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

GetBridgeURL = function()
    return GetModConfigData("bridge_url") or "http://127.0.0.1:8765"
end

GetLauncherURL = function()
    return GetModConfigData("launcher_url") or "http://127.0.0.1:8766"
end

AnnounceControllerStatus = function(message)
    if GLOBAL.TheNet ~= nil then
        GLOBAL.TheNet:Announce(
            "[微光] " .. message,
            nil,
            nil,
            "default"
        )
    end
end

local function ExtractCompanionChat(message)
    if type(message) ~= "string" then
        return nil
    end
    message = message:gsub("^%s+", ""):gsub("%s+$", "")
    return message ~= "" and message or nil
end

local function PostCompanionChat(route, text, userid, guid)
    text = type(text) == "string" and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if text == "" then
        return
    end
    local now = GLOBAL.GetTime()
    local dedupe_key = table.concat({
        tostring(userid or ""),
        tostring(guid or ""),
        text,
    }, ":")
    if now - (recent_chat_posts[dedupe_key] or -math.huge) < 0.5 then
        return
    end
    recent_chat_posts[dedupe_key] = now
    if #recent_chat_posts > 40 then
        recent_chat_posts = {}
    end

    local endpoint = GetBridgeURL() .. "/" .. route
    GLOBAL.TheSim:QueryServer(
        endpoint,
        function(_, success)
            if success then
                return
            end
            local companion = GLOBAL.TheWorld ~= nil
                and GLOBAL.TheWorld._codex_companion
                or nil
            if companion ~= nil
                and companion:IsValid()
                and companion.components.talker ~= nil
            then
                companion:DoTaskInTime(1, function()
                    companion.components.talker:Say(
                        "控制器没有连接，我暂时收不到游戏聊天指令。",
                        4
                    )
                end)
            end
        end,
        "POST",
        GLOBAL.json.encode({ text = text })
    )
end

local function InstallInGameChatHook()
    if GLOBAL._codex_companion_chat_hook_installed then
        return
    end
    local original = GLOBAL.Networking_Say
    if type(original) ~= "function" then
        return
    end
    GLOBAL._codex_companion_chat_hook_installed = true
    GLOBAL.Networking_Say = function(
        guid,
        userid,
        name,
        prefab,
        message,
        colour,
        whisper,
        isemote,
        user_vanity
    )
        if GLOBAL.TheWorld ~= nil
            and GLOBAL.TheWorld.ismastersim
            and not isemote
        then
            local speaker = GLOBAL.Ents ~= nil and GLOBAL.Ents[guid] or nil
            if speaker ~= nil and speaker:HasTag("player") then
                local text = ExtractCompanionChat(message)
                if text ~= nil then
                    PostCompanionChat("message", text, userid, guid)
                end
            end
        end
        return original(
            guid,
            userid,
            name,
            prefab,
            message,
            colour,
            whisper,
            isemote,
            user_vanity
        )
    end
    print("[Glimmer Companion] in-game chat hook installed")
end

local function GetShardId()
    return GLOBAL.TheShard ~= nil and GLOBAL.TheShard:GetShardId() or "unknown"
end

local function GetProfileStateFile()
    return "codex_companion_profile_v2"
end

local function GetLegacyStateFile()
    local shard = string.gsub(GetShardId(), "[^%w_%-]", "_")
    return "codex_companion_state_" .. shard
end

local function GetCompanionIdentity(player, existing)
    if type(existing) == "string" and existing ~= "" then
        return existing
    end
    if player ~= nil
        and type(player._codex_companion_identity) == "string"
        and player._codex_companion_identity ~= ""
    then
        return player._codex_companion_identity
    end
    return "codex_companion_primary"
end

local function MakeServerNonSleepable(inst)
    if inst == nil or inst.entity == nil then
        return
    end
    if inst.entity.AddServerNonSleepable ~= nil then
        inst.entity:AddServerNonSleepable()
    end
    inst.entity:SetCanSleep(false)
end

local function EnsureMiniMapIcon(inst)
    if inst == nil or inst.entity == nil then
        return
    end
    if inst.MiniMapEntity == nil and inst.entity.AddMiniMapEntity ~= nil then
        inst.entity:AddMiniMapEntity()
    end
    if inst.MiniMapEntity == nil then
        return
    end
    inst.MiniMapEntity:SetIcon((inst.prefab or "wilson") .. ".png")
    inst.MiniMapEntity:SetPriority(9)
    inst.MiniMapEntity:SetCanUseCache(false)
    inst.MiniMapEntity:SetDrawOverFogOfWar(true)
    inst.MiniMapEntity:SetEnabled(true)
end

local function EnsureLocomotor(inst)
    if inst.components.locomotor ~= nil then
        return
    end
    inst:AddComponent("locomotor")
    require("prefabs/player_common_extensions").ConfigurePlayerLocomotor(inst)
end

local function CopyOwnerCapabilities(companion, player)
    if companion == nil
        or player == nil
        or companion.prefab ~= player.prefab
        or companion.components.skilltreeupdater == nil
        or player.components.skilltreeupdater == nil
    then
        return
    end

    local selection = player.components.skilltreeupdater:GetPlayerSkillSelection()
    if selection ~= nil then
        companion.components.skilltreeupdater:SetPlayerSkillSelection(selection)
    end

    local source_builder = player.components.builder
    local target_builder = companion.components.builder
    if source_builder ~= nil
        and target_builder ~= nil
        and type(source_builder.recipes) == "table"
    then
        target_builder.recipes = {}
        for _, recipe_name in ipairs(source_builder.recipes) do
            table.insert(target_builder.recipes, recipe_name)
        end
    end
end

local function SaveCompanionState(inst)
    if inst == nil
        or not inst:IsValid()
        or not GLOBAL.TheWorld.ismastersim
        or inst._codex_skip_state_save
    then
        return
    end
    local data = {
        schema = 2,
        identity_id = GetCompanionIdentity(
            GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld._codex_primary_player or nil,
            inst._codex_companion_identity
        ),
        record = inst:GetSaveRecord(),
        landmarks = inst._codex_landmarks or {},
        shard = GetShardId(),
        saved_at = GLOBAL.GetTime(),
    }
    GLOBAL.TheSim:SetPersistentString(
        GetProfileStateFile(),
        GLOBAL.DataDumper(data, nil, false),
        false
    )
end

local function ApplyLegacyCompanionState(inst, data)
    if inst == nil or not inst:IsValid() or type(data) ~= "table" then
        return
    end
    if inst.components.health ~= nil and data.health ~= nil then
        inst.components.health:SetVal(
            tonumber(data.health) or inst.components.health.currenthealth
        )
    end
    if inst.components.hunger ~= nil and data.hunger ~= nil then
        inst.components.hunger:SetCurrent(
            tonumber(data.hunger) or inst.components.hunger.current
        )
    end
    if inst.components.sanity ~= nil and data.sanity ~= nil then
        inst.components.sanity:SetCurrent(
            tonumber(data.sanity) or inst.components.sanity.current
        )
    end

    if data.shard == GetShardId()
        and data.x ~= nil
        and data.z ~= nil
    then
        inst.Transform:SetPosition(
            tonumber(data.x) or 0,
            0,
            tonumber(data.z) or 0
        )
    end
    inst._codex_landmarks = type(data.landmarks) == "table"
        and data.landmarks
        or {}

    local inventory = inst.components.inventory
    local saved_inventory = data.inventory or {}
    local has_items = inventory ~= nil and next(inventory.itemslots) ~= nil
    local has_equipment = inventory ~= nil and next(inventory.equipslots) ~= nil
    if inventory ~= nil and not has_items and not has_equipment then
        for _, prefab in ipairs(saved_inventory.items or {}) do
            local item = GLOBAL.SpawnPrefab(prefab)
            if item ~= nil then
                inventory:GiveItem(item)
            end
        end
        for _, prefab in ipairs(saved_inventory.equipped or {}) do
            local item = GLOBAL.SpawnPrefab(prefab)
            if item ~= nil then
                inventory:Equip(item)
            end
        end
    end
end

local function DecodeProfile(raw)
    if raw == nil or raw == "" then
        return nil
    end
    local loader = GLOBAL.loadstring or loadstring
    if type(loader) ~= "function" then
        return nil
    end
    local chunk, err = loader("return " .. raw, "codex_companion_profile_v2")
    if chunk == nil then
        print("[Glimmer Companion] failed to decode profile", err)
        return nil
    end
    local data = chunk()
    return type(data) == "table" and data or nil
end

local function LoadLegacyCompanionState(callback)
    GLOBAL.TheSim:GetPersistentString(GetLegacyStateFile(), function(success, raw)
        if not success or raw == nil or raw == "" then
            callback(nil)
            return
        end
        local data = GLOBAL.json.decode(raw)
        callback(type(data) == "table" and data or nil)
    end)
end

local function PrepareCompanionEntity(inst)
    if inst == nil or not inst:IsValid() or inst:HasTag(COMPANION_TAG) then
        return
    end
    if GLOBAL.TheWorld == nil or not GLOBAL.TheWorld.ismastersim then
        return
    end

    -- Keep every component of the selected playable survivor, but detach the
    -- entity from the networking AllPlayers list so single-player checks pass.
    table.removearrayvalue(GLOBAL.AllPlayers, inst)
    inst:RemoveTag("playerghost")
    inst:RemoveTag("player")
    inst:AddTag("character")
    inst:AddTag("companion")
    inst:AddTag(COMPANION_TAG)
    inst:AddTag("notraptrigger")
    inst.userid = ""
    -- Keep the survivor outside DST's normal player persistence. The complete
    -- entity record is stored in the dedicated profile and migration checkpoint.
    inst.persists = false
    EnsureMiniMapIcon(inst)
    inst._codex_save_state = function()
        SaveCompanionState(inst)
    end
    MakeServerNonSleepable(inst)

    if inst.components.playercontroller ~= nil then
        inst:RemoveComponent("playercontroller")
    end
    if inst.components.playeractionpicker ~= nil then
        inst:RemoveComponent("playeractionpicker")
    end
    if inst.components.playervoter ~= nil then
        inst:RemoveComponent("playervoter")
    end
    if inst.components.playermetrics ~= nil then
        inst:RemoveComponent("playermetrics")
    end
    EnsureLocomotor(inst)
end

local function FindCompanion(world)
    world = world or GLOBAL.TheWorld
    if world == nil then
        return nil
    end
    local cached = world._codex_companion
    if cached ~= nil and cached:IsValid() then
        return cached
    end
    if GLOBAL.TheSim ~= nil
        and type(GLOBAL.TheSim.FindFirstEntityWithTag) == "function"
    then
        local entity = GLOBAL.TheSim:FindFirstEntityWithTag(COMPANION_TAG)
        if entity ~= nil and entity:IsValid() then
            world._codex_companion = entity
            return entity
        end
    end
    return nil
end

local function PlaceCompanionNearPlayer(companion, player)
    local x, y, z = player.Transform:GetWorldPosition()
    local offset = GLOBAL.FindWalkableOffset(
        GLOBAL.Vector3(x, y, z),
        math.random() * GLOBAL.PI2,
        3,
        8
    )
    local tx = offset ~= nil and x + offset.x or x
    local tz = offset ~= nil and z + offset.z or z
    if companion.Physics ~= nil then
        companion.Physics:Teleport(tx, 0, tz)
    else
        companion.Transform:SetPosition(tx, 0, tz)
    end
end

local function PlayCompanionSpawnEffect(companion)
    if companion == nil or not companion:IsValid() then
        return
    end
    if companion.AnimState ~= nil then
        companion.AnimState:SetMultColour(0, 0, 0, 1)
    end
    companion:Hide()
    local fx = GLOBAL.SpawnPrefab("spawn_fx_medium_static")
    if fx ~= nil then
        fx.entity:SetParent(companion.entity)
        fx.Transform:SetPosition(0, 0, 0)
    end
    companion:DoTaskInTime(6 / 30, function()
        if not companion:IsValid() then
            return
        end
        companion:Show()
        if companion.components.colourtweener ~= nil then
            companion.components.colourtweener:StartTween(
                { 1, 1, 1, 1 },
                19 / 30,
                nil,
                true
            )
        elseif companion.AnimState ~= nil then
            companion.AnimState:SetMultColour(1, 1, 1, 1)
        end
    end)
end

local function CreateCompanionEntity(player, record)
    spawning_companion = true
    local companion = record ~= nil
        and GLOBAL.SpawnSaveRecord(record)
        or nil
    if companion == nil then
        local character_prefab = GetCompanionCharacterPrefab(player)
        companion = GLOBAL.SpawnPrefab(character_prefab)
        if companion == nil then
            print(
                "[Glimmer Companion] failed to spawn configured survivor",
                character_prefab
            )
            companion = GLOBAL.SpawnPrefab("wendy")
        end
    end
    spawning_companion = false
    if companion == nil then
        print("[Glimmer Companion] failed to spawn fallback survivor")
    end
    return companion
end

local function FinishCompanionSpawn(
    player,
    profile,
    migration_state,
    legacy_state
)
    local record = migration_state ~= nil
        and migration_state.record
        or profile ~= nil and profile.record or nil
    if record ~= nil
        and migration_state == nil
        and GLOBAL.TheWorld ~= nil
        and GLOBAL.TheWorld._codex_selected_character ~= nil
    then
        local desired_prefab = GetCompanionCharacterPrefab(player)
        if record.prefab ~= nil and record.prefab ~= desired_prefab then
            record = nil
        end
    end
    local companion = CreateCompanionEntity(player, record)
    if companion == nil then
        if GLOBAL.TheWorld ~= nil then
            GLOBAL.TheWorld._codex_companion_spawning = false
        end
        return false
    end

    CopyOwnerCapabilities(companion, player)
    PrepareCompanionEntity(companion)
    local identity = GetCompanionIdentity(
        player,
        migration_state ~= nil and migration_state.identity_id
            or profile ~= nil and profile.identity_id
            or nil
    )
    companion._codex_companion_identity = identity
    player._codex_companion_identity = identity
    GLOBAL.TheWorld._codex_companion = companion
    GLOBAL.TheWorld._codex_companion_spawning = false
    GLOBAL.TheWorld._codex_companion_migrating = nil
    companion._codex_bridge_url = GetBridgeURL()
    companion._codex_area_radius =
        tonumber(GetModConfigData("area_radius")) or 18
    companion._codex_combat_leash_distance =
        tonumber(GetModConfigData("combat_leash_distance")) or 30
    EnsureLocomotor(companion)
    MakeServerNonSleepable(companion)
    companion.name = "微光"

    local saved_landmarks = migration_state ~= nil
        and migration_state.landmarks
        or profile ~= nil and profile.landmarks
        or nil
    companion._codex_landmarks = type(saved_landmarks) == "table"
        and saved_landmarks
        or {}

    if migration_state ~= nil
        or record == nil
        or GLOBAL.TheWorld._codex_controller_connection_ready
    then
        PlaceCompanionNearPlayer(companion, player)
    end
    PlayCompanionSpawnEffect(companion)
    if legacy_state ~= nil then
        ApplyLegacyCompanionState(companion, legacy_state)
    end

    companion:SetBrain(require("brains/codex_companion_brain"))
    companion:RestartBrain()
    if migration_state ~= nil and companion.brain ~= nil then
        companion.brain:ResumeAfterMigration(migration_state)
    end
    companion:DoPeriodicTask(10, SaveCompanionState)
    companion:ListenForEvent("onremove", function(inst)
        SaveCompanionState(inst)
        if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld._codex_companion == inst then
            GLOBAL.TheWorld._codex_companion = nil
        end
    end)
    SaveCompanionState(companion)
    if GLOBAL.TheWorld ~= nil
        and GLOBAL.TheWorld._codex_pending_character_switch
    then
        local selected = GetCompanionCharacterPrefab(player)
        local display_name = COMPANION_CHARACTER_NAMES[selected]
            or selected
        GLOBAL.TheWorld._codex_pending_character_switch = nil
        if GLOBAL.TheNet ~= nil then
            GLOBAL.TheNet:Announce(
                "[微光] 已切换为" .. display_name,
                nil,
                nil,
                "default"
            )
        end
    end
    print(
        "[Glimmer Companion] spawned persistent survivor",
        companion.prefab,
        identity,
        migration_state ~= nil and "migrated" or "profile"
    )
    return true
end

local function SpawnCompanion(player, migration_state)
    local world = GLOBAL.TheWorld
    if world == nil
        or FindCompanion(world) ~= nil
        or world._codex_companion_migrating
        or world._codex_companion_spawning
        or player == nil
        or not player:IsValid()
    then
        return false
    end

    if migration_state ~= nil then
        return FinishCompanionSpawn(
            player,
            nil,
            migration_state,
            nil
        )
    end

    world._codex_companion_spawning = true
    FetchControllerCompanionCharacter(world, player, function(selected)
        if selected ~= nil then
            world._codex_selected_character = selected
        end
        GLOBAL.TheSim:GetPersistentString(GetProfileStateFile(), function(success, raw)
            if not player:IsValid() or world ~= GLOBAL.TheWorld then
                if world ~= nil then
                    world._codex_companion_spawning = false
                end
                return
            end
            local profile = success and DecodeProfile(raw) or nil
            if profile ~= nil then
                FinishCompanionSpawn(player, profile, nil, nil)
                return
            end
            LoadLegacyCompanionState(function(legacy_state)
                if not player:IsValid() or world ~= GLOBAL.TheWorld then
                    if world ~= nil then
                        world._codex_companion_spawning = false
                    end
                    return
                end
                FinishCompanionSpawn(player, nil, nil, legacy_state)
            end)
        end)
    end)
    return true
end

local function CaptureCompanionForMigration(player, migration_data)
    local world = GLOBAL.TheWorld
    if world == nil
        or player == nil
        or not player:IsValid()
        or migration_data == nil
    then
        return nil
    end
    local companion = FindCompanion(world)
    if companion == nil or not companion:IsValid() then
        return nil
    end

    local interrupted = companion.brain ~= nil
        and type(companion.brain.PrepareForMigration) == "function"
        and companion.brain:PrepareForMigration(
            GetShardId(),
            migration_data.worldid
        )
        or nil
    local state = {
        schema = 1,
        identity_id = GetCompanionIdentity(player, companion._codex_companion_identity),
        record = companion:GetSaveRecord(),
        landmarks = companion._codex_landmarks or {},
        from_shard = GetShardId(),
        to_shard = migration_data.worldid,
        interrupted_intent_id = interrupted ~= nil
            and interrupted.intent_id
            or nil,
        interrupted_mode = interrupted ~= nil
            and interrupted.mode
            or nil,
        captured_at = GLOBAL.GetTime(),
    }
    world._codex_companion_migrating = true
    companion._codex_skip_state_save = true
    world._codex_companion = nil
    companion:Remove()
    print(
        "[Glimmer Companion] captured migration checkpoint",
        state.from_shard,
        state.to_shard,
        state.interrupted_intent_id or "no_active_task"
    )
    return state
end

TrySpawnCompanion = function(player)
    if player == nil or not player:IsValid() then
        return false
    end
    local migration_state = player._codex_companion_migration
    if migration_state ~= nil and GLOBAL.TheWorld ~= nil then
        -- A failed migration may return the player to the source shard.
        -- The embedded checkpoint is authoritative, so release that guard.
        GLOBAL.TheWorld._codex_companion_migrating = nil
    end
    local spawned = SpawnCompanion(player, migration_state)
    if spawned and migration_state ~= nil then
        player._codex_companion_migration = nil
    end
    return spawned
end

local function SwitchCompanionCharacter(requested_prefab)
    local world = GLOBAL.TheWorld
    if world == nil or not world.ismastersim then
        return false, "not_server"
    end
    if type(requested_prefab) ~= "string"
        or COMPANION_CHARACTER_NAMES[requested_prefab] == nil
    then
        return false, "invalid_character"
    end
    local player = GetPrimaryPlayer(nil)
    local desired_prefab = requested_prefab == "player"
        and player ~= nil
        and player.prefab
        or requested_prefab
    if desired_prefab == nil or desired_prefab == "" then
        return false, "player_missing"
    end

    world._codex_selected_character = requested_prefab
    local companion = FindCompanion(world)
    if companion == nil or not companion:IsValid() then
        return true, "spawn_pending"
    end
    if companion.prefab == desired_prefab then
        return true, "unchanged"
    end

    if companion.brain ~= nil
        and type(companion.brain.StopAll) == "function"
    then
        companion.brain:StopAll()
    end
    if companion.components.inventory ~= nil then
        companion.components.inventory:DropEverything()
    end
    companion._codex_skip_state_save = true
    world._codex_companion = nil
    world._codex_companion_spawning = false
    world._codex_pending_character_switch = true
    companion:Remove()
    GLOBAL.TheSim:SetPersistentString(
        GetProfileStateFile(),
        "",
        false
    )
    if GLOBAL.TheNet ~= nil then
        GLOBAL.TheNet:Announce(
            "[微光] 正在切换角色，原背包物品已放在脚下。",
            nil,
            nil,
            "default"
        )
    end
    return true, "switching"
end

local function StartCompanionSupervisor(world)
    world = world or GLOBAL.TheWorld
    print("[Glimmer Companion] supervisor startup requested")
    if world == nil or not world.ismastersim then
        print("[Glimmer Companion] supervisor skipped: world not master simulation")
        return
    end
    if world._codex_companion_supervisor ~= nil then
        print("[Glimmer Companion] supervisor already active")
        return
    end
    local reported_waiting = false
    world._codex_companion_supervisor = world:DoPeriodicTask(2, function()
        if not world.ismastersim or world._codex_companion_migrating then
            return
        end
        local companion = FindCompanion(world)
        if companion == nil or not companion:IsValid() then
            local player = GetPrimaryPlayer(companion)
            if player == nil then
                if not reported_waiting then
                    reported_waiting = true
                    print("[Glimmer Companion] supervisor waiting for primary player")
                end
                return
            end
            if not world._codex_controller_connection_ready then
                return
            end
            TrySpawnCompanion(player)
            return
        end
        MakeServerNonSleepable(companion)
        EnsureLocomotor(companion)
    end)
    print("[Glimmer Companion] supervisor active")
end

local function ScheduleCompanionSupervisor(world)
    if world == nil or not world.ismastersim then
        return
    end
    world._codex_companion_world_hook = true
    world._codex_switch_companion_character = SwitchCompanionCharacter
    world:ListenForEvent("ms_playerdespawnandmigrate", function(_, data)
        if data == nil or data.player == nil then
            return
        end
        local migration_state = CaptureCompanionForMigration(data.player, data)
        if migration_state ~= nil then
            data.player._codex_companion_migration = migration_state
        end
    end)
    world:ListenForEvent("ms_playerjoined", function(_, player)
        if player == nil or not player:IsValid() or player:HasTag(COMPANION_TAG) then
            return
        end
        world._codex_primary_player = player
        print("[Glimmer Companion] primary player joined", player.prefab)
        world:DoTaskInTime(1, function()
            if player:IsValid() and not world._codex_companion_migrating then
                StartCompanionSupervisor(world)
                RequestControllerStart(world, player)
            end
        end)
    end)
    world:ListenForEvent("ms_playerleft", function(_, player)
        if world._codex_primary_player == player then
            world._codex_primary_player = nil
        end
    end)
    world:DoTaskInTime(1, function()
        if world:IsValid() then
            StartCompanionSupervisor(world)
        end
    end)
end

AddPrefabPostInit("forest", ScheduleCompanionSupervisor)
AddPrefabPostInit("cave", ScheduleCompanionSupervisor)

AddSimPostInit(function()
    InstallInGameChatHook()
    if GLOBAL.TheWorld ~= nil then
        GLOBAL.TheWorld._codex_companion_sim_hook = true
    end
    print(
        "[Glimmer Companion] SimPostInit",
        tostring(GLOBAL.TheWorld ~= nil),
        tostring(GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim)
    )
    if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
        StartCompanionSupervisor(GLOBAL.TheWorld)
    end
end)

AddPlayerPostInit(function(inst)
    if spawning_companion then
        return
    end
    local original_on_save = inst.OnSave
    if type(original_on_save) == "function" then
        inst.OnSave = function(entity, data)
            original_on_save(entity, data)
            if data ~= nil
                and type(entity._codex_companion_migration) == "table"
            then
                data._codex_companion_migration =
                    entity._codex_companion_migration
            end
        end
    end
    local original_on_preload = inst.OnPreLoad
    if type(original_on_preload) == "function" then
        inst.OnPreLoad = function(entity, data, newents)
            original_on_preload(entity, data, newents)
            if data ~= nil
                and type(data._codex_companion_migration) == "table"
            then
                entity._codex_companion_migration =
                    data._codex_companion_migration
            end
        end
    end
    local function SpawnWhenWorldReady()
        if not inst:IsValid() then
            return
        end
        if GLOBAL.TheWorld == nil then
            inst:DoTaskInTime(1, SpawnWhenWorldReady)
            return
        end
        if not GLOBAL.TheWorld.ismastersim then
            return
        end
        StartCompanionSupervisor(GLOBAL.TheWorld)
        GLOBAL.TheWorld._codex_primary_player = inst
        RequestControllerStart(GLOBAL.TheWorld, inst)
    end
    inst:DoTaskInTime(1, SpawnWhenWorldReady)
end)
