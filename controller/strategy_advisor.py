from __future__ import annotations

import math
from typing import Any


FIST_DAMAGE = 10

WEAPON_DAMAGE = {
    "spear": 34,
    "tentaclespike": 51,
    "hambat": 59,
    "nightsword": 68,
    "ruins_bat": 59,
    "glasscutter": 68,
    "goldenaxe": 43.5,
    "axe": 27.2,
    "pickaxe": 27.2,
    "walter_slingshot": 17,
}

# Head and body protection is multiplied by the game. Explicit slots let the
# adviser use DST's real two-piece calculation without pretending that 80% +
# 90% equals 170%.
ARMOR_PROFILE = {
    "armorgrass": ("body", 0.6),
    "armorwood": ("body", 0.8),
    "armormarble": ("body", 0.95),
    "armornight": ("body", 0.95),
    "armordragonfly": ("body", 0.8),
    "armor_ruins": ("body", 0.9),
    "armor_lunarplant": ("body", 0.9),
    "armorfootball": ("head", 0.8),
    "armor_sanity": ("head", 0.8),
    "armorruinshat": ("head", 0.9),
    "wathgrithrhat": ("head", 0.8),
}

THREAT_PROFILE = {
    "frog": (100, 10),
    "frog_red": (100, 10),
    "frog_brightmare": (100, 10),
    "spider": (100, 20),
    "spider_warrior": (200, 20),
    "spider_hider": (100, 20),
    "spider_spitter": (100, 20),
    "hound": (150, 20),
    "firehound": (100, 20),
    "icehound": (100, 20),
    "bunnyman": (200, 40),
    "clockwork_knight": (300, 40),
    "clockwork_rook": (300, 45),
    "clockwork_bishop": (300, 40),
    "tentacle": (500, 34),
    "merm": (100, 20),
    "pigman": (250, 33),
    "pigguard": (250, 33),
}

THREAT_TACTICS = {
    "frog": {
        "approach": "avoid_surround",
        "notes": ["群居青蛙容易连续硬直，数量多时拉开再逐个处理"],
    },
    "frog_red": {
        "approach": "avoid_surround",
        "notes": ["群居青蛙容易连续硬直，数量多时拉开再逐个处理"],
    },
    "frog_brightmare": {
        "approach": "avoid_surround",
        "notes": ["群居青蛙容易连续硬直，数量多时拉开再逐个处理"],
    },
    "hound": {
        "approach": "kite_and_avoid_surround",
        "stunlock_risk": True,
        "notes": ["猎犬攻击后可能停顿，可边走边反击", "大群猎犬有连续硬直风险"],
    },
    "firehound": {
        "approach": "kite_away_from_flammables",
        "stunlock_risk": True,
        "danger_on_death": "fire",
        "notes": [
            "大群猎犬有连续硬直风险",
            "红猎犬死亡会留下火焰，不能在基地、森林或易燃物旁处理",
        ],
    },
    "icehound": {
        "approach": "kite_and_avoid_surround",
        "stunlock_risk": True,
        "notes": ["大群猎犬有连续硬直风险", "蓝猎犬攻击附带冰冻风险"],
    },
    "deerclops": {
        "approach": "kite_from_outside_aoe",
        "aoe_attack": True,
        "structure_damage": True,
        "notes": [
            "巨鹿攻击是前方大范围伤害，躲避距离要比普通敌人更远",
            "不得在基地核心建筑和玩家身边开战，优先引到空地",
        ],
    },
    "spiderqueen": {
        "approach": "clear_adds_and_keep_escape_route",
        "summons_adds": True,
        "notes": ["优先处理持续增援的小蜘蛛，并保留不会被包围的撤退路线"],
    },
    "beequeen": {
        "approach": "keep_moving_and_manage_adds",
        "summons_adds": True,
        "notes": ["避免站桩被蜂群包围，提前保留恢复、护甲和灭火手段"],
    },
    "dragonfly": {
        "approach": "kite_high_damage_attacks",
        "aoe_attack": True,
        "fire_damage": True,
        "notes": ["避开高危范围攻击，保留撤退通道，不能站桩硬吃伤害"],
    },
}

FOOD_ITEMS = {
    "berries",
    "berries_cooked",
    "berry_juice",
    "carrot",
    "carrot_cooked",
    "cookedmeat",
    "meatballs",
    "monstermeat",
    "monstermeat_cooked",
    "seeds",
    "seeds_cooked",
    "smallmeat",
    "smallmeat_cooked",
}

HEALING_ITEMS = {
    "healingsalve",
    "honey",
    "honey_nectar",
    "honeyham",
    "honeypoultice",
    "tallbirdegg_cooked",
}

FUEL_ITEMS = {
    "cutgrass",
    "twigs",
    "log",
    "boards",
    "charcoal",
    "petals",
    "petals_evil",
    "seeds",
}

LIGHT_ITEMS = {
    "torch",
    "lantern",
    "minerhat",
    "moggles",
}

FACILITY_PREFABS = {
    "cookpot",
    "portablecookpot",
    "icebox",
    "meatrack",
    "dryingrack",
    "firepit",
    "campfire",
    "coldfire",
    "coldfirepit",
    "lightning_rod",
    "treasurechest",
}

PUPPET_PREFABS = {
    "shadowworker",
    "shadowduelist",
    "shadowprotector",
}

FOOD_HUNGER = {
    "seeds": 4.7,
    "seeds_cooked": 9.4,
    "berries": 9.4,
    "berries_cooked": 12.5,
    "carrot": 12.5,
    "carrot_cooked": 18.8,
    "monstermeat": 18.8,
    "monstermeat_cooked": 18.8,
    "smallmeat": 12.5,
    "smallmeat_cooked": 18.8,
    "meat": 25,
    "cookedmeat": 25,
    "meatballs": 62.5,
}

FOOD_STRATEGIC_VALUE = {
    "seeds": 1,
    "seeds_cooked": 2,
    "monstermeat": 2,
    "monstermeat_cooked": 3,
    "berries": 3,
    "berries_cooked": 4,
    "carrot": 4,
    "carrot_cooked": 5,
    "smallmeat": 6,
    "smallmeat_cooked": 7,
    "cookedmeat": 8,
    "meatballs": 10,
    "honey": 12,
    "honeyham": 14,
}

