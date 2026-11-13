from __future__ import annotations

import re
import uuid
from dataclasses import dataclass
from typing import Any

from .decision_branches import BranchMatch
from .playbooks import PlaybookMatch
from .strategy_advisor import ARMOR_PROFILE


FORCE_COMBAT = re.compile(r"死战|别逃|不要逃|不用管危险|务必打|一定打")
RETREAT_COMMAND = re.compile(
    r"撤退|快跑|别追|不要追|回来|停止战斗|停手|别打了|不要打了"
)

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

TARGET_ALIASES = {
    "青蛙": ("frog", "frog_red", "frog_brightmare"),
    "蜘蛛": ("spider", "spider_warrior", "spider_hider", "spider_spitter"),
    "猎犬": ("hound", "firehound", "icehound"),
    "兔人": ("bunnyman",),
    "发条": ("clockwork_knight", "clockwork_rook", "clockwork_bishop"),
    "触手": ("tentacle",),
    "鱼人": ("merm",),
    "猪人": ("pigman", "pigguard"),
}

TARGET_LABELS = {
    "frog": "青蛙",
    "frog_red": "红青蛙",
    "frog_brightmare": "亮眼青蛙",
    "spider": "蜘蛛",
    "spider_warrior": "蜘蛛战士",
    "spider_hider": "洞穴蜘蛛",
    "spider_spitter": "喷射蜘蛛",
    "hound": "猎犬",
    "firehound": "红猎犬",
    "icehound": "蓝猎犬",
    "bunnyman": "兔人",
    "clockwork_knight": "发条骑士",
    "clockwork_rook": "发条战车",
    "clockwork_bishop": "发条主教",
    "tentacle": "触手",
    "merm": "鱼人",
    "pigman": "猪人",
    "pigguard": "猪人守卫",
}

