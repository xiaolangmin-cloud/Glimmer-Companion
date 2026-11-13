from __future__ import annotations

from dataclasses import dataclass
from typing import Any


WHEEL_BRANCH_IDS = (
    "combat",
    "collection",
    "crafting",
    "construction",
    "transport",
    "farming",
    "survival",
    "exploration",
    "base",
    "interaction",
    "movement",
    "information",
)

AMOUNTS = (5, 10, 15, 20, 30, 50)

RESOURCE_TARGETS = {
    "grass": {
        "label": "草",
        "prefabs": ["grass", "grass_tall", "grass_moon"],
        "drop": "cutgrass",
    },
    "twigs": {
        "label": "树枝",
        "prefabs": ["sapling", "sapling_moon"],
        "drop": "twigs",
    },
    "berries": {
        "label": "浆果",
        "prefabs": ["berrybush", "berrybush2", "berrybush_juicy"],
        "drop": "berries",
    },
    "carrots": {
        "label": "胡萝卜",
        "prefabs": ["carrot_planted"],
        "drop": "carrot",
    },
    "reeds": {
        "label": "芦苇",
        "prefabs": ["reeds", "reeds_water"],
        "drop": "cutreeds",
    },
    "wood": {
        "label": "木头",
        "prefabs": ["evergreen", "deciduoustree"],
        "drop": "log",
        "tool": "axe",
        "assist_minion": "shadowworker",
    },
    "rocks": {
        "label": "石头",
        "prefabs": ["rock1", "rock2", "rock_flintless"],
        "drop": "rocks",
        "tool": "pickaxe",
        "assist_minion": "shadowworker",
    },
    "gold": {
        "label": "金块",
        "prefabs": ["rock2"],
        "drop": "goldnugget",
        "tool": "pickaxe",
        "assist_minion": "shadowworker",
    },
}

PICKUP_TARGETS = {
    "cutgrass": {"label": "草", "prefab": "cutgrass"},
    "twigs": {"label": "树枝", "prefab": "twigs"},
    "berries": {"label": "浆果", "prefab": "berries"},
    "carrot": {"label": "胡萝卜", "prefab": "carrot"},
    "goldnugget": {"label": "金块", "prefab": "goldnugget"},
    "silk": {"label": "蜘蛛丝", "prefab": "silk"},
}

HUNT_TARGETS = {
    "silk": {
        "label": "蜘蛛丝",
        "item_prefab": "silk",
        "source_prefab": "spider",
        "source_tag": "spider",
    },
    "monstermeat": {
        "label": "怪物肉",
        "item_prefab": "monstermeat",
        "source_prefab": "spider",
        "source_tag": "spider",
    },
}

CRAFT_TARGETS = {
    "axe": {"label": "斧头", "text": "做一把斧头"},
    "pickaxe": {"label": "镐子", "text": "做一把镐子"},
    "shovel": {"label": "铲子", "text": "做一把铲子"},
    "hammer": {"label": "锤子", "text": "做一把锤子"},
    "farm_hoe": {"label": "园艺锄", "text": "做一把园艺锄"},
    "torch": {"label": "火把", "text": "做一支火把"},
    "rope": {"label": "绳子", "text": "做一根绳子"},
    "boards": {"label": "木板", "text": "做一些木板"},
    "cutstone": {"label": "石砖", "text": "做一些石砖"},
    "backpack": {"label": "背包", "text": "做一个背包"},
    "spear": {"label": "长矛", "text": "做一把长矛"},
    "armorwood": {"label": "木甲", "text": "做一件木甲"},
    "healingsalve": {"label": "治疗药膏", "text": "做治疗药膏"},
    "waxwelljournal": {
        "label": "暗影法典",
        "text": "做一本暗影法典",
    },
}

BUILD_TARGETS = {
    "campfire": {"label": "营火", "text": "建造营火"},
    "firepit": {"label": "石头火坑", "text": "建造石头火坑"},
    "treasurechest": {"label": "箱子", "text": "建造箱子"},
    "sciencemachine": {"label": "科学机器", "text": "建造科学机器"},
    "alchemyengine": {"label": "炼金引擎", "text": "建造炼金引擎"},
    "cookpot": {"label": "烹饪锅", "text": "建造烹饪锅"},
    "icebox": {"label": "冰箱", "text": "建造冰箱"},
    "tent": {"label": "帐篷", "text": "建造帐篷"},
    "lightning_rod": {"label": "避雷针", "text": "建造避雷针"},
}

