local INVENTORY_ATLAS = "images/inventoryimages.xml"

local function Icon(normal)
    return {
        atlas = INVENTORY_ATLAS,
        normal = normal,
    }
end

local function Item(id, label, normal, children, command)
    return {
        id = id,
        label = label,
        icon = type(normal) == "table" and normal or Icon(normal),
        children = children,
        command = command,
    }
end

local function Selection(branch_id, action, target_id, amount)
    return {
        schema = 1,
        branch_id = branch_id,
        action = action,
        target_id = target_id,
        amount = amount,
    }
end

local AMOUNTS = { 5, 10, 15, 20, 30, 50 }

local function AmountChildren(branch_id, action, target_id, label, normal)
    local children = {}
    for _, amount in ipairs(AMOUNTS) do
        table.insert(children, {
            id = "amount_" .. tostring(amount),
            label = label .. " × " .. tostring(amount),
            icon = Icon(normal),
            quantity = amount,
            command = Selection(
                branch_id,
                action,
                target_id,
                amount
            ),
        })
    end
    return children
end

local function ResourceTarget(
    id,
    label,
    normal,
    action
)
    return {
        id = id,
        label = label,
        icon = Icon(normal),
        children = AmountChildren(
            "collection",
            action or "collect_resource",
            id,
            label,
            normal
        ),
    }
end

local function CraftTarget(id, label, normal)
    return Item(
        id,
        "制作 " .. label,
        normal,
        nil,
        Selection("crafting", "craft", id)
    )
end

local function BuildTarget(id, label, normal)
    return Item(
        id,
        "建造 " .. label,
        normal,
        nil,
        Selection("construction", "build", id)
    )
end

local function DeliveryTarget(id, label, normal)
    return {
        id = id,
        label = "取 " .. label,
        icon = Icon(normal),
        children = AmountChildren(
            "transport",
            "fetch",
            id,
            label,
            normal
        ),
    }
end

local function HandOverTarget(id, label, normal)
    return {
        id = id,
        label = "交给玩家 " .. label,
        icon = Icon(normal),
        children = AmountChildren(
            "interaction",
            "deliver_item",
            id,
            label,
            normal
        ),
    }
end