CHEAP_MEAT = ("monstermeat", "smallmeat", "meat")
CHEAP_FILLERS = (
    "berries",
    "berries_cooked",
    "carrot",
    "carrot_cooked",
    "mushroom",
    "mushroom_cooked",
)

# The vanilla moon cycle is 20 days. Full moon occupies one day and the
# position is stable after accounting for waxing/waning in the reported phase.
MOON_CYCLE = (
    "new",
    "quarter",
    "quarter",
    "quarter",
    "half",
    "half",
    "half",
    "threequarter",
    "threequarter",
    "threequarter",
    "full",
    "threequarter",
    "threequarter",
    "threequarter",
    "half",
    "half",
    "half",
    "quarter",
    "quarter",
    "quarter",
)

HOME_FOREST_RADIUS = 18.0
HOME_FOREST_ALIGN_TOLERANCE = 0.75
HOME_FOREST_MIN_CLUSTER = 3

LIFE_KNOWLEDGE = (
    {
        "id": "glommer_full_moon",
        "fact": "格罗姆花在满月的格罗姆雕像旁出现；即使雕像已被挖掉，下一个满月仍会重新长出花。",
        "action": "接格罗姆应排到满月夜晚，先到已记录雕像，取得花后带回基地。",
        "source": "https://dontstarve.wiki.gg/wiki/Glommer%27s_Statue/DST",
    },
    {
        "id": "food_spoilage",
        "fact": "烹饪或锅煮会减缓现有腐坏，且多数食物熟制后三维收益更高。",
        "action": "快坏食材先安排消耗或烹饪；轻微饥饿优先现成低价食物，不直接做昂贵料理。",
        "source": "https://dontstarve.wiki.gg/wiki/Food/DST",
    },
    {
        "id": "drying_rack_preservation",
        "fact": "晾肉架可把生肉、鱼和部分蘑菇晾成更耐放的干货；DST 中成品留在架上仍会腐坏，下雨时不会继续变干。",
        "action": "有晾肉架时先收成品；空架只在食材快坏、不占任务预留且不下雨时逐份晾晒。",
        "source": "https://dontstarve.wiki.gg/wiki/Drying_Rack/DST",
    },
    {
        "id": "meatballs_baseline",
        "fact": "肉丸是早期处理饥饿、避免浪费零散食材的高性价比基础料理。",
        "action": "只有存在真实大饥饿缺口、锅和可用肉加三种廉价填充物时才做肉丸。",
        "source": "https://dontstarve.wiki.gg/wiki/Food/DST",
    },
    {
        "id": "tree_renewal",
        "fact": "砍倒常青树会留下树桩，铲掉可得一根原木；新树需要补种松果，树桩不会自行恢复成树。",
        "action": "只在家附近成片、行列对齐的自家林区砍成熟树，随后检查铲子、树桩和对应种子并补种。",
        "source": "https://dontstarve.wiki.gg/wiki/Evergreen/DST",
    },
    {
        "id": "shadow_worker_density",
        "fact": "麦斯威尔的暗影仆从可采矿、伐木、挖树桩、收获并搬运，但只在召唤点附近持续工作。",
        "action": "资源成片且预计持续数分钟才召唤；稀疏目标自己用普通工具，避免浪费理智和法典耐久。",
        "source": "https://dontstarve.wiki.gg/wiki/Shadow_Puppet/DST",
    },
    {
        "id": "supply_priority",
        "fact": "基地补给需要同时考虑腐坏、稀缺度、任务预留和工具等级。",
        "action": "先快坏食物、低价值燃料、普通工具；保留稀有材料、任务材料和最后一套应急补给。",
        "source": "https://dontstarve.wiki.gg/wiki/Inventory",
    },
    {
        "id": "icebox_preservation",
        "fact": "冰箱会把易腐食物的腐坏速度降到约一半，是暂时吃不完的食物的优先收纳处。",
        "action": "玩家不急需进食时把易腐食物收进冰箱；只有没有冰箱时才退回普通箱子。",
        "source": "https://dontstarve.wiki.gg/wiki/Ice_Box/DST",
    },
    {
        "id": "spring_lightning_protection",
        "fact": "春季雷击可能引燃并摧毁密集基地建筑；避雷针可吸引约 40 单位内的雷击。",
        "action": "春季前检查基地避雷针；没有可靠保护时不要贸然在核心建筑旁长时间点火或扩建。",
        "source": "https://dontstarve.wiki.gg/wiki/Lightning/DST",
    },
    {
        "id": "thermal_stone_durability",
        "fact": "DST 暖石通过吸收冷热工作并会损失耐久，离开热源后的冷热状态仍然有用。",
        "action": "冬季和夏季优先用暖石配合保暖或降温装备；不需要取暖时不要无意义地把它一直放在火边消耗耐久。",
        "source": "https://dontstarve.wiki.gg/wiki/Thermal_Stone/DST",
    },
    {
        "id": "rain_fire_consumption",
        "fact": "雨天火坑燃料消耗可能显著加快，湿燃料的燃烧时间也会缩短。",
        "action": "雨前或雨中提前检查基地火坑，优先使用低价值干燃料补齐；避免浪费稀有燃料。",
        "source": "https://dontstarve.wiki.gg/wiki/Fire_Pit/DST",
    },
    {
        "id": "berry_bush_winter",
        "fact": "浆果丛被采后会按周期恢复，但冬季不会正常长回浆果。",
        "action": "冬季不要把浆果当作稳定补给；入冬前保留不易腐坏食物和其他主食来源。",
        "source": "https://dontstarve.wiki.gg/wiki/Berry_Bush/DST",
    },
    {
        "id": "hound_wave_escalation",
        "fact": "猎犬袭击随生存天数增加而扩大，攻击后会短暂停顿，数量多时有连续硬直风险。",
        "action": "不要贴基地硬接大群猎犬；利用攻击停顿风筝，红猎犬要远离建筑、树林和易燃物处理。",
        "source": "https://dontstarve.wiki.gg/wiki/Hound/DST",
    },
)


def _ratio(section: dict[str, Any], current: str, maximum: str) -> float:
    value = section.get(current)
    cap = section.get(maximum)
    if not isinstance(value, (int, float)) or not isinstance(cap, (int, float)):
        return 1.0
    if cap <= 0:
        return 1.0
    return max(0.0, min(1.0, float(value) / float(cap)))