DELIVERY_TARGETS = {
    "cutgrass": "草",
    "twigs": "树枝",
    "berries": "浆果",
    "carrot": "胡萝卜",
    "goldnugget": "金块",
    "silk": "蜘蛛丝",
    "log": "木头",
    "rocks": "石头",
    "flint": "燧石",
}

PLANT_TARGETS = {
    "carrot_seeds": "胡萝卜种子",
    "corn_seeds": "玉米种子",
    "potato_seeds": "土豆种子",
    "tomato_seeds": "番茄种子",
    "pumpkin_seeds": "南瓜种子",
}

ALLOWED_ACTIONS = {
    "combat": {"guard", "retreat"},
    "collection": {"collect_resource", "pickup_loot", "hunt_loot"},
    "crafting": {"craft"},
    "construction": {"build"},
    "transport": {"fetch"},
    "farming": {"harvest", "plant", "till"},
    "survival": {"eat_best", "heal_best", "recover_tent"},
    "exploration": {"scout_resource", "return_home"},
    "base": {"inventory_status", "nearby_storage", "return_home"},
    "interaction": {
        "deliver_item",
        "nearby_interactions",
        "return_to_player",
    },
    "movement": {"follow", "hold", "retreat", "return_home"},
    "information": {
        "status",
        "inventory",
        "task_progress",
        "nearby",
        "location",
    },
}


class WheelCommandError(ValueError):
    pass


@dataclass(frozen=True)
class WheelSelection:
    branch_id: str
    action: str
    target_id: str | None = None
    amount: int | None = None

    def context(self) -> dict[str, Any]:
        return {
            "schema": 1,
            "branch_id": self.branch_id,
            "action": self.action,
            "target_id": self.target_id,
            "amount": self.amount,
        }


def normalize_selection(payload: dict[str, Any]) -> WheelSelection:
    if not isinstance(payload, dict):
        raise WheelCommandError("wheel command payload must be an object")
    if payload.get("schema") != 1:
        raise WheelCommandError("unsupported wheel command schema")
    branch_id = str(payload.get("branch_id") or "").strip()
    action = str(payload.get("action") or "").strip()
    if branch_id not in WHEEL_BRANCH_IDS:
        raise WheelCommandError("unknown wheel branch")
    if action not in ALLOWED_ACTIONS[branch_id]:
        raise WheelCommandError("action is not allowed in this branch")
    target_id = str(payload.get("target_id") or "").strip() or None
    amount_value = payload.get("amount")
    amount = None
    if amount_value is not None:
        if isinstance(amount_value, bool):
            raise WheelCommandError("amount must be an integer")
        try:
            amount = int(amount_value)
        except (TypeError, ValueError) as exc:
            raise WheelCommandError("amount must be an integer") from exc
        if amount not in AMOUNTS:
            raise WheelCommandError("amount is not an allowed wheel value")

    requiring_target = {
        ("collection", "collect_resource"),
        ("collection", "pickup_loot"),
        ("collection", "hunt_loot"),
        ("crafting", "craft"),
        ("construction", "build"),
        ("transport", "fetch"),
        ("farming", "plant"),
        ("exploration", "scout_resource"),
        ("interaction", "deliver_item"),
    }
    if (branch_id, action) in requiring_target and target_id is None:
        raise WheelCommandError("this wheel action requires a target")
    if (branch_id, action) in {
        ("collection", "collect_resource"),
        ("collection", "pickup_loot"),
        ("collection", "hunt_loot"),
        ("transport", "fetch"),
        ("farming", "harvest"),
        ("interaction", "deliver_item"),
    }:
        if amount is None:
            raise WheelCommandError("this wheel action requires an amount")
    return WheelSelection(branch_id, action, target_id, amount)


def canonical_text(command: WheelSelection) -> str:
    if command.branch_id == "combat" and command.action == "guard":
        return "帮我打附近威胁"
    if command.branch_id == "combat" and command.action == "retreat":
        return "撤退"
    if command.branch_id == "crafting" and command.target_id:
        return CRAFT_TARGETS[command.target_id]["text"]
    if command.branch_id == "construction" and command.target_id:
        return BUILD_TARGETS[command.target_id]["text"]
    if command.branch_id == "transport" and command.target_id:
        return f"去拿 {command.amount or 1} 个 {DELIVERY_TARGETS[command.target_id]}"
    if command.branch_id == "survival":
        return {
            "eat_best": "先吃点东西",
            "heal_best": "先治疗伤势",
            "recover_tent": "去帐篷休息",
        }[command.action]
    return ""