local branches = {
    Item("combat", "战斗与护卫", "spear.tex", {
        Item(
            "guard",
            "处理附近威胁",
            "spear.tex",
            nil,
            Selection("combat", "guard")
        ),
        Item(
            "retreat",
            "立刻撤回玩家身边",
            "cane.tex",
            nil,
            Selection("combat", "retreat")
        ),
    }),
    Item("collection", "采集与狩猎", "cutgrass.tex", {
        Item("resources", "采集资源", "cutgrass.tex", {
            ResourceTarget("grass", "草", "cutgrass.tex"),
            ResourceTarget("twigs", "树枝", "twigs.tex"),
            ResourceTarget("berries", "浆果", "berries.tex"),
            ResourceTarget("carrots", "胡萝卜", "carrot.tex"),
            ResourceTarget("reeds", "芦苇", "cutreeds.tex"),
            ResourceTarget("wood", "木头", "log.tex"),
            ResourceTarget("rocks", "石头", "rocks.tex"),
            ResourceTarget("gold", "金块", "goldnugget.tex"),
        }),
        Item("pickup", "捡地面掉落", "twigs.tex", {
            ResourceTarget("cutgrass", "草", "cutgrass.tex", "pickup_loot"),
            ResourceTarget("twigs", "树枝", "twigs.tex", "pickup_loot"),
            ResourceTarget("berries", "浆果", "berries.tex", "pickup_loot"),
            ResourceTarget("carrot", "胡萝卜", "carrot.tex", "pickup_loot"),
            ResourceTarget("goldnugget", "金块", "goldnugget.tex", "pickup_loot"),
            ResourceTarget("silk", "蜘蛛丝", "silk.tex", "pickup_loot"),
        }),
        Item("hunt", "击杀并收集掉落", "silk.tex", {
            ResourceTarget("silk", "蜘蛛丝", "silk.tex", "hunt_loot"),
            ResourceTarget("monstermeat", "怪物肉", "monstermeat.tex", "hunt_loot"),
        }),
    }),
    Item("crafting", "制作与配方", "transistor.tex", {
        CraftTarget("axe", "斧头", "axe.tex"),
        CraftTarget("pickaxe", "镐子", "pickaxe.tex"),
        CraftTarget("shovel", "铲子", "shovel.tex"),
        CraftTarget("hammer", "锤子", "hammer.tex"),
        CraftTarget("torch", "火把", "torch.tex"),
        CraftTarget("rope", "绳子", "rope.tex"),
        CraftTarget("boards", "木板", "boards.tex"),
        CraftTarget("cutstone", "石砖", "cutstone.tex"),
        CraftTarget("backpack", "背包", "backpack.tex"),
        CraftTarget("spear", "长矛", "spear.tex"),
        CraftTarget("armorwood", "木甲", "armorwood.tex"),
        CraftTarget("healingsalve", "治疗药膏", "healingsalve.tex"),
        CraftTarget("waxwelljournal", "暗影法典", "waxwelljournal.tex"),
    }),
    Item("construction", "建造与部署", "hammer.tex", {
        BuildTarget("campfire", "营火", "campfire.tex"),
        BuildTarget("firepit", "石头火坑", "firepit.tex"),
        BuildTarget("treasurechest", "箱子", "treasurechest.tex"),
        BuildTarget("sciencemachine", "科学机器", "transistor.tex"),
        BuildTarget("alchemyengine", "炼金引擎", "nightmarefuel.tex"),
        BuildTarget("cookpot", "烹饪锅", "cookpot.tex"),
        BuildTarget("icebox", "冰箱", "icebox.tex"),
        BuildTarget("tent", "帐篷", "tent.tex"),
        BuildTarget("lightning_rod", "避雷针", "lightning_rod.tex"),
    }),
    Item("transport", "运输与取物", "backpack.tex", {
        DeliveryTarget("goldnugget", "金块", "goldnugget.tex"),
        DeliveryTarget("cutgrass", "草", "cutgrass.tex"),
        DeliveryTarget("twigs", "树枝", "twigs.tex"),
        DeliveryTarget("log", "木头", "log.tex"),
        DeliveryTarget("silk", "蜘蛛丝", "silk.tex"),
        DeliveryTarget("rocks", "石头", "rocks.tex"),
    }),
    Item("farming", "耕种与养殖", "seeds.tex", {
        Item(
            "harvest",
            "收获成熟作物",
            "carrot.tex",
            AmountChildren(
                "farming",
                "harvest",
                nil,
                "成熟作物",
                "carrot.tex"
            )
        ),
        Item("plant", "播种", "seeds.tex", {
            Item(
                "carrot",
                "胡萝卜",
                "carrot_seeds.tex",
                nil,
                Selection("farming", "plant", "carrot_seeds")
            ),
            Item(
                "corn",
                "玉米",
                "corn_seeds.tex",
                nil,
                Selection("farming", "plant", "corn_seeds")
            ),
            Item(
                "potato",
                "土豆",
                {
                    atlas = "images/inventoryimages3.xml",
                    normal = "potato_seeds.tex",
                },
                nil,
                Selection("farming", "plant", "potato_seeds")
            ),
            Item(
                "tomato",
                "番茄",
                {
                    atlas = "images/inventoryimages3.xml",
                    normal = "tomato_seeds.tex",
                },
                nil,
                Selection("farming", "plant", "tomato_seeds")
            ),
            Item(
                "pumpkin",
                "南瓜",
                "pumpkin_seeds.tex",
                nil,
                Selection("farming", "plant", "pumpkin_seeds")
            ),
        }),
        Item(
            "till",
            "耕一格地",
            "shovel.tex",
            nil,
            Selection("farming", "till")
        ),
    }),
    Item("survival", "生存与恢复", "healingsalve.tex", {
        Item(
            "eat",
            "吃最合适的食物",
            "meatballs.tex",
            nil,
            Selection("survival", "eat_best")
        ),
        Item(
            "heal",
            "使用治疗物品",
            "healingsalve.tex",
            nil,
            Selection("survival", "heal_best")
        ),
        Item(
            "tent",
            "条件合适时去帐篷休息",
            "tent.tex",
            nil,
            Selection("survival", "recover_tent")
        ),
    }),
    Item("exploration", "探索与侦察", "compass.tex", {
        Item("scout", "寻找并记录资源", "compass.tex", {
            Item(
                "grass",
                "寻找草",
                "cutgrass.tex",
                nil,
                Selection("exploration", "scout_resource", "grass")
            ),
            Item(
                "twigs",
                "寻找树枝",
                "twigs.tex",
                nil,
                Selection("exploration", "scout_resource", "twigs")
            ),
            Item(
                "gold",
                "寻找金块",
                "goldnugget.tex",
                nil,
                Selection("exploration", "scout_resource", "gold")
            ),
            Item(
                "rocks",
                "寻找石头",
                "rocks.tex",
                nil,
                Selection("exploration", "scout_resource", "rocks")
            ),
        }),
        Item(
            "home",
            "回到已记录的家",
            "compass.tex",
            nil,
            Selection("exploration", "return_home")
        ),
    }),
    Item("base", "基地整理与维护", "treasurechest.tex", {
        Item(
            "inventory",
            "查看随身物资",
            "backpack.tex",
            nil,
            Selection("base", "inventory_status")
        ),
        Item(
            "storage",
            "查看附近容器",
            "treasurechest.tex",
            nil,
            Selection("base", "nearby_storage")
        ),
        Item(
            "home",
            "回到基地",
            "compass.tex",
            nil,
            Selection("base", "return_home")
        ),
    }),
    Item("interaction", "交易与角色互动", "goldnugget.tex", {
        Item(
            "nearby",
            "查看附近互动目标",
            "compass.tex",
            nil,
            Selection("interaction", "nearby_interactions")
        ),
        Item("deliver", "把身上物品交给玩家", "backpack.tex", {
            HandOverTarget("cutgrass", "草", "cutgrass.tex"),
            HandOverTarget("twigs", "树枝", "twigs.tex"),
            HandOverTarget("berries", "浆果", "berries.tex"),
            HandOverTarget("goldnugget", "金块", "goldnugget.tex"),
            HandOverTarget("silk", "蜘蛛丝", "silk.tex"),
            HandOverTarget("log", "木头", "log.tex"),
        }),
        Item(
            "return",
            "回到玩家身边",
            "cane.tex",
            nil,
            Selection("interaction", "return_to_player")
        ),
    }),
    Item("movement", "移动与跟随", "cane.tex", {
        Item(
            "follow",
            "跟着我",
            "cane.tex",
            nil,
            Selection("movement", "follow")
        ),
        Item(
            "hold",
            "原地等待",
            "torch.tex",
            nil,
            Selection("movement", "hold")
        ),
        Item(
            "retreat",
            "立刻回来",
            "cane.tex",
            nil,
            Selection("movement", "retreat")
        ),
        Item(
            "home",
            "回到已记录的家",
            "compass.tex",
            nil,
            Selection("movement", "return_home")
        ),
    }),
    Item("information", "信息查询与状态", "papyrus.tex", {
        Item(
            "status",
            "查看三维状态",
            "healingsalve.tex",
            nil,
            Selection("information", "status")
        ),
        Item(
            "inventory",
            "查看随身物资",
            "backpack.tex",
            nil,
            Selection("information", "inventory")
        ),
        Item(
            "task",
            "查看任务进度",
            "papyrus.tex",
            nil,
            Selection("information", "task_progress")
        ),
        Item(
            "nearby",
            "查看附近情况",
            "compass.tex",
            nil,
            Selection("information", "nearby")
        ),
        Item(
            "location",
            "查看当前位置",
            "compass.tex",
            nil,
            Selection("information", "location")
        ),
    }),
}

return {
    schema = 1,
    branches = branches,
    amounts = AMOUNTS,
}