def _condition(item: dict[str, Any]) -> float:
    raw = item.get("condition_percent")
    if not isinstance(raw, (int, float)):
        return 1.0
    value = float(raw)
    if value > 1:
        value /= 100.0
    return max(0.0, min(1.0, value))


class StrategyAdvisor:
    """Derive deterministic, source-backed strategy context for the planner."""

    def enrich(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        result = dict(snapshot)
        result["decision_support"] = self.analyze(result)
        return result

    def analyze(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        return {
            "schema": 1,
            "combat": self._combat(snapshot),
            "survival": self._survival(snapshot),
            "player_care": self._player_care(snapshot),
            "homestead": self._homestead(snapshot),
            "calendar": self._calendar(snapshot),
            "maxwell": self._maxwell(snapshot),
            "consumption": self._consumption(snapshot),
            "farming": self._farming(snapshot),
            "life_knowledge": self._life_knowledge(snapshot),
        }

    def _available_items(
        self,
        snapshot: dict[str, Any],
    ) -> list[dict[str, Any]]:
        result = [
            item
            for item in snapshot.get("inventory") or []
            if isinstance(item, dict) and item.get("prefab")
        ]
        result.extend(
            item
            for item in snapshot.get("equipped") or []
            if isinstance(item, dict) and item.get("prefab")
        )
        return result

    def _best_weapon(
        self,
        snapshot: dict[str, Any],
    ) -> tuple[float, str | None]:
        best_damage = float(FIST_DAMAGE)
        best_name = None
        for item in self._available_items(snapshot):
            prefab = str(item.get("prefab") or "")
            damage = WEAPON_DAMAGE.get(prefab)
            if damage is not None and damage > best_damage:
                best_damage = float(damage)
                best_name = prefab
        return best_damage, best_name

    def _best_armor(
        self,
        snapshot: dict[str, Any],
    ) -> dict[str, Any]:
        by_slot: dict[str, dict[str, Any]] = {}
        for item in self._available_items(snapshot):
            prefab = str(item.get("prefab") or "")
            profile = ARMOR_PROFILE.get(prefab)
            reported_absorb = item.get("armor_absorb_percent")
            if isinstance(reported_absorb, (int, float)):
                reported_absorb = float(reported_absorb)
                if reported_absorb > 1:
                    reported_absorb /= 100.0
                reported_absorb = max(0.0, min(1.0, reported_absorb))
            else:
                reported_absorb = None
            if profile is None and reported_absorb is None:
                continue
            if profile is None:
                slot, absorb = "unknown", float(reported_absorb)
            else:
                slot, absorb = profile
                if reported_absorb is not None:
                    absorb = reported_absorb
            reported_slot = str(item.get("slot") or "")
            if reported_slot in {"head", "body"}:
                slot = reported_slot
            effective_absorb = absorb * _condition(item)
            current = by_slot.get(slot)
            if current is None or effective_absorb > current["effective_absorb"]:
                by_slot[slot] = {
                    "slot": slot,
                    "prefab": prefab,
                    "absorb": absorb,
                    "condition": round(_condition(item), 4),
                    "effective_absorb": effective_absorb,
                }
        remaining = 1.0
        for armor in by_slot.values():
            remaining *= 1.0 - armor["effective_absorb"]
        return {
            "slots": by_slot,
            "effective_absorb": round(1.0 - remaining, 4),
            "pieces": len(by_slot),
        }

    @staticmethod
    def _tactics(
        prefab: str,
        combatants: int,
    ) -> dict[str, Any]:
        profile = THREAT_TACTICS.get(prefab)
        if profile is None:
            return {
                "approach": "standard_kite",
                "notes": ["观察攻击间隔和增援，保留撤退路线"],
            }
        tactics = {
            "approach": profile["approach"],
            "notes": list(profile["notes"]),
        }
        for key in (
            "aoe_attack",
            "structure_damage",
            "summons_adds",
            "fire_damage",
            "danger_on_death",
        ):
            if key in profile:
                tactics[key] = profile[key]
        if profile.get("stunlock_risk") and combatants >= 3:
            tactics["stunlock_risk"] = True
            tactics["notes"].append("三只以上时不要停在原地换血，优先拉开角度")
        return tactics

    def _combat(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        hostiles = [
            entity
            for entity in snapshot.get("nearby") or []
            if isinstance(entity, dict) and entity.get("hostile")
        ]
        hostiles.sort(key=lambda item: float(item.get("distance") or 9999))
        if not hostiles:
            return {
                "active": False,
                "stance": "unthreatened",
                "risk_score": 0,
            }

        target = hostiles[0]
        prefab = str(target.get("prefab") or "")
        default_health, default_damage = THREAT_PROFILE.get(
            prefab,
            (100, 20),
        )
        target_health = float(target.get("health") or default_health)
        target_damage = float(target.get("damage") or default_damage)
        weapon_damage, weapon = self._best_weapon(snapshot)
        armor = self._best_armor(snapshot)
        combatants = len(hostiles)
        kill_rounds = max(1, math.ceil(target_health / weapon_damage))
        incoming_per_hit = target_damage * (
            1.0 - float(armor["effective_absorb"])
        )
        health = snapshot.get("companion") or {}
        max_health = float(health.get("max_health") or 0)
        current_health = float(health.get("health") or 0)
        health_ratio = _ratio(health, "health", "max_health")
        survivable_hits = (
            current_health / incoming_per_hit
            if incoming_per_hit > 0
            else math.inf
        )
        projected_damage = incoming_per_hit * kill_rounds * combatants
        projected_health_loss = (
            projected_damage / max_health if max_health > 0 else 1.0
        )

        warnings: list[str] = []
        risk_score = 0
        tactics = self._tactics(prefab, combatants)
        if weapon_damage <= FIST_DAMAGE:
            warnings.append("没有可用武器")
            risk_score += 30
        if armor["effective_absorb"] < 0.4 and combatants >= 2:
            warnings.append("双层护甲覆盖不足")
            risk_score += 20
        if health_ratio < 0.35:
            warnings.append("生命低于 35%")
            risk_score += 40
        elif health_ratio < 0.55:
            warnings.append("生命低于 55%")
            risk_score += 20
        if projected_health_loss >= 0.85:
            warnings.append("预计承伤接近或超过当前生命")
            risk_score += 45
        elif projected_health_loss >= 0.55:
            warnings.append("预计承伤超过半数生命")
            risk_score += 25
        if tactics.get("structure_damage"):
            warnings.append("目标会破坏建筑，不能在基地核心开战")
            risk_score += 10
        if tactics.get("danger_on_death") == "fire":
            warnings.append("目标死亡会引燃附近物体")
            risk_score += 10
        if tactics.get("stunlock_risk"):
            warnings.append("多目标连续攻击可能造成硬直")
            risk_score += 10
        risk_score = min(100, risk_score)
        if risk_score >= 70:
            stance = "retreat"
        elif risk_score >= 45:
            stance = "recover_first"
        else:
            stance = "engage"
        return {
            "active": True,
            "target_guid": target.get("guid"),
            "target_prefab": prefab,
            "target_health": round(target_health, 1),
            "combatants": combatants,
            "weapon": weapon,
            "weapon_damage": round(weapon_damage, 1),
            "armor": armor,
            "incoming_damage_per_hit": round(incoming_per_hit, 2),
            "kill_rounds": kill_rounds,
            "survivable_hits": (
                None if math.isinf(survivable_hits)
                else round(survivable_hits, 2)
            ),
            "projected_damage": round(projected_damage, 1),
            "projected_health_loss": round(projected_health_loss, 3),
            "risk_score": risk_score,
            "stance": stance,
            "warnings": warnings,
            "tactics": tactics,
            "uncertainties": [
                "攻击间隔、走位、控制和敌人增援会改变实际承伤",
            ],
        }

    def _survival(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        companion = snapshot.get("companion") or {}
        player = snapshot.get("player") or {}
        world = snapshot.get("world") or {}
        inventory = snapshot.get("inventory_counts") or {}
        nearby_prefabs = {
            str(entity.get("prefab") or "")
            for entity in snapshot.get("nearby") or []
            if isinstance(entity, dict)
        }
        food_count = sum(
            int(inventory.get(prefab) or 0) for prefab in FOOD_ITEMS
        )
        healing_count = sum(
            int(inventory.get(prefab) or 0) for prefab in HEALING_ITEMS
        )
        fuel_count = sum(
            int(inventory.get(prefab) or 0) for prefab in FUEL_ITEMS
        )
        light_count = sum(
            int(inventory.get(prefab) or 0) for prefab in LIGHT_ITEMS
        )
        season = str(world.get("season") or "").lower()
        phase = str(world.get("phase") or "").lower()
        day = int(world.get("day") or 0)
        remaining_days_raw = world.get("remaining_days_in_season")
        remaining_days = (
            int(remaining_days_raw)
            if isinstance(remaining_days_raw, (int, float))
            else None
        )
        priorities: list[str] = []
        preparedness: dict[str, bool] = {}

        if companion.get("freezing") is True:
            priorities.extend(["立即保暖", "靠近火源或穿戴冬季保暖物"])
        if companion.get("overheating") is True:
            priorities.extend(["立即降温", "靠近冷源或穿戴夏季隔热物"])
        if companion.get("in_light") is False:
            priorities.append("先获得可信光源")
        if _ratio(companion, "hunger", "max_hunger") < 0.35:
            priorities.append("先补充饱食度")
        if _ratio(companion, "health", "max_health") < 0.35:
            priorities.append("先治疗")

        if season == "winter":
            preparedness.update(
                {
                    "winter_insulation": bool(
                        companion.get("winter_insulation")
                    ),
                    "food": food_count > 0,
                    "light": light_count > 0 or companion.get("in_light") is True,
                    "fuel": fuel_count > 0,
                }
            )
            if fuel_count == 0:
                priorities.append("冬夜前准备可用燃料")
            if food_count == 0:
                priorities.append("冬季食物储备不足")
            season_plan = "先保证保暖、光源、燃料和食物，再考虑远行"
        elif season == "summer":
            preparedness.update(
                {
                    "summer_insulation": bool(
                        companion.get("summer_insulation")
                    ),
                    "cooling": bool(
                        nearby_prefabs & {"coldfire", "coldfirepit", "icebox"}
                    ),
                    "food": food_count > 0,
                }
            )
            if not preparedness["cooling"]:
                priorities.append("确认基地附近有可靠冷源")
            season_plan = "控制体温并减少在基地外长时间停留，野火风险期间不在基地点火"
        elif season == "spring":
            preparedness["rain_protection"] = bool(
                companion.get("rain_immune")
                or companion.get("sheltered")
            )
            preparedness["lightning_protection"] = bool(
                nearby_prefabs & {"lightning_rod", "lightningrod"}
            )
            if not preparedness["rain_protection"]:
                priorities.append("准备避雨或防水装备")
            if not preparedness["lightning_protection"]:
                priorities.append("基地缺少避雷针，雷雨时不要守在建物密集处")
            season_plan = "关注潮湿、雷击和青蛙雨，雷雨时靠近避雷针或离开易燃基地核心"
        elif season == "autumn":
            preparedness["winter_preparation"] = food_count > 1 and fuel_count > 0
            # World day keeps increasing across years. The old day >= 12
            # test therefore treated every late autumn as the first winter.
            # Prefer the world-reported countdown and use the default calendar
            # only as a compatibility fallback for older Mod observations.
            winter_imminent = (
                0 <= remaining_days <= 9
                if remaining_days is not None
                else 12 <= day <= 20
            )
            preparedness["winter_imminent"] = winter_imminent
            if winter_imminent and not preparedness["winter_preparation"]:
                priorities.append("冬季将至，提前补足食物、燃料和保暖")
            season_plan = "入冬前补齐保暖、光源、燃料和不易腐坏食物"
        else:
            season_plan = "根据实际天气、体温和危险继续评估"

        if phase == "night" and companion.get("in_light") is not True:
            priorities.append("夜间未在可信光源内")
        priorities = list(dict.fromkeys(priorities))
        return {
            "season": season or None,
            "day": day or None,
            "remaining_days_in_season": remaining_days,
            "phase": phase or None,
            "body_temperature": world.get("body_temperature"),
            "ambient_temperature": world.get("ambient_temperature"),
            "wetness": world.get("wetness"),
            "food_count": food_count,
            "healing_count": healing_count,
            "fuel_count": fuel_count,
            "light_count": light_count,
            "facilities_nearby": sorted(nearby_prefabs & FACILITY_PREFABS),
            "preparedness": preparedness,
            "priorities": priorities,
            "season_plan": season_plan,
            "default_calendar": {
                "autumn_days": 20,
                "winter_days": 15,
                "spring_days": 20,
                "summer_days": 15,
                "first_winter_start_day": 21,
                "assumption": "仅用于默认世界长度；优先相信世界上报的季节布尔值",
            },
            "player_vitals": {
                "health_ratio": round(
                    _ratio(player, "health", "max_health"),
                    3,
                ),
                "hunger_ratio": round(
                    _ratio(player, "hunger", "max_hunger"),
                    3,
                ),
                "sanity_ratio": round(
                    _ratio(player, "sanity", "max_sanity"),
                    3,
                ),
            },
        }

    def _player_care(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        player = snapshot.get("player") or {}
        companion = snapshot.get("companion") or {}
        nearby_prefabs = {
            str(entity.get("prefab") or "")
            for entity in snapshot.get("nearby") or []
            if isinstance(entity, dict)
        }
        items = self._available_items(snapshot)
        counts = snapshot.get("inventory_counts") or {}
        foods = []
        for item in items:
            prefab = str(item.get("prefab") or "")
            if not item.get("edible") or prefab not in FOOD_HUNGER:
                continue
            hunger = item.get("food_hunger")
            if not isinstance(hunger, (int, float)):
                hunger = FOOD_HUNGER.get(prefab, 0)
            perish = item.get("perish_percent")
            foods.append(
                {
                    "prefab": prefab,
                    "hunger": round(float(hunger), 1),
                    "perish_percent": perish,
                    "strategic_cost": FOOD_STRATEGIC_VALUE.get(prefab, 16),
                }
            )

        max_hunger = float(player.get("max_hunger") or 0)
        hunger = float(player.get("hunger") or 0)
        hunger_deficit = max(0.0, max_hunger - hunger)
        hunger_ratio = hunger / max_hunger if max_hunger > 0 else 1.0
        max_health = float(player.get("max_health") or 0)
        health = float(player.get("health") or 0)
        health_deficit = max(0.0, max_health - health)
        health_ratio = health / max_health if max_health > 0 else 1.0
        max_sanity = float(player.get("max_sanity") or 0)
        sanity = float(player.get("sanity") or 0)
        sanity_deficit = max(0.0, max_sanity - sanity)
        sanity_ratio = sanity / max_sanity if max_sanity > 0 else 1.0

        tolerance = max(8.0, hunger_deficit * 0.35)
        for food in foods:
            gain = float(food["hunger"])
            covered = min(gain, hunger_deficit)
            food["overshoot"] = round(max(0.0, gain - hunger_deficit), 1)
            food["wasteful"] = food["overshoot"] > tolerance
            food["efficiency"] = round(
                covered / max(1, int(food["strategic_cost"])),
                2,
            )
        foods.sort(
            key=lambda item: (
                bool(item["wasteful"]),
                -float(item["efficiency"]),
                float(item["perish_percent"])
                if isinstance(item["perish_percent"], (int, float))
                else 100,
                int(item["strategic_cost"]),
                item["prefab"],
            )
        )
        suitable_foods = [item for item in foods if not item["wasteful"]]
        best_existing_food = (
            suitable_foods[0]
            if suitable_foods
            else (
                foods[0]
                if foods and hunger_ratio < 0.18
                else None
            )
        )

        pot_available = bool(
            nearby_prefabs
            & {
                "cookpot",
                "portablecookpot",
                "archive_cookpot",
            }
        )
        meat = [
            prefab
            for prefab in CHEAP_MEAT
            for _ in range(int(counts.get(prefab) or 0))
        ]
        fillers = [
            prefab
            for prefab in CHEAP_FILLERS
            for _ in range(int(counts.get(prefab) or 0))
        ]
        can_meatballs = pot_available and bool(meat) and len(fillers) >= 3
        needs_cooking = hunger_ratio < 0.58 or hunger_deficit >= 45
        should_cook = (
            needs_cooking
            and can_meatballs
            and best_existing_food is None
        )
        action = "none"
        reason = "三维暂时没有需要消耗基地食材补足的大缺口"
        if player.get("freezing") is True or player.get("overheating") is True:
            action = "thermal_first"
            reason = "先处理玩家体温，再考虑进食"
        elif hunger_ratio < 0.18 or hunger_deficit >= 90:
            action = "urgent_food"
            reason = "玩家饥饿缺口较大，先给现成食物；基地条件满足时再做 Meatballs"
        elif should_cook:
            action = "cook_meatballs"
            reason = "玩家有明显饥饿缺口且基地有锅，优先一份便宜肉配三种低价填充物"
        elif hunger_deficit >= 25 and best_existing_food is not None:
            action = "offer_existing_food"
            reason = "优先给快坏或单份饱食收益高的现成食物，不为此消耗昂贵料理"
        elif hunger_deficit >= 25:
            action = "wait_for_hunger"
            reason = "现有食物都会明显过量；轻微缺口先不消耗昂贵料理"
        if health_ratio < 0.4:
            action = "heal_first"
            reason = "玩家生命低于 40%，先治疗而不是用食物硬顶"
        elif sanity_ratio < 0.3:
            action = "sanity_first"
            reason = "玩家精神低于 30%，先处理精神风险"

        return {
            "player": {
                "health": round(health, 1),
                "max_health": round(max_health, 1),
                "hunger": round(hunger, 1),
                "max_hunger": round(max_hunger, 1),
                "sanity": round(sanity, 1),
                "max_sanity": round(max_sanity, 1),
            },
            "deficits": {
                "health": round(health_deficit, 1),
                "hunger": round(hunger_deficit, 1),
                "sanity": round(sanity_deficit, 1),
            },
            "ratios": {
                "health": round(health_ratio, 3),
                "hunger": round(hunger_ratio, 3),
                "sanity": round(sanity_ratio, 3),
            },
            "action": action,
            "reason": reason,
            "needs_cooking": needs_cooking,
            "should_cook_now": should_cook,
            "best_existing_food": best_existing_food,
            "existing_food": foods[:8],
            "food_economy": {
                "suitable_existing_food": len(suitable_foods),
                "waste_tolerance_hunger": round(tolerance, 1),
                "rule": (
                    "先匹配真实饥饿缺口，再比较饱食效率、腐坏时间和物资价值；"
                    "轻微饥饿不使用 Meatballs 等昂贵料理"
                ),
            },
            "cookpot_available": pot_available,
            "meatballs_ingredients_available": can_meatballs,
            "healing_reserve_policy": {
                "keep": 1,
                "use_last_when_health_ratio_at_or_below": 0.2,
            },
            "meatballs_plan": (
                {
                    "product": "meatballs",
                    "meat": meat[0],
                    "fillers": fillers[:3],
                    "expected_hunger": 62.5,
                    "expected_health": 5,
                    "expected_sanity": 3,
                    "rule": "只补真实缺口；轻微饥饿先吃现成低价食物，不消耗珍贵料理",
                }
                if can_meatballs
                else None
            ),
            "companion_distance": companion.get("distance"),
            "uncertainties": [
                "具体料理结果取决于游戏内锅的配方判定，执行前必须核对实际成品",
                "玩家移动、任务保留食材和其他 Mod 可能改变可用材料",
            ],
        }

    def _homestead(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        world = snapshot.get("world") or {}
        counts = snapshot.get("inventory_counts") or {}
        nearby = [
            entity
            for entity in snapshot.get("nearby") or []
            if isinstance(entity, dict)
        ]
        chests = [
            entity
            for entity in nearby
            if entity.get("container")
            and str(entity.get("prefab") or "")
            not in {"cookpot", "portablecookpot", "icebox"}
        ]
        ground_items = [
            entity
            for entity in nearby
            if entity.get("ground_item") is True
            or (
                entity.get("inventory_item") is True
                and not entity.get("owner")
            )
        ]
        tree_candidates = [
            entity
            for entity in nearby
            if str(entity.get("prefab") or "").startswith(
                ("evergreen", "deciduoustree")
            )
            and not entity.get("stump")
            and entity.get("mature") is not False
        ]
        stump_candidates = [
            entity
            for entity in nearby
            if entity.get("stump") is True
            or str(entity.get("prefab") or "").endswith("_stump")
        ]
        home = snapshot.get("home") or {}
        try:
            home_x = float(home.get("x"))
            home_z = float(home.get("z"))
        except (TypeError, ValueError, AttributeError):
            home_x = None
            home_z = None

        forest_layout = []
        for entity in tree_candidates + stump_candidates:
            try:
                x = float(entity.get("x"))
                z = float(entity.get("z"))
            except (TypeError, ValueError):
                continue
            if home_x is None or home_z is None:
                forest_layout.append(entity)
                continue
            dx = x - home_x
            dz = z - home_z
            if dx * dx + dz * dz <= HOME_FOREST_RADIUS * HOME_FOREST_RADIUS:
                forest_layout.append(entity)

        def in_aligned_home_forest(entity: dict[str, Any]) -> bool:
            if len(forest_layout) < HOME_FOREST_MIN_CLUSTER:
                return False
            try:
                x = float(entity.get("x"))
                z = float(entity.get("z"))
            except (TypeError, ValueError):
                return False
            aligned = 0
            for other in forest_layout:
                if other is entity:
                    continue
                try:
                    ox = float(other.get("x"))
                    oz = float(other.get("z"))
                except (TypeError, ValueError):
                    continue
                dx = abs(ox - x)
                dz = abs(oz - z)
                if (dx > 0.25 or dz > 0.25) and (
                    dx <= HOME_FOREST_ALIGN_TOLERANCE
                    or dz <= HOME_FOREST_ALIGN_TOLERANCE
                ):
                    aligned += 1
                    if aligned >= HOME_FOREST_MIN_CLUSTER - 1:
                        return True
            return False

        trees = [
            entity
            for entity in tree_candidates
            if in_aligned_home_forest(entity)
        ]
        stumps = [
            entity
            for entity in stump_candidates
            if in_aligned_home_forest(entity)
        ]
        marble = [
            entity
            for entity in nearby
            if str(entity.get("prefab") or "").startswith("marbletree")
        ]
        ready_crops = [
            entity
            for entity in nearby
            if entity.get("pickable") is True
            and entity.get("mature") is not False
        ]
        drying_racks = [
            entity
            for entity in nearby
            if entity.get("drying") is True
            or str(entity.get("prefab") or "") == "meatrack"
        ]
        drying_ready = [
            entity
            for entity in drying_racks
            if entity.get("drying_done") is True
        ]
        empty_drying_racks = [
            entity
            for entity in drying_racks
            if entity.get("drying_done") is not True
            and entity.get("drying_active") is not True
        ]
        seeds = {
            "pinecone": int(counts.get("pinecone") or 0),
            "acorn": int(counts.get("acorn") or 0),
        }
        available_tools = {
            tool
            for tool in (
                "axe",
                "goldenaxe",
                "pickaxe",
                "goldenpickaxe",
                "shovel",
                "goldenshovel",
                "multitool",
                "multitool_axe",
                "multitool_pickaxe",
                "multitool_shovel",
            )
            if int(counts.get(tool) or 0) > 0
        }
        craftable = {
            str(recipe.get("name") or "")
            for recipe in (
                (snapshot.get("capabilities") or {}).get(
                    "craftable_recipes"
                )
                or []
            )
            if isinstance(recipe, dict)
        }
        can_axe = bool(
            available_tools
            & {"axe", "goldenaxe", "multitool", "multitool_axe"}
        ) or "axe" in craftable
        can_mine = bool(
            available_tools
            & {
                "pickaxe",
                "goldenpickaxe",
                "multitool",
                "multitool_pickaxe",
            }
        ) or "pickaxe" in craftable
        can_dig = bool(
            available_tools
            & {"shovel", "goldenshovel", "multitool", "multitool_shovel"}
        ) or "shovel" in craftable
        phase = str(world.get("phase") or "").lower()
        raining = world.get("raining") is True or world.get(
            "israining"
        ) is True
        threats = [
            entity
            for entity in nearby
            if entity.get("hostile") is True
        ]
        seed_total = seeds["pinecone"] + seeds["acorn"]
        chores = []
        chore_plan: list[dict[str, Any]] = []

        def add_chore(
            chore_id: str,
            label: str,
            priority: int,
            reason: str,
            *,
            prerequisites: list[str] | None = None,
        ) -> None:
            chores.append(label)
            chore_plan.append(
                {
                    "id": chore_id,
                    "label": label,
                    "priority": priority,
                    "reason": reason,
                    "prerequisites": prerequisites or [],
                }
            )

        if chests and ground_items:
            add_chore(
                "collect_ground_items",
                "将家附近散落物资收进箱子",
                20,
                "先清理地面，避免资源继续腐坏或丢失",
            )
        if ready_crops:
            add_chore(
                "harvest_renewables",
                "收下成熟作物、浆果以及长成的草、树枝和芦苇",
                24,
                "成熟可再生资源不会继续增加收益",
            )
        if drying_ready:
            add_chore(
                "collect_drying",
                "先收晾肉架上的成品",
                28,
                "收取前成品仍会继续腐坏",
            )
        elif empty_drying_racks and not raining:
            add_chore(
                "load_drying",
                "用快坏且未被任务预留的食材逐份晾晒",
                72,
                "雨天会阻止晾干，只在不淋雨时处理",
            )
        if stumps and seed_total:
            add_chore(
                "clear_stumps",
                (
                    "优先挖掉附近树桩并补种"
                    if can_dig
                    else "在附近树桩旁补种，暂不强求挖桩"
                ),
                34,
                "树桩不会自行恢复成树，铲桩还能额外得到原木",
                prerequisites=["shovel"] if can_dig else [],
            )
        if trees and seed_total:
            seed_pressure = (
                len(trees) if seed_total >= len(trees) else seed_total
            )
            add_chore(
                "chop_replant",
                "只砍成熟树，并按砍伐数量补种对应树苗",
                46 if seed_pressure else 90,
                "没有足够对应种子的树不继续砍，避免基地树林变空",
                prerequisites=["axe", "tree_seed"],
            )
            if seed_pressure < len(trees):
                add_chore(
                    "gather_tree_seeds",
                    "先补足对应松果或桦栗果，再继续扩大砍伐",
                    58,
                    "当前种子不足以覆盖所有成熟树",
                )
        if marble:
            add_chore(
                "mine_marble",
                (
                    "基地附近有大理石树时用镐开采，稀疏目标不召唤工人"
                    if can_mine
                    else "先取得镐子，再开采基地附近的大理石树"
                ),
                62,
                "大理石稳定且可长期保存，但不能空手开采",
                prerequisites=["pickaxe"],
            )
        if phase in {"dusk", "night"}:
            for chore in chore_plan:
                if chore["id"] in {
                    "chop_replant",
                    "mine_marble",
                    "gather_tree_seeds",
                }:
                    chore["priority"] += 35
        if threats:
            for chore in chore_plan:
                chore["priority"] = 100
        chore_plan.sort(
            key=lambda chore: (
                int(chore["priority"]),
                str(chore["id"]),
            )
        )
        return {
            "at_home": bool(snapshot.get("home")),
            "storage_chests": len(chests),
            "ground_items": len(ground_items),
            "mature_trees": len(trees),
            "stumps": len(stumps),
            "marble_trees": len(marble),
            "ready_crops": len(ready_crops),
            "drying_racks": len(drying_racks),
            "drying_ready": len(drying_ready),
            "empty_drying_racks": len(empty_drying_racks),
            "saplings": seeds,
            "available_tools": sorted(available_tools),
            "tool_readiness": {
                "axe": can_axe,
                "pickaxe": can_mine,
                "shovel": can_dig,
            },
            "safe_for_outdoor_chores": not threats
            and phase not in {"dusk", "night"},
            "hostile_nearby": len(threats),
            "suggested_chores": chores,
            "chore_plan": chore_plan[:8],
            "routine": {
                "mode": (
                    "defend_or_return_home"
                    if threats
                    else "night_light_and_warmth"
                    if phase == "night"
                    else "evening_refuel_and_storage"
                    if phase == "dusk"
                    else "daytime_base_upkeep"
                ),
                "abort_outdoor_work_on": ["敌人接近", "玩家命令", "灾害或体温危险"],
                "rain_policy": (
                    "不新上晾肉架，优先收成品和归仓"
                    if raining
                    else "可以处理晾肉架"
                ),
            },
            "rules": [
                "危险、体温、玩家求救和当前明确任务永远先于家务",
                "只处理基地附近成片、行列对齐的自家林区成熟树，不砍幼苗或零散野树",
                "没有箱子时不把玩家物资随手丢到另一个地面位置",
                "树木任务默认补种；没有对应树苗时暂缓继续砍树",
                "只收最终成长阶段的作物、草、树枝和芦苇，不能为了任务收走玩家明确保留的物资",
                "晾肉架先收成品；新食材逐份晾晒，任务物品和最后一份应急食物不动",
                "归仓时按工具能力保留至少一件斧头、镐子、铲子等当前可用工具",
                "黄昏先补燃料和光源，夜间不主动离开基地砍树或采矿",
            ],
        }

    def _calendar(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        world = snapshot.get("world") or {}
        moon_phase = str(world.get("moon_phase") or "").lower()
        phase = str(world.get("phase") or "").lower()
        position = (
            MOON_CYCLE.index(moon_phase)
            if moon_phase in MOON_CYCLE
            else None
        )
        days_until_full = None
        if position is not None:
            full_positions = [
                index
                for index, value in enumerate(MOON_CYCLE)
                if value == "full"
            ]
            if full_positions:
                full_position = full_positions[0]
                days_until_full = (
                    full_position - position
                    if position <= full_position
                    else len(MOON_CYCLE) - position + full_position
                )
        nearby_prefabs = {
            str(entity.get("prefab") or "")
            for entity in snapshot.get("nearby") or []
            if isinstance(entity, dict)
        }
        known_glommer_points = [
            note
            for note in snapshot.get("world_points") or []
            if isinstance(note, dict)
            and str(note.get("prefab") or "")
            in {"statueglommer", "glommerflower"}
        ]
        if "glommerflower" in nearby_prefabs:
            glommer_state = "flower_present"
        elif "statueglommer" in nearby_prefabs:
            glommer_state = "statue_visible"
        elif "glommer" in nearby_prefabs:
            glommer_state = "glommer_visible"
        else:
            glommer_state = "not_observed"
        return {
            "moon_phase": moon_phase or None,
            "is_waxing_moon": world.get("is_waxing_moon"),
            "is_full_moon": world.get("is_full_moon"),
            "cycle_position": position,
            "cycle_length": 20,
            "days_until_full_moon": days_until_full,
            "full_moon_active_now": bool(
                world.get("is_full_moon") is True
                or (moon_phase == "full" and phase == "night")
            ),
            "full_moon_later_today": bool(
                moon_phase == "full" and phase in {"day", "dusk"}
            ),
            "glommer": {
                "state": glommer_state,
                "statue_known": bool(known_glommer_points)
                or "statueglommer" in nearby_prefabs,
                "known_points": known_glommer_points[:5],
                "rule": "格罗姆花在满月时出现在格罗姆雕像；玩家要求接回时，先记坐标并排到下一个满月",
            },
        }

    def _maxwell(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        companion = snapshot.get("companion") or {}
        puppet_counts = companion.get("shadow_puppet_counts") or {}
        if not isinstance(puppet_counts, dict):
            puppet_counts = {}
        puppet_counts = {
            str(prefab): int(count)
            for prefab, count in puppet_counts.items()
            if str(prefab) in PUPPET_PREFABS and int(count) > 0
        }
        total_puppets = sum(puppet_counts.values())
        codex = companion.get("codex_umbra") or {}
        warnings: list[str] = []
        if total_puppets >= 6:
            warnings.append("暗影傀儡达到 6 个，继续增加会容易触发影怪")
        elif total_puppets >= 5:
            warnings.append("已有 5 个暗影傀儡，通常应停止继续召唤")
        if companion.get("prefab") != "waxwell":
            return {
                "applicable": False,
                "puppet_counts": puppet_counts,
                "total_puppets": total_puppets,
                "warnings": warnings,
            }
        return {
            "applicable": True,
            "puppet_counts": puppet_counts,
            "total_puppets": total_puppets,
            "recommended_max_puppets": 5,
            "codex_umbra": codex,
            "warnings": warnings,
            "summon_policy": [
                "暗影仆从只用于召唤点附近、资源密集且预计持续数分钟的采矿、伐木或挖掘",
                "不要提前召唤决斗者；它们闲置 10 秒就会消失",
                "普通战斗优先使用武器和双件护甲；只有压力超出装备承受范围才使用法术",
                "暗影牢笼不造成伤害并会吸引仇恨，对 Boss 的控制时间约为普通生物的一半",
                "暗影蝶陷阱对 Boss 无效，适合限制会恐慌的普通敌群",
            ],
        }

    def _consumption(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        perishable_food = [
            item
            for item in snapshot.get("inventory") or []
            if isinstance(item, dict)
            and str(item.get("prefab") or "") in FOOD_ITEMS
            and item.get("perish_percent") is not None
        ]
        perishable_food.sort(
            key=lambda item: (
                float(item.get("perish_percent") or 1),
                str(item.get("prefab") or ""),
            )
        )
        nearby_prefabs = {
            str(entity.get("prefab") or "")
            for entity in snapshot.get("nearby") or []
            if isinstance(entity, dict)
        }
        return {
            "eat_first": [
                {
                    "prefab": str(item.get("prefab") or ""),
                    "perish_percent": item.get("perish_percent"),
                }
                for item in perishable_food[:5]
            ],
            "reserve_task_items": True,
            "prefer_ordinary_tools_before_gold_or_multitool": True,
            "prefer_cheap_fuel_before_boards_or_charcoal": True,
            "keep_last_emergency_portions": {
                "food": 1,
                "fuel": 1,
                "healing": 1,
            },
            "preserve_tool_capabilities": (
                "归仓时至少保留一件能执行每种现有工具动作的工具；"
                "唯一斧头、镐子或铲子不能全被存走"
            ),
            "cook_or_dry_before_spoiling_when_facilities_exist": bool(
                nearby_prefabs
                & {
                    "cookpot",
                    "portablecookpot",
                    "meatrack",
                    "dryingrack",
                }
            ),
        }

    def _farming(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        nearby = [
            entity
            for entity in snapshot.get("nearby") or []
            if isinstance(entity, dict)
        ]
        farm_plants = [
            entity
            for entity in nearby
            if str(entity.get("prefab") or "").startswith("farm_plant")
        ]
        ready = [
            entity
            for entity in farm_plants
            if entity.get("harvestable") is True
        ]
        inventory = snapshot.get("inventory_counts") or {}
        seed_count = sum(
            int(count or 0)
            for prefab, count in inventory.items()
            if "seeds" in str(prefab)
        )
        return {
            "visible_plants": len(farm_plants),
            "mature_plants": len(ready),
            "seed_count": seed_count,
            "giant_crop_requires_zero_or_one_stress_total": True,
            "check_every_growth_stage": True,
            "rules": [
                "只收获已经达到最终成长阶段的作物",
                "巨型作物需要从种子到成熟的每个阶段都控制压力，不能成熟时补救",
                "相近作物成族种植可降低压力；缺少种子、耕地或适宜季节时不要空耗材料",
            ],
            "uncertainties": [
                "当前观察只包含附近实体，看不到远处农场的完整压力历史",
            ],
        }

    def _life_knowledge(
        self,
        snapshot: dict[str, Any],
    ) -> list[dict[str, str]]:
        nearby_prefabs = {
            str(entity.get("prefab") or "")
            for entity in snapshot.get("nearby") or []
            if isinstance(entity, dict)
        }
        world = snapshot.get("world") or {}
        companion = snapshot.get("companion") or {}
        include = {
            "glommer_full_moon",
            "food_spoilage",
            "meatballs_baseline",
            "supply_priority",
        }
        if snapshot.get("home") or nearby_prefabs & {
            "evergreen",
            "evergreen_sparse",
            "deciduoustree",
            "stump",
        }:
            include.add("tree_renewal")
        if companion.get("prefab") == "waxwell" and nearby_prefabs & {
            "rock1",
            "rock2",
            "marbletree",
            "evergreen",
            "evergreen_sparse",
        }:
            include.add("shadow_worker_density")
        if nearby_prefabs & {"icebox", "berries", "carrot", "meat"}:
            include.add("icebox_preservation")
        if nearby_prefabs & {"meatrack", "dryingrack"}:
            include.add("drying_rack_preservation")
        if world.get("is_raining") or nearby_prefabs & {
            "firepit",
            "campfire",
        }:
            include.add("rain_fire_consumption")
        if world.get("is_winter") or nearby_prefabs & {
            "berrybush",
            "berrybush2",
            "berrybush_juicy",
        }:
            include.add("berry_bush_winter")
        if nearby_prefabs & {
            "hound",
            "firehound",
            "icehound",
            "moonhound",
        }:
            include.add("hound_wave_escalation")
        return [
            dict(item)
            for item in LIFE_KNOWLEDGE
            if item["id"] in include
        ]