TARGET_GROUP_NOTES = {
    "frog": "青蛙会互相支援，攻击一只会把周围整群引过来",
    "frog_red": "青蛙会互相支援，攻击一只会把周围整群引过来",
    "frog_brightmare": "亮眼青蛙也会互相支援，攻击一只会把周围整群引过来",
    "spider": "蜘蛛会从附近的巢继续增援",
    "spider_warrior": "蜘蛛战士会带着附近蜘蛛一起进攻",
    "hound": "猎犬会成群追击",
    "firehound": "猎犬会成群追击",
    "icehound": "猎犬会成群追击",
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

RESOURCE_ALIASES = {
    "草": ("grass", "grass_tall", "grass_moon"),
    "树枝": ("sapling", "sapling_moon"),
    "浆果": ("berrybush", "berrybush2", "berrybush_juicy", "berrybush_moon"),
    "胡萝卜": ("carrot", "carrot_planted"),
    "花": ("flower", "flower_evil", "flower_rose"),
    "芦苇": ("reeds", "reeds_water"),
    "木头": ("evergreen", "deciduoustree", "twiggytree"),
    "石头": ("rock1", "rock2", "rock_flintless"),
}

RECIPE_ALIASES = {
    "斧头": "axe",
    "锤子": "hammer",
    "镐子": "pickaxe",
    "铲子": "shovel",
    "火把": "torch",
    "营火": "campfire",
    "箱子": "treasurechest",
    "背包": "backpack",
    "长矛": "spear",
    "木甲": "armorwood",
    "足球头盔": "armorfootball",
    "科学机器": "sciencemachine",
    "炼金引擎": "alchemyengine",
}

ITEM_ALIASES = {
    "金块": "goldnugget",
    "木头": "log",
    "原木": "log",
    "草": "cutgrass",
    "青草": "cutgrass",
    "树枝": "twigs",
    "小树枝": "twigs",
    "蜘蛛丝": "silk",
    "噩梦燃料": "nightmarefuel",
    "怪物肉": "monstermeat",
    "种子": "seeds",
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

HOME_ESTABLISH = re.compile(
    r"(?:这里|这儿).{0,8}(?:是|当作|作为|算).{0,4}(?:我的|你的|咱们的)?"
    r"(?:家|基地|营地|据点)"
    r"|把(?:这里|这儿).{0,10}(?:记|当|设).{0,6}(?:家|基地|营地|据点)"
)
HOME_RETURN = re.compile(r"回家|回基地|回营地|回据点|回仓库")
HOME_NAMES = ("家", "基地", "营地", "据点", "仓库")
HOME_CHORE_REQUEST = re.compile(
    r"(?:家里|基地|营地|据点).{0,12}(?:收拾|整理|打扫|清点|维护|干活)"
    r"|(?:收拾|整理|打扫|清点|维护).{0,10}(?:家|基地|营地|据点)"
    r"|自己看着办|随便找点活干|找点家务做"
)
GLOM_MER_REQUEST = re.compile(
    r"(?:接|带|领|找|抓|收).{0,8}格罗姆"
    r"|格罗姆.{0,8}(?:接|带|领|找|抓|收)"
)


@dataclass(frozen=True)
class PolicyDecision:
    branch_id: str
    rule_id: str
    confidence: float
    reply: str
    intent: dict[str, Any]
    reason: str
    schedule: dict[str, Any] | list[dict[str, Any]] | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "kind": "local_policy",
            "branch_id": self.branch_id,
            "rule_id": self.rule_id,
            "confidence": self.confidence,
            "reply": self.reply,
            "intent": self.intent,
            "reason": self.reason,
            "schedule": self.schedule,
        }


class BranchPolicyEngine:
    """Deterministic preflight policies for common, state-dependent decisions."""

    def decide(
        self,
        message: str,
        snapshot: dict[str, Any],
        branch: BranchMatch,
    ) -> PolicyDecision | None:
        home = self._homestead(message, snapshot)
        if home is not None:
            return home
        glommer = self._glommer(message, snapshot)
        if glommer is not None:
            return glommer
        handlers = {
            "combat": self._combat,
            "collection": self._collection,
            "crafting": self._crafting,
            "construction": self._construction,
            "transport": self._transport,
            "farming": self._farming,
            "survival": self._survival,
            "exploration": self._exploration,
            "movement": self._movement,
        }
        handler = handlers.get(branch.branch_id)
        return handler(message, snapshot) if handler is not None else None

    def _homestead(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PolicyDecision | None:
        if HOME_ESTABLISH.search(message):
            return PolicyDecision(
                branch_id="base",
                rule_id="base.establish_home",
                confidence=0.99,
                reply="好，我记住这里。以后我回基地后会留下照料自己，不再跟着你乱跑。",
                intent=self._intent(
                    "homestead",
                    reason="establish_persistent_home",
                    lease_seconds=24 * 60 * 60,
                    params={
                        "establish_home": True,
                        "name": "家",
                        "stay_home": True,
                        "stop_distance": 4,
                    },
                ),
                reason="persistent_home_established",
            )
        if HOME_CHORE_REQUEST.search(message):
            home = snapshot.get("home")
            home = home if isinstance(home, dict) else {}
            landmarks = snapshot.get("landmarks")
            landmarks = landmarks if isinstance(landmarks, dict) else {}
            name = next(
                (
                    str(home.get(key))
                    for key in ("name", "landmark")
                    if home.get(key)
                ),
                None,
            )
            if name is None:
                name = next(
                    (
                        candidate
                        for candidate in HOME_NAMES
                        if candidate in landmarks
                    ),
                    None,
                )
            if name is not None:
                companion = snapshot.get("companion") or {}
                dx = float(companion.get("x") or 0) - float(
                    home.get("x") or 0
                )
                dz = float(companion.get("z") or 0) - float(
                    home.get("z") or 0
                )
                same_shard = (
                    home.get("shard") is None
                    or home.get("shard")
                    == (snapshot.get("world") or {}).get("shard")
                )
                at_home = bool(
                    same_shard
                    and home.get("x") is not None
                    and home.get("z") is not None
                    and dx * dx + dz * dz <= 16 * 16
                )
                return PolicyDecision(
                    branch_id="base",
                    rule_id="base.run_home_chores",
                    confidence=0.96,
                    reply=(
                        "好，我先把家里散落的物资、成熟资源和快坏食物检查一遍。"
                        if at_home
                        else f"好，我先回“{name}”，到家后从散落物资和成熟资源开始收拾。"
                    ),
                    intent=self._intent(
                        "homestead",
                        reason="run_autonomous_home_chores",
                        lease_seconds=24 * 60 * 60,
                        params={
                            "landmark": name,
                            "stay_home": True,
                            "stop_distance": 4,
                        },
                    ),
                    reason="home_chores_requested",
                )
        if not HOME_RETURN.search(message):
            return None
        landmarks = snapshot.get("landmarks")
        if not isinstance(landmarks, dict):
            return None
        name = next(
            (
                candidate
                for candidate in HOME_NAMES
                if candidate in landmarks
            ),
            None,
        )
        if name is None:
            return None
        return PolicyDecision(
            branch_id="base",
            rule_id="base.return_home_and_stay",
            confidence=0.98,
            reply=f"好，我回“{name}”待命，路上会先照顾好自己的状态。",
            intent=self._intent(
                "homestead",
                reason="persistent_return_home",
                lease_seconds=24 * 60 * 60,
                params={
                    "landmark": name,
                    "stay_home": True,
                    "stop_distance": 4,
                },
            ),
            reason="return_to_persistent_home",
        )

    def _glommer(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PolicyDecision | None:
        if GLOM_MER_REQUEST.search(message) is None:
            return None

        calendar = (snapshot.get("decision_support") or {}).get(
            "calendar"
        ) or {}
        glommer = calendar.get("glommer") or {}
        known_points = [
            point
            for point in glommer.get("known_points") or []
            if isinstance(point, dict)
            and isinstance(point.get("x"), (int, float))
            and isinstance(point.get("z"), (int, float))
        ]
        statue = next(
            (
                entity
                for entity in snapshot.get("nearby") or []
                if isinstance(entity, dict)
                and str(entity.get("prefab") or "")
                == "statueglommer"
                and isinstance(entity.get("x"), (int, float))
                and isinstance(entity.get("z"), (int, float))
            ),
            None,
        )
        point = statue or (known_points[0] if known_points else None)
        world = snapshot.get("world") or {}
        home = snapshot.get("home")
        home = home if isinstance(home, dict) else {}
        return_landmark = next(
            (
                str(home.get(key))
                for key in ("name", "landmark")
                if home.get(key)
            ),
            "家",
        )
        schedule = {
            "kind": "glommer_pickup",
            "goal": "满月时在格罗姆雕像旁接格罗姆并带回基地",
            "due_phase": "night",
            "due_moon_phase": "full",
            "shard": world.get("shard") or home.get("shard"),
            "x": point.get("x") if point is not None else None,
            "z": point.get("z") if point is not None else None,
            "details": {
                "location": "格罗姆雕像",
                "statue_known": point is not None,
                "requires_flower": True,
                "return_landmark": return_landmark,
                "avoid_early_arrival": True,
            },
        }

        if point is not None:
            reply = (
                "我记住了，到下一个满月的夜里会先去雕像旁，"
                "把格罗姆接回基地。"
            )
            rule_id = "exploration.glommer_scheduled"
            confidence = 0.97
        else:
            reply = (
                "我先把接格罗姆记成满月待办；但现在还没掌握雕像坐标，"
                "我会在出发前先找到它，不会假装知道位置。"
            )
            rule_id = "exploration.glommer_schedule_needs_location"
            confidence = 0.93

        mode = "follow"
        params: dict[str, Any] = {}
        home_name = next(
            (
                str(home.get(key))
                for key in ("name", "landmark")
                if home.get(key)
            ),
            None,
        )
        if home_name is not None:
            mode = "homestead"
            params = {
                "landmark": home_name,
                "stay_home": True,
                "stop_distance": 4,
            }
        return PolicyDecision(
            branch_id="exploration",
            rule_id=rule_id,
            confidence=confidence,
            reply=reply,
            intent=self._intent(
                mode,
                reason="glommer_pickup_scheduled",
                lease_seconds=24 * 60 * 60,
                params=params,
            ),
            reason=(
                "glommer_scheduled_with_known_statue"
                if point is not None
                else "glommer_scheduled_pending_location"
            ),
            schedule=schedule,
        )

    def preflight_playbook(
        self,
        message: str,
        snapshot: dict[str, Any],
        branch: BranchMatch,
        playbook: PlaybookMatch,
    ) -> PolicyDecision | None:
        if branch.branch_id != "combat" and playbook.task_type not in {
            "combat",
            "boss",
            "combat_loot",
        }:
            return None
        decision = self._combat(message, snapshot)
        if (
            decision is not None
            and decision.rule_id == "combat.avoid_unfavorable_group"
        ):
            return decision
        return None
    @staticmethod
    def _ratio(section: dict[str, Any], current: str, maximum: str) -> float:
        value = section.get(current)
        cap = section.get(maximum)
        if not isinstance(value, (int, float)) or not isinstance(
            cap, (int, float)
        ):
            return 1.0
        if cap <= 0:
            return 1.0
        return max(0.0, min(1.0, float(value) / float(cap)))

    @staticmethod
    def _position(section: dict[str, Any]) -> list[float] | None:
        x = section.get("x")
        z = section.get("z")
        if isinstance(x, (int, float)) and isinstance(z, (int, float)):
            return [x, z]
        return None

    @staticmethod
    def _inventory_counts(snapshot: dict[str, Any]) -> dict[str, int]:
        counts = {
            str(key): int(value)
            for key, value in (snapshot.get("inventory_counts") or {}).items()
            if isinstance(value, int)
        }
        if counts:
            return counts
        for item in snapshot.get("inventory") or []:
            if not isinstance(item, dict) or not item.get("prefab"):
                continue
            prefab = str(item["prefab"])
            counts[prefab] = counts.get(prefab, 0) + int(
                item.get("stacksize") or 1
            )
        for item in snapshot.get("equipped") or []:
            if not isinstance(item, dict) or not item.get("prefab"):
                continue
            prefab = str(item["prefab"])
            counts[prefab] = counts.get(prefab, 0) + int(
                item.get("stacksize") or 1
            )
        return counts

    @staticmethod
    def _equipped_prefabs(snapshot: dict[str, Any]) -> set[str]:
        return {
            str(item.get("prefab"))
            for item in snapshot.get("equipped") or []
            if isinstance(item, dict) and item.get("prefab")
        }

    @classmethod
    def _best_weapon_damage(
        cls,
        snapshot: dict[str, Any],
    ) -> tuple[int, str | None]:
        available = set(cls._inventory_counts(snapshot)) | cls._equipped_prefabs(
            snapshot
        )
        best_name = None
        best_damage = FIST_DAMAGE
        for prefab in available:
            damage = WEAPON_DAMAGE.get(prefab)
            if damage is not None and damage > best_damage:
                best_name = prefab
                best_damage = damage
        return best_damage, best_name

    @classmethod
    def _best_armor_absorb(cls, snapshot: dict[str, Any]) -> float:
        best_by_slot: dict[str, float] = {}
        items = [
            item
            for item in snapshot.get("inventory") or []
            if isinstance(item, dict) and item.get("prefab")
        ]
        items.extend(
            item
            for item in snapshot.get("equipped") or []
            if isinstance(item, dict) and item.get("prefab")
        )
        for item in items:
            prefab = str(item.get("prefab") or "")
            profile = ARMOR_PROFILE.get(prefab)
            if profile is None:
                continue
            default_slot, absorb = profile
            slot = str(item.get("slot") or default_slot)
            condition = item.get("condition_percent")
            if isinstance(condition, (int, float)):
                condition = float(condition)
                if condition > 1:
                    condition /= 100.0
            else:
                condition = 1.0
            score = absorb * max(0.0, min(1.0, condition))
            best_by_slot[slot] = max(best_by_slot.get(slot, 0.0), score)
        remaining = 1.0
        for absorb in best_by_slot.values():
            remaining *= 1.0 - absorb
        return 1.0 - remaining

    @staticmethod
    def _intent(
        mode: str,
        *,
        reason: str,
        lease_seconds: int,
        target_guid: str | None = None,
        target_prefab: str | None = None,
        position: list[float] | None = None,
        params: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        return {
            "intent_id": f"local-{mode}-{uuid.uuid4()}",
            "mode": mode,
            "target_guid": target_guid,
            "target_prefab": target_prefab,
            "position": position,
            "params": params or {},
            "lease_seconds": lease_seconds,
            "reason": reason,
        }

    @staticmethod
    def _matching_prefabs(
        message: str,
        aliases: dict[str, tuple[str, ...]],
    ) -> set[str]:
        result: set[str] = set()
        for word, prefabs in aliases.items():
            if word in message:
                result.update(prefabs)
        return result

    def _combat(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PolicyDecision | None:
        if RETREAT_COMMAND.search(message):
            return PolicyDecision(
                branch_id="combat",
                rule_id="combat.explicit_retreat",
                confidence=0.99,
                reply="收到，我立刻停止战斗并撤回你身边。",
                intent=self._intent(
                    "retreat",
                    reason="explicit_stop_combat",
                    lease_seconds=120,
                ),
                reason="explicit_retreat",
            )
        wanted = self._matching_prefabs(message, TARGET_ALIASES)
        if not wanted:
            return None
        hostiles = [
            entity
            for entity in snapshot.get("nearby") or []
            if isinstance(entity, dict)
            and entity.get("hostile")
            and str(entity.get("prefab") or "") in wanted
        ]
        if not hostiles:
            return None
        hostiles.sort(key=lambda item: float(item.get("distance") or 9999))
        target = hostiles[0]
        companion = snapshot.get("companion") or {}
        health_ratio = self._ratio(companion, "health", "max_health")
        current_health = float(companion.get("health") or 0)
        weapon_damage, weapon = self._best_weapon_damage(snapshot)
        armor = self._best_armor_absorb(snapshot)
        count = len(hostiles)
        forced = FORCE_COMBAT.search(message) is not None
        target_prefab = str(target.get("prefab") or "")
        target_health, target_damage = THREAT_PROFILE.get(
            target_prefab,
            (target.get("health") or 100, 20),
        )
        current_target_health = target.get("health") or target_health
        kill_rounds = max(
            1,
            int((float(current_target_health) + weapon_damage - 1) // weapon_damage),
        )
        effective_damage = float(target_damage) * max(0.05, 1 - armor)
        projected_damage = kill_rounds * effective_damage * count

        unarmed_crowd = weapon_damage <= FIST_DAMAGE and count >= 2
        exposed_crowd = armor < 0.4 and count >= 3
        critical = health_ratio < 0.35 and count >= 1
        projected_loss = current_health > 0 and (
            projected_damage >= current_health * 0.85
        )
        if not forced and (
            unarmed_crowd
            or exposed_crowd
            or critical
            or projected_loss
        ):
            missing = []
            if weapon_damage <= FIST_DAMAGE:
                missing.append("没有可用武器")
            if armor < 0.4:
                missing.append("没有有效护甲")
            if health_ratio < 0.35:
                missing.append(f"生命只剩 {round(health_ratio * 100)}%")
            detail = "、".join(missing) or "局面明显不利"
            target_label = TARGET_LABELS.get(target_prefab, target_prefab)
            group_note = TARGET_GROUP_NOTES.get(
                target_prefab,
                "这类目标会互相支援",
            )
            return PolicyDecision(
                branch_id="combat",
                rule_id="combat.avoid_unfavorable_group",
                confidence=0.98,
                reply=(
                    f"附近有 {count} 只{target_label}，{group_note}；"
                    f"而且{detail}。这样直接冲进去风险太高，我先退回你身边。"
                ),
                intent=self._intent(
                    "follow",
                    reason="local_combat_unfavorable",
                    lease_seconds=120,
                    params={
                        "avoid_target_prefab": target.get("prefab"),
                        "observed_group_size": count,
                    },
                ),
                reason="unfavorable_combat",
            )

        return PolicyDecision(
            branch_id="combat",
            rule_id="combat.engage_with_advantage",
            confidence=0.9,
            reply=(
                f"我评估过了，当前装备和生命可以处理这 {count} 只"
                f"{TARGET_LABELS.get(str(target.get('prefab') or ''), '目标')}，"
                "我会先打最近的一只。"
            ),
            intent=self._intent(
                "combat",
                reason="local_combat_advantage",
                lease_seconds=300,
                target_guid=str(target.get("guid") or "") or None,
                target_prefab=str(target.get("prefab") or "") or None,
                params={
                    "auto_dodge": True,
                    "retreat_on_lethal": True,
                    "observed_group_size": count,
                    "weapon": weapon,
                    "armor_absorb": armor,
                },
            ),
            reason="favorable_combat",
        )

    def _collection(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PolicyDecision | None:
        wanted = self._matching_prefabs(message, RESOURCE_ALIASES)
        if not wanted:
            return None
        nearby = [
            entity
            for entity in snapshot.get("nearby") or []
            if isinstance(entity, dict)
            and str(entity.get("prefab") or "") in wanted
            and (entity.get("pickable") or entity.get("workable"))
        ]
        if not nearby:
            return PolicyDecision(
                branch_id="collection",
                rule_id="collection.no_local_target",
                confidence=0.82,
                reply="这附近没有发现对应的可采集目标，我没有乱跑。",
                intent=self._intent(
                    "follow",
                    reason="local_collect_target_missing",
                    lease_seconds=90,
                ),
                reason="no_local_target",
            )
        player = snapshot.get("player") or {}
        return PolicyDecision(
            branch_id="collection",
            rule_id="collection.nearby_resources",
            confidence=0.92,
            reply="附近有可采集目标，我先处理这一片。",
            intent=self._intent(
                "harvest_area",
                reason="local_collection_nearby",
                lease_seconds=600,
                position=self._position(player),
                params={
                    "radius": 24,
                    "arrive_distance": 4,
                    "target_prefabs": sorted(wanted),
                },
            ),
            reason="nearby_resources",
        )

    @staticmethod
    def _recipe_entry(
        snapshot: dict[str, Any],
        recipe_name: str,
    ) -> tuple[bool, bool]:
        known = False
        available = False
        for recipe in (snapshot.get("capabilities") or {}).get(
            "known_recipes"
        ) or []:
            if not isinstance(recipe, dict):
                continue
            if recipe_name not in {
                str(recipe.get("name") or ""),
                str(recipe.get("product") or ""),
            }:
                continue
            if recipe.get("known") is False:
                continue
            known = True
            available = available or bool(recipe.get("available"))
        return known, available

    def _crafting(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PolicyDecision | None:
        recipe_name = next(
            (prefab for word, prefab in RECIPE_ALIASES.items() if word in message),
            None,
        )
        if recipe_name is None:
            return None
        known, available = self._recipe_entry(snapshot, recipe_name)
        if available:
            return PolicyDecision(
                branch_id="crafting",
                rule_id="crafting.available",
                confidence=0.94,
                reply="材料和配方都齐了，我现在制作。",
                intent=self._intent(
                    "craft",
                    reason="local_craft_available",
                    lease_seconds=180,
                    params={"recipe": recipe_name},
                ),
                reason="recipe_available",
            )
        return PolicyDecision(
            branch_id="crafting",
            rule_id="crafting.blocked",
            confidence=0.9,
            reply=(
                f"我现在{'没学会' if not known else '材料不足'}，"
                f"不能直接制作 {recipe_name}。"
            ),
            intent=self._intent(
                "hold",
                reason="local_craft_unavailable",
                lease_seconds=120,
            ),
            reason="recipe_unavailable",
        )

    def _construction(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PolicyDecision | None:
        recipe_name = next(
            (prefab for word, prefab in RECIPE_ALIASES.items() if word in message),
            None,
        )
        if recipe_name is None:
            return None
        known, available = self._recipe_entry(snapshot, recipe_name)
        if not available:
            return PolicyDecision(
                branch_id="construction",
                rule_id="construction.blocked",
                confidence=0.9,
                reply=(
                    f"我现在{'没学会' if not known else '材料不足'}，"
                    f"不能直接建造 {recipe_name}。"
                ),
                intent=self._intent(
                    "hold",
                    reason="local_build_unavailable",
                    lease_seconds=120,
                ),
                reason="recipe_unavailable",
            )
        player_position = self._position(snapshot.get("player") or {})
        return PolicyDecision(
            branch_id="construction",
            rule_id="construction.available",
            confidence=0.9,
            reply="材料齐了，我会先在附近检查落点再建。",
            intent=self._intent(
                "build",
                reason="local_build_available",
                lease_seconds=300,
                position=player_position,
                params={"recipe": recipe_name},
            ),
            reason="recipe_available",
        )

    def _transport(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PolicyDecision | None:
        prefabs = set(self._inventory_counts(snapshot))
        for entity in snapshot.get("nearby") or []:
            if not isinstance(entity, dict):
                continue
            for item in entity.get("container_items") or []:
                if isinstance(item, dict) and item.get("prefab"):
                    prefabs.add(str(item["prefab"]))
        wanted = next(
            (prefab for word, prefab in ITEM_ALIASES.items() if word in message),
            None,
        )
        if wanted is None:
            wanted = next(
                (prefab for prefab in prefabs if prefab in message),
                None,
            )
        if wanted is None:
            return None
        owned = self._inventory_counts(snapshot).get(wanted, 0)
        if owned > 0:
            return PolicyDecision(
                branch_id="transport",
                rule_id="transport.already_owned",
                confidence=0.9,
                reply=f"我身上已经有 {owned} 个 {wanted}，不用再跑一趟。",
                intent=self._intent(
                    "follow",
                    reason="local_transport_already_owned",
                    lease_seconds=120,
                ),
                reason="item_already_owned",
            )
        for entity in snapshot.get("nearby") or []:
            if not isinstance(entity, dict) or not entity.get("container"):
                continue
            if any(
                isinstance(item, dict) and item.get("prefab") == wanted
                for item in entity.get("container_items") or []
            ):
                return PolicyDecision(
                    branch_id="transport",
                    rule_id="transport.nearby_container",
                    confidence=0.92,
                    reply=f"附近容器里找到了 {wanted}，我去取给你。",
                    intent=self._intent(
                        "fetch_item",
                        reason="local_transport_nearby_container",
                        lease_seconds=300,
                        target_prefab=wanted,
                        position=self._position(entity),
                        params={
                            "search_radius": 8,
                            "give_to_player": True,
                        },
                    ),
                    reason="known_local_container",
                )
        return None

    def _farming(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PolicyDecision | None:
        if not re.search(r"收|采|摘|成熟|作物", message):
            return None
        mature = [
            entity
            for entity in snapshot.get("nearby") or []
            if isinstance(entity, dict) and entity.get("harvestable")
        ]
        if not mature:
            return PolicyDecision(
                branch_id="farming",
                rule_id="farming.not_mature",
                confidence=0.88,
                reply="附近的作物还没有成熟，我先不浪费体力。",
                intent=self._intent(
                    "follow",
                    reason="local_farm_not_mature",
                    lease_seconds=120,
                ),
                reason="no_mature_crops",
            )
        prefabs = sorted(
            {
                str(entity.get("prefab"))
                for entity in mature
                if entity.get("prefab")
            }
        )
        return PolicyDecision(
            branch_id="farming",
            rule_id="farming.harvest_mature",
            confidence=0.93,
            reply=f"附近有 {len(mature)} 个成熟作物，我先收这些。",
            intent=self._intent(
                "harvest_area",
                reason="local_farm_harvest_mature",
                lease_seconds=600,
                position=self._position(snapshot.get("player") or {}),
                params={
                    "radius": 16,
                    "arrive_distance": 2,
                    "target_prefabs": prefabs,
                },
            ),
            reason="mature_crops",
        )

    def _survival(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PolicyDecision | None:
        inventory = self._inventory_counts(snapshot)
        wants_health = re.search(r"回血|治疗|受伤|生命", message) is not None
        wants_food = re.search(r"吃|饿|饱食|食物", message) is not None
        if wants_health or wants_food:
            healing = next(
                (item for item in HEALING_ITEMS if inventory.get(item, 0) > 0),
                None,
            )
            food = next(
                (item for item in FOOD_ITEMS if inventory.get(item, 0) > 0),
                None,
            )
            if wants_health and healing is not None:
                return PolicyDecision(
                    branch_id="survival",
                    rule_id="survival.healing_item",
                    confidence=0.9,
                    reply="我背包里有治疗物品，先处理伤势。",
                    intent=self._intent(
                        "use_skill",
                        reason="local_survival_healing",
                        lease_seconds=60,
                        target_guid=str(
                            (snapshot.get("companion") or {}).get("guid") or ""
                        ),
                        params={
                            "action": "USEITEM",
                            "item_prefab": healing,
                            "on_self": True,
                        },
                    ),
                    reason="healing_item_available",
                )
            if wants_food and food is not None:
                return PolicyDecision(
                    branch_id="survival",
                    rule_id="survival.eat_food",
                    confidence=0.9,
                    reply=f"背包里有 {food}，我先吃点东西。",
                    intent=self._intent(
                        "eat",
                        reason="local_survival_eat",
                        lease_seconds=60,
                        params={"item_prefab": food},
                    ),
                    reason="food_available",
                )
            return PolicyDecision(
                branch_id="survival",
                rule_id="survival.no_supplies",
                confidence=0.9,
                reply="背包里没有合适的食物或治疗物品，我需要先回到安全位置。",
                intent=self._intent(
                    "follow",
                    reason="local_survival_no_supplies",
                    lease_seconds=120,
                ),
                reason="no_survival_supplies",
            )
        return None

    def _exploration(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PolicyDecision | None:
        landmarks = snapshot.get("landmarks")
        if not isinstance(landmarks, dict):
            return None
        for name in landmarks:
            if name and name in message:
                return PolicyDecision(
                    branch_id="exploration",
                    rule_id="exploration.known_landmark",
                    confidence=0.95,
                    reply=f"我记得“{name}”的位置，现在就过去。",
                    intent=self._intent(
                        "move_to_landmark",
                        reason="local_known_landmark",
                        lease_seconds=1800,
                        params={"landmark": name},
                    ),
                    reason="known_landmark",
                )
        return None

    def _movement(
        self,
        message: str,
        snapshot: dict[str, Any],
    ) -> PolicyDecision | None:
        if RETREAT_COMMAND.search(message):
            return PolicyDecision(
                branch_id="movement",
                rule_id="movement.retreat",
                confidence=0.95,
                reply="收到，我马上回来。",
                intent=self._intent(
                    "retreat",
                    reason="local_retreat",
                    lease_seconds=120,
                ),
                reason="explicit_retreat",
            )
        if re.search(r"等我|原地等|别动|停在这里", message):
            return PolicyDecision(
                branch_id="movement",
                rule_id="movement.hold",
                confidence=0.95,
                reply="好，我就在这里等你。",
                intent=self._intent(
                    "hold",
                    reason="local_hold",
                    lease_seconds=86400,
                ),
                reason="explicit_hold",
            )
        if HOME_RETURN.search(message):
            landmarks = snapshot.get("landmarks")
            if isinstance(landmarks, dict):
                name = next(
                    (
                        candidate
                        for candidate in HOME_NAMES
                        if candidate in landmarks
                    ),
                    None,
                )
                if name is not None:
                    return PolicyDecision(
                        branch_id="movement",
                        rule_id="movement.known_home",
                        confidence=0.94,
                        reply=f"好，我回“{name}”待命。",
                        intent=self._intent(
                            "homestead",
                            reason="persistent_return_home",
                            lease_seconds=24 * 60 * 60,
                            params={
                                "landmark": name,
                                "stay_home": True,
                                "stop_distance": 4,
                            },
                        ),
                        reason="return_to_persistent_home",
                    )
        return None