def build_intent(
    command: WheelSelection,
    snapshot: dict[str, Any],
) -> tuple[dict[str, Any] | None, str]:
    branch = command.branch_id
    action = command.action
    player = snapshot.get("player") or {}
    player_position = _position(player)
    player_guid = str(player.get("guid") or "")
    companion = snapshot.get("companion") or {}
    intent_id = f"wheel-{branch}-{action}"
    base = {
        "intent_id": intent_id,
        "lease_seconds": 300,
        "reason": f"wheel:{branch}.{action}",
        "params": {"wheel_command": True},
    }

    if branch == "combat":
        if action == "guard":
            return {
                **base,
                "mode": "guard",
                "params": {
                    "wheel_command": True,
                    "auto_dodge": True,
                    "retreat_on_lethal": True,
                },
            }, "收到，我会处理附近威胁。"
        return {
            **base,
            "mode": "retreat",
            "params": {"wheel_command": True},
        }, "收到，我马上撤回你身边。"

    if branch == "collection":
        if action == "collect_resource":
            resource = RESOURCE_TARGETS.get(command.target_id or "")
            if resource is None:
                raise WheelCommandError("unknown collection resource")
            return {
                **base,
                "mode": "harvest_area",
                "position": player_position,
                "target_prefab": resource["prefabs"][0],
                "lease_seconds": 600,
                "params": {
                    "wheel_command": True,
                    "radius": 32,
                    "arrive_distance": 4,
                    "target_prefabs": resource["prefabs"],
                    "amount": command.amount,
                    "drop_prefab": resource.get("drop"),
                    "required_tool": resource.get("tool"),
                    "assist_minion_prefab": resource.get("assist_minion"),
                    "max_assist_workers": 2,
                    "ignore_player_leash": True,
                },
            }, (
                f"收到，我去采集{resource['label']}，目标 "
                f"{command.amount} 个。"
            )
        if action == "pickup_loot":
            target = PICKUP_TARGETS.get(command.target_id or "")
            if target is None:
                raise WheelCommandError("unknown pickup target")
            return {
                **base,
                "mode": "gather",
                "position": player_position,
                "target_prefab": target["prefab"],
                "lease_seconds": 600,
                "params": {
                    "wheel_command": True,
                    "radius": 32,
                    "arrive_distance": 3,
                    "target_prefabs": [target["prefab"]],
                    "amount": command.amount,
                    "ignore_player_leash": True,
                },
            }, (
                f"收到，我去附近捡{target['label']}，目标 "
                f"{command.amount} 个。"
            )
        target = HUNT_TARGETS.get(command.target_id or "")
        if target is None:
            raise WheelCommandError("unknown hunt target")
        return {
            **base,
            "mode": "collect_loot",
            "target_prefab": target["item_prefab"],
            "lease_seconds": 1800,
            "params": {
                "wheel_command": True,
                "source_prefab": target["source_prefab"],
                "source_tag": target["source_tag"],
                "amount": command.amount,
                "give_to_player": True,
                "ignore_player_leash": True,
                "progress_reports": False,
                "patrol_radius": 48,
                "no_source_timeout": 60,
            },
        }, f"收到，我去收集{target['label']}，目标 {command.amount} 个。"

    if branch == "crafting":
        target = CRAFT_TARGETS.get(command.target_id or "")
        if target is None:
            raise WheelCommandError("unknown craft target")
        return {
            **base,
            "mode": "craft",
            "target_prefab": command.target_id,
            "params": {
                "wheel_command": True,
                "recipe": command.target_id,
            },
        }, f"收到，我开始制作{target['label']}。"

    if branch == "construction":
        target = BUILD_TARGETS.get(command.target_id or "")
        if target is None:
            raise WheelCommandError("unknown build target")
        return {
            **base,
            "mode": "build",
            "position": player_position,
            "target_prefab": command.target_id,
            "params": {
                "wheel_command": True,
                "recipe": command.target_id,
                "rotation": 0,
            },
        }, f"收到，我在你附近建造{target['label']}。"

    if branch == "transport":
        label = DELIVERY_TARGETS.get(command.target_id or "")
        if label is None:
            raise WheelCommandError("unknown transport target")
        location = _known_storage_position(snapshot)
        if location is None:
            return None, (
                f"要取{label}的话，我需要知道箱子或基地在哪里。"
                "先带我到那里，或把那里记成“家/基地”。"
            )
        return {
            **base,
            "mode": "fetch_item",
            "target_prefab": command.target_id,
            "position": location,
            "lease_seconds": 1800,
            "params": {
                "wheel_command": True,
                "search_radius": 24,
                "give_to_player": True,
                "amount": command.amount,
            },
        }, f"收到，我去取 {command.amount} 个{label}并带回来。"

    if branch == "farming":
        if action == "harvest":
            return {
                **base,
                "mode": "harvest_area",
                "position": player_position,
                "lease_seconds": 600,
                "params": {
                    "wheel_command": True,
                    "radius": 24,
                    "arrive_distance": 3,
                    "amount": command.amount,
                    "ignore_player_leash": True,
                    "allow_partial": True,
                },
            }, f"收到，我去收成熟作物，最多 {command.amount} 个。"
        if action == "plant":
            label = PLANT_TARGETS.get(command.target_id or "")
            if label is None:
                raise WheelCommandError("unknown plant target")
            owned = int(
                (snapshot.get("inventory_counts") or {}).get(
                    command.target_id,
                    0,
                )
            )
            if owned <= 0:
                return None, f"背包里没有{label}，我先不种。"
            return {
                **base,
                "mode": "deploy",
                "target_prefab": command.target_id,
                "position": player_position,
                "params": {
                    "wheel_command": True,
                    "item_prefab": command.target_id,
                    "prefer_existing_soil": True,
                    "till_if_needed": True,
                    "soil_search_radius": 16,
                    "till_search_radius": 6,
                },
            }, f"收到，我在附近种下{label}。"
        return {
            **base,
            "mode": "till",
            "position": player_position,
            "params": {
                "wheel_command": True,
                "required_tool": "farm_hoe",
                "craft_tool_if_missing": True,
                "soil_search_radius": 6,
            },
        }, "收到，我先耕一格地。"

    if branch == "survival":
        if action == "eat_best":
            food = _first_inventory(
                snapshot,
                (
                    "meatballs",
                    "cookedmeat",
                    "smallmeat_cooked",
                    "carrot_cooked",
                    "berries_cooked",
                    "berries",
                    "carrot",
                    "seeds",
                ),
            )
            if food is None:
                return None, "背包里没有能立刻吃的东西。"
            return {
                **base,
                "mode": "eat",
                "lease_seconds": 60,
                "params": {
                    "wheel_command": True,
                    "item_prefab": food,
                },
            }, "收到，我先吃点东西。"
        if action == "heal_best":
            healing = _first_inventory(
                snapshot,
                ("healingsalve", "honeypoultice"),
            )
            if healing is None:
                return None, "背包里没有治疗物品。"
            return {
                **base,
                "mode": "use_skill",
                "target_guid": str(companion.get("guid") or "") or None,
                "lease_seconds": 60,
                "params": {
                    "wheel_command": True,
                    "action": "USEITEM",
                    "item_prefab": healing,
                    "on_self": True,
                },
            }, "收到，我先处理伤势。"
        return {
            **base,
            "mode": "follow",
            "lease_seconds": 1800,
            "params": {
                "wheel_command": True,
                "ignore_autonomous_recovery": False,
                "force_recovery_check": True,
            },
        }, "好，我会在条件合适时去帐篷恢复三维。"

    if branch == "exploration":
        if action == "return_home":
            landmark = _home_landmark(snapshot)
            if landmark is None:
                return None, "还没有记录“家/基地/仓库”的位置。"
            return {
                **base,
                "mode": "homestead",
                "lease_seconds": 24 * 60 * 60,
                "params": {
                    "wheel_command": True,
                    "landmark": landmark,
                    "stay_home": True,
                    "stop_distance": 4,
                },
            }, f"收到，我回“{landmark}”待命。"
        resource = RESOURCE_TARGETS.get(command.target_id or "")
        if resource is None:
            raise WheelCommandError("unknown exploration resource")
        return {
            **base,
            "mode": "harvest_area",
            "position": player_position,
            "target_prefab": resource["prefabs"][0],
            "lease_seconds": 900,
            "params": {
                "wheel_command": True,
                "radius": 48,
                "arrive_distance": 4,
                "target_prefabs": resource["prefabs"],
                "ignore_player_leash": True,
            },
        }, f"收到，我去较大范围寻找并记录{resource['label']}。"

    if branch == "base":
        if action == "return_home":
            landmark = _home_landmark(snapshot)
            if landmark is None:
                return None, "还没有记录“家/基地/仓库”的位置。"
            return {
                **base,
                "mode": "homestead",
                "lease_seconds": 24 * 60 * 60,
                "params": {
                    "wheel_command": True,
                    "landmark": landmark,
                    "stay_home": True,
                    "stop_distance": 4,
                },
            }, f"收到，我回“{landmark}”待命。"
        return None, ""

    if branch == "interaction":
        if action == "return_to_player":
            return {
                **base,
                "mode": "follow",
                "params": {"wheel_command": True},
            }, "好，我回到你身边。"
        if action == "nearby_interactions":
            return None, ""
        label = DELIVERY_TARGETS.get(command.target_id or "")
        if label is None:
            raise WheelCommandError("unknown delivery target")
        owned = int(
            (snapshot.get("inventory_counts") or {}).get(command.target_id, 0)
        )
        if owned <= 0:
            return None, f"我身上没有{label}。"
        if owned < int(command.amount or 0):
            return None, (
                f"我身上只有 {owned} 个{label}，"
                f"不够你要的 {command.amount} 个。"
            )
        return {
            **base,
            "mode": "deliver_item",
            "target_guid": player_guid or None,
            "target_prefab": command.target_id,
            "lease_seconds": 180,
            "params": {
                "wheel_command": True,
                "amount": command.amount,
                "give_to_player": True,
            },
        }, f"收到，我把 {command.amount} 个{label}交给你。"

    if branch == "movement":
        if action == "follow":
            return {
                **base,
                "mode": "follow",
                "lease_seconds": 1800,
                "params": {"wheel_command": True},
            }, "好，我跟着你。"
        if action == "hold":
            return {
                **base,
                "mode": "hold",
                "lease_seconds": 24 * 60 * 60,
                "params": {"wheel_command": True},
            }, "好，我就在这里等你。"
        if action == "retreat":
            return {
                **base,
                "mode": "retreat",
                "params": {"wheel_command": True},
            }, "收到，我马上回来。"
        landmark = _home_landmark(snapshot)
        if landmark is None:
            return None, "还没有记录“家/基地/仓库”的位置。"
        return {
            **base,
            "mode": "homestead",
            "lease_seconds": 24 * 60 * 60,
            "params": {
                "wheel_command": True,
                "landmark": landmark,
                "stay_home": True,
                "stop_distance": 4,
            },
        }, f"收到，我回“{landmark}”待命。"

    return None, ""


