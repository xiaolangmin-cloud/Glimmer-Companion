local INTERVAL = 0.25
local NETWORK_INTERVAL = 0.5
local NETWORK_REQUEST_TIMEOUT_SECONDS = 5
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
local RECOVERY_WAKE_EVIDENCE_DELAY_SECONDS = 1
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
local EMERGENCY_FROG_RAIN_SCAN_RADIUS = 32
local EMERGENCY_FROG_RAIN_VERTICAL_SEARCH_RADIUS = 40
local EMERGENCY_FROG_RAIN_DROP_WINDOW_SECONDS = 10
local EMERGENCY_FROG_RAIN_MIN_DROPS = 2
local EMERGENCY_FROG_RAIN_FALL_HEIGHT = 2
local EMERGENCY_FROG_RAIN_OBSERVE_SECONDS = 0.1
local REMOTE_TASK_MODES = {
    move_to = true,
    move_to_landmark = true,
    fetch_item = true,
    collect_loot = true,
    deliver_item = true,
    harvest_area = true,
    gather = true,
    operate = true,
}

local SKILL_ACTION_NAMES = {
    "CASTSPELL",
    "CAST_SPELLBOOK",
    "CAST_POCKETWATCH",
    "CLOSESPELLBOOK",
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

local CODEX_UMBRA_PREFAB = "waxwelljournal"
local CODEX_SPELL_WORKER = 1
local CODEX_SPELL_PROTECTOR = 2
local CODEX_SPELL_TRAP = 3
local CODEX_SPELL_PILLARS = 4
local CODEX_MIN_SANITY_PERCENT = 0.3
local CODEX_MIN_FUEL_PERCENT = 0.05
local CODEX_SPELL_COOLDOWN_SECONDS = 9
local CODEX_WORKER_SPELL_COOLDOWN_SECONDS = 4
local CODEX_TARGET_SPELL_COOLDOWN_SECONDS = 30
local CODEX_NOTICE_COOLDOWN_SECONDS = 30
local CODEX_GOOD_ARMOR_ABSORB = 0.6
local CODEX_GOOD_WEAPON_DAMAGE = 25
local CODEX_SAFE_HITS = 4
local CODEX_RECOMMENDED_MAX_PUPPETS = 5
local CODEX_PUPPET_PREFABS = {
    "shadowworker",
    "shadowduelist",
    "shadowprotector",
}
local AREA_TOOL_CRAFT_TIMEOUT_SECONDS = 14
local AREA_MINION_DENSITY_THRESHOLD = 5
local AREA_DENSE_MINION_DENSITY_THRESHOLD = 12
local FARMING_SEARCH_RADIUS = 16
local FARMING_TILL_SEARCH_RADIUS = 6
local HOME_ARRIVAL_DISTANCE = 4
local HOME_LOITER_RADIUS = 8
local HOME_LOCAL_SUPPLY_RADIUS = 20
local HOME_CHORE_SCAN_RADIUS = 18
local HOME_CHORE_STORAGE_RADIUS = 14
local HOME_CHORE_TREE_MIN_CLUSTER = 3
local HOME_FOREST_ALIGN_TOLERANCE = 0.75
local HOME_CHORE_MARBLE_ASSIST_MIN_CLUSTER = 4
local HOME_CHORE_ACTION_TIMEOUT_SECONDS = 8
local HOME_CHORE_NOTICE_COOLDOWN_SECONDS = 90
local HOME_PLAYER_PRESENCE_RADIUS = 10
local HOME_RETURN_CARE_COOLDOWN_SECONDS = 180
local AUTONOMY_KEEP_LAST_FOOD_PORTION = 1
local AUTONOMY_KEEP_LAST_FUEL_PORTION = 1
local AUTONOMY_KEEP_LAST_HEALING_PORTION = 1
local HOME_TREE_REPLANT_MAX_ATTEMPTS = 4
local HOME_TREE_REPLANT_RETRY_DELAY_SECONDS = 0.35
local HOME_CHORE_FIRE_REFUEL_PERCENT = 0.25
local HOME_PLAYER_MEAL_MIN_HUNGER_DEFICIT = 45
local HOME_PLAYER_FOOD_OFFER_MIN_HUNGER_DEFICIT = 25
local HOME_PLAYER_HEAL_MIN_RATIO = 0.4
local HOME_PLAYER_CRITICAL_HEAL_RATIO = 0.2
local HOME_PLAYER_SANITY_MIN_RATIO = 0.3
local EMERGENCY_WARMTH_SEARCH_RADIUS = 32
local EMERGENCY_WARMTH_STANDOFF_DISTANCE = 3
local EMERGENCY_WARMTH_REFUEL_PERCENT = 0.35

local BASIC_TOOL_COST = {
    axe = 0,
    pickaxe = 0,
    shovel = 0,
    hammer = 0,
    farm_hoe = 0,
    goldenaxe = 30,
    goldenpickaxe = 30,
    goldenshovel = 30,
    multitool = 40,
    multitool_axe = 40,
    multitool_pickaxe = 40,
    multitool_shovel = 40,
}

local FOOD_VALUE = {
    seeds = 1,
    seeds_cooked = 2,
    monstermeat = 2,
    monstermeat_cooked = 3,
    berries = 3,
    berries_cooked = 4,
    carrot = 4,
    carrot_cooked = 5,
    smallmeat = 6,
    smallmeat_cooked = 7,
    cookedmeat = 8,
    meatballs = 10,
    honey = 12,
    honeyham = 14,
}

local HEALING_VALUE = {
    healingsalve = 1,
    honeypoultice = 5,
    tallbirdegg_cooked = 8,
}

local HOME_MEAT_PREFABS = {
    "monstermeat",
    "smallmeat",
    "meat",
}

local HOME_FILLER_PREFABS = {
    "berries",
    "berries_cooked",
    "carrot",
    "carrot_cooked",
    "mushroom",
    "mushroom_cooked",
}

local FUEL_VALUE = {
    cutgrass = 1,
    twigs = 2,
    log = 3,
    seeds = 4,
    petals = 4,
    petals_evil = 5,
    charcoal = 6,
    boards = 12,
}

local TOOL_WORK_ACTIONS = {
    pickaxe = ACTIONS.MINE,
    axe = ACTIONS.CHOP,
    shovel = ACTIONS.DIG,
    hammer = ACTIONS.HAMMER,
    farm_hoe = ACTIONS.TILL,
}

local function IsLiveShadowProtector(pet)
    return pet ~= nil
        and pet:IsValid()
        and (
            pet.prefab == "shadowprotector"
            or pet.isprotector == true
        )
end

local function CountLivePetsForPrefab(petleash, prefab)
    local count = 0
    for _, pet in pairs(petleash ~= nil and petleash.pets or {}) do
        local matches = prefab == "shadowprotector"
            and IsLiveShadowProtector(pet)
            or pet ~= nil and pet:IsValid() and pet.prefab == prefab
        if matches then
            count = count + 1
        end
    end
    return count
end

local function GetLivePetsForPrefab(petleash, prefab)
    local pets = {}
    for _, pet in pairs(petleash ~= nil and petleash.pets or {}) do
        local matches = prefab == "shadowprotector"
            and IsLiveShadowProtector(pet)
            or pet ~= nil and pet:IsValid() and pet.prefab == prefab
        if matches then
            table.insert(pets, pet)
        end
    end
    return pets
end

local function GetCodexPuppetSummary(petleash)
    local counts = {}
    local total = 0
    for _, prefab in ipairs(CODEX_PUPPET_PREFABS) do
        local count = CountLivePetsForPrefab(petleash, prefab)
        counts[prefab] = count
        total = total + count
    end
    return counts, total
end

local function HasInsulationType(inst, wanted_type)
    local inventory = inst ~= nil and inst.components.inventory or nil
    if inventory == nil then
        return false
    end
    for _, item in pairs(inventory.equipslots or {}) do
        local insulator = item.components.insulator
        if insulator ~= nil
            and type(insulator.GetInsulation) == "function"
        then
            local _, insulation_type = insulator:GetInsulation()
            if insulation_type == wanted_type then
                return true
            end
        end
    end
    return false
end

local function Round(value, places)
    local mult = 10 ^ (places or 2)
    return math.floor((value or 0) * mult + 0.5) / mult
end

local function VitalityEvidence(inst)
    local health = inst.components.health
    local hunger = inst.components.hunger
    local sanity = inst.components.sanity
    return {
        health = health ~= nil and Round(health.currenthealth) or nil,
        health_max = health ~= nil and Round(health.maxhealth) or nil,
        health_percent = health ~= nil and health.maxhealth > 0
            and Round(health.currenthealth / health.maxhealth * 100)
            or nil,
        hunger = hunger ~= nil and Round(hunger.current) or nil,
        hunger_max = hunger ~= nil and Round(hunger.max) or nil,
        hunger_percent = hunger ~= nil and hunger.max > 0
            and Round(hunger.current / hunger.max * 100)
            or nil,
        sanity = sanity ~= nil and Round(sanity.current) or nil,
        sanity_max = sanity ~= nil and Round(sanity.max) or nil,
        sanity_percent = sanity ~= nil and sanity.max > 0
            and Round(sanity.current / sanity.max * 100)
            or nil,
    }
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

local function PerishPercent(item)
    local perishable = item ~= nil and item.components.perishable or nil
    if perishable ~= nil
        and type(perishable.GetPercent) == "function"
    then
        return perishable:GetPercent()
    end
    return 1
end

local function InventoryPercent(item, component_name)
    local component = item ~= nil
        and item.components[component_name]
        or nil
    if component ~= nil and type(component.GetPercent) == "function" then
        return component:GetPercent()
    end
    local percentused = item ~= nil and item.components.percentused or nil
    if percentused ~= nil
        and type(percentused.GetPercent) == "function"
    then
        return percentused:GetPercent()
    end
    return 1
end

local function IsTaskInventoryItem(intent, prefab)
    if type(intent) ~= "table" or type(prefab) ~= "string" then
        return false
    end
    local params = type(intent.params) == "table" and intent.params or {}
    if prefab == intent.target_prefab
        or prefab == params.target_prefab
        or prefab == params.item_prefab
        or prefab == params.drop_prefab
    then
        return true
    end
    local target_prefabs = params.target_prefabs
    if type(target_prefabs) == "table" then
        for _, target_prefab in ipairs(target_prefabs) do
            if target_prefab == prefab then
                return true
            end
        end
    end
    local preserve = params.preserve_items
    if type(preserve) == "table" then
        if preserve[prefab] ~= nil then
            return true
        end
        for _, preserved_prefab in ipairs(preserve) do
            if preserved_prefab == prefab then
                return true
            end
        end
    end
    return false
end

local function InventoryEdiblePortionCount(inst)
    local inventory = inst ~= nil and inst.components.inventory or nil
    if inventory == nil then
        return 0
    end
    local total = 0
    for _, item in pairs(inventory.itemslots) do
        if item ~= nil and item.components.edible ~= nil then
            local stackable = item.components.stackable
            total = total + (
                stackable ~= nil and stackable:StackSize() or 1
            )
        end
    end
    return total
end

local function InventoryFuelPortionCount(inst, intent, fueled)
    local inventory = inst ~= nil and inst.components.inventory or nil
    if inventory == nil then
        return 0
    end
    local total = 0
    for _, item in pairs(inventory.itemslots) do
        if item ~= nil
            and (
                item.components.fuel ~= nil
                or item.components.fueler ~= nil
            )
            and (
                fueled == nil
                or fueled:CanAcceptFuelItem(item)
            )
            and not IsTaskInventoryItem(intent, item.prefab)
        then
            local stackable = item.components.stackable
            total = total + (
                stackable ~= nil and stackable:StackSize() or 1
            )
        end
    end
    return total
end

local function InventoryHealingPortionCount(inst)
    local inventory = inst ~= nil and inst.components.inventory or nil
    if inventory == nil then
        return 0
    end
    local total = 0
    for _, item in pairs(inventory.itemslots) do
        if item ~= nil
            and (
                item.components.healer ~= nil
                or item.components.maxhealer ~= nil
            )
        then
            local stackable = item.components.stackable
            total = total + (
                stackable ~= nil and stackable:StackSize() or 1
            )
        end
    end
    return total
end

local function GetAutonomyFoodReserveCount(inst, prefab)
    if type(prefab) ~= "string"
        or InventoryCount(inst, prefab) <= 0
        or InventoryEdiblePortionCount(inst)
            > AUTONOMY_KEEP_LAST_FOOD_PORTION
    then
        return 0
    end
    return AUTONOMY_KEEP_LAST_FOOD_PORTION
end

local function GetAutonomyFuelReserveCount(inst, intent, prefab, fueled)
    if type(prefab) ~= "string"
        or InventoryCount(inst, prefab) <= 0
        or InventoryFuelPortionCount(inst, intent, fueled)
            > AUTONOMY_KEEP_LAST_FUEL_PORTION
    then
        return 0
    end
    return AUTONOMY_KEEP_LAST_FUEL_PORTION
end

local function GetAutonomyHealingReserveCount(inst, prefab)
    if type(prefab) ~= "string"
        or InventoryCount(inst, prefab) <= 0
        or InventoryHealingPortionCount(inst)
            > AUTONOMY_KEEP_LAST_HEALING_PORTION
    then
        return 0
    end
    return AUTONOMY_KEEP_LAST_HEALING_PORTION
end

local function FindDisposableDuplicateTool(inst, intent)
    local inventory = inst.components.inventory
    if inventory == nil then
        return nil
    end
    local counts = {}
    for _, item in pairs(inventory.itemslots) do
        if item ~= nil then
            counts[item.prefab] = (counts[item.prefab] or 0) + 1
        end
    end

    local best = nil
    local best_key = nil
    for _, item in pairs(inventory.itemslots) do
        if item ~= nil
            and (counts[item.prefab] or 0) > 1
            and TOOL_WORK_ACTIONS[item.prefab] ~= nil
            and not IsTaskInventoryItem(intent, item.prefab)
            and item.components.inventoryitem ~= nil
            and item.components.inventoryitem.canbepickedup ~= false
        then
            local key = {
                BASIC_TOOL_COST[item.prefab] or 0,
                InventoryPercent(item, "finiteuses"),
                item.prefab,
            }
            if best_key == nil
                or key[1] < best_key[1]
                or (
                    key[1] == best_key[1]
                    and (
                        key[2] < best_key[2]
                        or (key[2] == best_key[2] and key[3] < best_key[3])
                    )
                )
            then
                best = item
                best_key = key
            end
        end
    end
    return best
end

local function InventoryCanStackPrefab(inventory, prefab)
    if inventory == nil or type(prefab) ~= "string" then
        return false
    end
    for _, item in pairs(inventory.itemslots) do
        local stackable = item ~= nil and item.prefab == prefab
            and item.components.stackable
            or nil
        if stackable ~= nil
            and stackable:StackSize() < stackable.maxsize
        then
            return true
        end
    end
    return false
end

local function FoodSelectionKey(item)
    local prefab = item ~= nil and item.prefab or ""
    return PerishPercent(item), FOOD_VALUE[prefab] or 8, prefab
end

local function IsBetterFood(candidate, current)
    if current == nil then
        return true
    end
    local candidate_perish, candidate_value, candidate_prefab =
        FoodSelectionKey(candidate)
    local current_perish, current_value, current_prefab =
        FoodSelectionKey(current)
    if candidate_perish ~= current_perish then
        return candidate_perish < current_perish
    end
    if candidate_value ~= current_value then
        return candidate_value < current_value
    end
    return candidate_prefab < current_prefab
end

local function PlayerFoodHunger(item, player)
    local edible = item ~= nil and item.components.edible or nil
    if edible == nil or type(edible.GetHunger) ~= "function" then
        return FOOD_VALUE[item ~= nil and item.prefab or ""] or 8
    end
    return math.max(0, tonumber(edible:GetHunger(player)) or 0)
end

local function PlayerFoodEfficiency(item, player, deficit)
    local gain = PlayerFoodHunger(item, player)
    local covered = math.min(gain, math.max(0, deficit))
    local value = FOOD_VALUE[item ~= nil and item.prefab or ""] or 16
    return covered / math.max(1, value)
end

local function IsBetterPlayerFood(candidate, current, player, deficit)
    if current == nil then
        return true
    end
    local candidate_gain = PlayerFoodHunger(candidate, player)
    local current_gain = PlayerFoodHunger(current, player)
    local candidate_overshoot = math.max(0, candidate_gain - deficit)
    local current_overshoot = math.max(0, current_gain - deficit)
    -- Do not waste a high-value dish on a small hunger gap. The tolerance
    -- scales with the real deficit, while freshness and ordinary food value
    -- break ties in favour of consuming food that would spoil first.
    local tolerance = math.max(8, deficit * 0.35)
    local candidate_wasteful = candidate_overshoot > tolerance
    local current_wasteful = current_overshoot > tolerance
    if candidate_wasteful ~= current_wasteful then
        return not candidate_wasteful
    end
    local candidate_perish = PerishPercent(candidate)
    local current_perish = PerishPercent(current)
    local candidate_urgent = candidate_perish <= 20
    local current_urgent = current_perish <= 20
    if candidate_urgent ~= current_urgent then
        return candidate_urgent
    end
    local candidate_efficiency = PlayerFoodEfficiency(
        candidate,
        player,
        deficit
    )
    local current_efficiency = PlayerFoodEfficiency(
        current,
        player,
        deficit
    )
    if math.abs(candidate_efficiency - current_efficiency) > 0.001 then
        return candidate_efficiency > current_efficiency
    end
    if candidate_overshoot ~= current_overshoot then
        return candidate_overshoot < current_overshoot
    end
    if candidate_perish ~= current_perish then
        return candidate_perish < current_perish
    end
    local candidate_value = FOOD_VALUE[candidate.prefab] or 16
    local current_value = FOOD_VALUE[current.prefab] or 16
    if candidate_value ~= current_value then
        return candidate_value < current_value
    end
    return candidate.prefab < current.prefab
end

local function GetFoodReserveCount(inst, intent, prefab)
    if type(intent) ~= "table" or type(prefab) ~= "string" then
        return 0
    end
    local params = type(intent.params) == "table" and intent.params or {}
    if intent.mode == "eat" or params.allow_eat_task_items == true then
        return 0
    end
    local preserve = params.preserve_items
    if type(preserve) == "table" then
        local amount = preserve[prefab]
        if type(amount) == "number" then
            return math.max(0, math.floor(amount))
        end
        for _, preserved_prefab in ipairs(preserve) do
            if preserved_prefab == prefab then
                return InventoryCount(inst, prefab)
            end
        end
    end
    local wanted = intent.target_prefab
        or params.item_prefab
        or params.target_prefab
    if wanted ~= prefab then
        wanted = nil
        local target_prefabs = params.target_prefabs
        if type(target_prefabs) == "table" then
            for _, target_prefab in ipairs(target_prefabs) do
                if target_prefab == prefab then
                    wanted = prefab
                    break
                end
            end
        end
        if wanted == nil then
            return 0
        end
    end
    local requested = tonumber(
        params.amount
        or params.requested_amount
        or params.target_amount
    )
    if requested == nil then
        requested = InventoryCount(inst, prefab)
    end
    return math.max(0, math.floor(requested))
end

local function FindBestFood(inst, wanted_prefab, intent, extra_reserve)
    local inventory = inst.components.inventory
    local eater = inst.components.eater
    if inventory == nil or eater == nil then
        return nil
    end
    local best = nil
    local reserves = {}
    for _, item in pairs(inventory.itemslots) do
        if item.components.edible ~= nil
            and (wanted_prefab == nil or item.prefab == wanted_prefab)
            and eater:CanEat(item)
        then
            if reserves[item.prefab] == nil then
                reserves[item.prefab] = GetFoodReserveCount(
                    inst,
                    intent,
                    item.prefab
                )
            end
            local stack_size = item.components.stackable ~= nil
                and item.components.stackable:StackSize()
                or 1
            local reserve = math.max(
                reserves[item.prefab],
                extra_reserve ~= nil
                    and extra_reserve(inst, item.prefab)
                    or 0
            )
            if reserve > 0 and stack_size <= reserve then
                -- This stack is still needed by the active delivery,
                -- collection, or preservation task.
                reserves[item.prefab] = reserve - stack_size
            elseif IsBetterFood(item, best) then
                best = item
            end
        end
    end
    return best
end

local function FindBestCheapFood(inst, intent, max_value, extra_reserve)
    local inventory = inst.components.inventory
    local eater = inst.components.eater
    if inventory == nil or eater == nil then
        return nil
    end
    max_value = max_value or 5
    local best = nil
    local reserves = {}
    for _, item in pairs(inventory.itemslots) do
        local value = FOOD_VALUE[item.prefab] or 99
        if item.components.edible ~= nil
            and value <= max_value
            and eater:CanEat(item)
        then
            if reserves[item.prefab] == nil then
                reserves[item.prefab] = GetFoodReserveCount(
                    inst,
                    intent,
                    item.prefab
                )
            end
            local stack_size = item.components.stackable ~= nil
                and item.components.stackable:StackSize()
                or 1
            local reserve = math.max(
                reserves[item.prefab],
                extra_reserve ~= nil
                    and extra_reserve(inst, item.prefab)
                    or 0
            )
            if reserve > 0 and stack_size <= reserve then
                reserves[item.prefab] = reserve - stack_size
            elseif IsBetterFood(item, best) then
                best = item
            end
        end
    end
    return best
end

local function FindBestHealingItem(inst, extra_reserve)
    local inventory = inst.components.inventory
    if inventory == nil then
        return nil
    end
    local best = nil
    local best_key = nil
    local reserves = {}
    for _, item in pairs(inventory.itemslots) do
        if item.components.healer ~= nil
            or item.components.maxhealer ~= nil
        then
            if reserves[item.prefab] == nil then
                reserves[item.prefab] = extra_reserve ~= nil
                    and extra_reserve(inst, item.prefab)
                    or 0
            end
            local stack_size = item.components.stackable ~= nil
                and item.components.stackable:StackSize()
                or 1
            local key = {
                HEALING_VALUE[item.prefab] or 10,
                InventoryPercent(item, "healer"),
                item.prefab,
            }
            if reserves[item.prefab] > 0
                and stack_size <= reserves[item.prefab]
            then
                reserves[item.prefab] = reserves[item.prefab] - stack_size
            elseif best_key == nil
                or key[1] < best_key[1]
                or (
                    key[1] == best_key[1]
                    and (
                        key[2] < best_key[2]
                        or (key[2] == best_key[2] and key[3] < best_key[3])
                    )
                )
            then
                best = item
                best_key = key
            end
        end
    end
    return best
end

local function FindBestSanityFood(inst, player, intent, extra_reserve)
    local inventory = inst.components.inventory
    local eater = player ~= nil and player.components.eater or nil
    local health = player ~= nil and player.components.health or nil
    if inventory == nil or eater == nil or health == nil then
        return nil
    end
    local health_safe = health.maxhealth > 0
        and health.currenthealth / health.maxhealth >= 0.5
    local best = nil
    local best_key = nil
    local reserves = {}
    for _, item in pairs(inventory.itemslots) do
        local edible = item.components.edible
        local sanity_gain = edible ~= nil
            and edible:GetSanity(player)
            or 0
        local health_gain = edible ~= nil
            and edible:GetHealth(player)
            or 0
        if edible ~= nil
            and sanity_gain > 0
            and (
                health_gain >= 0
                or (
                    health_safe
                    and health.currenthealth + health_gain >= 30
                )
            )
            and eater:CanEat(item)
            and not IsTaskInventoryItem(intent, item.prefab)
        then
            if reserves[item.prefab] == nil then
                reserves[item.prefab] = GetFoodReserveCount(
                    inst,
                    intent,
                    item.prefab
                )
            end
            local stack_size = item.components.stackable ~= nil
                and item.components.stackable:StackSize()
                or 1
            local reserve = math.max(
                reserves[item.prefab],
                extra_reserve ~= nil
                    and extra_reserve(inst, item.prefab)
                    or 0
            )
            if reserve > 0 and stack_size <= reserve then
                reserves[item.prefab] = reserve - stack_size
            else
                local key = {
                    -sanity_gain,
                    FOOD_VALUE[item.prefab] or 16,
                    PerishPercent(item),
                    item.prefab,
                }
                if best_key == nil
                    or key[1] < best_key[1]
                    or (
                        key[1] == best_key[1]
                        and (
                            key[2] < best_key[2]
                            or (
                                key[2] == best_key[2]
                                and (
                                    key[3] < best_key[3]
                                    or (
                                        key[3] == best_key[3]
                                        and key[4] < best_key[4]
                                    )
                                )
                            )
                        )
                    )
                then
                    best = item
                    best_key = key
                end
            end
        end
    end
    return best
end

local function IsGivingToPlayer(inst, player)
    local action = inst ~= nil and inst:GetBufferedAction() or nil
    return action ~= nil
        and (
            action.action == ACTIONS.GIVETOPLAYER
            or action.action == ACTIONS.GIVEALLTOPLAYER
        )
        and action.target == player
end

local function GiveToPlayerAction(item)
    return item ~= nil and item.components.stackable ~= nil
        and ACTIONS.GIVEALLTOPLAYER
        or ACTIONS.GIVETOPLAYER
end

local function SplitOneInventoryItem(inst, item)
    local inventory = inst ~= nil and inst.components.inventory or nil
    local stackable = item ~= nil and item.components.stackable or nil
    if inventory == nil or item == nil then
        return nil
    end
    if stackable == nil or stackable:StackSize() <= 1 then
        return item
    end
    local empty_slot = nil
    for slot = 1, inventory:GetNumSlots() do
        if inventory:GetItemInSlot(slot) == nil then
            empty_slot = slot
            break
        end
    end
    if empty_slot == nil then
        return nil
    end
    -- Stackable:Get preserves per-item data such as food freshness. Spawning
    -- a fresh prefab here would make an old portion look new and could cause
    -- the companion to waste the wrong ingredient.
    local split = stackable:Get(1)
    if split == nil then
        return nil
    end
    inventory:GiveItem(split, empty_slot)
    if split:IsValid()
        and split.components.inventoryitem ~= nil
        and split.components.inventoryitem.owner == inst
        and inventory:GetItemInSlot(empty_slot) == split
    then
        return split
    end
    if split:IsValid() then
        split:Remove()
    end
    stackable:SetStackSize(stackable:StackSize() + 1)
    return nil
end

local function SplitInventoryItemCount(inst, item, count)
    local inventory = inst ~= nil and inst.components.inventory or nil
    local stackable = item ~= nil and item.components.stackable or nil
    if inventory == nil or item == nil or count <= 0 then
        return nil
    end
    if stackable == nil or stackable:StackSize() <= count then
        return item
    end
    local empty_slot = nil
    for slot = 1, inventory:GetNumSlots() do
        if inventory:GetItemInSlot(slot) == nil then
            empty_slot = slot
            break
        end
    end
    if empty_slot == nil then
        return nil
    end
    local split = stackable:Get(count)
    if split == nil then
        return nil
    end
    inventory:GiveItem(split, empty_slot)
    if split:IsValid()
        and split.components.inventoryitem ~= nil
        and split.components.inventoryitem.owner == inst
        and inventory:GetItemInSlot(empty_slot) == split
    then
        return split
    end
    if split:IsValid() then
        split:Remove()
    end
    stackable:SetStackSize(stackable:StackSize() + count)
    return nil
end

local function FindInventoryTool(inst, action)
    local inventory = inst.components.inventory
    if inventory == nil then
        return nil
    end
    local best = nil
    local best_key = nil
    local function consider(item)
        local tool = item.components.tool
        local inherent = item.inherentactions ~= nil
            and item.inherentactions[action]
        local effectiveness = tool ~= nil
            and (tool:GetEffectiveness(action) or 0)
            or 0
        if inherent or effectiveness > 0 then
            local key = {
                BASIC_TOOL_COST[item.prefab] or 15,
                -effectiveness,
                InventoryPercent(item, "tool"),
                item.prefab,
            }
            if best_key == nil
                or key[1] < best_key[1]
                or (
                    key[1] == best_key[1]
                    and (
                        key[2] < best_key[2]
                        or (
                            key[2] == best_key[2]
                            and (
                                key[3] < best_key[3]
                                or (
                                    key[3] == best_key[3]
                                    and key[4] < best_key[4]
                                )
                            )
                        )
                    )
                )
            then
                best = item
                best_key = key
            end
        end
    end
    for _, item in pairs(inventory.itemslots) do
        consider(item)
    end
    for _, item in pairs(inventory.equipslots or {}) do
        consider(item)
    end
    return best
end

local function GetLandmarkParams(intent)
    if type(intent.params) ~= "table" then
        return nil, nil
    end
    local name = intent.params.landmark or intent.params.location_name
    if (type(name) ~= "string" or name == "")
        and intent.params.establish_home == true
    then
        -- Establishing a home stores the location under `name`. Keep the
        -- following homestead tick on the same record instead of requiring
        -- an unrelated `landmark` field.
        name = intent.params.name
    end
    if type(name) ~= "string" or name == "" then
        return nil, nil
    end
    return name, intent.params
end

local function IsHomeLandmarkName(name)
    return name == "家"
        or name == "基地"
        or name == "营地"
        or name == "据点"
        or name == "仓库"
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

local function IsActivelyHostileToCompanion(inst, entity, player)
    if entity == nil
        or entity == inst
        or not entity:IsValid()
        or entity.components.health == nil
        or entity.components.health:IsDead()
        or entity.components.combat == nil
    then
        return false
    end
    local target = entity.components.combat.target
    if target == inst or target == player then
        return true
    end
    return entity:HasTag("hound")
        or entity:HasTag("worm")
        or entity:HasTag("shadowcreature")
        or entity:HasTag("nightmarecreature")
end

local function DescribeEntity(inst, entity, player)
    local x, y, z = entity.Transform:GetWorldPosition()
    local inventoryitem = entity.components.inventoryitem
    local growable = entity.components.growable
    local dryer = entity.components.dryingrack or entity.components.dryer
    local drying_active = false
    local drying_done = false
    if dryer ~= nil and entity.components.container ~= nil then
        for _, rack_item in pairs(entity.components.container.slots or {}) do
            if rack_item ~= nil then
                if rack_item.components.dryable ~= nil then
                    drying_active = true
                elseif rack_item.components.edible ~= nil then
                    drying_done = true
                end
            end
        end
    end
    local stage_data = growable ~= nil
        and type(growable.GetCurrentStageData) == "function"
        and growable:GetCurrentStageData()
        or nil
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
        hostile = IsActivelyHostileToCompanion(inst, entity, player),
        pickable = entity.components.pickable ~= nil,
        workable = entity.components.workable ~= nil,
        harvestable = entity:HasTag("readyforharvest"),
        inventory_item = inventoryitem ~= nil,
        ground_item = inventoryitem ~= nil and inventoryitem.owner == nil,
        owner = inventoryitem ~= nil and inventoryitem.owner ~= nil
            and tostring(inventoryitem.owner.GUID)
            or nil,
        container = entity.components.container ~= nil,
        container_items = container_items,
        drying = dryer ~= nil,
        drying_active = drying_active,
        drying_done = drying_done,
        mature = stage_data == nil
            or stage_data.name == "full"
            or stage_data.name == "tall"
            or stage_data.name == "normal",
        stump = entity:HasTag("stump")
            or string.sub(entity.prefab or "", -6) == "_stump",
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
    self.network_request_started_at = nil
    self.network_request_id = 0
    self.network_inflight_events = nil
    self.last_action_target = nil
    self.last_action_name = nil
    self.ents = {}
    self.pending_events = {}
    self.seen_messages = {}
    self.speech_queue = {}
    self.last_speech_at = 0
    self.is_dead = false
    self.message_cursor = os.time()
    self.area_entities = {}
    self.route = nil
    self.fetch_state = nil
    self.harvest_state = nil
    self.area_state = nil
    self.collect_state = nil
    self.blocked_intents = {}
    self.server_non_sleepable_ready = false
    self.active_intent_id = nil
    self.active_intent_created_at = nil
    self.suppressed_intent_id = nil
    self.combat_target = nil
    self.combat_target_guid = nil
    self.combat_missing_since = nil
    self.combat_target_death_listener = nil
    self.last_combat_repath_at = 0
    self.combat_best_distance = nil
    self.combat_last_progress_at = nil
    self.next_codex_spell_at = 0
    self.next_codex_worker_spell_at = 0
    self.codex_spell_target_until = {}
    self.last_codex_notice_at = -math.huge
    self.skill_state = nil
    self.craft_state = nil
    self.build_state = nil
    self.till_state = nil
    self.plant_state = nil
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
    self.recovery_itemget_listener = nil
    self.home_state = nil
    self.home_chore_state = nil
    self.home_food_offer = nil
    self.home_heal_offer = nil
    self.home_sanity_offer = nil
    self.home_player_present = nil
    self.home_return_care_at = -math.huge
    self.last_home_chore_notice_at = {}
    self.emergency_warmth_state = nil
    self.emergency_next_check = 0
    self.emergency_state = nil
    self.last_observed_in_light = nil
    self.last_observed_in_light_at = nil
    self.emergency_notice_at = {}
    self.emergency_attack_memory = nil
    self.emergency_player_listener_target = nil
    self.emergency_native = {
        quake_warning = false,
        quaking = false,
        quake_started_at = nil,
        hound_warning_at = nil,
        hound_wave_seen = false,
        nightmare_phase = nil,
        frog_rain_drops = {},
        frog_rain_known = {},
        frog_rain_baseline_ready = false,
        frog_rain_seen_at = nil,
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
        and not entity:HasTag("irreplaceable")
        and (
            entity.brain ~= nil
            or entity.sg ~= nil
            or (
                entity.components.inventoryitem ~= nil
                and entity.components.inventoryitem.canbepickedup ~= false
                and not entity:HasTag("heavy")
            )
            or (
                entity.components.container ~= nil
                and not entity:HasTag("structure")
            )
            or (
                entity.components.workable ~= nil
                and entity:HasTag("tree")
            )
        )
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
        if target.entity ~= nil then
            target.entity:SetCanSleep(false)
        end
        -- A sleeping container can keep a pending STORE action forever. Wake
        -- it explicitly before walking to it; SetCanSleep(false) alone does
        -- not revive the already-buffered action on all world entities.
        if target:IsAsleep()
            and type(target.SetAwake) == "function"
        then
            target:SetAwake(true)
        end
        local inventoryitem = target.components.inventoryitem
        if inventoryitem ~= nil
            and inventoryitem.owner == nil
            and target:IsAsleep()
            and self.inst:GetDistanceSqToInst(target) <= 9
        then
            -- Some sleeping ground items do not resume a pending walk action
            -- even after SetCanSleep(false). Once the companion is already in
            -- pickup range, the native action body is safe to execute directly.
            local action = BufferedAction(self.inst, target, ACTIONS.PICKUP)
            if action:Do() then
                target.entity:SetCanSleep(true)
            end
        end
    end
end

function CodexCompanionBrain:EnsureAreaInventorySpace(intent)
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return false, "inventory_missing"
    end
    if not inventory:IsFull() then
        return true
    end
    local drop_prefab = self.area_state ~= nil
        and self.area_state.drop_prefab
        or nil
    if InventoryCanStackPrefab(inventory, drop_prefab) then
        return true
    end

    local item = FindDisposableDuplicateTool(self.inst, intent)
    if item == nil then
        return false, "inventory_full"
    end
    local prefab = item.prefab
    local player = GetPrimaryPlayer(self.inst)
    local handed_to_player = false
    if player ~= nil
        and player:IsValid()
        and player.components.inventory ~= nil
        and not player.components.inventory:IsFull()
        and self.inst:GetDistanceSqToInst(player) <= 64
    then
        handed_to_player = player.components.inventory:GiveItem(
            item,
            nil,
            self.inst:GetPosition()
        ) ~= nil
    end
    if not handed_to_player then
        inventory:DropItem(item, true)
    end
    self:QueueEvent("task_progress", {
        intent_id = intent.intent_id,
        mode = intent.mode,
        stage = "inventory_space_freed",
        item_prefab = prefab,
        duplicate_tool = true,
        handed_to_player = handed_to_player,
    })
    return true
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
    local landmark = {
        name = name,
        shard = TheShard:GetShardId(),
        x = Round(x),
        z = Round(z),
        saved_at = GetTime(),
    }
    self.inst._codex_landmarks = self.inst._codex_landmarks or {}
    self.inst._codex_landmarks[name] = landmark
    local is_home = params.establish_home == true
        or IsHomeLandmarkName(name)
    if is_home then
        self.inst._codex_home = landmark
        self.home_state = {
            intent_id = intent.intent_id,
            stage = "home",
            home_name = name,
            home_x = landmark.x,
            home_z = landmark.z,
            arrived_at = GetTime(),
        }
    end
    if self.inst._codex_save_state ~= nil then
        self.inst._codex_save_state()
    end
    if is_home then
        self:QueueEvent("task_progress", {
            intent_id = intent.intent_id,
            mode = "homestead",
            stage = "home_established",
            landmark = name,
            position = { landmark.x, landmark.z },
            shard = landmark.shard,
            stay_home = true,
            verified = true,
        })
        return
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

function CodexCompanionBrain:FindBestGroundFood()
    local eater = self.inst.components.eater
    if eater == nil then
        return nil
    end
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        0,
        z,
        HOME_LOCAL_SUPPLY_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        local inventoryitem = entity ~= self.inst
            and entity.components.inventoryitem
            or nil
        if inventoryitem ~= nil
            and inventoryitem.owner == nil
            and (
                inventoryitem.canbepickedup == nil
                or inventoryitem.canbepickedup
            )
            and entity.components.edible ~= nil
            and eater:CanEat(entity)
            and CanBeSeen(entity)
        then
            local distance = self.inst:GetDistanceSqToInst(entity)
            local current_best = best
            if best == nil
                or IsBetterFood(entity, current_best)
                or (
                    PerishPercent(entity) == PerishPercent(current_best)
                    and distance < best_distance
                )
            then
                best = entity
                best_distance = distance
            end
        end
    end
    return best
end

function CodexCompanionBrain:SeekHomeFood()
    if FindBestFood(self.inst, nil, self.intent) ~= nil then
        return false
    end
    local hunger = self.inst.components.hunger
    if hunger == nil
        or hunger.max <= 0
        or hunger.current / hunger.max >= 0.55
    then
        return false
    end
    if self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy") then
        return true
    end
    if self.inst:GetBufferedAction() ~= nil then
        return true
    end
    local food = self:FindBestGroundFood()
    if food ~= nil then
        self:KeepTargetAwake(food)
        self.inst:ClearBufferedAction()
        self.inst.components.locomotor:PushAction(
            BufferedAction(self.inst, food, ACTIONS.PICKUP),
            true
        )
        return true
    end

    local container, stored_food = self:FindBestHomeStoredFood()
    if container == nil or stored_food == nil then
        return false
    end
    local item_prefab = stored_food.prefab
    if not self:TakeOneFromHomeContainer(container, stored_food) then
        return false
    end
    self:NoticeHomeChore(
        "home_food_taken_from_storage",
        "我饿了，刚从家里箱子里拿了一份吃的",
        {
            item_prefab = item_prefab,
            container_prefab = container.prefab,
            verified = InventoryCount(self.inst, item_prefab) > 0,
        }
    )
    return true
end

function CodexCompanionBrain:NoticeHomeChore(stage, message, data)
    local now = GetTime()
    if now - (self.last_home_chore_notice_at[stage] or -math.huge)
        < HOME_CHORE_NOTICE_COOLDOWN_SECONDS
    then
        return
    end
    self.last_home_chore_notice_at[stage] = now
    local payload = data or {}
    payload.stage = stage
    payload.message = message
    payload.announce = false
    self:QueueEvent("home_chore_progress", payload)
end

function CodexCompanionBrain:EnqueueSpeech(message)
    if self.is_dead
        or self.inst:HasTag("playerghost")
        or type(message) ~= "string"
        or message == ""
        or #self.speech_queue >= 3
    then
        return false
    end
    for _, queued in ipairs(self.speech_queue) do
        if queued == message then
            return false
        end
    end
    table.insert(self.speech_queue, message)
    return true
end

function CodexCompanionBrain:GetHomeChoreCenter()
    local home = self.inst._codex_home
    if home ~= nil and home.x ~= nil and home.z ~= nil then
        return tonumber(home.x), tonumber(home.z), home.shard
    end
    local x, _, z = self.inst.Transform:GetWorldPosition()
    return x, z, TheShard:GetShardId()
end

local function IsHomeTidyItem(item)
    if item == nil
        or not item:IsValid()
        or item:HasTag("heavy")
        or item:HasTag("irreplaceable")
        or item:HasTag("questitem")
    then
        return false
    end
    local inventoryitem = item.components.inventoryitem
    if inventoryitem == nil or inventoryitem.canbepickedup == false then
        return false
    end
    return true
end

local function IsEquippedInventoryItem(inst, item)
    local inventory = inst ~= nil and inst.components.inventory or nil
    if inventory == nil or item == nil then
        return false
    end
    return inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == item
        or inventory:GetEquippedItem(EQUIPSLOTS.BODY) == item
        or inventory:GetEquippedItem(EQUIPSLOTS.HEAD) == item
end

local function IsPerishableFood(item)
    return item ~= nil
        and item.components.edible ~= nil
        and item.components.perishable ~= nil
end

local function IsTreeSeedPrefab(prefab)
    return prefab == "pinecone" or prefab == "acorn"
end

local function ToolActionKeys(item)
    local tool = item ~= nil and item.components.tool or nil
    if tool == nil then
        return nil
    end
    local keys = {}
    for action in pairs(tool.actions or {}) do
        table.insert(keys, action)
    end
    if #keys == 0 then
        keys[1] = item.prefab
    end
    return keys
end

local function WouldStoreLastToolCapability(inst, item)
    local action_keys = ToolActionKeys(item)
    if action_keys == nil then
        return false
    end
    local inventory = inst ~= nil and inst.components.inventory or nil
    if inventory == nil then
        return true
    end
    local matched = {}
    for _, other in pairs(inventory.itemslots) do
        if other ~= nil and other ~= item and other.components.tool ~= nil then
            for action in pairs(other.components.tool.actions or {}) do
                matched[action] = true
            end
        end
    end
    for _, action in ipairs(action_keys) do
        if not matched[action] then
            return true
        end
    end
    return false
end

function CodexCompanionBrain:GetHomeStorageCandidate(item)
    if not IsHomeTidyItem(item)
        or IsEquippedInventoryItem(self.inst, item)
    then
        return nil
    end
    local stack_size = item.components.stackable ~= nil
        and item.components.stackable:StackSize()
        or 1
    if IsPerishableFood(item) then
        local excess = InventoryEdiblePortionCount(self.inst)
            - AUTONOMY_KEEP_LAST_FOOD_PORTION
        if excess <= 0 then
            return nil
        end
        item = SplitInventoryItemCount(
            self.inst,
            item,
            math.min(stack_size, excess)
        )
        if item == nil then
            return nil
        end
    end
    if (
        item.components.fuel ~= nil
        or item.components.fueler ~= nil
    )
    then
        local excess = InventoryFuelPortionCount(
            self.inst,
            self.intent,
            nil
        ) - AUTONOMY_KEEP_LAST_FUEL_PORTION
        if excess <= 0 then
            return nil
        end
        item = SplitInventoryItemCount(
            self.inst,
            item,
            math.min(
                item.components.stackable ~= nil
                    and item.components.stackable:StackSize()
                    or 1,
                excess
            )
        )
        if item == nil then
            return nil
        end
    end
    if item:HasTag("tool")
        and WouldStoreLastToolCapability(self.inst, item)
    then
        return nil
    end
    if not IsTreeSeedPrefab(item.prefab) then
        return item
    end

    -- Keep enough seeds for the next compact home grove. Storing a whole
    -- stack would otherwise make the tree loop unable to replant after one
    -- chop, while storing none would defeat the tidying task.
    local total = InventoryCount(self.inst, item.prefab)
    local excess = total - HOME_CHORE_TREE_MIN_CLUSTER
    if excess <= 0 then
        return nil
    end
    local stackable = item.components.stackable
    local stacksize = stackable ~= nil and stackable:StackSize() or 1
    if stacksize <= excess then
        return item
    end
    local inventory = self.inst.components.inventory
    local empty_slot = nil
    for slot = 1, inventory:GetNumSlots() do
        if inventory:GetItemInSlot(slot) == nil then
            empty_slot = slot
            break
        end
    end
    if empty_slot == nil then
        return nil
    end
    local split = stackable:Get(excess)
    if split == nil then
        return nil
    end
    -- Stackable:Get assigns the split back to the same owner but does not put
    -- it in an inventory slot. Give it an explicit empty slot so it cannot
    -- immediately merge into the protected seed stack and invalidate STORE.
    inventory:GiveItem(split, empty_slot)
    if split:IsValid()
        and split.components.inventoryitem ~= nil
        and split.components.inventoryitem.owner == self.inst
        and inventory:GetItemInSlot(empty_slot) == split
    then
        return split
    end
    return nil
end

function CodexCompanionBrain:GetHomeStoredItemCandidates(can_use)
    local hx, hz, shard = self:GetHomeChoreCenter()
    if shard ~= nil and shard ~= TheShard:GetShardId() then
        return {}
    end
    local entities = TheSim:FindEntities(
        hx,
        0,
        hz,
        HOME_CHORE_STORAGE_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX", "player" }
    )
    local candidates = {}
    for _, entity in ipairs(entities) do
        local container = entity.components.container
        if entity ~= self.inst
            and container ~= nil
            and entity.prefab ~= "cookpot"
            and entity.prefab ~= "portablecookpot"
            and entity.prefab ~= "archive_cookpot"
            and entity.components.dryingrack == nil
            and entity.components.dryer == nil
            and not container:IsRestricted(self.inst)
        then
            for _, item in pairs(container.slots or {}) do
                if item ~= nil and can_use(item) then
                    table.insert(candidates, {
                        container = entity,
                        item = item,
                    })
                end
            end
        end
    end
    return candidates
end

function CodexCompanionBrain:FindHomeStoredItem(
    can_use,
    is_better
)
    local candidates = self:GetHomeStoredItemCandidates(can_use)
    local best_container = nil
    local best_item = nil
    for _, candidate in ipairs(candidates) do
        local item = candidate.item
        if item ~= nil
            and item:IsValid()
            and (
                best_item == nil
                or (
                    is_better ~= nil
                    and is_better(item, best_item)
                )
            )
        then
            best_container = candidate.container
            best_item = item
        end
    end
    return best_container, best_item
end

function CodexCompanionBrain:TakeOneFromHomeContainer(container, item)
    local inventory = self.inst.components.inventory
    local container_component = container ~= nil
        and container.components.container
        or nil
    if inventory == nil
        or container_component == nil
        or item == nil
        or inventory:IsFull()
    then
        return false
    end
    self:KeepTargetAwake(container)
    -- Sleeping is only an entity optimization; the container component remains
    -- authoritative on the server. SetCanSleep(false) prevents future sleeps,
    -- but old DST entities expose no reliable SetAwake, so refusing operations
    -- solely because the entity is already asleep breaks food and supply access.
    if not container:IsValid() then
        return false
    end
    local item_prefab = item.prefab
    local before = InventoryCount(self.inst, item_prefab)
    local removed = container_component:RemoveItem(item, false)
    if removed == nil then
        return false
    end
    local stackable = removed.components.stackable
    if stackable == nil or stackable:StackSize() <= 1 then
        if inventory:GiveItem(
            removed,
            nil,
            self.inst:GetPosition()
        ) and InventoryCount(self.inst, item_prefab) > before
        then
            return true
        end
        if removed:IsValid() then
            container_component:GiveItem(removed)
        end
        return false
    end

    -- Taking the whole stack left the base with fewer emergency supplies than
    -- intended. Split one fresh-and-oldness-correct portion, return the rest,
    -- and only report success after the companion's inventory really changed.
    local one = stackable:Get(1)
    if one == nil then
        container_component:GiveItem(removed)
        return false
    end
    if inventory:GiveItem(
        one,
        nil,
        self.inst:GetPosition()
    ) and InventoryCount(self.inst, item_prefab) > before
    then
        if removed:IsValid() then
            container_component:GiveItem(removed)
        end
        return true
    end
    if one:IsValid() then
        one:Remove()
        stackable:SetStackSize(stackable:StackSize() + 1)
    end
    if removed:IsValid() then
        container_component:GiveItem(removed)
    end
    return false
end

function CodexCompanionBrain:FindBestHomeStoredFood()
    local eater = self.inst.components.eater
    if eater == nil then
        return nil, nil
    end
    return self:FindHomeStoredItem(
        function(item)
            return item.components.edible ~= nil
                and eater:CanEat(item)
        end,
        IsBetterFood
    )
end

function CodexCompanionBrain:FindBestPlayerHomeStoredFood(
    player,
    deficit
)
    local eater = player ~= nil and player.components.eater or nil
    if eater == nil then
        return nil, nil
    end
    return self:FindHomeStoredItem(
        function(item)
            return item.components.edible ~= nil
                and eater:CanEat(item)
        end,
        function(candidate, current)
            return IsBetterPlayerFood(
                candidate,
                current,
                player,
                deficit
            )
        end
    )
end

function CodexCompanionBrain:FindBestPlayerInventoryFood(
    player,
    deficit
)
    local inventory = self.inst.components.inventory
    local eater = player ~= nil and player.components.eater or nil
    if inventory == nil or eater == nil then
        return nil
    end
    local best = nil
    for _, item in pairs(inventory.itemslots) do
        if item ~= nil
            and item.components.edible ~= nil
            and eater:CanEat(item)
            and not IsTaskInventoryItem(self.intent, item.prefab)
        then
            local stack = item.components.stackable
            local count = stack ~= nil and stack:StackSize() or 1
            local reserve = GetAutonomyFoodReserveCount(
                self.inst,
                item.prefab
            )
            if deficit >= HOME_PLAYER_MEAL_MIN_HUNGER_DEFICIT
                or count > reserve
            then
                if IsBetterPlayerFood(item, best, player, deficit) then
                    best = item
                end
            end
        end
    end
    return best
end

local function CookingPrefabPriority(prefab_list, prefab)
    for priority, candidate in ipairs(prefab_list) do
        if candidate == prefab then
            return priority
        end
    end
    return 999
end

function CodexCompanionBrain:CountHomeCookingPortions(prefab_list)
    local total = 0
    local inventory = self.inst.components.inventory
    if inventory ~= nil then
        for _, item in pairs(inventory.itemslots) do
            if item ~= nil
                and item.components.edible ~= nil
                and CookingPrefabPriority(prefab_list, item.prefab) < 999
                and not IsTaskInventoryItem(self.intent, item.prefab)
            then
                local stack = item.components.stackable
                total = total + (
                    stack ~= nil and stack:StackSize() or 1
                )
            end
        end
    end
    local candidates = self:GetHomeStoredItemCandidates(function(item)
        return item ~= nil
            and item.components.edible ~= nil
            and CookingPrefabPriority(prefab_list, item.prefab) < 999
    end)
    for _, candidate in ipairs(candidates) do
        local stack = candidate.item.components.stackable
        total = total + (
            stack ~= nil and stack:StackSize() or 1
        )
    end
    return total
end

function CodexCompanionBrain:GetHomeCookingPortions(prefab_list, required)
    local inventory = self.inst.components.inventory
    if inventory == nil or required <= 0 then
        return {}
    end
    local entries = {}
    for _, item in pairs(inventory.itemslots) do
        if item ~= nil
            and item.components.edible ~= nil
            and CookingPrefabPriority(prefab_list, item.prefab) < 999
            and not IsTaskInventoryItem(self.intent, item.prefab)
        then
            local stack = item.components.stackable
            local count = stack ~= nil and stack:StackSize() or 1
            for _ = 1, count do
                table.insert(entries, {
                    source = "inventory",
                    item = item,
                    prefab = item.prefab,
                    key = {
                        PerishPercent(item),
                        CookingPrefabPriority(prefab_list, item.prefab),
                        item.prefab,
                    },
                })
            end
        end
    end
    local candidates = self:GetHomeStoredItemCandidates(function(item)
        return item ~= nil
            and item.components.edible ~= nil
            and CookingPrefabPriority(prefab_list, item.prefab) < 999
    end)
    for _, candidate in ipairs(candidates) do
        local item = candidate.item
        local stack = item.components.stackable
        local count = stack ~= nil and stack:StackSize() or 1
        for _ = 1, count do
            table.insert(entries, {
                source = "home_storage",
                item = item,
                container = candidate.container,
                prefab = item.prefab,
                key = {
                    PerishPercent(item),
                    CookingPrefabPriority(prefab_list, item.prefab),
                    item.prefab,
                },
            })
        end
    end
    table.sort(entries, function(a, b)
        if a.key[1] ~= b.key[1] then
            return a.key[1] < b.key[1]
        end
        if a.key[2] ~= b.key[2] then
            return a.key[2] < b.key[2]
        end
        return a.key[3] < b.key[3]
    end)
    local result = {}
    for index = 1, math.min(required, #entries) do
        table.insert(result, entries[index])
    end
    return result
end

local function HomeStoragePriority(item)
    local perishable = item.components.perishable
    if perishable ~= nil then
        return perishable:GetPercent()
    end
    -- Low-value construction and burnable supplies are safe to tuck away
    -- first; rarer materials stay available for longer without extra work.
    return ({
        twigs = 0.20,
        cutgrass = 0.25,
        rocks = 0.30,
        flint = 0.35,
        log = 0.40,
        nitre = 0.75,
        marble = 0.80,
        goldnugget = 0.85,
        gears = 0.92,
        nightmarefuel = 0.94,
        thulecite = 0.97,
        thulecite_pieces = 0.98,
    })[item.prefab] or 0.60
end

local function HomeStorageCategory(item)
    if item == nil then
        return "unknown"
    end
    if item.components.edible ~= nil then
        return "food"
    end
    if item.components.fuel ~= nil or item.components.fueler ~= nil then
        return "fuel"
    end
    if item:HasTag("tool") or item.components.tool ~= nil then
        return "tools"
    end
    if item.components.armor ~= nil
        or item.components.weapon ~= nil
        or item.components.equippable ~= nil
    then
        return "equipment"
    end
    local prefab = item.prefab or ""
    if prefab == "log"
        or prefab == "boards"
        or prefab == "cutstone"
        or prefab == "rocks"
        or prefab == "flint"
        or prefab == "goldnugget"
        or prefab == "marble"
        or prefab == "nitre"
        or prefab == "gears"
    then
        return "materials"
    end
    return "utility"
end

function CodexCompanionBrain:FindHomeStorage(item)
    local hx, hz, shard = self:GetHomeChoreCenter()
    if shard ~= nil and shard ~= TheShard:GetShardId() then
        return nil
    end
    local entities = TheSim:FindEntities(
        hx,
        0,
        hz,
        HOME_CHORE_STORAGE_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local best = nil
    local best_score = math.huge
    for _, entity in ipairs(entities) do
        local container = entity.components.container
        local is_icebox = entity.prefab == "icebox"
        if entity ~= self.inst
            and CanBeSeen(entity)
            and container ~= nil
            and entity.prefab ~= "cookpot"
            and entity.prefab ~= "portablecookpot"
            and entity.prefab ~= "archive_cookpot"
            and entity.components.dryingrack == nil
            and entity.components.dryer == nil
            and (not is_icebox or IsPerishableFood(item))
            and not container:IsRestricted(self.inst)
            and (
                item == nil
                or container:CanTakeItemInSlot(item) ~= false
                and container:CanAcceptCount(item) > 0
            )
        then
            local distance = self.inst:GetDistanceSqToInst(entity)
            local score = distance
            if is_icebox and IsPerishableFood(item) then
                score = score - 10000
            end
            if item ~= nil then
                local wanted_category = HomeStorageCategory(item)
                for _, stored in pairs(container.slots) do
                    if stored ~= nil then
                        if stored.prefab == item.prefab then
                            score = score - 1000
                            break
                        elseif HomeStorageCategory(stored) == wanted_category then
                            score = score - 250
                        end
                    end
                end
            end
            if score < best_score then
                best = entity
                best_score = score
            end
        end
    end
    return best
end

function CodexCompanionBrain:TryStoreOneHomeItem()
    local state = self.home_chore_state
    if state ~= nil
        and state.stage == "storing"
        and state.item ~= nil
    then
        local stored = not state.item:IsValid()
            or (
                state.item.components.inventoryitem ~= nil
                and state.item.components.inventoryitem.owner ~= self.inst
            )
        if stored then
            self:NoticeHomeChore(
                "item_stored",
                "地上的物资已经收进箱子",
                {
                    item_prefab = state.item_prefab
                        or (
                            state.item:IsValid()
                            and state.item.prefab
                            or nil
                        ),
                    container_prefab = state.chest ~= nil
                        and state.chest.prefab
                        or nil,
                    verified = true,
                }
            )
            self.home_chore_state = nil
            return true
        end
    end
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return false
    end
    local best_raw_item = nil
    local best_priority = math.huge
    for _, item in pairs(inventory.itemslots) do
        if IsHomeTidyItem(item)
            and not IsEquippedInventoryItem(self.inst, item)
            and not IsTaskInventoryItem(self.intent, item.prefab)
        then
            local eligible = true
            if IsPerishableFood(item) then
                eligible = InventoryEdiblePortionCount(self.inst)
                    > AUTONOMY_KEEP_LAST_FOOD_PORTION
            elseif (
                item.components.fuel ~= nil
                or item.components.fueler ~= nil
            )
            then
                eligible = InventoryFuelPortionCount(
                    self.inst,
                    self.intent,
                    nil
                ) > AUTONOMY_KEEP_LAST_FUEL_PORTION
            elseif item:HasTag("tool") then
                eligible = not WouldStoreLastToolCapability(
                    self.inst,
                    item
                )
            elseif IsTreeSeedPrefab(item.prefab) then
                eligible = InventoryCount(self.inst, item.prefab)
                    > HOME_CHORE_TREE_MIN_CLUSTER
            end
            local priority = HomeStoragePriority(item)
            if eligible and priority < best_priority then
                best_raw_item = item
                best_priority = priority
            end
        end
    end
    if best_raw_item == nil then
        return false
    end
    local best_item = self:GetHomeStorageCandidate(best_raw_item)
    local best_chest = best_item ~= nil
        and self:FindHomeStorage(best_item)
        or nil
    if best_item == nil or best_chest == nil then
        return false
    end
    state = state or {}
    state.stage = "storing"
    state.started_at = GetTime()
    state.item = best_item
    state.item_prefab = best_item.prefab
    state.chest = best_chest
    self.home_chore_state = state
    self:KeepTargetAwake(best_chest)
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(
        BufferedAction(self.inst, best_chest, ACTIONS.STORE, best_item),
        true
    )
    return true
end

function CodexCompanionBrain:FindHomeGroundStorageItem()
    local hx, hz, shard = self:GetHomeChoreCenter()
    if shard ~= nil and shard ~= TheShard:GetShardId() then
        return nil
    end
    local entities = TheSim:FindEntities(
        hx,
        0,
        hz,
        HOME_CHORE_SCAN_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        local inventoryitem = entity.components.inventoryitem
        if entity ~= self.inst
            and inventoryitem ~= nil
            and inventoryitem.owner == nil
            and IsHomeTidyItem(entity)
            and CanBeSeen(entity)
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

function CodexCompanionBrain:TryPickupHomeGroundItem()
    local item = self:FindHomeGroundStorageItem()
    if item == nil or self:FindHomeStorage(item) == nil then
        return false
    end
    self.home_chore_state = {
        stage = "picking_up",
        started_at = GetTime(),
        item = item,
    }
    self:KeepTargetAwake(item)
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(
        BufferedAction(self.inst, item, ACTIONS.PICKUP),
        true
    )
    return true
end

local function IsHomeRenewablePlant(entity)
    if entity == nil then
        return false
    end
    local prefab = entity.prefab or ""
    return entity:HasTag("grass")
        or entity:HasTag("sapling")
        or entity:HasTag("reeds")
        or prefab == "grass"
        or prefab == "grass_tall"
        or prefab == "grass_moon"
        or prefab == "sapling"
        or prefab == "sapling_moon"
        or prefab == "reeds"
        or prefab == "reeds_water"
end

local function IsHomeHarvestable(entity)
    if entity == nil then
        return false
    end
    local pickable = entity.components.pickable
    if pickable ~= nil and pickable:CanBePicked() then
        return entity:HasTag("bush")
            or entity:HasTag("farm_plant")
            or entity:HasTag("readyforharvest")
            or IsHomeRenewablePlant(entity)
    end
    if entity:HasTag("farm_plant") then
        local growable = entity.components.growable
        local stage_data = growable ~= nil
            and type(growable.GetCurrentStageData) == "function"
            and growable:GetCurrentStageData()
            or nil
        return stage_data ~= nil
            and stage_data.name == "full"
            and entity.components.workable ~= nil
            and entity.components.workable:CanBeWorked()
    end
    if entity:HasTag("readyforharvest") then
        local workable = entity.components.workable
        return workable == nil or workable:CanBeWorked()
    end
    return false
end

function CodexCompanionBrain:FindHomeHarvestable()
    local hx, hz, shard = self:GetHomeChoreCenter()
    if shard ~= nil and shard ~= TheShard:GetShardId() then
        return nil
    end
    local entities = TheSim:FindEntities(
        hx,
        0,
        hz,
        HOME_CHORE_SCAN_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        if entity ~= self.inst
            and CanBeSeen(entity)
            and IsHomeHarvestable(entity)
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

function CodexCompanionBrain:TryHarvestHomePlant()
    local state = self.home_chore_state
    if state ~= nil and state.stage == "harvesting_plant" then
        local target = state.target
        if target == nil
            or not target:IsValid()
            or not IsHomeHarvestable(target)
        then
            self:NoticeHomeChore(
                "home_plant_harvested",
                "基地成熟的作物或可再生资源已经收下来了",
                {
                    target_prefab = state.target_prefab,
                    target_guid = state.target_guid,
                    target_position = state.target_position,
                    verified = state.action_started == true,
                }
            )
            self.home_chore_state = nil
            return true
        end
        if self.inst.sg ~= nil
            and self.inst.sg:HasStateTag("busy")
        then
            return true
        end
        if self.inst:GetBufferedAction() ~= nil then
            return true
        end
        local action = target.components.pickable ~= nil
            and ACTIONS.PICK
            or target:HasTag("readyforharvest")
            and ACTIONS.HARVEST
            or (
                target.components.workable ~= nil
                and target.components.workable:GetWorkAction()
            )
        if action == nil then
            self.home_chore_state = nil
            return false
        end
        state.action_started = true
        self:KeepTargetAwake(target)
        self.inst:ClearBufferedAction()
        self.inst.components.locomotor:PushAction(
            BufferedAction(self.inst, target, action),
            true
        )
        return true
    end

    local target = self:FindHomeHarvestable()
    if target == nil then
        return false
    end
    local target_x, _, target_z = target.Transform:GetWorldPosition()
    self.home_chore_state = {
        stage = "harvesting_plant",
        started_at = GetTime(),
        target = target,
        target_prefab = target.prefab,
        target_guid = tostring(target.GUID),
        target_position = {
            Round(target_x),
            Round(target_z),
        },
        action_started = false,
    }
    return self:TryHarvestHomePlant()
end

local function HomeSeedForStump(stump)
    if stump == nil then
        return "pinecone"
    end
    if stump:HasTag("deciduoustree")
        or string.find(stump.prefab or "", "deciduous", 1, true) ~= nil
    then
        return "acorn"
    end
    return "pinecone"
end

local function IsMatureHomeTree(entity)
    if entity == nil
        or not entity:IsValid()
        or not entity:HasTag("tree")
        or entity.components.workable == nil
        or not entity.components.workable:CanBeWorked()
        or entity.components.workable:GetWorkAction() ~= ACTIONS.CHOP
    then
        return false
    end
    local growable = entity.components.growable
    local stage_data = growable ~= nil
        and type(growable.GetCurrentStageData) == "function"
        and growable:GetCurrentStageData()
        or nil
    return stage_data == nil
        or stage_data.name == "normal"
        or stage_data.name == "tall"
        or stage_data.name == "old"
end

local function HasAlignedForestNeighbors(x, z, layout)
    local aligned = 0
    for _, other in ipairs(layout) do
        local ox, _, oz = other.Transform:GetWorldPosition()
        local dx = math.abs(ox - x)
        local dz = math.abs(oz - z)
        local separated = dx > 0.25 or dz > 0.25
        if separated
            and (
                dx <= HOME_FOREST_ALIGN_TOLERANCE
                or dz <= HOME_FOREST_ALIGN_TOLERANCE
            )
        then
            aligned = aligned + 1
            if aligned >= HOME_CHORE_TREE_MIN_CLUSTER - 1 then
                return true
            end
        end
    end
    return false
end

function CodexCompanionBrain:GetHomeForestLayout()
    local hx, hz, shard = self:GetHomeChoreCenter()
    if shard ~= nil and shard ~= TheShard:GetShardId() then
        return {}
    end
    local entities = TheSim:FindEntities(
        hx,
        0,
        hz,
        HOME_CHORE_SCAN_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX", "burnt" }
    )
    local layout = {}
    for _, entity in ipairs(entities) do
        if entity ~= self.inst
            and CanBeSeen(entity)
            and (
                entity:HasTag("tree")
                or entity:HasTag("stump")
            )
        then
            local x, _, z = entity.Transform:GetWorldPosition()
            local dx = x - hx
            local dz = z - hz
            if dx * dx + dz * dz <= HOME_CHORE_SCAN_RADIUS ^ 2 then
                table.insert(layout, entity)
            end
        end
    end
    return layout
end

function CodexCompanionBrain:IsHomeForestPoint(x, z)
    if x == nil or z == nil then
        return false
    end
    local layout = self:GetHomeForestLayout()
    if #layout < HOME_CHORE_TREE_MIN_CLUSTER then
        return false
    end
    return HasAlignedForestNeighbors(x, z, layout)
end

function CodexCompanionBrain:GetHomeForestTrees()
    local layout = self:GetHomeForestLayout()
    if #layout < HOME_CHORE_TREE_MIN_CLUSTER then
        return {}
    end
    local trees = {}
    for _, entity in ipairs(layout) do
        local x, _, z = entity.Transform:GetWorldPosition()
        if IsMatureHomeTree(entity)
            and HasAlignedForestNeighbors(x, z, layout)
        then
            table.insert(trees, entity)
        end
    end
    return trees
end

function CodexCompanionBrain:FindHomeStump()
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(self:GetHomeForestLayout()) do
        if entity:HasTag("stump")
            and entity.components.workable ~= nil
            and entity.components.workable:CanBeWorked()
        then
            local x, _, z = entity.Transform:GetWorldPosition()
            if self:IsHomeForestPoint(x, z) then
                local distance = self.inst:GetDistanceSqToInst(entity)
                if distance < best_distance then
                    best = entity
                    best_distance = distance
                end
            end
        end
    end
    return best
end

function CodexCompanionBrain:FindDeployPointNear(seed, x, z, avoid_points)
    local deployable = seed ~= nil and seed.components.deployable or nil
    if deployable == nil then
        return nil
    end
    local function IsAvoided(point)
        for _, avoided in ipairs(avoid_points or {}) do
            local dx = point.x - (tonumber(avoided.x) or math.huge)
            local dz = point.z - (tonumber(avoided.z) or math.huge)
            if dx * dx + dz * dz < 0.25 then
                return true
            end
        end
        return false
    end
    local point = Vector3(x, 0, z)
    if not IsAvoided(point)
        and deployable:CanDeploy(point, nil, self.inst, 0)
    then
        return point
    end
    for radius = 1.5, 5.5, 1 do
        for step = 0, 15 do
            local angle = step / 16 * TWOPI
            point = Vector3(
                x + math.cos(angle) * radius,
                0,
                z + math.sin(angle) * radius
            )
            if not IsAvoided(point)
                and deployable:CanDeploy(point, nil, self.inst, 0)
            then
                return point
            end
        end
    end
    return nil
end

function CodexCompanionBrain:DeployHomeTreeSeed(seed, position, source_prefab)
    if seed == nil or position == nil then
        return false
    end
    local state = self.home_chore_state or {}
    local attempt = (tonumber(state.replant_attempt) or 0) + 1
    local attempt_id = (tonumber(state.replant_attempt_id) or 0) + 1
    state.stage = "planting"
    state.seed = seed
    state.started_at = GetTime()
    state.replant_attempt = attempt
    state.replant_attempt_id = attempt_id
    state.pending_deploy = true
    state.tree_x = position.x
    state.tree_z = position.z
    self.home_chore_state = state
    local buffered = BufferedAction(
        self.inst,
        nil,
        ACTIONS.DEPLOY,
        seed,
        position
    )
    buffered:AddSuccessAction(function()
        local current = self.home_chore_state
        if current == nil
            or current.stage ~= "planting"
            or current.replant_attempt_id ~= attempt_id
        then
            return
        end
        self:NoticeHomeChore("tree_replanted", "树砍完了，也把树苗补种回去了", {
            source_tree = source_prefab,
            seed_prefab = seed.prefab,
            position = { Round(position.x), Round(position.z) },
            attempts = attempt,
            verified = true,
        })
        self.home_chore_state = nil
    end)
    buffered:AddFailAction(function()
        local current = self.home_chore_state
        if current == nil
            or current.stage ~= "planting"
            or current.replant_attempt_id ~= attempt_id
        then
            return
        end
        current.pending_deploy = false
        current.started_at = GetTime()
        current.tree_x = position.x
        current.tree_z = position.z
        current.replant_avoid_points = current.replant_avoid_points or {}
        table.insert(current.replant_avoid_points, {
            x = position.x,
            z = position.z,
        })
        if attempt >= HOME_TREE_REPLANT_MAX_ATTEMPTS then
            self:NoticeHomeChore(
                "tree_replant_failed",
                "附近暂时没有能顺利种树的位置，我先停在这里",
                {
                    source_tree = source_prefab,
                    seed_prefab = seed.prefab,
                    reason = "deploy_failed",
                    attempts = attempt,
                }
            )
            self.home_chore_state = nil
            return
        end
        current.stage = "replant_retry"
        self:NoticeHomeChore(
            "tree_replant_retry",
            "刚才那个位置没种下去，我换个地方再试",
            {
                source_tree = source_prefab,
                seed_prefab = seed.prefab,
                reason = "deploy_retry",
                attempt = attempt,
            }
        )
    end)
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(buffered, true)
    return true
end

function CodexCompanionBrain:TryReplantHomeTree()
    local state = self.home_chore_state
    if state ~= nil and state.stage == "planting" then
        return true
    end
    if state ~= nil
        and state.stage == "replant_retry"
        and GetTime() - (state.started_at or 0)
            < HOME_TREE_REPLANT_RETRY_DELAY_SECONDS
    then
        return true
    end
    if state ~= nil and state.stage == "digging_stump" then
        if state.stump ~= nil and state.stump:IsValid() then
            return true
        end
        state.stage = "deploy_after_dig"
    end

    local stump, x, z
    if state ~= nil
        and state.stage == "deploy_after_dig"
        and state.stump_x ~= nil
        and state.stump_z ~= nil
    then
        x, z = state.stump_x, state.stump_z
    elseif state ~= nil
        and state.stage == "replant_retry"
        and state.tree_x ~= nil
        and state.tree_z ~= nil
    then
        x, z = state.tree_x, state.tree_z
    else
        stump = self:FindHomeStump()
        if stump ~= nil then
            local stump_y
            x, stump_y, z = stump.Transform:GetWorldPosition()
        elseif state ~= nil
            and state.stage == "replant_after_chop"
            and state.tree_x ~= nil
            and state.tree_z ~= nil
        then
            x, z = state.tree_x, state.tree_z
        end
    end
    if x == nil or z == nil then
        return false
    end

    local seed_prefab = stump ~= nil
        and HomeSeedForStump(stump)
        or (
            state ~= nil
                and string.find(
                    state.tree_prefab or "",
                    "deciduous",
                    1,
                    true
                ) ~= nil
                and "acorn"
                or "pinecone"
        )
    local seed = FindInventoryItem(self.inst, seed_prefab)
    if seed == nil then
        self:NoticeHomeChore("tree_replant_waiting_seed", "附近还有树桩，但暂时没有对应树苗，我先不继续砍树", {
            required_seed = seed_prefab,
            reason = "seed_missing",
        })
        self.home_chore_state = nil
        return false
    end

    if stump ~= nil then
        local shovel = FindInventoryTool(self.inst, ACTIONS.DIG)
        if shovel ~= nil then
            local inventory = self.inst.components.inventory
            if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= shovel then
                inventory:Equip(shovel)
            end
            if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= shovel
                or self.inst.sg:HasStateTag("busy")
            then
                -- Equipping the shovel enters an item-out animation. Wait
                -- for that transition instead of planting next to the stump.
                return true
            end
            state = state or {}
            state.stage = "digging_stump"
            state.stump = stump
            state.stump_x = x
            state.stump_z = z
            state.tree_prefab = stump.prefab
            self.home_chore_state = state
            self.inst:ClearBufferedAction()
            self.inst.components.locomotor:PushAction(
                BufferedAction(self.inst, stump, ACTIONS.DIG, shovel),
                true
            )
            return true
        end
    end

    local point = self:FindDeployPointNear(
        seed,
        x,
        z,
        state ~= nil and state.replant_avoid_points or nil
    )
    if point == nil then
        self:NoticeHomeChore("tree_replant_blocked", "树桩旁边暂时没有能种树的位置", {
            required_seed = seed_prefab,
            reason = "deploy_position_blocked",
        })
        self.home_chore_state = nil
        return false
    end
    return self:DeployHomeTreeSeed(
        seed,
        point,
        state ~= nil and state.tree_prefab or stump.prefab
    )
end

function CodexCompanionBrain:EnsureHomeTool(tool_name)
    local action = TOOL_WORK_ACTIONS[tool_name]
    if action == nil then
        return false, "work_action_unknown"
    end
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return false, "inventory_missing"
    end
    local tool = FindInventoryTool(self.inst, action)
    if tool ~= nil then
        if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= tool then
            inventory:Equip(tool)
        end
        if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == tool then
            return true, "tool_ready"
        end
        return false, "tool_equipping"
    end
    local recipe = AllRecipes[tool_name]
    local builder = self.inst.components.builder
    if recipe == nil then
        return false, "tool_recipe_missing"
    end
    if builder == nil or not builder:KnowsRecipe(recipe) then
        return false, "tool_recipe_not_known"
    end
    if not builder:HasIngredients(recipe) then
        return false, "tool_ingredients_missing"
    end
    local state = self.home_chore_state or {}
    if state.tool_crafting then
        return false, "tool_crafting"
    end
    state.tool_crafting = true
    state.started_at = GetTime()
    self.home_chore_state = state
    local started = builder:MakeRecipe(
        recipe,
        self.inst:GetPosition(),
        nil,
        nil,
        function()
            if self.home_chore_state ~= nil then
                self.home_chore_state.tool_crafting = false
            end
            self:NoticeHomeChore("home_tool_crafted", "家里缺工具，我用现有材料做了一把", {
                item_prefab = tool_name,
                verified = true,
            })
        end
    )
    if not started then
        state.tool_crafting = false
        return false, "tool_craft_start_failed"
    end
    return false, "tool_crafting"
end

function CodexCompanionBrain:CountMatureHomeTrees()
    local count = 0
    for _, entity in ipairs(self:GetHomeForestTrees()) do
        if CanBeSeen(entity) then
            count = count + 1
        end
    end
    return count
end

function CodexCompanionBrain:FindHomeChopTree()
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(self:GetHomeForestTrees()) do
        if CanBeSeen(entity)
            and not entity:IsAsleep()
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

function CodexCompanionBrain:TryChopHomeTree()
    local state = self.home_chore_state
    if state ~= nil and state.stage == "chopping" then
        local tree = state.tree
        if tree == nil or not tree:IsValid() then
            state.stage = "replant_after_chop"
            state.tree = nil
            return true
        end
        local ready, reason = self:EnsureHomeTool("axe")
        if ready and not self.inst.sg:HasStateTag("busy") then
            self:KeepTargetAwake(tree)
            self.inst:ClearBufferedAction()
            self.inst.components.locomotor:PushAction(
                BufferedAction(
                    self.inst,
                    tree,
                    ACTIONS.CHOP,
                    FindInventoryTool(self.inst, ACTIONS.CHOP)
                ),
                true
            )
            return true
        end
        if reason == "tool_equipping"
            or reason == "tool_crafting"
            or ready
        then
            return true
        end
        if reason ~= "tool_crafting" then
            self:NoticeHomeChore("tree_chop_paused", "附近有成熟树，但我暂时处理不了斧头", {
                reason = reason,
            })
            self.home_chore_state = nil
        end
        return true
    end
    if self:FindHomeStump() ~= nil then
        return false
    end
    if self:CountMatureHomeTrees() < HOME_CHORE_TREE_MIN_CLUSTER then
        return false
    end
    local tree = self:FindHomeChopTree()
    if tree == nil then
        return false
    end
    local seed_prefab = HomeSeedForStump(tree)
    if FindInventoryItem(self.inst, seed_prefab) == nil then
        self:NoticeHomeChore("tree_chop_skipped_seed", "附近树林可以打理，但没有对应树苗，我先不砍", {
            required_seed = seed_prefab,
            reason = "seed_missing",
        })
        return false
    end
    local ready, reason = self:EnsureHomeTool("axe")
    if reason == "tool_crafting" or reason == "tool_equipping" then
        return true
    end
    if not ready then
        self:NoticeHomeChore("tree_chop_skipped_tool", "附近有成熟树，但我没有斧头也不能现做", {
            reason = reason,
            required_tool = "axe",
        })
        return false
    end
    local x, _, z = tree.Transform:GetWorldPosition()
    self.home_chore_state = {
        stage = "chopping",
        started_at = GetTime(),
        tree = tree,
        tree_x = x,
        tree_z = z,
        tree_prefab = tree.prefab,
    }
    self:KeepTargetAwake(tree)
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(
        BufferedAction(
            self.inst,
            tree,
            ACTIONS.CHOP,
            FindInventoryTool(self.inst, ACTIONS.CHOP)
        ),
        true
    )
    return true
end

function CodexCompanionBrain:FindHomeMarbleTree()
    local hx, hz = self:GetHomeChoreCenter()
    local entities = TheSim:FindEntities(
        hx,
        0,
        hz,
        HOME_CHORE_SCAN_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        if entity ~= self.inst
            and CanBeSeen(entity)
            and string.sub(entity.prefab or "", 1, 10) == "marbletree"
            and entity.components.workable ~= nil
            and entity.components.workable:CanBeWorked()
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

function CodexCompanionBrain:CountHomeMarbleTrees()
    local hx, hz = self:GetHomeChoreCenter()
    local entities = TheSim:FindEntities(
        hx,
        0,
        hz,
        HOME_CHORE_SCAN_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local count = 0
    for _, entity in ipairs(entities) do
        if entity ~= self.inst
            and CanBeSeen(entity)
            and string.sub(entity.prefab or "", 1, 10) == "marbletree"
            and entity.components.workable ~= nil
            and entity.components.workable:CanBeWorked()
        then
            count = count + 1
        end
    end
    return count
end

function CodexCompanionBrain:TryMineHomeMarble()
    local state = self.home_chore_state
    if state ~= nil and state.stage == "mining_marble" then
        if state.marble_tree == nil or not state.marble_tree:IsValid() then
            self:NoticeHomeChore("marble_mined", "基地附近的大理石树已经敲完", {
                item_prefab = "marble",
                verified = (InventoryCount(self.inst, "marble") or 0)
                    > (state.initial_marble or 0),
            })
            self.home_chore_state = nil
            return true
        end
        if state.marble_assist_requested ~= true
            and (tonumber(state.marble_cluster_size) or 0)
                >= HOME_CHORE_MARBLE_ASSIST_MIN_CLUSTER
        then
            state.marble_assist_requested = true
            local x, _, z = state.marble_tree.Transform:GetWorldPosition()
            local summoned, reason = self:TryCodexUmbraWorkerSpell(
                Vector3(x, 0, z),
                "resource_assist"
            )
            self:NoticeHomeChore(
                summoned and "marble_helper_summoned"
                    or "marble_helper_unavailable",
                summoned
                    and "大理石林比较大，我叫暗影仆从一起开采"
                    or "大理石林比较大，但这次不能安全召唤帮手",
                {
                    marble_cluster_size = state.marble_cluster_size,
                    reason = reason,
                    verified = summoned == true,
                }
            )
        end
        local ready, reason = self:EnsureHomeTool("pickaxe")
        if ready and not self.inst.sg:HasStateTag("busy") then
            self:KeepTargetAwake(state.marble_tree)
            self.inst:ClearBufferedAction()
            self.inst.components.locomotor:PushAction(
                BufferedAction(
                    self.inst,
                    state.marble_tree,
                    ACTIONS.MINE,
                    FindInventoryTool(self.inst, ACTIONS.MINE)
                ),
                true
            )
            return true
        end
        if reason == "tool_equipping"
            or reason == "tool_crafting"
            or ready
        then
            return true
        end
        if reason ~= "tool_crafting" then
            self:NoticeHomeChore("marble_paused", "基地附近有大理石树，但我暂时处理不了镐子", {
                reason = reason,
            })
            self.home_chore_state = nil
        end
        return true
    end
    local marble_tree = self:FindHomeMarbleTree()
    if marble_tree == nil then
        return false
    end
    local ready, reason = self:EnsureHomeTool("pickaxe")
    if reason == "tool_crafting" or reason == "tool_equipping" then
        return true
    end
    if not ready then
        self:NoticeHomeChore("marble_skipped_tool", "基地附近有大理石树，但我没有镐子也不能现做", {
            reason = reason,
            required_tool = "pickaxe",
        })
        return false
    end
    self.home_chore_state = {
        stage = "mining_marble",
        started_at = GetTime(),
        marble_tree = marble_tree,
        marble_cluster_size = self:CountHomeMarbleTrees(),
        initial_marble = InventoryCount(self.inst, "marble") or 0,
    }
    self:KeepTargetAwake(marble_tree)
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(
        BufferedAction(
            self.inst,
            marble_tree,
            ACTIONS.MINE,
            FindInventoryTool(self.inst, ACTIONS.MINE)
        ),
        true
    )
    return true
end

local function GetHomeDryingRackComponent(entity)
    if entity == nil or not entity:IsValid() then
        return nil
    end
    return entity.components.dryingrack
        or entity.components.dryer
        or nil
end

local function GetHomeDryingRackContainer(rack)
    local container = rack ~= nil
        and rack.components.container
        or nil
    return container
end

local function RackCanDryItem(dryer, item)
    if item == nil or item.components.edible == nil then
        return false
    end
    if type(dryer.CanDry) == "function" then
        return dryer:CanDry(item)
    end
    local dryable = item.components.dryable
    return dryable ~= nil
        and type(dryable.GetProduct) == "function"
        and type(dryable.GetDryTime) == "function"
        and dryable:GetProduct() ~= nil
        and dryable:GetDryTime() ~= nil
end

local function FindFinishedRackItem(rack)
    local container = GetHomeDryingRackContainer(rack)
    if container == nil then
        return nil
    end
    for _, item in pairs(container.slots or {}) do
        if item ~= nil
            and item:IsValid()
            and item.components.edible ~= nil
            and item.components.dryable == nil
        then
            return item
        end
    end
    return nil
end

local function RackContainsPrefab(rack, prefab)
    local container = GetHomeDryingRackContainer(rack)
    if container == nil or type(prefab) ~= "string" then
        return false
    end
    for _, item in pairs(container.slots or {}) do
        if item ~= nil and item:IsValid() and item.prefab == prefab then
            return true
        end
    end
    return false
end

function CodexCompanionBrain:FindHomeDryingRack()
    local hx, hz, shard = self:GetHomeChoreCenter()
    if shard ~= nil and shard ~= TheShard:GetShardId() then
        return nil
    end
    local entities = TheSim:FindEntities(
        hx,
        0,
        hz,
        HOME_CHORE_SCAN_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        if entity ~= self.inst
            and CanBeSeen(entity)
            and entity.prefab == "meatrack"
            and GetHomeDryingRackComponent(entity) ~= nil
            and GetHomeDryingRackContainer(entity) ~= nil
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

function CodexCompanionBrain:FindHomeDryableFood(rack)
    local inventory = self.inst.components.inventory
    local dryer = GetHomeDryingRackComponent(rack)
    local container = GetHomeDryingRackContainer(rack)
    if inventory == nil or dryer == nil or container == nil then
        return nil
    end
    local best = nil
    local best_key = nil
    for _, item in pairs(inventory.itemslots) do
        local stackable = item.components.stackable
        local stack_size = stackable ~= nil and stackable:StackSize() or 1
        local reserve = math.max(
            GetFoodReserveCount(self.inst, self.intent, item.prefab),
            GetAutonomyFoodReserveCount(self.inst, item.prefab)
        )
        if item.components.perishable ~= nil
            and stack_size > reserve
            and not IsTaskInventoryItem(self.intent, item.prefab)
            and RackCanDryItem(dryer, item)
            and container:CanTakeItemInSlot(item) ~= false
            and container:CanAcceptCount(item) > 0
        then
            local key = {
                PerishPercent(item),
                FOOD_VALUE[item.prefab] or 16,
                item.prefab,
            }
            if best_key == nil
                or key[1] < best_key[1]
                or (
                    key[1] == best_key[1]
                    and (
                        key[2] < best_key[2]
                        or (key[2] == best_key[2] and key[3] < best_key[3])
                    )
                )
            then
                best = item
                best_key = key
            end
        end
    end
    return best
end

function CodexCompanionBrain:TryMaintainHomeDryingRack()
    local state = self.home_chore_state
    local rack = state ~= nil
        and (state.dryer_rack or state.drying_rack)
        or nil
    if state ~= nil
        and (
            state.stage == "loading_dryer"
            or state.stage == "harvesting_dryer"
        )
    then
        local container = rack ~= nil
            and rack:IsValid()
            and GetHomeDryingRackContainer(rack)
            or nil
        if container == nil then
            self.home_chore_state = nil
            return false
        end
        if self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy") then
            return true
        end
        if self.inst:GetBufferedAction() ~= nil then
            return true
        end
        if state.stage == "loading_dryer"
            and RackContainsPrefab(rack, state.item_prefab)
        then
            self:NoticeHomeChore(
                "drying_started",
                "快坏的食材挂上晾肉架了，之后我会回来收",
                {
                    dryer_guid = state.dryer_guid,
                    item_prefab = state.item_prefab,
                    before = state.item_count_before,
                    after = InventoryCount(self.inst, state.item_prefab),
                    verified = true,
                }
            )
            self.home_chore_state = nil
            return true
        end
        if state.stage == "harvesting_dryer"
            and InventoryCount(self.inst, state.item_prefab)
                > (state.item_count_before or 0)
        then
            self:NoticeHomeChore(
                "dried_food_harvested",
                "晾肉架上的东西已经收下来了",
                {
                    dryer_guid = state.dryer_guid,
                    dryer_position = state.dryer_position,
                    item_prefab = state.item_prefab,
                    before = state.item_count_before,
                    after = InventoryCount(self.inst, state.item_prefab),
                    verified = true,
                }
            )
            self.home_chore_state = nil
            return true
        end
        if state.action_started ~= true then
            return true
        end
        self:NoticeHomeChore(
            "drying_action_failed",
            "这次没把东西挂上晾肉架，我先不收走你的食材",
            {
                dryer_guid = state.dryer_guid,
                item_prefab = state.item_prefab,
                reason = "native_action_not_verified",
            }
        )
        self.home_chore_state = nil
        return true
    end

    rack = self:FindHomeDryingRack()
    if rack == nil then
        return false
    end
    local container = GetHomeDryingRackContainer(rack)
    local finished = FindFinishedRackItem(rack)
    if finished ~= nil then
        local x, _, z = rack.Transform:GetWorldPosition()
        self.home_chore_state = {
            stage = "harvesting_dryer",
            started_at = GetTime(),
            dryer_rack = rack,
            dryer_guid = tostring(rack.GUID),
            dryer_position = { Round(x), Round(z) },
            item_prefab = finished.prefab,
            item_count_before = InventoryCount(self.inst, finished.prefab),
            action_started = false,
        }
        self:KeepTargetAwake(rack)
        self.inst:ClearBufferedAction()
        self.inst.components.locomotor:PushAction(
            BufferedAction(
                self.inst,
                rack,
                ACTIONS.HARVEST,
                finished
            ),
            true
        )
        self.home_chore_state.action_started = true
        return true
    end
    if container:IsFull() then
        return false
    end
    if TheWorld ~= nil and TheWorld.state.israining then
        return false
    end

    local food = self:FindHomeDryableFood(rack)
    local food_prefab = food ~= nil and food.prefab or nil
    local inventory_food = food_prefab ~= nil
        and FindInventoryItem(self.inst, food_prefab)
        or nil
    local portion = SplitOneInventoryItem(self.inst, inventory_food)
    if portion == nil then
        return false
    end
    local item_count_before = InventoryCount(self.inst, portion.prefab)
    local x, _, z = rack.Transform:GetWorldPosition()
    self.home_chore_state = {
        stage = "loading_dryer",
        started_at = GetTime(),
        dryer_rack = rack,
        dryer_guid = tostring(rack.GUID),
        dryer_position = { Round(x), Round(z) },
        item_prefab = portion.prefab,
        item_count_before = item_count_before,
        action_started = false,
    }
    local buffered = BufferedAction(
        self.inst,
        rack,
        ACTIONS.STORE,
        portion
    )
    buffered:AddFailAction(function()
        if portion:IsValid()
            and portion.components.inventoryitem ~= nil
            and portion.components.inventoryitem.owner == nil
        then
            self.inst.components.inventory:GiveItem(portion)
        end
    end)
    self:KeepTargetAwake(rack)
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(buffered, true)
    self.home_chore_state.action_started = true
    return true
end

function CodexCompanionBrain:FindHomeCookPot()
    local hx, hz = self:GetHomeChoreCenter()
    local entities = TheSim:FindEntities(
        hx,
        0,
        hz,
        HOME_CHORE_SCAN_RADIUS,
        { "stewer" },
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        if entity ~= self.inst
            and CanBeSeen(entity)
            and entity.components.stewer ~= nil
            and entity.components.container ~= nil
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

function CodexCompanionBrain:TryOfferHomeHealing()
    local player = GetPrimaryPlayer(self.inst)
    if player == nil
        or not player:IsValid()
        or player.components.inventory == nil
        or player.components.health == nil
    then
        return false
    end
    local state = self.home_heal_offer
    if state ~= nil then
        local player_after = InventoryCount(player, state.prefab)
        local delivered = player_after > (state.player_before or 0)
        if delivered
            or GetTime() - (state.started_at or GetTime()) > 8
        then
            self:NoticeHomeChore(
                delivered and "player_healing_delivered"
                    or "player_healing_offer_failed",
                delivered
                    and "玩家受伤了，我把较低阶的治疗品递了过去"
                    or "没能把治疗品递给玩家，我先停手检查背包",
                {
                    item_prefab = state.prefab,
                    player_before = state.player_before,
                    player_after = player_after,
                    source = state.source,
                    verified = delivered,
                }
            )
            self.home_heal_offer = nil
            return false
        end
        return true
    end

    local health = player.components.health
    if health.maxhealth <= 0
        or health.currenthealth / health.maxhealth
            >= HOME_PLAYER_HEAL_MIN_RATIO
        or self.inst:GetDistanceSqToInst(player) > 24 * 24
        or player.components.inventory:IsFull()
    then
        return false
    end
    if self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy") then
        return true
    end
    if self.inst:GetBufferedAction() ~= nil then
        return true
    end
    local health_ratio = health.currenthealth / health.maxhealth
    local healing_reserve = nil
    if health_ratio > HOME_PLAYER_CRITICAL_HEAL_RATIO then
        healing_reserve = GetAutonomyHealingReserveCount
    end
    local item = FindBestHealingItem(self.inst, healing_reserve)
    local portion = SplitOneInventoryItem(self.inst, item)
    if portion == nil then
        return false
    end
    self.home_heal_offer = {
        started_at = GetTime(),
        prefab = portion.prefab,
        player_before = InventoryCount(player, portion.prefab),
    }
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(
        BufferedAction(
            self.inst,
            player,
            GiveToPlayerAction(portion),
            portion
        ),
        true
    )
    return true
end

function CodexCompanionBrain:TryOfferHomeSanity()
    local player = GetPrimaryPlayer(self.inst)
    if player == nil
        or not player:IsValid()
        or player.components.inventory == nil
        or player.components.sanity == nil
    then
        return false
    end
    local state = self.home_sanity_offer
    if state ~= nil then
        local player_after = InventoryCount(player, state.prefab)
        local delivered = player_after > (state.player_before or 0)
        if delivered
            or GetTime() - (state.started_at or GetTime()) > 8
        then
            self:NoticeHomeChore(
                delivered and "player_sanity_delivered"
                    or "player_sanity_offer_failed",
                delivered
                    and "你精神太低了，我把能稳定精神的东西递给你"
                    or "没能把恢复精神的食物递给你，我先继续手头的事",
                {
                    item_prefab = state.prefab,
                    player_before = state.player_before,
                    player_after = player_after,
                    verified = delivered,
                }
            )
            self.home_sanity_offer = nil
            return false
        end
        return true
    end

    local sanity = player.components.sanity
    if sanity.max <= 0
        or sanity.current / sanity.max >= HOME_PLAYER_SANITY_MIN_RATIO
        or self.inst:GetDistanceSqToInst(player) > 24 * 24
        or player.components.inventory:IsFull()
    then
        return false
    end
    if self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy") then
        return true
    end
    if self.inst:GetBufferedAction() ~= nil then
        return true
    end
    local food = FindBestSanityFood(
        self.inst,
        player,
        self.intent,
        GetAutonomyFoodReserveCount
    )
    local portion = SplitOneInventoryItem(self.inst, food)
    if portion == nil then
        return false
    end
    self.home_sanity_offer = {
        started_at = GetTime(),
        prefab = portion.prefab,
        player_before = InventoryCount(player, portion.prefab),
    }
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(
        BufferedAction(
            self.inst,
            player,
            GiveToPlayerAction(portion),
            portion
        ),
        true
    )
    return true
end

function CodexCompanionBrain:FindHomeFireStructure()
    local hx, hz, shard = self:GetHomeChoreCenter()
    if shard ~= nil and shard ~= TheShard:GetShardId() then
        return nil
    end
    local entities = TheSim:FindEntities(
        hx,
        0,
        hz,
        HOME_CHORE_SCAN_RADIUS,
        { "campfire" },
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX", "burnt" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        local fueled = entity.components.fueled
        if entity ~= self.inst
            and CanBeSeen(entity)
            and fueled ~= nil
            and fueled:GetPercent() < HOME_CHORE_FIRE_REFUEL_PERCENT
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

function CodexCompanionBrain:TryMaintainHomeFire()
    if TheWorld ~= nil
        and TheWorld.state.issummer
        and not self.inst:IsFreezing()
    then
        return false
    end
    local state = self.home_chore_state
    if state ~= nil and state.stage == "refueling_fire" then
        local fire = state.fire
        local fueled = fire ~= nil and fire:IsValid()
            and fire.components.fueled
            or nil
        local added = fueled ~= nil
            and fueled:GetPercent() > (state.fire_percent or 0) + 0.001
        if not added
            and state.action_started ~= true
        then
            return true
        end
        if not added
            and fueled ~= nil
            and GetTime() - (state.started_at or GetTime()) <= 8
        then
            return true
        end
        self:NoticeHomeChore(
            added and "home_fire_refuelled" or "home_fire_refuel_failed",
            added
                and "家里火快灭了，我用较低价值燃料补上了"
                or "这次没补进燃料，我先检查火堆和背包",
            {
                fire_prefab = state.fire_prefab,
                fuel_prefab = state.fuel_prefab,
                before = state.fire_percent,
                after = fueled and fueled:GetPercent() or nil,
                verified = added,
            }
        )
        self.home_chore_state = nil
        return true
    end
    if self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy") then
        return true
    end
    if self.inst:GetBufferedAction() ~= nil then
        return true
    end
    local fire = self:FindHomeFireStructure()
    if fire == nil then
        return false
    end
    local fueled = fire.components.fueled
    local fuel = self:FindBestFuelFor(fire, true)
    local fuel_stack = fuel ~= nil
        and fuel.components.stackable
        or nil
    local fuel_count = fuel_stack ~= nil and fuel_stack:StackSize() or 1
    local fuel_reserve = fuel ~= nil
        and GetAutonomyFuelReserveCount(
            self.inst,
            self.intent,
            fuel.prefab,
            fueled
        )
        or 0
    if fuel ~= nil and fuel_count <= fuel_reserve then
        self:NoticeHomeChore(
            "home_fire_last_fuel_kept",
            "家里只剩最后一份应急燃料，我先留着，等真正需要照明或取暖时再用",
            {
                fuel_prefab = fuel.prefab,
                reserved_count = fuel_reserve,
            }
        )
        return false
    end
    local one_fuel = SplitOneInventoryItem(self.inst, fuel)
    if one_fuel == nil
        or (
            one_fuel.components.fuel == nil
            and one_fuel.components.fueler == nil
        )
    then
        return false
    end
    self.home_chore_state = {
        stage = "refueling_fire",
        started_at = GetTime(),
        fire = fire,
        fire_prefab = fire.prefab,
        fire_percent = fueled:GetPercent(),
        fuel_prefab = one_fuel.prefab,
        action_started = false,
    }
    self:KeepTargetAwake(fire)
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(
        BufferedAction(
            self.inst,
            fire,
            ACTIONS.ADDFUEL,
            one_fuel
        ),
        true
    )
    self.home_chore_state.action_started = true
    return true
end

function CodexCompanionBrain:TryOfferHomeFood()
    local player = GetPrimaryPlayer(self.inst)
    if player == nil
        or not player:IsValid()
        or player.components.inventory == nil
        or player.components.hunger == nil
    then
        return false
    end
    local state = self.home_food_offer
    if state ~= nil then
        local player_after = InventoryCount(player, state.prefab)
        local delivered = player_after > (state.player_before or 0)
        if delivered
            or GetTime() - (state.started_at or GetTime()) > 8
        then
            self:NoticeHomeChore(
                delivered and "player_food_delivered"
                    or "player_food_offer_failed",
                delivered
                    and "玩家有点饿，我按快坏优先给了现成食物"
                    or "没能把食物递给玩家，我先继续手头的事",
                {
                    item_prefab = state.prefab,
                    player_before = state.player_before,
                    player_after = player_after,
                    verified = delivered,
                }
            )
            self.home_food_offer = nil
            return false
        end
        return true
    end

    local hunger = player.components.hunger
    local deficit = math.max(0, hunger.max - hunger.current)
    if deficit < HOME_PLAYER_FOOD_OFFER_MIN_HUNGER_DEFICIT
        or self.inst:GetDistanceSqToInst(player) > 24 * 24
        or player.components.inventory:IsFull()
    then
        return false
    end
    if self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy") then
        return true
    end
    if self.inst:GetBufferedAction() ~= nil then
        return true
    end

    local food = self:FindBestPlayerInventoryFood(player, deficit)
    local home_container = nil
    if food == nil then
        home_container, food = self:FindBestPlayerHomeStoredFood(
            player,
            deficit
        )
        if home_container ~= nil
            and food ~= nil
            and not self:TakeOneFromHomeContainer(home_container, food)
        then
            return false
        end
    end
    local portion = SplitOneInventoryItem(self.inst, food)
    if portion == nil then
        return false
    end
    self.home_food_offer = {
        started_at = GetTime(),
        prefab = portion.prefab,
        player_before = InventoryCount(player, portion.prefab),
        source = home_container ~= nil and "home_storage" or "inventory",
    }
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(
        BufferedAction(
            self.inst,
            player,
            GiveToPlayerAction(portion),
            portion
        ),
        true
    )
    return true
end

function CodexCompanionBrain:TryGiveMealToPlayer(meal)
    local player = GetPrimaryPlayer(self.inst)
    if meal == nil
        or player == nil
        or not player:IsValid()
        or player.components.inventory == nil
        or player.components.inventory:IsFull()
        or self.inst:GetDistanceSqToInst(player) > 16
    then
        return false
    end
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(
        BufferedAction(
            self.inst,
            player,
            GiveToPlayerAction(meal),
            meal
        ),
        true
    )
    return true
end

function CodexCompanionBrain:TryHomePlayerMeal()
    local player = GetPrimaryPlayer(self.inst)
    if player == nil
        or not player:IsValid()
        or player.components.hunger == nil
        or self.inst:GetDistanceSqToInst(player) > 24 * 24
    then
        return false
    end
    local pot = self:FindHomeCookPot()
    if pot == nil then
        return false
    end
    local stewer = pot.components.stewer
    local container = pot.components.container
    if stewer:IsDone() then
        stewer:Harvest(self.inst)
        local meal = FindInventoryItem(self.inst, "meatballs")
            or FindInventoryItem(self.inst, "cookedmeat")
            or FindInventoryItem(self.inst, "smallmeat_cooked")
        if meal ~= nil then
            self:NoticeHomeChore("meal_ready", "锅里的饭好了，我给玩家送过去", {
                item_prefab = meal.prefab,
                verified = true,
            })
            self:TryGiveMealToPlayer(meal)
            return true
        end
        return false
    end
    if stewer:IsCooking()
        or not container:IsEmpty()
        or (
            type(container.CanOpen) == "function"
            and not container:CanOpen()
        )
    then
        return false
    end
    local hunger = player.components.hunger
    if hunger.max <= 0
        or hunger.max - hunger.current
            < HOME_PLAYER_MEAL_MIN_HUNGER_DEFICIT
    then
        return false
    end
    -- Validate the pot before taking ingredients out of storage or splitting
    -- stacks. A disabled or otherwise unusable pot must not trap four portions
    -- inside its container while reporting no meal started.
    if not stewer:CanCook() then
        return false
    end

    local inventory = self.inst.components.inventory
    if inventory == nil
        or self.inst:GetDistanceSqToInst(pot) > HOME_CHORE_SCAN_RADIUS ^ 2
    then
        return false
    end
    if self:CountHomeCookingPortions(HOME_MEAT_PREFABS) < 1
        or self:CountHomeCookingPortions(HOME_FILLER_PREFABS) < 3
    then
        return false
    end
    local portions = {}
    for _, entry in ipairs(
        self:GetHomeCookingPortions(HOME_MEAT_PREFABS, 1)
    ) do
        table.insert(portions, entry)
    end
    for _, entry in ipairs(
        self:GetHomeCookingPortions(HOME_FILLER_PREFABS, 3)
    ) do
        table.insert(portions, entry)
    end
    if #portions < 4 then
        return false
    end
    local chosen = {}
    for _, portion in ipairs(portions) do
        local item = portion.item
        if portion.source == "home_storage" then
            if not self:TakeOneFromHomeContainer(
                portion.container,
                item
            ) then
                return false
            end
            item = FindInventoryItem(self.inst, portion.prefab)
        end
        if item == nil or not item:IsValid() then
            return false
        end
        local stack = item.components.stackable
        local ingredient = stack ~= nil and stack:Get(1) or item
        if ingredient ~= nil and not container:GiveItem(ingredient) then
            if ingredient == item then
                return false
            elseif ingredient:IsValid() and ingredient.components.inventoryitem ~= nil then
                inventory:GiveItem(ingredient)
            end
            return false
        end
        table.insert(chosen, ingredient or item)
    end
    stewer:StartCooking(self.inst)
    self:NoticeHomeChore("meal_cooking", "玩家饿了，我用便宜食材做一份 Meatballs", {
        item_prefab = "meatballs",
        ingredients = {
            chosen[1] ~= nil and chosen[1].prefab or nil,
            chosen[2] ~= nil and chosen[2].prefab or nil,
            chosen[3] ~= nil and chosen[3].prefab or nil,
            chosen[4] ~= nil and chosen[4].prefab or nil,
        },
    })
    return true
end

function CodexCompanionBrain:RunHomeAutonomy(intent, emergency)
    local params = type(intent.params) == "table" and intent.params or {}
    if params.disable_autonomous_chores == true then
        return false
    end
    if emergency ~= nil then
        self.home_chore_state = nil
        self:NoticeHomeChore(
            "home_chore_interrupted",
            "家里附近还有危险，我先放下手里的活",
            {
                emergency_category = emergency.category,
                emergency_action = emergency.action,
                threat_count = emergency.threat_count,
            }
        )
        return false
    end
    if self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy") then
        return true
    end
    local pending_action = self.inst:GetBufferedAction()
    if pending_action ~= nil then
        self:KeepTargetAwake(pending_action.target)
        -- Do not cancel a server-side STORE merely because the target is
        -- sleeping. SetCanSleep(false) disables future sleep, while already
        -- sleeping world entities have no dependable wake method. The native
        -- action owns its own failure handling and the chore timeout below
        -- prevents a genuinely stuck action from lasting forever.
        return true
    end
    if self.home_chore_state ~= nil
        and self.home_chore_state.started_at ~= nil
        and GetTime() - self.home_chore_state.started_at
            > HOME_CHORE_ACTION_TIMEOUT_SECONDS
        and self.home_chore_state.stage ~= "replant_after_chop"
        and self.home_chore_state.stage ~= "deploy_after_dig"
    then
        self.home_chore_state = nil
    end
    if self:TryOfferHomeHealing() then
        return true
    end
    if self:TryOfferHomeSanity() then
        return true
    end
    if self:TryOfferHomeFood() then
        return true
    end
    if self:TryHomePlayerMeal() then
        return true
    end
    if self:TryMaintainHomeFire() then
        return true
    end
    if self:TryMaintainHomeDryingRack() then
        return true
    end
    if self:TryStoreOneHomeItem() then
        return true
    end
    if self:TryPickupHomeGroundItem() then
        return true
    end
    if self:TryHarvestHomePlant() then
        return true
    end
    if self:TryReplantHomeTree() then
        return true
    end
    if self:TryChopHomeTree() then
        return true
    end
    if self:TryMineHomeMarble() then
        return true
    end
    return false
end

function CodexCompanionBrain:CheckReturningPlayerCare(landmark)
    local player = GetPrimaryPlayer(self.inst)
    if player == nil
        or not player:IsValid()
        or landmark == nil
    then
        self.home_player_present = nil
        return
    end
    local shard = landmark.shard
    if shard ~= nil and shard ~= TheShard:GetShardId() then
        self.home_player_present = false
        return
    end
    local px, _, pz = player.Transform:GetWorldPosition()
    local dx = px - landmark.x
    local dz = pz - landmark.z
    local at_home = dx * dx + dz * dz
        <= HOME_PLAYER_PRESENCE_RADIUS ^ 2
    local was_present = self.home_player_present
    self.home_player_present = at_home
    if not at_home
        or was_present == true
        or GetTime() - self.home_return_care_at
            < HOME_RETURN_CARE_COOLDOWN_SECONDS
    then
        return
    end

    local message = nil
    local health = player.components.health
    local hunger = player.components.hunger
    local sanity = player.components.sanity
    if health ~= nil
        and health.maxhealth > 0
        and health.currenthealth / health.maxhealth
            < HOME_PLAYER_HEAL_MIN_RATIO
    then
        local reserve = health.currenthealth / health.maxhealth
                > HOME_PLAYER_CRITICAL_HEAL_RATIO
            and GetAutonomyHealingReserveCount
            or nil
        local healing = FindBestHealingItem(self.inst, reserve)
        message = healing ~= nil
                and "你受伤了，我来给你处理一下。"
            or "你受伤了，可家里没有能用的药，先别再挨打。"
    elseif hunger ~= nil and hunger.max > 0
        and hunger.max - hunger.current
            >= HOME_PLAYER_FOOD_OFFER_MIN_HUNGER_DEFICIT
    then
        local food = self:FindBestPlayerInventoryFood(
            player,
            hunger.max - hunger.current
        )
        if food == nil then
            local _, stored = self:FindBestPlayerHomeStoredFood(
                player,
                hunger.max - hunger.current
            )
            food = stored
        end
        local pot = self:FindHomeCookPot()
        local can_cook = pot ~= nil
            and pot.components.stewer ~= nil
            and pot.components.stewer:CanCook()
            and self:CountHomeCookingPortions(HOME_MEAT_PREFABS) >= 1
            and self:CountHomeCookingPortions(HOME_FILLER_PREFABS) >= 3
        if food ~= nil then
            message = "你饿了吧，我这儿有现成的吃的。"
        elseif can_cook then
            message = "你饿了，我去给你做点吃的。"
        else
            message = "你饿了，我先找找家里还有什么能吃。"
        end
    elseif sanity ~= nil and sanity.max > 0
        and sanity.current / sanity.max
            < HOME_PLAYER_SANITY_MIN_RATIO
    then
        local food = FindBestSanityFood(
            self.inst,
            player,
            self.intent,
            GetAutonomyFoodReserveCount
        )
        message = food ~= nil
                and "你精神不太好，我找点能稳住精神的东西。"
            or "你精神不太好，先离危险远一点，我再想办法。"
    end

    if message ~= nil then
        self.home_return_care_at = GetTime()
        self:EnqueueSpeech(message)
        self:QueueEvent("home_player_care_prompt", {
            stage = "return_home",
            message = message,
        })
    end
end

function CodexCompanionBrain:Homestead(intent, emergency)
    local params = type(intent.params) == "table" and intent.params or {}
    if params.establish_home == true
        and (
            self.home_state == nil
            or self.home_state.intent_id ~= intent.intent_id
            or self.home_state.stage ~= "home"
        )
    then
        self:RememberLocation(intent)
        return
    end
    local landmark = self:ResolveLandmark(intent)
    if landmark == nil then
        self:QueueEvent("task_failed", {
            intent_id = intent.intent_id,
            mode = "homestead",
            reason = "landmark_not_found",
        })
        self:SuppressIntent(intent)
        return
    end
    if self.home_state == nil
        or self.home_state.intent_id ~= intent.intent_id
    then
        self.home_state = {
            intent_id = intent.intent_id,
            stage = "travel",
            home_name = landmark.name,
            home_x = landmark.x,
            home_z = landmark.z,
            started_at = GetTime(),
        }
    end
    local state = self.home_state
    state.home_name = landmark.name
    state.home_x = landmark.x
    state.home_z = landmark.z
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local dx = landmark.x - x
    local dz = landmark.z - z
    local distance = math.sqrt(dx * dx + dz * dz)
    self:CheckReturningPlayerCare(landmark)
    if state.stage == "travel" then
        if distance <= HOME_ARRIVAL_DISTANCE then
            state.stage = "home"
            state.arrived_at = GetTime()
            self.route = nil
            self:QueueEvent("task_progress", {
                intent_id = intent.intent_id,
                mode = "homestead",
                stage = "home_reached",
                landmark = landmark.name,
                position = { landmark.x, landmark.z },
                stay_home = true,
                verified = true,
            })
        else
            self:NavigateTo(
                intent,
                landmark.x,
                landmark.z,
                HOME_ARRIVAL_DISTANCE,
                "homestead_travel"
            )
            return
        end
    end
    if distance > HOME_LOITER_RADIUS then
        self:NavigateTo(
            intent,
            landmark.x,
            landmark.z,
            HOME_ARRIVAL_DISTANCE,
            "homestead_return"
        )
        return
    end
    -- A homestead task can span several ticks while the companion walks to a
    -- chest, tree, or crop. Stopping unconditionally here clears the locomotor
    -- path every tick, leaving a valid buffered action permanently in "idle".
    if self.inst:GetBufferedAction() == nil
        and (
            self.inst.sg == nil
            or not self.inst.sg:HasStateTag("busy")
        )
    then
        self.inst.components.locomotor:Stop()
    end
    if not self:TryHomesteadThermalCare() then
        if not self:SeekHomeFood() then
            self:RunHomeAutonomy(intent, emergency)
        end
    end
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
                if known then
                    local available = builder:HasIngredients(recipe)
                    local recipe_data = {
                        name = recipe_name,
                        product = recipe.product,
                        placer = recipe.placer,
                        known = true,
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
    local player = GetPrimaryPlayer(self.inst)
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
            table.insert(nearby, DescribeEntity(self.inst, entity, player))
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
            local edible = item.components.edible
            inventory_counts[item.prefab] =
                (inventory_counts[item.prefab] or 0) + stacksize
            table.insert(inventory, {
                guid = tostring(item.GUID),
                prefab = item.prefab,
                edible = edible ~= nil,
                food_hunger = edible ~= nil
                    and edible:GetHunger(self.inst)
                    or nil,
                food_health = edible ~= nil
                    and edible:GetHealth(self.inst)
                    or nil,
                food_sanity = edible ~= nil
                    and edible:GetSanity(self.inst)
                    or nil,
                equippable = item.components.equippable ~= nil,
                slot = item.components.equippable ~= nil
                    and item.components.equippable.equipslot
                    or nil,
                stacksize = stacksize,
                perish_percent = item.components.perishable ~= nil
                    and Round(PerishPercent(item) * 100)
                    or nil,
                condition_percent = item.components.armor ~= nil
                    and Round(InventoryPercent(item, "armor") * 100)
                    or nil,
                armor_absorb_percent = item.components.armor ~= nil
                    and type(item.components.armor.absorb_percent) == "number"
                    and Round(item.components.armor.absorb_percent * 100)
                    or nil,
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
                armor_absorb_percent = item.components.armor ~= nil
                    and type(item.components.armor.absorb_percent) == "number"
                    and Round(item.components.armor.absorb_percent * 100)
                    or nil,
                condition_percent = item.components.armor ~= nil
                    and Round(InventoryPercent(item, "armor") * 100)
                    or nil,
            })
        end
    end

    local codex_book = FindInventoryItem(self.inst, CODEX_UMBRA_PREFAB)
    local codex_fueled = codex_book ~= nil
        and codex_book.components.fueled
        or nil
    local codex_state = nil
    if codex_fueled ~= nil then
        local fuel_percent = codex_fueled:GetPercent()
        codex_state = {
            fuel_percent = fuel_percent ~= nil
                and Round(fuel_percent * 100)
                or nil,
            empty = codex_fueled:IsEmpty(),
        }
    end
    local puppet_counts, puppet_total = GetCodexPuppetSummary(
        self.inst.components.petleash
    )
    local body_temperature = self.inst.components.temperature ~= nil
        and self.inst.components.temperature.current
        or nil
    local moisture = self.inst.components.moisture
    local wetness = moisture ~= nil and moisture.moistness or nil

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
            winter_insulation = HasInsulationType(self.inst, SEASONS.WINTER),
            summer_insulation = HasInsulationType(self.inst, SEASONS.SUMMER),
            shadow_puppet_counts = puppet_counts,
            shadow_puppet_total = puppet_total,
            codex_umbra = codex_state,
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
            health = player.components.health ~= nil
                and Round(player.components.health.currenthealth)
                or 0,
            max_health = player.components.health ~= nil
                and Round(player.components.health.maxhealth)
                or 0,
            hunger = player.components.hunger ~= nil
                and Round(player.components.hunger.current)
                or 0,
            max_hunger = player.components.hunger ~= nil
                and Round(player.components.hunger.max)
                or 0,
            sanity = player.components.sanity ~= nil
                and Round(player.components.sanity.current)
                or 0,
            max_sanity = player.components.sanity ~= nil
                and Round(player.components.sanity.max)
                or 0,
            freezing = player:IsFreezing(),
            overheating = player:IsOverheating(),
        },
        world = {
            shard = TheShard:GetShardId(),
            is_master = not TheShard:IsSecondary(),
            session_id = TheWorld.components.shardstate ~= nil
                and TheWorld.components.shardstate:GetMasterSessionId()
                or nil,
            day = TheWorld.state.cycles,
            remaining_days_in_season = TheWorld.state.remainingdaysinseason,
            elapsed_days_in_season = TheWorld.state.elapseddaysinseason,
            phase = TheWorld.state.phase,
            season = TheWorld.state.season,
            moon_phase = TheWorld.state.moonphase,
            is_waxing_moon = TheWorld.state.iswaxingmoon == true,
            is_full_moon = TheWorld.state.isfullmoon == true,
            is_new_moon = TheWorld.state.isnewmoon == true,
            raining = TheWorld.state.israining,
            snowing = TheWorld.state.issnowing,
            iswinter = TheWorld.state.iswinter == true,
            isspring = TheWorld.state.isspring == true,
            issummer = TheWorld.state.issummer == true,
            isautumn = TheWorld.state.isautumn == true,
            precipitation = TheWorld.state.precipitation,
            ambient_temperature = TheWorld.state.temperature ~= nil
                and Round(TheWorld.state.temperature)
                or nil,
            body_temperature = body_temperature ~= nil
                and Round(body_temperature)
                or nil,
            wetness = wetness ~= nil and Round(wetness) or nil,
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
        home = self.inst._codex_home or nil,
        capabilities = capabilities,
        nearby = nearby,
        events = events or {},
    }
end

function CodexCompanionBrain:OnBridgeResponse(result, success, http_code, sent_events)
    self.pending_request = false
    self.network_request_started_at = nil
    self.network_inflight_events = nil
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
                self:EnqueueSpeech(message.text)
            end
        end
    end
end

function CodexCompanionBrain:QueueEvent(event_type, payload)
    if self.is_dead and event_type ~= "companion_dead" then
        return
    end
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
        local elapsed = GetTime() - (self.network_request_started_at or GetTime())
        if elapsed <= NETWORK_REQUEST_TIMEOUT_SECONDS then
            return
        end
        self.pending_request = false
        self.network_request_started_at = nil
        for _, event in ipairs(self.network_inflight_events or {}) do
            table.insert(self.pending_events, event)
        end
        self.network_inflight_events = nil
    end
    self.pending_request = true
    self.network_request_started_at = GetTime()
    self.network_request_id = (self.network_request_id or 0) + 1
    local request_id = self.network_request_id
    local sent_events = self.pending_events
    self.pending_events = {}
    self.network_inflight_events = sent_events
    TheSim:QueryServer(
        self.bridge_url,
        function(result, success, http_code)
            if request_id ~= self.network_request_id then
                return
            end
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
    local intent_created_at = tostring(self.intent.created_at or "")
    if self.active_intent_id ~= self.intent.intent_id
        or (
            intent_created_at ~= ""
            and self.active_intent_created_at ~= intent_created_at
        )
    then
        self:StopAll()
        self.active_intent_id = self.intent.intent_id
        self.active_intent_created_at = intent_created_at
        self.route = nil
        self.fetch_state = nil
        self.harvest_state = nil
        self.area_state = nil
        self.collect_state = nil
        self.skill_state = nil
        self.craft_state = nil
        self.build_state = nil
        self.till_state = nil
        self.plant_state = nil
        self.home_state = nil
        self.home_chore_state = nil
        self.emergency_warmth_state = nil
        self.combat_started_at = nil
        self.last_combat_event_at = nil
        self:ClearCombatTarget()
        self.combat_missing_since = nil
        self.last_combat_repath_at = 0
        self.combat_best_distance = nil
        self.combat_last_progress_at = nil
        local params = type(self.intent.params) == "table"
            and self.intent.params
            or {}
        if params.wheel_command == true
            and params.force_recovery_check == true
        then
            if self.inst.sleepingbag ~= nil
                and self.inst.components.sleepingbaguser ~= nil
            then
                self.inst.components.sleepingbaguser:DoWakeUp()
            end
            self.recovery_state = nil
            self.recovery_next_check = 0
            self:QueueEvent("task_progress", {
                intent_id = self.intent.intent_id,
                mode = self.intent.mode,
                stage = "recovery_check_forced",
            })
        end
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
    self.home_chore_state = nil
    self.home_food_offer = nil
    self.home_heal_offer = nil
    self.home_sanity_offer = nil
    self.home_player_present = nil
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
    extra,
    success_handler
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
        if success_handler ~= nil then
            success_handler(payload)
            return
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

local function IsFarmSeed(item)
    return item ~= nil
        and item:HasTag("deployedfarmplant")
        and item.components.farmplantable ~= nil
end

function CodexCompanionBrain:FailFarmingTask(intent, reason, extra)
    local payload = {
        intent_id = intent.intent_id,
        mode = intent.mode,
        reason = reason,
    }
    for key, value in pairs(extra or {}) do
        payload[key] = value
    end
    self:QueueEvent("task_failed", payload)
    self:SuppressIntent(intent)
    self.till_state = nil
    self.plant_state = nil
end

function CodexCompanionBrain:FindFarmSoil(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local origin = self:GetActionPosition(intent)
    if origin == nil then
        local x, _, z = self.inst.Transform:GetWorldPosition()
        origin = Vector3(x, 0, z)
    end
    local radius = tonumber(params.soil_search_radius)
        or FARMING_SEARCH_RADIUS
    local entities = TheSim:FindEntities(
        origin.x,
        0,
        origin.z,
        radius,
        { "soil" },
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX", "plantedsoil" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        if entity ~= self.inst
            and entity:HasTag("soil")
            and not entity:HasTag("plantedsoil")
            and CanBeSeen(entity)
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

function CodexCompanionBrain:FindTillPoint(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local origin = self:GetActionPosition(intent)
    if origin == nil then
        local x, _, z = self.inst.Transform:GetWorldPosition()
        origin = Vector3(x, 0, z)
    end
    local radius = tonumber(params.soil_search_radius)
        or FARMING_TILL_SEARCH_RADIUS
    local checked = {}
    local function candidate(x, z)
        local cx, _, cz = TheWorld.Map:GetTileCenterPoint(x, 0, z)
        if cx == nil then
            return nil
        end
        local key = string.format("%.2f:%.2f", cx, cz)
        if checked[key] then
            return nil
        end
        checked[key] = true
        if TheWorld.Map:CanTillSoilAtPoint(cx, 0, cz, false) then
            return Vector3(cx, 0, cz)
        end
    end
    local point = candidate(origin.x, origin.z)
    if point ~= nil then
        return point
    end
    for distance = 1, math.max(1, math.floor(radius)) do
        for step = 0, 15 do
            local angle = step / 16 * TWOPI
            point = candidate(
                origin.x + math.cos(angle) * distance,
                origin.z + math.sin(angle) * distance
            )
            if point ~= nil then
                return point
            end
        end
    end
end

function CodexCompanionBrain:EnsureFarmingTool(intent, state)
    local inventory = self.inst.components.inventory
    if inventory == nil then
        self:FailFarmingTask(intent, "farming_inventory_missing")
        return false
    end
    local tool = FindInventoryTool(self.inst, ACTIONS.TILL)
    if tool ~= nil then
        if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= tool then
            inventory:Equip(tool)
        end
        if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= tool then
            self:FailFarmingTask(intent, "farming_tool_equip_failed", {
                required_tool = "farm_hoe",
                item_prefab = tool.prefab,
            })
            return false
        end
        state.tool_prefab = tool.prefab
        state.tool_craft_started_at = nil
        return true
    end

    local recipe = AllRecipes.farm_hoe
    local builder = self.inst.components.builder
    if recipe == nil then
        self:FailFarmingTask(intent, "farming_tool_recipe_missing", {
            required_tool = "farm_hoe",
        })
        return false
    end
    if builder == nil then
        self:FailFarmingTask(intent, "farming_builder_missing", {
            required_tool = "farm_hoe",
        })
        return false
    end
    if not builder:KnowsRecipe(recipe) then
        self:FailFarmingTask(intent, "farming_tool_recipe_not_known", {
            required_tool = "farm_hoe",
        })
        return false
    end
    if not builder:HasIngredients(recipe) then
        self:FailFarmingTask(intent, "farming_tool_ingredients_missing", {
            required_tool = "farm_hoe",
        })
        return false
    end

    local now = GetTime()
    if state.tool_craft_started_at ~= nil then
        if now - state.tool_craft_started_at
            > AREA_TOOL_CRAFT_TIMEOUT_SECONDS
        then
            self:FailFarmingTask(intent, "farming_tool_craft_timeout", {
                required_tool = "farm_hoe",
            })
        end
        return false
    end

    state.tool_craft_started_at = now
    self:QueueEvent("task_progress", {
        intent_id = intent.intent_id,
        mode = intent.mode,
        stage = "crafting_farming_tool",
        required_tool = "farm_hoe",
    })
    local started = builder:MakeRecipe(
        recipe,
        self.inst:GetPosition(),
        nil,
        nil,
        function()
            if state == self.till_state
                or state == self.plant_state
            then
                state.tool_craft_started_at = nil
                self:QueueEvent("task_progress", {
                    intent_id = intent.intent_id,
                    mode = intent.mode,
                    stage = "farming_tool_crafted",
                    required_tool = "farm_hoe",
                })
            end
        end
    )
    if not started then
        self:FailFarmingTask(intent, "farming_tool_craft_start_failed", {
            required_tool = "farm_hoe",
        })
    end
    return false
end

function CodexCompanionBrain:FindFarmPlantAt(position, radius)
    if position == nil then
        return nil
    end
    local entities = TheSim:FindEntities(
        position.x,
        0,
        position.z,
        radius or 0.75,
        { "farm_plant" },
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    for _, entity in ipairs(entities) do
        if CanBeSeen(entity) then
            return entity
        end
    end
end

function CodexCompanionBrain:FindFarmSoilAt(position, radius)
    if position == nil then
        return nil
    end
    local entities = TheSim:FindEntities(
        position.x,
        0,
        position.z,
        radius or 0.75,
        { "soil" },
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX", "plantedsoil" }
    )
    for _, entity in ipairs(entities) do
        if entity.prefab == "farm_soil"
            and entity:HasTag("soil")
            and CanBeSeen(entity)
        then
            return entity
        end
    end
end

function CodexCompanionBrain:CompleteFarmPlant(
    intent,
    item,
    soil,
    action_payload
)
    local state = self.plant_state
    if state == nil
        or state.intent_id ~= intent.intent_id
    then
        return
    end
    local after_count = InventoryCount(self.inst, item.prefab)
    local seed_delta = math.max(
        0,
        (state.initial_count or 0) - after_count
    )
    local planted = self:FindFarmPlantAt(soil:GetPosition(), 0.75)
    if seed_delta < 1 or planted == nil then
        self:FailFarmingTask(intent, "plant_not_verified", {
            item_prefab = item.prefab,
            seed_before = state.initial_count,
            seed_after = after_count,
            seed_delta = seed_delta,
            plant_found = planted ~= nil,
        })
        return
    end

    local plant_x, _, plant_z = planted.Transform:GetWorldPosition()
    local payload = {
        intent_id = intent.intent_id,
        mode = intent.mode,
        target_prefab = intent.target_prefab,
        item_prefab = item.prefab,
        amount = 1,
        requested_amount = 1,
        inventory_before = state.initial_count,
        inventory_after = after_count,
        companion_delta = seed_delta,
        seed_delta = seed_delta,
        plant_prefab = planted.prefab,
        position = {
            Round(plant_x),
            Round(plant_z),
        },
        delivered_to_player = false,
        verified = true,
        action = action_payload ~= nil and action_payload.action or nil,
    }
    self:QueueEvent("task_complete", payload)
    self:SuppressIntent(intent)
    self.plant_state = nil
end

function CodexCompanionBrain:PlantFarmSeed(intent, item)
    local params = type(intent.params) == "table" and intent.params or {}
    if self.plant_state == nil
        or self.plant_state.intent_id ~= intent.intent_id
    then
        self.plant_state = {
            intent_id = intent.intent_id,
            stage = "find_soil",
            started_at = GetTime(),
            initial_count = InventoryCount(self.inst, item.prefab),
        }
    end
    local state = self.plant_state
    if state.stage == "tilling" or state.stage == "planting" then
        return
    end

    local soil = self:FindFarmSoil(intent)
    if soil ~= nil then
        if self.inst:GetBufferedAction() ~= nil
            or (
                self.inst.sg ~= nil
                and self.inst.sg:HasStateTag("busy")
            )
        then
            return
        end
        local queued = self:QueueIntentAction(
            intent,
            ACTIONS.PLANTSOIL,
            soil,
            item,
            nil,
            "task_complete",
            {
                item_prefab = item.prefab,
                soil_prefab = soil.prefab,
                inventory_before = state.initial_count,
            },
            function(action_payload)
                self:CompleteFarmPlant(
                    intent,
                    item,
                    soil,
                    action_payload
                )
            end
        )
        if queued then
            state.stage = "planting"
        end
        return
    end

    if params.till_if_needed == false then
        self:FailFarmingTask(intent, "plant_soil_not_found", {
            item_prefab = item.prefab,
        })
        return
    end
    if not self:EnsureFarmingTool(intent, state) then
        return
    end
    local tool = FindInventoryTool(self.inst, ACTIONS.TILL)
    local position = self:FindTillPoint(intent)
    if tool == nil or position == nil then
        self:FailFarmingTask(intent, "plant_till_soil_not_found", {
            item_prefab = item.prefab,
            required_tool = "farm_hoe",
        })
        return
    end

    state.till_position = position
    if self.inst:GetBufferedAction() ~= nil
        or (
            self.inst.sg ~= nil
            and self.inst.sg:HasStateTag("busy")
        )
    then
        return
    end
    local queued = self:QueueIntentAction(
        intent,
        ACTIONS.TILL,
        nil,
        tool,
        position,
        "task_progress",
        {
            item_prefab = item.prefab,
            required_tool = "farm_hoe",
            stage = "tilling_soil",
        },
        function()
            if state ~= self.plant_state then
                return
            end
            if self:FindFarmSoilAt(position, 1.25) == nil then
                self:FailFarmingTask(intent, "till_not_verified", {
                    item_prefab = item.prefab,
                    required_tool = "farm_hoe",
                })
                return
            end
            state.stage = "find_soil"
            state.till_position = nil
            self:QueueEvent("task_progress", {
                intent_id = intent.intent_id,
                mode = intent.mode,
                stage = "soil_tilled",
                item_prefab = item.prefab,
                soil_verified = true,
            })
        end
    )
    if queued then
        state.stage = "tilling"
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
    if IsFarmSeed(item) then
        self:PlantFarmSeed(intent, item)
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
    if self.till_state == nil
        or self.till_state.intent_id ~= intent.intent_id
    then
        self.till_state = {
            intent_id = intent.intent_id,
            started_at = GetTime(),
        }
    end
    local state = self.till_state
    if state.queued then
        return
    end
    if not self:EnsureFarmingTool(intent, state) then
        return
    end
    local tool = FindInventoryTool(self.inst, ACTIONS.TILL)
    local position = self:FindTillPoint(intent)
    if tool == nil or position == nil then
        self:FailFarmingTask(intent, "till_soil_not_found", {
            required_tool = "farm_hoe",
        })
        return
    end
    if self.inst:GetBufferedAction() ~= nil
        or (
            self.inst.sg ~= nil
            and self.inst.sg:HasStateTag("busy")
        )
    then
        return
    end
    local queued = self:QueueIntentAction(
        intent,
        ACTIONS.TILL,
        nil,
        tool,
        position,
        "task_complete",
        {
            required_tool = "farm_hoe",
            position = { Round(position.x), Round(position.z) },
        },
        function(action_payload)
            local soil = self:FindFarmSoilAt(position, 1.25)
            if soil == nil then
                self:FailFarmingTask(intent, "till_not_verified", {
                    required_tool = "farm_hoe",
                    position = { Round(position.x), Round(position.z) },
                })
                return
            end
            action_payload.soil_prefab = soil.prefab
            action_payload.position = {
                Round(soil.Transform:GetWorldPosition()),
                Round(select(3, soil.Transform:GetWorldPosition())),
            }
            action_payload.verified = true
            self:QueueEvent("task_complete", action_payload)
            self:SuppressIntent(intent)
            self.till_state = nil
        end
    )
    if queued then
        state.queued = true
    end
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
    local function consider_item(item)
        if item == nil then
            return
        end
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
    for _, item in pairs(inventory.itemslots) do
        consider_item(item)
    end
    for _, item in pairs(inventory.equipslots or {}) do
        consider_item(item)
    end
    return best_weapon, best_armor
end

function CodexCompanionBrain:FindBestArmorBySlot()
    local inventory = self.inst.components.inventory
    if inventory == nil then
        return {}
    end
    local best_by_slot = {}
    local function consider_item(item)
        if item == nil then
            return
        end
        local armor = item.components.armor
        local equippable = item.components.equippable
        if armor == nil or equippable == nil then
            return
        end
        local slot = equippable.equipslot
        local condition_percent = armor.maxcondition ~= nil
            and armor.maxcondition > 0
            and (armor.condition or armor.maxcondition) / armor.maxcondition
            or 1
        local score = (armor.absorb_percent or 0) * condition_percent
        if score <= 0 then
            return
        end
        local current = best_by_slot[slot]
        if current == nil
            or score > current.score
            or (
                score == current.score
                and condition_percent > current.condition_percent
            )
        then
            best_by_slot[slot] = {
                item = item,
                score = score,
                condition_percent = condition_percent,
            }
        end
    end
    for _, item in pairs(inventory.itemslots) do
        consider_item(item)
    end
    for _, item in pairs(inventory.equipslots or {}) do
        consider_item(item)
    end
    return best_by_slot
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
    local best_weapon = self:FindBestEquipment(target)
    local weapon_slot = best_weapon ~= nil
        and best_weapon.components.equippable.equipslot
        or nil
    if best_weapon ~= nil
        and inventory:GetEquippedItem(weapon_slot) ~= best_weapon
    then
        inventory:Equip(best_weapon)
    end
    for slot, candidate in pairs(self:FindBestArmorBySlot()) do
        if inventory:GetEquippedItem(slot) ~= candidate.item then
            inventory:Equip(candidate.item)
        end
    end
end

function CodexCompanionBrain:HasCombatGearSufficient(target, threat_count)
    local health = self.inst.components.health
    local current_health = health ~= nil and health.currenthealth or nil
    local incoming_damage = EstimateIncomingDamage(target, self.inst)
    local survivable_hits = current_health ~= nil
        and incoming_damage ~= nil
        and incoming_damage > 0
        and current_health / incoming_damage
        or math.huge
    local threats = math.max(1, tonumber(threat_count) or 1)
    local best_weapon = self:FindBestEquipment(target)
    local weapon_damage = best_weapon ~= nil
        and best_weapon.components.weapon ~= nil
        and best_weapon.components.weapon:GetDamage(self.inst, target)
        or 0
    if type(weapon_damage) ~= "number" then
        weapon_damage = 0
    end
    local remaining_damage = 1
    for _, candidate in pairs(self:FindBestArmorBySlot()) do
        local armor = candidate.item.components.armor
        local condition_percent = armor.maxcondition ~= nil
            and armor.maxcondition > 0
            and (armor.condition or armor.maxcondition) / armor.maxcondition
            or 1
        remaining_damage = remaining_damage
            * (1 - (armor.absorb_percent or 0) * condition_percent)
    end
    local armor_absorb = 1 - remaining_damage
    return armor_absorb >= CODEX_GOOD_ARMOR_ABSORB
        and weapon_damage >= CODEX_GOOD_WEAPON_DAMAGE
        and survivable_hits >= math.max(CODEX_SAFE_HITS, threats * 2)
end

function CodexCompanionBrain:NotifyCodexSpellUnavailable(reason)
    local now = GetTime()
    if now - self.last_codex_notice_at < CODEX_NOTICE_COOLDOWN_SECONDS then
        return
    end
    self.last_codex_notice_at = now

    local messages = {
        sanity_low = "我的理智不够了，继续用暗影法典会失控。",
        no_fuel = "暗影法典里没有噩梦燃料了。",
        protector_full = "暗影保护者已经到上限了。",
        puppet_limit = "已经有五个暗影傀儡了，再召会更容易引来影怪。",
        cannot_cast = "这里没法展开暗影法术。",
    }
    local message = messages[reason]
    if message ~= nil then
        self:EnqueueSpeech(message)
    end
    self:QueueEvent("tactical_spell_unavailable", {
        spell = "codex_umbra",
        reason = reason,
    })
end

function CodexCompanionBrain:TryCodexUmbraCombatSpell(
    target,
    threat_count,
    category
)
    if self.inst.prefab ~= "waxwell" then
        return false, "not_waxwell"
    end
    local now = GetTime()
    if now < self.next_codex_spell_at then
        return false, "cooldown"
    end
    if target == nil
        or not target:IsValid()
        or target.components.health == nil
        or target.components.health:IsDead()
    then
        return false, "target_missing"
    end
    local target_guid = tostring(target.GUID)
    local target_cooldown_until =
        self.codex_spell_target_until[target_guid] or 0
    if now < target_cooldown_until then
        return false, "target_cooldown"
    elseif target_cooldown_until > 0 then
        self.codex_spell_target_until[target_guid] = nil
    end

    local book = FindInventoryItem(self.inst, CODEX_UMBRA_PREFAB)
    local spellbook = book ~= nil and book.components.spellbook or nil
    local aoespell = book ~= nil and book.components.aoespell or nil
    local fueled = book ~= nil and book.components.fueled or nil
    if spellbook == nil or aoespell == nil or fueled == nil then
        return false, "book_missing"
    end

    local health = self.inst.components.health
    local health_percent = health ~= nil and health.maxhealth > 0
        and health.currenthealth / health.maxhealth
        or 1
    local threats = tonumber(threat_count) or 1
    local is_boss = target:HasTag("epic")
        or target:HasTag("boss")
        or (target.components.health.maxhealth or 0) >= 1000
    local urgent = category == "lethal_threat"
        or health_percent <= 0.35
        or is_boss
        or threats >= 3
    local gear_sufficient = self:HasCombatGearSufficient(target, threats)
    if not urgent or gear_sufficient then
        return false, "gear_sufficient"
    end

    local sanity = self.inst.components.sanity
    local sanity_percent = sanity ~= nil and sanity.max > 0
        and sanity.current / sanity.max
        or 1
    if sanity_percent < CODEX_MIN_SANITY_PERCENT then
        self:NotifyCodexSpellUnavailable("sanity_low")
        self.next_codex_spell_at = now + CODEX_NOTICE_COOLDOWN_SECONDS
        return false, "sanity_low"
    end
    if fueled:IsEmpty()
        or fueled:GetPercent() < CODEX_MIN_FUEL_PERCENT
    then
        self:NotifyCodexSpellUnavailable("no_fuel")
        self.next_codex_spell_at = now + CODEX_NOTICE_COOLDOWN_SECONDS
        return false, "no_fuel"
    end

    local petleash = self.inst.components.petleash
    local _, puppet_total = GetCodexPuppetSummary(petleash)
    if puppet_total >= CODEX_RECOMMENDED_MAX_PUPPETS then
        self:NotifyCodexSpellUnavailable("puppet_limit")
        self.next_codex_spell_at = now + CODEX_SPELL_COOLDOWN_SECONDS
        return false, "puppet_limit"
    end
    local protector_count = CountLivePetsForPrefab(
        petleash,
        "shadowprotector"
    )
    local can_summon_protector = petleash ~= nil
        and not petleash:IsFull()
        and protector_count < 1
    local spell_index
    local spell_name
    if can_summon_protector
        and sanity_percent >= CODEX_MIN_SANITY_PERCENT
    then
        spell_index = CODEX_SPELL_PROTECTOR
        spell_name = "shadow_protector"
    elseif is_boss or category == "lethal_threat" then
        spell_index = CODEX_SPELL_PILLARS
        spell_name = "shadow_pillars"
    elseif threats >= 2 then
        spell_index = CODEX_SPELL_TRAP
        spell_name = "shadow_trap"
    elseif can_summon_protector then
        self:NotifyCodexSpellUnavailable("sanity_low")
        self.next_codex_spell_at = now + CODEX_NOTICE_COOLDOWN_SECONDS
        return false, "sanity_low"
    else
        self:NotifyCodexSpellUnavailable("protector_full")
        self.next_codex_spell_at = now + CODEX_SPELL_COOLDOWN_SECONDS
        return false, "protector_full"
    end

    if not spellbook:SelectSpell(spell_index) then
        return false, "spell_selection_failed"
    end
    local x, _, z = target.Transform:GetWorldPosition()
    local pos = Vector3(x, 0, z)
    if not aoespell:CanCast(self.inst, pos) then
        self:NotifyCodexSpellUnavailable("cannot_cast")
        self.next_codex_spell_at = now + CODEX_SPELL_COOLDOWN_SECONDS
        return false, "cannot_cast"
    end

    local success, reason = aoespell:CastSpell(self.inst, pos)
    if not success then
        return false, reason or "cast_failed"
    end

    self.next_codex_spell_at = now + CODEX_SPELL_COOLDOWN_SECONDS
    self.codex_spell_target_until[target_guid] =
        now + CODEX_TARGET_SPELL_COOLDOWN_SECONDS
    local fuel_percent = fueled:GetPercent()
    self:QueueEvent("tactical_spell", {
        spell = spell_name,
        target_guid = target_guid,
        target_prefab = target.prefab,
        threat_count = threat_count,
        sanity_percent = Round(sanity_percent * 100),
        fuel_percent = fuel_percent ~= nil
            and Round(fuel_percent * 100)
            or nil,
    })

    if spell_name == "shadow_protector" and petleash ~= nil then
        for _, pet in ipairs(
            GetLivePetsForPrefab(petleash, "shadowprotector")
        ) do
            if pet:IsValid() and pet.components.combat ~= nil then
                pet.components.combat:SetTarget(target)
            end
        end
        self:EnqueueSpeech("去吧，暗影保护者，替我挡住它们。")
    elseif spell_name == "shadow_trap" then
        self:EnqueueSpeech("布下暗影陷阱，别让它们靠近。")
    elseif spell_name == "shadow_pillars" then
        self:EnqueueSpeech("醒来吧，暗影柱。")
    end
    return true, spell_name
end

function CodexCompanionBrain:TryCodexUmbraWorkerSpell(pos, purpose)
    if self.inst.prefab ~= "waxwell" then
        return false, "not_waxwell"
    end
    local now = GetTime()
    if now < self.next_codex_worker_spell_at then
        return false, "cooldown"
    end

    local book = FindInventoryItem(self.inst, CODEX_UMBRA_PREFAB)
    local spellbook = book ~= nil and book.components.spellbook or nil
    local aoespell = book ~= nil and book.components.aoespell or nil
    local fueled = book ~= nil and book.components.fueled or nil
    if spellbook == nil or aoespell == nil or fueled == nil then
        return false, "book_missing"
    end
    if fueled:IsEmpty() or fueled:GetPercent() < CODEX_MIN_FUEL_PERCENT then
        return false, "no_fuel"
    end

    local sanity = self.inst.components.sanity
    local sanity_percent = sanity ~= nil and sanity.max > 0
        and sanity.current / sanity.max
        or 1
    if sanity_percent < CODEX_MIN_SANITY_PERCENT then
        return false, "sanity_low"
    end

    local petleash = self.inst.components.petleash
    if petleash == nil then
        return false, "petleash_missing"
    end
    if petleash:IsFull() then
        return false, "petleash_full"
    end
    local _, puppet_total = GetCodexPuppetSummary(petleash)
    if puppet_total >= CODEX_RECOMMENDED_MAX_PUPPETS then
        return false, "puppet_limit"
    end

    if not spellbook:SelectSpell(CODEX_SPELL_WORKER) then
        return false, "spell_selection_failed"
    end
    local cast_pos = pos
    if cast_pos == nil then
        local x, _, z = self.inst.Transform:GetWorldPosition()
        cast_pos = Vector3(x, 0, z)
    end
    if not aoespell:CanCast(self.inst, cast_pos) then
        return false, "cannot_cast"
    end
    local success, reason = aoespell:CastSpell(self.inst, cast_pos)
    if not success then
        return false, reason or "cast_failed"
    end

    self.next_codex_worker_spell_at =
        now + CODEX_WORKER_SPELL_COOLDOWN_SECONDS
    local fuel_percent = fueled:GetPercent()
    self:QueueEvent("tactical_spell", {
        spell = "shadow_worker",
        purpose = purpose or "work",
        sanity_percent = Round(sanity_percent * 100),
        fuel_percent = fuel_percent ~= nil
            and Round(fuel_percent * 100)
            or nil,
    })
    self:EnqueueSpeech(
        purpose == "resource_assist"
            and "出来吧，暗影仆从，分头处理这片资源。"
            or "出来吧，暗影仆从，替我分担手上的活。"
    )
    return true, "shadow_worker"
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
    self:TryCodexUmbraCombatSpell(target, 1, "combat")
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

    local food = FindBestFood(self.inst, nil, intent)
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
        intent_id = self.recovery_state ~= nil
            and self.recovery_state.original_intent_id
            or nil,
    }
    for key, value in pairs(extra or {}) do
        payload[key] = value
    end
    self:QueueEvent("recovery_unavailable", payload)
end

function CodexCompanionBrain:FindRecoveryTent()
    local player = GetPrimaryPlayer(self.inst)
    local home = self.inst._codex_home
    local active_home = self.intent ~= nil
        and self.intent.mode == "homestead"
    local x, _, z = 0, 0, 0
    if active_home
        and type(home) == "table"
        and home.x ~= nil
        and home.z ~= nil
    then
        x = tonumber(home.x)
        z = tonumber(home.z)
    else
        local origin = player ~= nil and player:IsValid() and player or self.inst
        x, _, z = origin.Transform:GetWorldPosition()
    end
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
    local player = GetPrimaryPlayer(self.inst)
    return FindEntity(
        self.inst,
        radius,
        function(entity)
            return IsActivelyHostileToCompanion(
                self.inst,
                entity,
                player
            )
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
    return IsActivelyHostileToCompanion(companion, entity, player)
end

local function IsLiveEmergencyThreat(entity)
    return entity ~= nil
        and entity:IsValid()
        and entity.components.health ~= nil
        and not entity.components.health:IsDead()
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
            frog_rain_seen_at = self.emergency_native.frog_rain_seen_at,
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
        player_distance = IsLiveEmergencyThreat(state.target)
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
        frog_rain_seen_at = self.emergency_native.frog_rain_seen_at,
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

function CodexCompanionBrain:TrackFrogRainDrops(now)
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local frogs = TheSim:FindEntities(
        x,
        0,
        z,
        EMERGENCY_FROG_RAIN_VERTICAL_SEARCH_RADIUS,
        { "frog" },
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local drops = self.emergency_native.frog_rain_drops
    local known = self.emergency_native.frog_rain_known
    local baseline_ready =
        self.emergency_native.frog_rain_baseline_ready == true
    local current = {}
    local nearby_count = 0
    for _, frog in ipairs(frogs) do
        local frog_x, frog_y, frog_z =
            frog.Transform:GetWorldPosition()
        local horizontal_sq =
            (frog_x - x) * (frog_x - x) + (frog_z - z) * (frog_z - z)
        if horizontal_sq
                <= EMERGENCY_FROG_RAIN_SCAN_RADIUS
                    * EMERGENCY_FROG_RAIN_SCAN_RADIUS
            and frog:IsValid()
            and CanBeSeen(frog)
            and frog.components.health ~= nil
            and not frog.components.health:IsDead()
        then
            nearby_count = nearby_count + 1
            local guid = tostring(frog.GUID)
            current[guid] = true
            -- Only a newly observed frog that is still above the ground can
            -- be evidence of rain. Preexisting pond frogs jumping or merely
            -- standing nearby during ordinary rain must never count.
            if baseline_ready
                and known[guid] ~= true
                and frog_y >= EMERGENCY_FROG_RAIN_FALL_HEIGHT
            then
                drops[guid] = now
            end
        end
    end
    self.emergency_native.frog_rain_known = current
    self.emergency_native.frog_rain_baseline_ready = true

    local recent_drop_count = 0
    for guid, seen_at in pairs(drops) do
        if now - seen_at <= EMERGENCY_FROG_RAIN_DROP_WINDOW_SECONDS then
            recent_drop_count = recent_drop_count + 1
        else
            drops[guid] = nil
        end
    end
    if recent_drop_count >= EMERGENCY_FROG_RAIN_MIN_DROPS then
        self.emergency_native.frog_rain_seen_at = now
    end
    return recent_drop_count, nearby_count
end

function CodexCompanionBrain:GetFirstLiveEmergencyThreat(state)
    local threats = state ~= nil and state.threats or nil
    if type(threats) ~= "table" then
        return nil, 0
    end
    local best
    local best_distance_sq = math.huge
    local live_count = 0
    for _, threat in ipairs(threats) do
        local entity = threat ~= nil and threat.entity or nil
        if IsLiveEmergencyThreat(entity) then
            live_count = live_count + 1
            local distance_sq = self.inst:GetDistanceSqToInst(entity)
            if distance_sq < best_distance_sq then
                best = entity
                best_distance_sq = distance_sq
            end
        end
    end
    return best, live_count
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
    local candidates = self:FindBestArmorBySlot()
    local equipped = false
    for slot, candidate in pairs(candidates) do
        if inventory:GetEquippedItem(slot) ~= candidate.item then
            inventory:Equip(candidate.item)
        end
        equipped = equipped
            or inventory:GetEquippedItem(slot) == candidate.item
    end
    if not equipped then
        return false
    end
    return true
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

local function IsHeatSource(entity, companion)
    local heater = entity ~= nil and entity.components.heater or nil
    if heater ~= nil
        and type(heater.GetHeat) == "function"
        and (
            type(heater.IsEndothermic) ~= "function"
            or not heater:IsEndothermic()
        )
    then
        local heat = heater:GetHeat(companion) or 0
        if heat > 0 then
            return heat
        end
    end
    local burnable = entity ~= nil and entity.components.burnable or nil
    if burnable ~= nil
        and type(burnable.IsBurning) == "function"
        and burnable:IsBurning()
        and (
            entity:HasTag("campfire")
            or entity.prefab == "campfire"
            or entity.prefab == "firepit"
        )
    then
        return 1
    end
    return 0
end

function CodexCompanionBrain:FindNearbyWarmthSource()
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        0,
        z,
        EMERGENCY_WARMTH_SEARCH_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX", "burnt" }
    )
    local best = nil
    local best_score = -math.huge
    for _, entity in ipairs(entities) do
        if entity ~= self.inst and CanBeSeen(entity) then
            local heat = IsHeatSource(entity, self.inst)
            if heat > 0 then
                local distance = self.inst:GetDistanceSqToInst(entity) ^ 0.5
                local score = heat * 10 - distance
                if score > best_score then
                    best = entity
                    best_score = score
                end
            end
        end
    end
    return best
end

local function IsCoolingSource(entity, companion)
    local heater = entity ~= nil and entity.components.heater or nil
    if heater == nil
        or type(heater.IsEndothermic) ~= "function"
        or not heater:IsEndothermic()
    then
        return false
    end
    local heat = type(heater.GetHeat) == "function"
        and (heater:GetHeat(companion) or 0)
        or 1
    return heat < 0 or entity:HasTag("coldfire")
end

function CodexCompanionBrain:FindNearbyCoolingSource()
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        0,
        z,
        EMERGENCY_WARMTH_SEARCH_RADIUS,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX", "burnt" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        if entity ~= self.inst
            and CanBeSeen(entity)
            and IsCoolingSource(entity, self.inst)
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

function CodexCompanionBrain:FindNearbyFireStructure()
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        0,
        z,
        EMERGENCY_WARMTH_SEARCH_RADIUS,
        { "campfire" },
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX", "burnt" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        if entity ~= self.inst and CanBeSeen(entity) then
            local distance = self.inst:GetDistanceSqToInst(entity)
            if distance < best_distance then
                best = entity
                best_distance = distance
            end
        end
    end
    return best
end

function CodexCompanionBrain:FindBestFuelFor(structure, avoid_task_items)
    local inventory = self.inst.components.inventory
    local fueled = structure ~= nil
        and structure.components.fueled
        or nil
    if inventory == nil or fueled == nil then
        return nil
    end
    local best = nil
    local best_key = nil
    for _, item in pairs(inventory.itemslots) do
        -- Fueled:CanAcceptFuelItem dereferences fuel without nil-checking it.
        -- Validate the item component before asking the target whether this
        -- fuel type is accepted.
        if (
                item.components.fuel ~= nil
                or item.components.fueler ~= nil
            )
            and fueled:CanAcceptFuelItem(item)
            and (
                not avoid_task_items
                or not IsTaskInventoryItem(self.intent, item.prefab)
            )
        then
            local key = {
                FUEL_VALUE[item.prefab] or 20,
                InventoryPercent(item, "fuel"),
                item.prefab,
            }
            if best_key == nil
                or key[1] < best_key[1]
                or (
                    key[1] == best_key[1]
                    and (
                        key[2] < best_key[2]
                        or (key[2] == best_key[2] and key[3] < best_key[3])
                    )
                )
            then
                best = item
                best_key = key
            end
        end
    end
    return best
end

function CodexCompanionBrain:RefuelWarmthSource(structure)
    local fueled = structure ~= nil
        and structure.components.fueled
        or nil
    if fueled == nil or fueled:IsEmpty() == false
        and fueled:GetPercent() >= EMERGENCY_WARMTH_REFUEL_PERCENT
    then
        return false
    end
    local fuel = self:FindBestFuelFor(structure)
    if fuel == nil then
        return false
    end
    local fuelled = fueled:TakeFuelItem(fuel, self.inst)
    if fuelled then
        self.capability_cache_at = -math.huge
    end
    return fuelled == true
end

function CodexCompanionBrain:StartEmergencyFire()
    local builder = self.inst.components.builder
    local recipe = AllRecipes.campfire
    if builder == nil or recipe == nil then
        return false
    end
    local product = recipe.product or "campfire"
    local now = GetTime()
    local state = self.emergency_warmth_state

    local item = FindInventoryItem(self.inst, product)
    if item ~= nil then
        local deployable = item.components.deployable
        if deployable == nil then
            self.emergency_warmth_state = {
                stage = "deploy_unavailable",
                reason = "campfire_not_deployable",
                started_at = now,
            }
            return false
        end
        if state ~= nil
            and state.stage == "deploying"
            and now - (state.started_at or now)
                < CRAFT_ACTION_TIMEOUT_SECONDS
        then
            return true
        end
        local position = self.inst:GetPosition()
        local can_deploy, reason = deployable:CanDeploy(
            position,
            nil,
            self.inst
        )
        if not can_deploy then
            self.emergency_warmth_state = {
                stage = "deploy_blocked",
                reason = reason or "campfire_deploy_invalid",
                started_at = now,
            }
            return false
        end
        self.emergency_warmth_state = {
            stage = "deploying",
            started_at = now,
            item_prefab = product,
        }
        self.inst:ClearBufferedAction()
        self.inst.components.locomotor:PushAction(
            BufferedAction(
                self.inst,
                nil,
                ACTIONS.DEPLOY,
                item,
                position
            ),
            true
        )
        return true
    end

    if state ~= nil
        and state.stage == "crafting"
        and now - (state.started_at or now) < CRAFT_ACTION_TIMEOUT_SECONDS
    then
        return true
    end
    if not builder:KnowsRecipe(recipe)
        or not builder:HasIngredients(recipe)
    then
        self.emergency_warmth_state = {
            stage = "craft_unavailable",
            reason = not builder:KnowsRecipe(recipe)
                and "campfire_recipe_not_known"
                or "campfire_ingredients_missing",
            started_at = now,
        }
        return false
    end

    self.emergency_warmth_state = {
        stage = "crafting",
        started_at = now,
        item_prefab = product,
    }
    local started = builder:MakeRecipe(
        recipe,
        self.inst:GetPosition(),
        nil,
        nil,
        function()
            if self.emergency_warmth_state ~= nil
                and self.emergency_warmth_state.stage == "crafting"
            then
                self.emergency_warmth_state.stage = "crafted"
                self.emergency_warmth_state.started_at = GetTime()
            end
            self.capability_cache_at = -math.huge
        end
    )
    if not started then
        self.emergency_warmth_state = nil
    end
    return started == true
end

function CodexCompanionBrain:TryEmergencyWarmth()
    local source = self:FindNearbyWarmthSource()
    if source ~= nil then
        self.emergency_warmth_state = nil
        local x, _, z = source.Transform:GetWorldPosition()
        local distance = self.inst:GetDistanceSqToPoint(x, 0, z) ^ 0.5
        if distance > EMERGENCY_WARMTH_STANDOFF_DISTANCE then
            self:MoveDirect(x, z)
            return "seek_warmth"
        end
        if self:RefuelWarmthSource(source) then
            return "refuel_warmth"
        end
        return "seek_warmth"
    end

    local structure = self:FindNearbyFireStructure()
    if structure ~= nil then
        self.emergency_warmth_state = nil
        local x, _, z = structure.Transform:GetWorldPosition()
        local distance = self.inst:GetDistanceSqToPoint(x, 0, z) ^ 0.5
        if distance > EMERGENCY_WARMTH_STANDOFF_DISTANCE then
            self:MoveDirect(x, z)
            return "seek_warmth"
        end
        if self:RefuelWarmthSource(structure) then
            return "refuel_warmth"
        end
    end

    if self:StartEmergencyFire() then
        return "building_warmth"
    end
    return "no_heat_available"
end

function CodexCompanionBrain:TryHomesteadThermalCare()
    local temperature = self.inst.components.temperature
    local current = temperature ~= nil and temperature.current or nil
    if current == nil then
        return false
    end
    if self.inst:IsFreezing()
        or (
            TheWorld.state.iswinter == true
            and current <= 12
        )
    then
        self:EquipThermalProtection(true)
        self:TryEmergencyWarmth()
        return true
    end
    if self.inst:IsOverheating()
        or (
            TheWorld.state.issummer == true
            and current >= 58
        )
    then
        self:EquipThermalProtection(false)
        local source = self:FindNearbyCoolingSource()
        if source ~= nil then
            local x, _, z = source.Transform:GetWorldPosition()
            local distance = self.inst:GetDistanceSqToPoint(x, 0, z) ^ 0.5
            if distance > EMERGENCY_WARMTH_STANDOFF_DISTANCE then
                self:MoveDirect(x, z)
            end
        end
        return true
    end
    return false
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
        if enabled
            and radius > 0
            and entity.prefab ~= "fireflies"
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

function CodexCompanionBrain:FindEmergencyGroundTorch()
    return FindEntity(
        self.inst,
        EMERGENCY_LIGHT_SEARCH_RADIUS,
        function(entity)
            local inventoryitem = entity.components.inventoryitem
            return entity.prefab == "torch"
                and inventoryitem ~= nil
                and inventoryitem.owner == nil
                and (
                    inventoryitem.canbepickedup == nil
                    or inventoryitem.canbepickedup
                )
                and not entity:HasTag("heavy")
                and CanBeSeen(entity)
        end,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
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
    local ground_torch = self:FindEmergencyGroundTorch()
    if ground_torch ~= nil then
        local current = self.inst:GetBufferedAction()
        if (current == nil or current.target ~= ground_torch)
            and (
                self.inst.sg == nil
                or not self.inst.sg:HasStateTag("busy")
            )
        then
            self:KeepTargetAwake(ground_torch)
            self.inst:ClearBufferedAction()
            self.inst.components.locomotor:PushAction(
                BufferedAction(self.inst, ground_torch, ACTIONS.PICKUP),
                true
            )
        end
        return "moving_to_light"
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
            source_prefab = state.source_prefab,
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
        frog_rain_drop_count = state.frog_rain_drop_count,
        frog_rain_nearby_count = state.frog_rain_nearby_count,
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
    self.last_observed_in_light = in_light
    self.last_observed_in_light_at = now
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
    local frog_rain_drop_count, frog_rain_nearby_count =
        self:TrackFrogRainDrops(now)

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
    local hound_wave = hound_attacking
        or (hound_warning and hound_count > 0)
    if hound_wave then
        self.emergency_native.hound_wave_seen = true
    elseif not hound_warning and not hound_attacking then
        self.emergency_native.hound_wave_seen = false
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
    elseif hound_wave then
        state = {
            category = "hound_wave",
            severity = "high",
            threat_count = #threats,
            source_prefab = hound_count > 0 and threats[1].entity.prefab or nil,
            target_prefab = hound_count > 0 and threats[1].entity.prefab or nil,
        }
    elseif frog_rain_drop_count >= EMERGENCY_FROG_RAIN_MIN_DROPS
        and frog_rain_nearby_count >= 2
        and TheWorld.state.isspring
        and TheWorld.state.israining
    then
        state = {
            category = "frog_rain",
            severity = "high",
            threat_count = #threats,
            source_prefab = "frog",
            frog_rain_drop_count = frog_rain_drop_count,
            frog_rain_nearby_count = frog_rain_nearby_count,
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
    elseif hound_warning and not self.emergency_native.hound_wave_seen then
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
        state.frog_rain_drop_count = frog_rain_drop_count
        state.frog_rain_nearby_count = frog_rain_nearby_count
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
                source_prefab = current.source_prefab,
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
    local target, live_threat_count = self:GetFirstLiveEmergencyThreat(state)
    if category == "lethal_threat"
        or category == "hostile_group"
        or category == "hound_wave"
        or category == "frog_rain"
        or category == "nightmare_riot"
        or category == "attacked"
    then
        if target ~= nil then
            self:TryCodexUmbraCombatSpell(
                target,
                live_threat_count > 0 and live_threat_count or 1,
                category
            )
        end
    end
    if category == "lethal_threat" then
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
    elseif category == "hound_wave" or category == "frog_rain" then
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
    elseif category == "hostile_group" then
        self:EquipBestArmor()
        if target ~= nil
            and self.inst:GetDistanceSqToInst(target)
                <= EMERGENCY_WAVE_ENGAGE_RADIUS ^ 2
            and self:HasCombatGearSufficient(target, live_threat_count)
        then
            if not self:EmergencyFightTarget(state, target, params) then
                self:EmergencyRally(state)
            end
        else
            self:EmergencyRally(state)
        end
    elseif category == "nightmare_riot" then
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
        elseif category == "freezing" then
            local action = self:TryEmergencyWarmth()
            self:SetEmergencyAction(state, action)
            if action == "no_heat_available" then
                self:EmergencyFollowPlayer()
            end
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
    return FindBestFood(self.inst, nil, self.intent)
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
    local item = FindBestHealingItem(self.inst)
    if item ~= nil then
        self:StopAll()
        self.inst.components.locomotor:PushAction(
            BufferedAction(self.inst, self.inst, ACTIONS.HEAL, item),
            true
        )
        return true
    end
    return false
end

function CodexCompanionBrain:NotifyRecoveryCompleted(method)
    local state = self.recovery_state or {}
    local payload = VitalityEvidence(self.inst)
    local health_gain = math.max(
        0,
        (payload.health or state.started_health or 0)
            - (state.started_health or payload.health or 0)
    )
    local sanity_gain = math.max(
        0,
        (payload.sanity or state.started_sanity or 0)
            - (state.started_sanity or payload.sanity or 0)
    )
    payload.method = method
    payload.intent_id = state.original_intent_id
    payload.health_gain = Round(health_gain)
    payload.sanity_gain = Round(sanity_gain)
    payload.started_health = state.started_health
    payload.started_health_max = state.started_health_max
    payload.started_hunger = state.started_hunger
    payload.started_hunger_max = state.started_hunger_max
    payload.started_sanity = state.started_sanity
    payload.started_sanity_max = state.started_sanity_max
    if method == "food" then
        payload.verified = (payload.hunger_percent or 0) >= 55
    elseif method == "healing_item" then
        payload.verified = (payload.health_percent or 0) >= 65
    else
        payload.verified = health_gain >= RECOVERY_MIN_HEALTH_GAIN
            or sanity_gain >= RECOVERY_MIN_SANITY_GAIN
    end
    self:QueueEvent("recovery_completed", payload)
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
    local vitals = VitalityEvidence(self.inst)
    local original_intent_id = intent ~= nil and intent.intent_id or nil

    if health_percent < 0.45 and self:TryRecoveryHealing() then
        self.recovery_state = {
            stage = "heal",
            started_at = GetTime(),
            original_intent_id = original_intent_id,
            started_health = vitals.health,
            started_health_max = vitals.health_max,
            started_hunger = vitals.hunger,
            started_hunger_max = vitals.hunger_max,
            started_sanity = vitals.sanity,
            started_sanity_max = vitals.sanity_max,
        }
        self:QueueEvent("recovery_started", {
            method = "healing_item",
            intent_id = original_intent_id,
            health = vitals.health,
            health_max = vitals.health_max,
            health_percent = vitals.health_percent,
            hunger = vitals.hunger,
            hunger_max = vitals.hunger_max,
            sanity = vitals.sanity,
            sanity_max = vitals.sanity_max,
        })
        return true
    end
    if hunger_percent < 0.55 then
        if self:QueueRecoveryEat(self:FindRecoveryFood()) then
            self.recovery_state = {
                stage = "eat",
                started_at = GetTime(),
                original_intent_id = original_intent_id,
                started_health = vitals.health,
                started_health_max = vitals.health_max,
                started_hunger = vitals.hunger,
                started_hunger_max = vitals.hunger_max,
                started_sanity = vitals.sanity,
                started_sanity_max = vitals.sanity_max,
            }
            self:QueueEvent("recovery_started", {
                method = "food",
                intent_id = original_intent_id,
                health = vitals.health,
                health_max = vitals.health_max,
                hunger = vitals.hunger,
                hunger_max = vitals.hunger_max,
                hunger_percent = vitals.hunger_percent,
                sanity = vitals.sanity,
                sanity_max = vitals.sanity_max,
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
        original_intent_id = original_intent_id,
        started_health = vitals.health,
        started_health_max = vitals.health_max,
        started_hunger = vitals.hunger,
        started_hunger_max = vitals.hunger_max,
        started_sanity = vitals.sanity,
        started_sanity_max = vitals.sanity_max,
        tent = tent,
        estimate = estimate_or_reason,
    }
    self:QueueEvent("recovery_started", {
        method = "tent",
        intent_id = original_intent_id,
        tent_prefab = tent.prefab,
        health = vitals.health,
        health_max = vitals.health_max,
        health_percent = vitals.health_percent,
        hunger = vitals.hunger,
        hunger_max = vitals.hunger_max,
        hunger_percent = vitals.hunger_percent,
        sanity = vitals.sanity,
        sanity_max = vitals.sanity_max,
        sanity_percent = vitals.sanity_percent,
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
    local resident_mode = intent ~= nil
        and (
            intent.mode == "follow"
            or intent.mode == "homestead"
        )
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
            and not resident_mode
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
    if self.recovery_state ~= nil then
        if self.recovery_state.stage == "sleeping" then
            -- Native sleepingbag effects can be committed after the sleeper
            -- entity is detached. Wait briefly before sampling rewards.
            self.recovery_state.stage = "waking"
            self.recovery_state.wake_started_at = GetTime()
            return true
        end
        if self.recovery_state.stage == "waking" then
            if GetTime() - (self.recovery_state.wake_started_at or GetTime())
                < RECOVERY_WAKE_EVIDENCE_DELAY_SECONDS
            then
                return true
            end
            self:NotifyRecoveryCompleted("tent")
            self.recovery_state = nil
            self.recovery_next_check = GetTime() + 5
            return false
        end
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
        local initial_count = InventoryCount(self.inst, prefab)
        self.collect_state = {
            intent_id = intent.intent_id,
            amount = desired,
            kills = 0,
            stage = "collect",
            started_at = GetTime(),
            no_progress_since = GetTime(),
            initial_count = initial_count,
            last_count = initial_count,
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
            before_amount = state.last_count or 0,
            after_amount = current,
            delta = current - (state.last_count or 0),
            desired_amount = desired,
            requested_amount = desired,
            kills = state.kills,
            verified = current > (state.last_count or 0),
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
        if state.stage ~= "return" then
            state.return_amount = current
            local player = GetPrimaryPlayer(self.inst)
            state.player_before = player ~= nil
                and InventoryCount(player, prefab)
                or nil
        end
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
            if state.player_before == nil then
                state.player_before = InventoryCount(player, prefab)
            end
            local item = self.inst.components.inventory:FindItem(function(candidate)
                return candidate ~= nil and candidate.prefab == prefab
            end)
            if item ~= nil then
                state.give_started_at = state.give_started_at or GetTime()
                if GetTime() - state.give_started_at > 8 then
                    self:FailCollect(intent, "player_inventory_full")
                    return
                end
                if IsGivingToPlayer(self.inst, player) then
                    return
                end
                if self.inst.sg == nil or not self.inst.sg:HasStateTag("busy") then
                    self.inst:ClearBufferedAction()
                    self.inst.components.locomotor:PushAction(
                        BufferedAction(
                            self.inst,
                            player,
                            GiveToPlayerAction(item),
                            item
                        ),
                        true
                    )
                end
                return
            end
            state.give_started_at = nil
        end
        local delivered = params.give_to_player ~= false
        local player_after = delivered
            and InventoryCount(player, prefab)
            or nil
        local player_delta = delivered
            and math.max(0, (player_after or 0) - (state.player_before or 0))
            or 0
        local companion_delta = math.max(
            0,
            (state.initial_count or 0) - current
        )
        local completed_amount = state.return_amount or current
        local delivered_verified = not delivered
            or (
                companion_delta > 0
                and player_delta >= completed_amount
            )
        self:QueueEvent("task_complete", {
            intent_id = intent.intent_id,
            mode = "collect_loot",
            item_prefab = prefab,
            amount = completed_amount,
            kills = state.kills,
            desired_amount = desired,
            requested_amount = desired,
            inventory_before = state.initial_count or 0,
            inventory_after = current,
            companion_delta = companion_delta,
            player_before = state.player_before,
            player_after = player_after,
            player_delta = player_delta,
            delivered_to_player = delivered,
            delivered_verified = delivered_verified,
            verified = delivered and delivered_verified
                or (
                    not delivered
                    and current >= desired
                    and (state.initial_count or 0) >= 0
                ),
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
    if target.components.pickable ~= nil then
        return ACTIONS.PICK
    elseif target:HasTag("readyforharvest") then
        return ACTIONS.HARVEST
    elseif target.components.workable ~= nil then
        return target.components.workable:GetWorkAction()
    elseif target.components.inventoryitem ~= nil then
        return ACTIONS.PICKUP
    elseif target.components.activatable ~= nil then
        return ACTIONS.ACTIVATE
    end
end

local function IsMatureGrowthStage(entity)
    local growable = entity ~= nil and entity.components.growable or nil
    if growable == nil then
        return true
    end
    if type(growable.GetCurrentStageData) ~= "function" then
        return false
    end
    local stage_data = growable:GetCurrentStageData()
    return stage_data ~= nil and stage_data.name == "full"
end

local function IsHarvestableNow(entity)
    if entity == nil then
        return false
    end
    local pickable = entity.components.pickable
    if pickable ~= nil then
        return pickable:CanBePicked()
    end
    if entity:HasTag("readyforharvest") then
        return true
    end
    local workable = entity.components.workable
    if workable == nil or not workable:CanBeWorked() then
        return false
    end
    if entity:HasTag("farm_plant") then
        return IsMatureGrowthStage(entity)
    end
    return true
end

local function IsTreeHarvestIntent(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local requested = intent.target_prefab
        or params.target_prefab
        or nil
    return requested == "evergreen"
        or requested == "deciduoustree"
        or params.drop_prefab == "log"
end

local function IsTreeStump(entity)
    return entity ~= nil
        and (
            entity:HasTag("stump")
            or entity.prefab == "evergreen_stump"
            or entity.prefab == "deciduoustree_stump"
        )
end

function CodexCompanionBrain:GetAreaRequestedPrefab(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    return intent.target_prefab
        or params.target_prefab
        or (
            type(params.target_prefabs) == "table"
            and params.target_prefabs[1]
            or nil
        )
end

function CodexCompanionBrain:FailAreaTask(intent, mode, reason, extra)
    local state = self.area_state
    local payload = {
        intent_id = intent.intent_id,
        mode = mode,
        reason = reason,
        target_prefab = self:GetAreaRequestedPrefab(intent),
        requested_amount = type(intent.params) == "table"
            and tonumber(intent.params.amount)
            or nil,
        amount = state ~= nil and state.collected or nil,
        targets_cleared = state ~= nil and state.count or nil,
    }
    for key, value in pairs(extra or {}) do
        payload[key] = value
    end
    self:QueueEvent("task_failed", payload)
    self:SuppressIntent(intent)
    self.area_state = nil
    self.harvest_state = nil
end

function CodexCompanionBrain:CompleteAreaTask(
    intent,
    mode,
    item_prefab,
    amount,
    verified,
    partial
)
    local state = self.area_state
    local params = type(intent.params) == "table" and intent.params or {}
    local desired = tonumber(params.amount)
    self:QueueEvent("task_complete", {
        intent_id = intent.intent_id,
        mode = mode,
        target_prefab = self:GetAreaRequestedPrefab(intent),
        item_prefab = item_prefab,
        amount = amount or (state ~= nil and state.count or 0),
        desired_amount = desired,
        requested_amount = desired,
        targets_cleared = state ~= nil and state.count or nil,
        collected_amount = state ~= nil and state.collected or nil,
        final_growth_only = true,
        growth_stage = "mature",
        verified = verified == true,
        partial = partial == true,
    })
    self:SuppressIntent(intent)
    self.area_state = nil
    self.harvest_state = nil
end

function CodexCompanionBrain:EnsureAreaTool(intent, mode)
    local params = type(intent.params) == "table" and intent.params or {}
    local tool_name = params.required_tool or params.tool_prefab
    if tool_name == nil then
        return true
    end
    local action = TOOL_WORK_ACTIONS[tool_name]
    if action == nil then
        self:FailAreaTask(intent, mode, "work_action_unknown", {
            required_tool = tool_name,
        })
        return false
    end

    local inventory = self.inst.components.inventory
    if inventory == nil then
        self:FailAreaTask(intent, mode, "inventory_missing")
        return false
    end
    local tool = FindInventoryTool(self.inst, action)
    if tool ~= nil then
        if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= tool then
            inventory:Equip(tool)
        end
        if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= tool then
            self:FailAreaTask(intent, mode, "tool_equip_failed", {
                required_tool = tool_name,
                item_prefab = tool.prefab,
            })
            return false
        end
        self.area_state.tool_prefab = tool.prefab
        return true
    end

    local state = self.area_state
    local recipe = AllRecipes[tool_name]
    local builder = self.inst.components.builder
    if recipe == nil then
        self:FailAreaTask(intent, mode, "tool_recipe_missing", {
            required_tool = tool_name,
        })
        return false
    end
    if builder == nil then
        self:FailAreaTask(intent, mode, "builder_missing", {
            required_tool = tool_name,
        })
        return false
    end
    if not builder:KnowsRecipe(recipe) then
        self:FailAreaTask(intent, mode, "tool_recipe_not_known", {
            required_tool = tool_name,
        })
        return false
    end
    if not builder:HasIngredients(recipe) then
        self:FailAreaTask(intent, mode, "tool_ingredients_missing", {
            required_tool = tool_name,
        })
        return false
    end

    local now = GetTime()
    if state.tool_craft_started_at ~= nil then
        if now - state.tool_craft_started_at
            > AREA_TOOL_CRAFT_TIMEOUT_SECONDS
        then
            self:FailAreaTask(intent, mode, "tool_craft_timeout", {
                required_tool = tool_name,
            })
        end
        return false
    end

    state.tool_craft_started_at = now
    state.tool_craft_name = tool_name
    self:QueueEvent("task_progress", {
        intent_id = intent.intent_id,
        mode = mode,
        stage = "crafting_tool",
        required_tool = tool_name,
    })
    local started = builder:MakeRecipe(
        recipe,
        self.inst:GetPosition(),
        nil,
        nil,
        function()
            if self.area_state ~= nil
                and self.area_state.intent_id == intent.intent_id
            then
                self.area_state.tool_craft_started_at = nil
                self:QueueEvent("task_progress", {
                    intent_id = intent.intent_id,
                    mode = mode,
                    stage = "tool_crafted",
                    required_tool = tool_name,
                })
            end
        end
    )
    if not started then
        self:FailAreaTask(intent, mode, "tool_craft_start_failed", {
            required_tool = tool_name,
        })
        return false
    end
    return false
end

function CodexCompanionBrain:RecordAreaHarvest(intent, prefab)
    if self.area_state == nil
        or self.area_state.intent_id ~= intent.intent_id
    then
        self.area_state = {
            intent_id = intent.intent_id,
            count = 0,
            started_at = GetTime(),
        }
    end
    self.area_state.count = (self.area_state.count or 0) + 1
    self.area_state.last_prefab = prefab
    self.harvest_state = nil
    self:QueueEvent("task_progress", {
        intent_id = intent.intent_id,
        mode = intent.mode,
        stage = "target_cleared",
        target_prefab = prefab,
        targets_cleared = self.area_state.count,
        desired_amount = tonumber(
            type(intent.params) == "table" and intent.params.amount or nil
        ),
    })
end

function CodexCompanionBrain:Harvest(intent)
    local area_mode = intent.mode == "harvest_area"
        or intent.mode == "gather"
    if self.harvest_state == nil
        or self.harvest_state.intent_id ~= intent.intent_id
    then
        self.harvest_state = {
            intent_id = intent.intent_id,
            started_at = GetTime(),
            target_guid = intent.target_guid,
            target_prefab = intent.target_prefab,
            acted = false,
        }
    end
    local target = self:FindTarget(intent)
    if target == nil or not target:IsValid() then
        if area_mode then
            if self.harvest_state.acted then
                if self.harvest_state.stump_dig_acted then
                    self:QueueEvent("task_progress", {
                        intent_id = intent.intent_id,
                        mode = intent.mode,
                        stage = "tree_stump_dig_verified",
                        target_prefab = intent.target_prefab,
                        stump_guid = self.harvest_state.stump_guid,
                        item_prefab = "shovel",
                    })
                end
                self:RecordAreaHarvest(
                    intent,
                    intent.target_prefab or self.harvest_state.target_prefab
                )
            else
                self.harvest_state = nil
            end
            return
        end
        if self.harvest_state.acted then
            self:QueueEvent("task_complete", {
                intent_id = intent.intent_id,
                mode = intent.mode,
                target_prefab = intent.target_prefab,
                requested_amount = 1,
                amount = 1,
                growth_stage = "mature",
                final_growth_only = true,
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
    if area_mode and self.area_state.drop_prefab == nil then
        local plant_def = target.plant_def
        local product = plant_def ~= nil and plant_def.product or nil
        if type(product) == "string" and product ~= "" then
            self.area_state.drop_prefab = product
            self.area_state.initial_drop_count =
                InventoryCount(self.inst, product)
            self.area_state.collected = 0
            self.area_state.last_reported_drop = 0
        end
    end
    if area_mode
        and action == ACTIONS.DIG
        and IsTreeHarvestIntent(intent)
        and IsTreeStump(target)
    then
        local shovel = FindInventoryTool(self.inst, ACTIONS.DIG)
        if shovel == nil then
            self:QueueEvent("task_progress", {
                intent_id = intent.intent_id,
                mode = intent.mode,
                stage = "tree_stump_skipped",
                reason = "shovel_not_found",
                target_prefab = intent.target_prefab,
                stump_guid = tostring(target.GUID),
            })
            self:RecordAreaHarvest(
                intent,
                intent.target_prefab or self.harvest_state.target_prefab
            )
            return
        end
        local inventory = self.inst.components.inventory
        if inventory == nil then
            self:RecordAreaHarvest(
                intent,
                intent.target_prefab or self.harvest_state.target_prefab
            )
            return
        end
        if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= shovel then
            inventory:Equip(shovel)
        end
        if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= shovel then
            self:QueueEvent("task_progress", {
                intent_id = intent.intent_id,
                mode = intent.mode,
                stage = "tree_stump_skipped",
                reason = "shovel_equip_failed",
                target_prefab = intent.target_prefab,
                stump_guid = tostring(target.GUID),
                item_prefab = shovel.prefab,
            })
            self:RecordAreaHarvest(
                intent,
                intent.target_prefab or self.harvest_state.target_prefab
            )
            return
        end
        if self.harvest_state.stump_dig_scheduled then
            return
        end
        local busy = self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy")
        if not busy and self.inst:GetBufferedAction() == nil then
            self.inst:ClearBufferedAction()
            self.harvest_state.acted = true
            self.harvest_state.stump_dig_acted = true
            self.harvest_state.stump_guid = target.GUID
            self.harvest_state.stump_dig_scheduled = true
            if not self.harvest_state.stump_dig_notice_sent then
                self.harvest_state.stump_dig_notice_sent = true
                self:QueueEvent("task_progress", {
                    intent_id = intent.intent_id,
                    mode = intent.mode,
                    stage = "digging_tree_stump",
                    target_prefab = intent.target_prefab,
                    stump_guid = tostring(target.GUID),
                    item_prefab = shovel.prefab,
                })
            end
            -- Equipping the shovel enters the item_out animation. Submit the
            -- already-in-range DIG action after that animation settles, rather
            -- than replacing the action on every brain tick.
            self.inst:DoTaskInTime(0.75, function()
                if self.harvest_state == nil
                    or self.harvest_state.intent_id ~= intent.intent_id
                then
                    return
                end
                self.harvest_state.stump_dig_scheduled = false
                if target:IsValid()
                    and IsTreeStump(target)
                    and target.components.workable ~= nil
                    and target.components.workable:CanBeWorked()
                    and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == shovel
                    and self.inst.sg ~= nil
                    and not self.inst.sg:HasStateTag("busy")
                then
                    self.inst:ClearBufferedAction()
                    self.inst.sg:GoToState("idle")
                    self.inst:PushBufferedAction(
                        BufferedAction(
                            self.inst,
                            target,
                            ACTIONS.DIG,
                            shovel
                        )
                    )
                    self.inst:DoTaskInTime(1.25, function()
                        if self.harvest_state == nil
                            or self.harvest_state.intent_id ~= intent.intent_id
                            or not target:IsValid()
                            or not IsTreeStump(target)
                            or target.components.workable == nil
                            or not target.components.workable:CanBeWorked()
                            or inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= shovel
                        then
                            return
                        end
                        self.inst:ClearBufferedAction()
                        if self.inst.sg ~= nil
                            and not self.inst.sg:HasStateTag("busy")
                        then
                            self.inst.sg:GoToState("idle")
                        end
                        BufferedAction(
                            self.inst,
                            target,
                            ACTIONS.DIG,
                            shovel
                        ):Do()
                    end)
                end
            end)
        end
        return
    end
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
    if finished and not self.harvest_state.acted then
        self.harvest_state = nil
        if not area_mode then
            self:QueueEvent("task_failed", {
                intent_id = intent.intent_id,
                mode = intent.mode,
                reason = "target_unavailable",
                target_prefab = target.prefab,
            })
            self:SuppressIntent(intent)
        end
        return
    end
    if finished then
        if area_mode then
            self:RecordAreaHarvest(intent, target.prefab)
            return
        end
        self:QueueEvent("task_complete", {
            intent_id = intent.intent_id,
            mode = intent.mode,
            target_prefab = target.prefab,
            requested_amount = 1,
            amount = 1,
            growth_stage = "mature",
            final_growth_only = true,
            verified = true,
        })
        self:SuppressIntent(intent)
        return
    end

    local invobject = nil
    local params = type(intent.params) == "table" and intent.params or {}
    local required_tool = params.required_tool or params.tool_prefab
    local work_requires_tool = action == ACTIONS.MINE
        or action == ACTIONS.CHOP
        or action == ACTIONS.DIG
        or action == ACTIONS.HAMMER
    if required_tool ~= nil or work_requires_tool then
        invobject = FindInventoryTool(self.inst, action)
        if invobject == nil then
            self:FailAreaTask(intent, intent.mode, "tool_not_found", {
                required_tool = required_tool,
                target_prefab = target.prefab,
            })
            return
        end
        local inventory = self.inst.components.inventory
        if inventory == nil then
            self:FailAreaTask(intent, intent.mode, "inventory_missing")
            return
        end
        if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= invobject then
            inventory:Equip(invobject)
        end
        if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= invobject then
            self:FailAreaTask(intent, intent.mode, "tool_equip_failed", {
                required_tool = required_tool,
                item_prefab = invobject.prefab,
            })
            return
        end
    end

    local busy = self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy")
    if not busy and self.inst:GetBufferedAction() == nil then
        self.inst:ClearBufferedAction()
        self.harvest_state.acted = true
        self.inst.components.locomotor:PushAction(
            BufferedAction(self.inst, target, action, invobject),
            true
        )
    end
end

function CodexCompanionBrain:FindAreaTarget(intent, mode)
    local params = type(intent.params) == "table" and intent.params or {}
    local radius = params.radius ~= nil
        and tonumber(params.radius)
        or 18
    local target_prefabs = type(params.target_prefabs) == "table"
        and params.target_prefabs
        or nil
    local target_prefab_set = nil
    if target_prefabs ~= nil then
        target_prefab_set = {}
        for _, prefab in ipairs(target_prefabs) do
            target_prefab_set[prefab] = true
        end
    end
    local requested_prefab = intent.target_prefab or params.target_prefab
    if type(requested_prefab) == "string" and requested_prefab ~= "" then
        target_prefab_set = target_prefab_set or {}
        target_prefab_set[requested_prefab] = true
    end
    local crop_only = mode == "harvest_area"
        and not params.all_plants
        and target_prefab_set == nil
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        0,
        z,
        radius,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local best = nil
    local best_distance = math.huge
    for _, entity in ipairs(entities) do
        local matches = entity ~= self.inst and CanBeSeen(entity)
        if matches
            and target_prefab_set ~= nil
            and not target_prefab_set[entity.prefab]
        then
            matches = false
        end
        if matches and crop_only then
            matches = entity:HasTag("farm_plant")
                and IsHarvestableNow(entity)
        elseif matches and mode == "harvest_area" then
            matches = IsHarvestableNow(entity)
        elseif matches and mode == "gather" and target_prefab_set == nil then
            matches = entity.components.inventoryitem ~= nil
                and entity.components.inventoryitem.canbepickedup
                and not entity:HasTag("heavy")
        end
        if matches then
            local distance = self.inst:GetDistanceSqToInst(entity)
            if distance < best_distance then
                best = entity
                best_distance = distance
            end
        end
    end
    self:KeepTargetAwake(best)
    return best
end

function CodexCompanionBrain:CountAreaTargets(intent, mode)
    local params = type(intent.params) == "table" and intent.params or {}
    local radius = params.radius ~= nil and tonumber(params.radius) or 18
    local target_prefabs = type(params.target_prefabs) == "table"
        and params.target_prefabs
        or nil
    local target_prefab_set = nil
    if target_prefabs ~= nil then
        target_prefab_set = {}
        for _, prefab in ipairs(target_prefabs) do
            target_prefab_set[prefab] = true
        end
    end
    local requested_prefab = intent.target_prefab or params.target_prefab
    if type(requested_prefab) == "string" and requested_prefab ~= "" then
        target_prefab_set = target_prefab_set or {}
        target_prefab_set[requested_prefab] = true
    end
    local crop_only = mode == "harvest_area"
        and not params.all_plants
        and target_prefab_set == nil
    local x, _, z = self.inst.Transform:GetWorldPosition()
    local entities = TheSim:FindEntities(
        x,
        0,
        z,
        radius,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
    local count = 0
    for _, entity in ipairs(entities) do
        local matches = entity ~= self.inst and CanBeSeen(entity)
        if matches
            and target_prefab_set ~= nil
            and not target_prefab_set[entity.prefab]
        then
            matches = false
        end
        if matches and crop_only then
            matches = entity:HasTag("farm_plant")
                and IsHarvestableNow(entity)
        elseif matches and mode == "harvest_area" then
            matches = IsHarvestableNow(entity)
        elseif matches and mode == "gather" and target_prefab_set == nil then
            matches = entity.components.inventoryitem ~= nil
                and entity.components.inventoryitem.canbepickup
                and not entity:HasTag("heavy")
        end
        if matches then
            count = count + 1
        end
    end
    return count
end

function CodexCompanionBrain:FindAreaDrop(intent, prefab)
    if type(prefab) ~= "string" or prefab == "" then
        return nil
    end
    local params = type(intent.params) == "table" and intent.params or {}
    local radius = tonumber(params.desired_drop_search_radius)
        or tonumber(params.radius)
        or 24
    return FindEntity(
        self.inst,
        radius,
        function(entity)
            local inventoryitem = entity.components.inventoryitem
            return entity.prefab == prefab
                and inventoryitem ~= nil
                and inventoryitem.owner == nil
                and (inventoryitem.canbepickedup == nil
                    or inventoryitem.canbepickedup)
                and not entity:HasTag("heavy")
                and CanBeSeen(entity)
        end,
        nil,
        { "INLIMBO", "NOCLICK", "CLASSIFIED", "FX" }
    )
end

function CodexCompanionBrain:UpdateAreaDropProgress(intent, mode)
    local state = self.area_state
    if state == nil or type(state.drop_prefab) ~= "string" then
        return nil
    end
    local current = InventoryCount(self.inst, state.drop_prefab)
    local collected = math.max(0, current - (state.initial_drop_count or 0))
    state.collected = collected
    local reported = state.last_reported_drop or 0
    if collected > reported then
        self:QueueEvent("item_acquired", {
            intent_id = intent.intent_id,
            mode = mode,
            item_prefab = state.drop_prefab,
            source = "area_collection",
            amount = collected,
            before_amount = reported,
            after_amount = collected,
            delta = collected - reported,
            desired_amount = tonumber(
                type(intent.params) == "table" and intent.params.amount or nil
            ),
            targets_cleared = state.count,
            verified = true,
        })
        state.last_reported_drop = collected
    end
    return collected
end

function CodexCompanionBrain:PickupAreaDrop(intent)
    local state = self.area_state
    if state == nil or type(state.drop_prefab) ~= "string" then
        return false
    end
    local drop = self:FindAreaDrop(intent, state.drop_prefab)
    if drop == nil then
        state.drop_pickup_started_at = nil
        return false
    end
    if self.inst.sg ~= nil and self.inst.sg:HasStateTag("busy") then
        return true
    end
    if self.inst:GetBufferedAction() ~= nil then
        return true
    end
    state.drop_pickup_started_at = GetTime()
    self:KeepTargetAwake(drop)
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(
        BufferedAction(self.inst, drop, ACTIONS.PICKUP),
        true
    )
    return true
end

function CodexCompanionBrain:MaybeSummonAreaHelpers(intent, mode)
    local params = type(intent.params) == "table" and intent.params or {}
    local minion_prefab = params.assist_minion_prefab
    if minion_prefab ~= "shadowworker" then
        return
    end
    if self.inst.prefab ~= "waxwell" then
        return
    end
    local state = self.area_state
    if state == nil or state.assist_unavailable_reason ~= nil then
        return
    end
    local petleash = self.inst.components.petleash
    local existing = CountLivePetsForPrefab(petleash, minion_prefab)
    local desired_amount = tonumber(params.amount) or 0
    local target_count = self:CountAreaTargets(intent, mode)
    if state.desired_assist_workers == nil then
        if target_count >= AREA_DENSE_MINION_DENSITY_THRESHOLD
            and desired_amount >= 20
        then
            state.desired_assist_workers = math.min(
                2,
                math.max(1, tonumber(params.max_assist_workers) or 2)
            )
        elseif target_count >= AREA_MINION_DENSITY_THRESHOLD then
            state.desired_assist_workers = 1
        else
            state.desired_assist_workers = 0
        end
    end
    if existing >= state.desired_assist_workers then
        return
    end
    local now = GetTime()
    if now < (state.assist_retry_at or 0)
        or now < self.next_codex_worker_spell_at
    then
        return
    end
    local target = self:FindAreaTarget(intent, mode)
    if target == nil then
        return
    end
    local x, _, z = target.Transform:GetWorldPosition()
    local success, reason = self:TryCodexUmbraWorkerSpell(
        Vector3(x, 0, z),
        "resource_assist"
    )
    if success then
        self:QueueEvent("task_progress", {
            intent_id = intent.intent_id,
            mode = mode,
            stage = "assist_minion_summoned",
            minion_prefab = minion_prefab,
            desired_assist_workers = state.desired_assist_workers,
            existing_assist_workers = existing + 1,
        })
        return
    end
    state.assist_retry_at = now + CODEX_WORKER_SPELL_COOLDOWN_SECONDS
    if reason == "book_missing"
        or reason == "no_fuel"
        or reason == "sanity_low"
        or reason == "petleash_missing"
        or reason == "cannot_cast"
    then
        state.assist_unavailable_reason = reason
    end
end

function CodexCompanionBrain:AreaTask(intent, mode)
    local params = type(intent.params) == "table" and intent.params or {}
    local desired_amount = tonumber(params.amount)
    local drop_prefab = params.drop_prefab
    if self.area_state == nil
        or self.area_state.intent_id ~= intent.intent_id
    then
        self.area_state = {
            intent_id = intent.intent_id,
            count = 0,
            started_at = GetTime(),
            arrived = intent.position == nil,
            drop_prefab = type(drop_prefab) == "string"
                and drop_prefab
                or nil,
            initial_drop_count = type(drop_prefab) == "string"
                and InventoryCount(self.inst, drop_prefab)
                or 0,
            collected = 0,
            last_reported_drop = 0,
        }
    end
    local state = self.area_state
    local collected = self:UpdateAreaDropProgress(intent, mode)
    local tree_stump_pending = IsTreeHarvestIntent(intent)
        and self.harvest_state ~= nil
        and self.harvest_state.intent_id == intent.intent_id
        and self.harvest_state.target_guid ~= nil
    if not tree_stump_pending
        and desired_amount ~= nil
        and state.drop_prefab ~= nil
        and (collected or 0) >= desired_amount
    then
        self:CompleteAreaTask(
            intent,
            mode,
            state.drop_prefab,
            collected,
            true
        )
        return
    end
    if desired_amount ~= nil
        and state.drop_prefab == nil
        and (state.count or 0) >= desired_amount
    then
        self:CompleteAreaTask(
            intent,
            mode,
            self:GetAreaRequestedPrefab(intent),
            state.count,
            true
        )
        return
    end

    if intent.position ~= nil and not state.arrived then
        local arrived = self:NavigateTo(
            intent,
            intent.position[1],
            intent.position[2],
            tonumber(params.arrive_distance) or 4,
            "area_travel"
        )
        if not arrived then
            return
        end
        state.arrived = true
    end
    if self.harvest_state ~= nil
        and self.harvest_state.intent_id == intent.intent_id
        and self.harvest_state.target_guid ~= nil
    then
        local pending = {}
        for key, value in pairs(intent) do
            pending[key] = value
        end
        pending.target_guid = self.harvest_state.target_guid
        pending.target_prefab = self.harvest_state.target_prefab
        if not self:EnsureAreaTool(intent, mode) then
            return
        end
        self:Harvest(pending)
        return
    end

    collected = self:UpdateAreaDropProgress(intent, mode)
    if desired_amount ~= nil
        and state.drop_prefab ~= nil
        and (collected or 0) >= desired_amount
    then
        self:CompleteAreaTask(
            intent,
            mode,
            state.drop_prefab,
            collected,
            true
        )
        return
    end
    local has_space, space_reason = self:EnsureAreaInventorySpace(intent)
    if not has_space then
        self:FailAreaTask(intent, mode, space_reason)
        return
    end
    if self:PickupAreaDrop(intent) then
        state.exhausted_since = nil
        return
    end

    local target = self:FindAreaTarget(intent, mode)
    if target == nil then
        local now = GetTime()
        state.exhausted_since = state.exhausted_since or now
        local grace = tonumber(params.exhausted_grace_seconds) or 4
        if now - state.exhausted_since < grace then
            return
        end
        local requested = self:GetAreaRequestedPrefab(intent)
        if desired_amount == nil then
            self:CompleteAreaTask(
                intent,
                mode,
                requested,
                state.count,
                true
            )
        elseif params.allow_partial == true
            and (state.count or 0) > 0
        then
            self:CompleteAreaTask(
                intent,
                mode,
                state.drop_prefab or requested,
                math.max(state.count or 0, state.collected or 0),
                true,
                true
            )
        elseif desired_amount <= 0
            or (
                (state.count or 0) == 0
                and (state.collected or 0) == 0
            )
        then
            self:FailAreaTask(intent, mode, "target_not_found", {
                required_tool = params.required_tool,
            })
        else
            self:FailAreaTask(intent, mode, "target_exhausted", {
                requested_amount = desired_amount,
                targets_cleared = state.count,
                collected_amount = state.collected,
                item_prefab = state.drop_prefab,
            })
        end
        return
    end
    state.exhausted_since = nil
    -- Do not consume tool ingredients until a matching target is actually in
    -- range. A stale resource command must fail without crafting an unused tool.
    if not self:EnsureAreaTool(intent, mode) then
        return
    end
    self:MaybeSummonAreaHelpers(intent, mode)
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
        local params = type(intent.params) == "table" and intent.params or {}
        local initial_count = InventoryCount(self.inst, prefab)
        self.fetch_state = {
            intent_id = intent.intent_id,
            stage = "travel",
            started_at = GetTime(),
            prefab = prefab,
            initial_count = initial_count,
            target_amount = math.max(1, tonumber(params.amount) or 1),
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
        if InventoryCount(self.inst, prefab) >= state.target_amount then
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
                local pickup_item = ground_item
                local remaining = state.target_amount
                    - InventoryCount(self.inst, prefab)
                local pickup_stackable = ground_item.components.stackable
                if pickup_stackable ~= nil
                    and pickup_stackable:StackSize() > remaining
                then
                    local split = pickup_stackable:Get(remaining)
                    if split ~= nil then
                        split.Transform:SetPosition(
                            ground_item.Transform:GetWorldPosition()
                        )
                        pickup_item = split
                    end
                end
                self:KeepTargetAwake(pickup_item)
                state.stage = "pickup"
                state.pickup_target = pickup_item
                state.pickup_started_at = GetTime()
                self.inst:ClearBufferedAction()
                self.inst.components.locomotor:PushAction(
                    BufferedAction(self.inst, pickup_item, ACTIONS.PICKUP),
                    true
                )
                return
            end

            local container, item = self:FindContainingItem(prefab, radius)
            if container ~= nil and item ~= nil then
                local before_count = InventoryCount(self.inst, prefab)
                local container_component = container.components.container
                local needed = state.target_amount - before_count
                for _ = 1, needed do
                    local removed = container_component:RemoveItem(item, false)
                    if removed == nil
                        or not inventory:GiveItem(
                            removed,
                            nil,
                            self.inst:GetPosition()
                        )
                    then
                        if removed ~= nil and removed:IsValid() then
                            container_component:GiveItem(removed)
                        end
                        self:FailFetch(intent, "item_transfer_failed")
                        return
                    end
                end
                local after_count = InventoryCount(self.inst, prefab)
                self:QueueEvent("item_acquired", {
                    intent_id = intent.intent_id,
                    item_prefab = prefab,
                    source = "container",
                    container_prefab = container.prefab,
                    before_amount = before_count,
                    after_amount = after_count,
                    delta = after_count - before_count,
                    desired_amount = state.target_amount,
                    verified = after_count > before_count,
                })
                state.acquired_amount = (state.acquired_amount or 0)
                    + math.max(0, after_count - before_count)
                state.stage = after_count >= state.target_amount
                    and "return"
                    or "search"
            elseif GetTime() - (state.search_started_at or GetTime())
                > (tonumber(params.search_timeout) or FETCH_SEARCH_SECONDS)
            then
                self:FailFetch(intent, "item_not_found")
                return
            end
        end
    end

    if state.stage == "pickup" then
        if InventoryCount(self.inst, prefab) >= state.target_amount then
            local after_count = InventoryCount(self.inst, prefab)
            self:QueueEvent("item_acquired", {
                intent_id = intent.intent_id,
                item_prefab = prefab,
                source = "ground",
                before_amount = state.initial_count or 0,
                after_amount = after_count,
                delta = math.max(
                    0,
                    after_count - (state.initial_count or 0)
                ),
                desired_amount = state.target_amount,
                verified = after_count >= state.target_amount,
            })
            state.acquired_amount = (state.acquired_amount or 0) + math.max(
                0,
                after_count - (state.initial_count or 0)
            )
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
            state.player_before = state.player_before
                or InventoryCount(player, prefab)
            local item = self.inst.components.inventory:FindItem(function(candidate)
                return candidate ~= nil and candidate.prefab == prefab
            end)
            if item ~= nil and state.give_started_at == nil then
                state.give_started_at = GetTime()
                self.inst:ClearBufferedAction()
                self.inst.components.locomotor:PushAction(
                    BufferedAction(
                        self.inst,
                        player,
                        GiveToPlayerAction(item),
                        item
                    ),
                    true
                )
                return
            end
            local companion_after = InventoryCount(self.inst, prefab)
            local player_after = InventoryCount(player, prefab)
            local player_delta = math.max(
                0,
                player_after - (state.player_before or 0)
            )
            if companion_after < state.target_amount
                and player_delta >= state.target_amount
            then
                self:QueueEvent("task_complete", {
                    intent_id = intent.intent_id,
                    mode = "fetch_item",
                    item_prefab = prefab,
                    amount = state.target_amount,
                    requested_amount = state.target_amount,
                    inventory_before = state.initial_count or 0,
                    inventory_after = companion_after,
                    companion_delta = state.acquired_amount or 0,
                    acquired_amount = state.acquired_amount or 0,
                    player_before = state.player_before,
                    player_after = player_after,
                    player_delta = player_delta,
                    delivered_to_player = true,
                    delivered_verified = player_delta >= state.target_amount,
                    verified = player_delta >= state.target_amount,
                })
                self:SuppressIntent(intent)
                self.fetch_state = nil
                return
            end
            if state.give_started_at ~= nil
                and GetTime() - state.give_started_at > 8
            then
                self:FailFetch(intent, "player_inventory_full")
            end
            return
        end

        local held = InventoryCount(self.inst, prefab)
        self:QueueEvent("task_complete", {
            intent_id = intent.intent_id,
            mode = "fetch_item",
            item_prefab = prefab,
            amount = state.target_amount,
            requested_amount = state.target_amount,
            inventory_before = state.initial_count or 0,
            inventory_after = held,
            companion_delta = math.max(
                0,
                held - (state.initial_count or 0)
            ),
            delivered_to_player = false,
            verified = held >= state.target_amount,
        })
        self:SuppressIntent(intent)
        self.fetch_state = nil
    end
end

function CodexCompanionBrain:Eat()
    local inventory = self.inst.components.inventory
    if inventory == nil or self.inst.sg:HasStateTag("busy") then
        return
    end
    local params = self.intent ~= nil
        and type(self.intent.params) == "table"
        and self.intent.params
        or {}
    local wanted = type(params.item_prefab) == "string"
        and params.item_prefab
        or nil
    local item = FindBestFood(self.inst, wanted, self.intent)
        or (
            wanted == nil
            and FindBestFood(self.inst, nil, self.intent)
            or nil
        )
    if item ~= nil then
        self.inst:ClearBufferedAction()
        self.inst.components.locomotor:PushAction(
            BufferedAction(self.inst, nil, ACTIONS.EAT, item),
            true
        )
    end
end

function CodexCompanionBrain:DeliverItem(intent)
    local params = type(intent.params) == "table" and intent.params or {}
    local prefab = intent.target_prefab or params.item_prefab
    if type(prefab) ~= "string" or prefab == "" then
        self:FailAction(intent, "deliver_item_missing")
        return
    end
    local desired = math.max(1, tonumber(params.amount) or 1)
    if self.deliver_state == nil
        or self.deliver_state.intent_id ~= intent.intent_id
    then
        self.deliver_state = {
            intent_id = intent.intent_id,
            prefab = prefab,
            amount = desired,
            initial_count = InventoryCount(self.inst, prefab),
            stage = "travel",
            started_at = GetTime(),
        }
    end
    local state = self.deliver_state
    if (state.initial_count or 0) < desired then
        self.deliver_state = nil
        self:FailAction(intent, "deliver_item_not_enough")
        return
    end
    local player = GetPrimaryPlayer(self.inst)
    if player == nil or not player:IsValid() then
        self.deliver_state = nil
        self:FailAction(intent, "player_missing")
        return
    end
    state.player_initial_count = state.player_initial_count
        or InventoryCount(player, prefab)
    if state.stage == "travel" then
        local px, _, pz = player.Transform:GetWorldPosition()
        if self:NavigateTo(intent, px, pz, 3, "deliver_travel") then
            state.stage = "giving"
            state.give_started_at = GetTime()
        end
        return
    end
    local current = InventoryCount(self.inst, prefab)
    if current <= (state.initial_count or 0) - desired then
        local player_after = InventoryCount(player, prefab)
        local companion_delta = math.max(
            0,
            (state.initial_count or 0) - current
        )
        local player_delta = math.max(
            0,
            player_after - (state.player_initial_count or 0)
        )
        local verified = companion_delta >= desired
            and player_delta >= desired
        self:QueueEvent("task_complete", {
            intent_id = intent.intent_id,
            mode = "deliver_item",
            item_prefab = prefab,
            amount = desired,
            requested_amount = desired,
            inventory_before = state.initial_count or 0,
            inventory_after = current,
            companion_delta = companion_delta,
            player_before = state.player_initial_count,
            player_after = player_after,
            player_delta = player_delta,
            delivered_to_player = true,
            delivered_verified = verified,
            verified = verified,
        })
        self:SuppressIntent(intent)
        self.deliver_state = nil
        return
    end
    if GetTime() - (state.give_started_at or GetTime()) > 8 then
        self.deliver_state = nil
        self:FailAction(intent, "player_inventory_full")
        return
    end
    if IsGivingToPlayer(self.inst, player)
        or (
            self.inst.sg ~= nil
            and self.inst.sg:HasStateTag("busy")
        )
    then
        return
    end
    local item = FindInventoryItem(self.inst, prefab)
    if item == nil then
        self.deliver_state = nil
        self:FailAction(intent, "deliver_item_not_found")
        return
    end
    local stackable = item.components.stackable
    if stackable ~= nil and stackable:StackSize() > desired then
        item = stackable:Get(desired) or item
    end
    self.inst:ClearBufferedAction()
    self.inst.components.locomotor:PushAction(
        BufferedAction(
            self.inst,
            player,
            GiveToPlayerAction(item),
            item
        ),
        true
    )
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
    if self.is_dead or self.inst:HasTag("playerghost") then
        self.speech_queue = {}
        return
    end
    if #self.speech_queue == 0
        or GetTime() - self.last_speech_at < 7
    then
        return
    end
    local message = table.remove(self.speech_queue, 1)
    if self.inst.components.talker ~= nil and message ~= nil then
        self.inst.components.talker:Say(message, 4)
        if TheNet ~= nil then
            TheNet:Announce("[微光] " .. message, nil, nil, "default")
        end
        self.last_speech_at = GetTime()
    end
end

function CodexCompanionBrain:IsDeadOrGhost()
    if self.inst:HasTag("playerghost") then
        return true
    end
    local health = self.inst.components.health
    return health ~= nil and health:IsDead()
end

function CodexCompanionBrain:EnterDeathPassive()
    if self.is_dead then
        return
    end
    self.is_dead = true
    self.speech_queue = {}
    self.recovery_state = nil
    self.home_chore_state = nil
    self:StopAll()
end

function CodexCompanionBrain:Act()
    if not self.inst:IsValid() then
        return
    end
    if self:IsDeadOrGhost() then
        self:EnterDeathPassive()
        return
    end
    if self.is_dead then
        self.is_dead = false
    end
    local pending_action = self.inst:GetBufferedAction()
    if pending_action ~= nil
        and pending_action.target ~= nil
        and (
            not pending_action.target:IsValid()
            or (
                pending_action.action == ACTIONS.PICKUP
                and pending_action.target.components.inventoryitem ~= nil
                and pending_action.target.components.inventoryitem.owner ~= nil
            )
        )
    then
        self.inst:ClearBufferedAction()
        if self.inst.components.locomotor ~= nil then
            self.inst.components.locomotor:Stop()
        end
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
    elseif intent.mode == "homestead" then
        self:Homestead(intent, emergency)
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
    elseif intent.mode == "deliver_item" then
        self:DeliverItem(intent)
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
        if type(intent.params) == "table"
            and type(intent.params.text) == "string"
        then
            self:EnqueueSpeech(intent.params.text)
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
    self.active_intent_created_at = nil
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
    if self.inst._codex_home == nil
        and type(self.inst._codex_landmarks) == "table"
    then
        for _, name in ipairs({ "家", "基地", "营地", "据点" }) do
            local landmark = self.inst._codex_landmarks[name]
            if type(landmark) == "table"
                and landmark.x ~= nil
                and landmark.z ~= nil
            then
                self.inst._codex_home = landmark
                break
            end
        end
    end
    self.death_listener = function(_, data)
        self.is_dead = true
        self.speech_queue = {}
        self.recovery_state = nil
        local vitals = VitalityEvidence(self.inst)
        local live_in_light = nil
        if self.inst.LightWatcher ~= nil then
            live_in_light = self.inst.LightWatcher:IsInLight()
        end
        local observed_in_light = self.last_observed_in_light
        local in_light = live_in_light
        if in_light == nil then
            in_light = observed_in_light
        end
        local inferred_cause = nil
        if vitals.hunger_percent ~= nil
            and vitals.hunger_percent <= 0
        then
            inferred_cause = "hunger"
        elseif self.inst:IsFreezing() then
            inferred_cause = "cold"
        elseif self.inst:IsOverheating() then
            inferred_cause = "hot"
        elseif in_light == false then
            inferred_cause = "darkness"
        end
        self:QueueEvent("companion_dead", {
            cause = data ~= nil
                and data.cause ~= nil
                and tostring(data.cause)
                or nil,
            afflicter = data ~= nil
                and data.afflicter ~= nil
                and data.afflicter.prefab
                or nil,
            health = vitals.health,
            health_max = vitals.health_max,
            health_percent = vitals.health_percent,
            hunger = vitals.hunger,
            hunger_max = vitals.hunger_max,
            hunger_percent = vitals.hunger_percent,
            sanity = vitals.sanity,
            sanity_max = vitals.sanity_max,
            sanity_percent = vitals.sanity_percent,
            freezing = self.inst:IsFreezing(),
            overheating = self.inst:IsOverheating(),
            in_light = in_light,
            in_light_source = live_in_light ~= nil
                and "live"
                or observed_in_light ~= nil
                and "last_observed"
                or nil,
            inferred_cause = inferred_cause,
            active_intent_id = self.intent ~= nil
                and self.intent.intent_id
                or nil,
            active_mode = self.intent ~= nil
                and self.intent.mode
                or nil,
            home = self.inst._codex_home,
        })
        if self.intent ~= nil then
            self:SuppressIntent(self.intent)
        end
    end
    self.inst:ListenForEvent("death", self.death_listener)
    if self.inst.components.inventory ~= nil then
        self.recovery_itemget_listener = function(_, data)
            local item = type(data) == "table" and data.item or data
            if item ~= nil and item.components ~= nil
                and item.components.edible ~= nil
            then
                self.recovery_state = nil
                self.recovery_next_check = 0
            end
        end
        self.inst:ListenForEvent(
            "itemget",
            self.recovery_itemget_listener
        )
    end
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
    self.frog_rain_task = self.inst:DoPeriodicTask(
        EMERGENCY_FROG_RAIN_OBSERVE_SECONDS,
        function()
            if TheWorld ~= nil
                and TheWorld.state.isspring
                and TheWorld.state.israining
            then
                self:TrackFrogRainDrops(GetTime())
            end
        end,
        0
    )
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
    if self.recovery_itemget_listener ~= nil
        and self.inst.components.inventory ~= nil
    then
        self.inst:RemoveEventCallback(
            "itemget",
            self.recovery_itemget_listener
        )
        self.recovery_itemget_listener = nil
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
    if self.frog_rain_task ~= nil then
        self.frog_rain_task:Cancel()
        self.frog_rain_task = nil
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