def _position(section: dict[str, Any]) -> list[float] | None:
    x = section.get("x")
    z = section.get("z")
    if isinstance(x, (int, float)) and isinstance(z, (int, float)):
        return [float(x), float(z)]
    return None


def _home_landmark(snapshot: dict[str, Any]) -> str | None:
    landmarks = snapshot.get("landmarks")
    if not isinstance(landmarks, dict):
        return None
    return next(
        (
            name
            for name in ("家", "基地", "仓库")
            if isinstance(landmarks.get(name), dict)
        ),
        None,
    )


def _known_storage_position(
    snapshot: dict[str, Any],
) -> list[float] | None:
    landmarks = snapshot.get("landmarks")
    if not isinstance(landmarks, dict):
        return None
    for name in ("仓库", "基地", "家"):
        landmark = landmarks.get(name)
        if isinstance(landmark, dict):
            position = _position(landmark)
            if position is not None:
                return position
    for entity in snapshot.get("nearby") or []:
        if isinstance(entity, dict) and entity.get("container"):
            position = _position(entity)
            if position is not None:
                return position
    return None


def _first_inventory(
    snapshot: dict[str, Any],
    prefabs: tuple[str, ...],
) -> str | None:
    counts = snapshot.get("inventory_counts") or {}
    return next(
        (
            prefab
            for prefab in prefabs
            if int(counts.get(prefab, 0)) > 0
        ),
        None,
    )
