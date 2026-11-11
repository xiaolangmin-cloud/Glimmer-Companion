from __future__ import annotations

import copy
import json
import random
import threading
import time
import uuid
from collections import deque
from pathlib import Path
from typing import Any

from .agent_memory import AgentMemoryStore
from .arbiter import IntentArbiter
from .characters import CharacterPreferenceStore
from .config import Settings
from .deepseek import DeepSeekError, DeepSeekPlanner
from .journal import CompanionJournal
from .memory import MemoryStore
from .mod_knowledge import IMPLEMENTATION_NOTES
from .playbooks import PlaybookMatch, PlaybookMatcher
from .research import CodexResearchService, ResearchError


IMPORTANT_EVENTS = {
    "task_complete",
    "task_failed",
    "task_blocked",
    "combat_target_lost",
    "combat_target_defeated",
    "inventory_full",
    "companion_dead",
    "critical_hunger",
    "critical_health",
}

CROSS_WORLD_MODES = {
    "change_shard",
    "enter_shard",
    "go_to_shard",
    "migrate",
    "travel_shard",
}

CROSS_WORLD_REPLY = (
    "不能进入另一个世界。控制器已阻止这条指令：伴侣只能在当前世界行动，"
    "过世界必须由你本人通过传送门或洞口带着它切换。"
)

RECOVERY_REASON_TEXT = {
    "recovery_food_missing": "饥饿偏低，但没有能吃的食物",
    "recovery_tent_missing": "状态偏低，但附近没有可用帐篷",
    "not_enough_hunger_for_sleep": "剩余饥饿不够支付整晚睡眠",
    "not_enough_sleep_time": "距离唤醒时间太近，睡觉收益不足",
    "not_enough_recovery_benefit": "睡眠预计恢复的生命和精神太少",
    "wrong_time_of_day": "当前时间不适合使用附近帐篷",
    "danger_nearby": "附近有危险，暂时不能睡",
    "danger_during_sleep": "睡觉时出现危险，已经醒来",
    "sleepingbag_missing": "附近的睡具已经不可用了",
    "sleepingbag_in_use": "附近的帐篷正在被使用",
    "sleepingbaguser_missing": "微光当前不能使用睡具",
    "cannot_sleep": "当前状态不满足睡觉条件",
    "tent_empty": "附近帐篷已经没有剩余使用次数",
    "tent_burning": "附近帐篷正在燃烧",
    "clock_missing": "无法读取当前昼夜时间",
    "recovery_tent_unreachable": "无法走到附近帐篷",
    "tent_enter_failed": "到达帐篷后仍无法进入睡眠",
}

EMERGENCY_CATEGORY_TEXT = {
    "lethal_threat": "下一次受击可能致命",
    "earthquake": "地震",
    "hound_wave": "猎犬或洞穴蠕虫来袭",
    "frog_rain": "青蛙雨",
    "nightmare_riot": "梦魇暴乱",
    "attacked": "我们遭到攻击",
    "hostile_group": "附近出现敌对群体",
    "quake_warning": "地震预警",
    "hound_warning": "猎犬或洞穴蠕虫预警",
    "acid_rain": "酸雨",
    "darkness": "周围突然变黑",
    "freezing": "过冷",
    "overheating": "过热",
}

EMERGENCY_ACTION_TEXT = {
    "fight": "我先处理附近的威胁",
    "rally": "我先向你靠拢",
    "prepare_rally": "我先做好准备并向你靠拢",
    "brace": "我先停下、穿好护甲并向你靠拢",
    "retreat": "我先撤到安全位置",
    "equipped_torch": "我已经点亮火把",
    "moving_to_light": "我先走向附近光源",
    "following_player": "我先向你靠拢寻找光源",
    "already_lit": "附近已经有光",
    "equipped_protection": "我已经换上防护装备",
    "seek_shelter": "我先去附近避雨处",
    "no_light_available": "我没找到可用光源",
    "continue_task_override": "你要求继续任务，所以我不中断，但会保留这次高风险选择的记录",
}

EMERGENCY_DETECTED_LINES = {
    "lethal_threat": (
        "呜哇，这一下会把我拍扁！我先溜到你身边！",
        "不行不行，再挨一下就倒啦，我先撤！",
        "这次真的疼！我先回你身边缓一缓！",
        "警报拉满，我先保命，马上贴过来！",
    ),
    "earthquake": (
        "地震啦地震啦，我先穿好护甲贴过去！",
        "地在晃，石头要掉啦！快让我挨着你！",
        "轰隆隆的，我先停下躲一躲！",
        "别站在石头下面呀，微光马上过来！",
    ),
    "hound_wave": (
        "来狗啦来狗啦！我先把近处的坏家伙赶走！",
        "汪汪军团到门口啦，你先别跑太远！",
        "好多牙好多尾巴！我贴着你打，不追远！",
        "猎犬开饭时间到了……骗你的，我先上！",
    ),
    "frog_rain": (
        "天上下青蛙啦，好离谱！我先拍走近处的！",
        "呱呱军团落下来啦，你别被围住呀！",
        "青蛙雨来啦！我今天可没带伞，先打！",
        "满地都在蹦！我守着你身边这一圈！",
    ),
    "nightmare_riot": (
        "影子开始闹腾啦，我先赶走近处的！",
        "暗处有东西在盯着我们……我先挡着！",
        "梦魇暴乱啦，别离我太远呀！",
        "坏影子冒出来啦，微光先把它们戳回去！",
    ),
    "attacked": (
        "有人偷袭！我先还手，你别慌！",
        "哎哟，谁打我！我先把这家伙赶走！",
        "挨了一下！我先处理眼前这个坏家伙！",
        "偷袭警报！微光要凶一下了！",
    ),
    "hostile_group": (
        "前面聚了一群坏家伙，我先挡在你前面！",
        "好多不友善的家伙！我先处理近处的！",
        "它们凑过来了，我守着你身边这一圈！",
        "坏家伙组团啦，我可不会让它们欺负你！",
    ),
    "quake_warning": (
        "好像要地震啦，我先穿甲，马上靠过去！",
        "地下传来轰隆声……你站到空一点的地方呀！",
        "石头预警！微光先做好准备！",
        "地底在咕噜咕噜响，我有种不好的预感！",
    ),
    "hound_warning": (
        "听见狗叫啦，我先穿甲，马上贴过来！",
        "好像要来狗啦，你别走太远呀！",
        "远处有爪子挠地声……我先准备一下！",
        "狗牙警报！微光先靠到你身边！",
    ),
    "acid_rain": (
        "酸雨酸雨！我先找防护，别让衣服化掉！",
        "天上下酸水啦，快跟我找地方躲！",
        "嘶……地面都在冒烟，我先换防护装备！",
        "酸雨来啦！微光先看有没有雨具！",
    ),
    "darkness": (
        "诶？周围突然变黑啦，我先点亮火把！",
        "伸手不见五指啦，等我亮起来！",
        "查理的黑暗来啦？我先找光，别乱跑！",
        "看不见路啦，微光去把灯点上！",
    ),
    "freezing": (
        "冷得牙都在打架啦，我先换保暖装备！",
        "要冻成冰棍啦！我先找件厚衣服！",
        "呼……好冷好冷，我往你那边靠一靠！",
        "手指都不听使唤啦，我先保暖！",
    ),
    "overheating": (
        "热得快要冒烟啦，我先换降温装备！",
        "太阳好凶！再晒下去要熟啦！",
        "脑袋晕乎乎的……我先躲一躲热气！",
        "好烫好烫，微光要先降温！",
    ),
}

EMERGENCY_ACTION_LINES = {
    "fight": (
        "我先把近处的坏家伙赶走！",
        "别跑太远，我就在你旁边打！",
        "这些家伙交给我，你先留意身后！",
    ),
    "rally": (
        "等等我呀，我朝你这边来！",
        "你先别跑太远，我马上贴过来！",
        "我回来我回来，别把我落下呀！",
    ),
    "prepare_rally": (
        "我先做好准备，然后马上靠过去！",
        "给我一秒准备，我这就贴着你！",
        "先穿好甲，再跟你站一起！",
    ),
    "brace": (
        "我先站稳，石头掉下来也不乱跑！",
        "缩一下脖子，我先挨到你身边！",
        "别怕，我先穿好护甲顶一下！",
    ),
    "retreat": (
        "有点危险，我先溜到你身边！",
        "打不过就先跑，这可不丢脸！",
        "我先撤，留着力气再来帮你！",
    ),
    "equipped_torch": (
        "火把点亮啦，现在能看见一点点！",
        "有光啦！跟着我走就好！",
        "灯亮了，黑暗先退退！",
    ),
    "moving_to_light": (
        "附近有光，我先跑过去！",
        "我看到亮处啦，马上过去！",
        "朝灯那边走，黑暗追不上我！",
    ),
    "following_player": (
        "我找不到亮处，先来你身边！",
        "你有光吗？我先贴着你走！",
        "哪儿都黑漆漆的，我跟着你！",
    ),
    "already_lit": (
        "原来这里已经有光啦。",
        "还好还好，这块地方亮着。",
        "有光就行，我不用再点啦。",
    ),
    "equipped_protection": (
        "防护换好啦，这下舒服多了！",
        "装备切好，我不怕它！",
        "这样应该能顶住了。",
    ),
    "seek_shelter": (
        "那边能躲，我先进去！",
        "我看到避雨处啦，快跟上！",
        "先躲一下，别让酸雨啃衣服！",
    ),
    "no_light_available": (
        "糟糕，我包里没有能点的东西……先来找你！",
        "火把没啦！我先贴着你找亮处！",
        "一点光都没有，我先跟你走！",
    ),
    "continue_task_override": (
        "你说要继续，我就咬牙不中断；风险我会一直盯着！",
        "好，我硬着头皮接着做，不过会随时报告危险！",
        "收到，这次高风险也继续，但我会把防护做到最好！",
    ),
}

EMERGENCY_RESOLVED_LINES = {
    "lethal_threat": (
        "呼……活下来啦，我慢慢贴回来。",
        "刚才真的好险，现在能喘口气了。",
        "命保住啦！我先乖乖跟着你。",
    ),
    "earthquake": (
        "地面安静下来啦，我回来啦。",
        "地震警报解除啦，呼……尾巴都还在吧？",
        "不晃了不晃了，我去捡捡掉的东西。",
    ),
    "hound_wave": (
        "狗群散啦，呼……牙齿还真多。",
        "汪汪军团终于走啦，我回来啦。",
        "耳边清净了，总算不用一直呲牙啦。",
    ),
    "frog_rain": (
        "青蛙雨停啦，满地都是呱呱声的余音。",
        "终于不往下掉青蛙了……",
        "蛙群散啦，我先擦擦手。",
    ),
    "nightmare_riot": (
        "影子退下去啦，周围安静了。",
        "黑暗不闹了，我回来啦。",
        "那些坏影子散掉啦。",
    ),
    "attacked": (
        "偷袭的家伙走啦，现在安全一点。",
        "总算清净了，我继续跟着你。",
        "坏家伙解决啦，我回来啦。",
    ),
    "hostile_group": (
        "那群坏家伙散啦，安全一点了。",
        "附近清净了，我回来啦。",
        "不围着我们了，呼。",
    ),
    "quake_warning": (
        "地底不响啦，可能只是虚惊一场。",
        "轰隆声没啦，我先把肩膀放下来。",
        "地震预警过去啦，继续走吧。",
    ),
    "hound_warning": (
        "耳朵清静啦，狗狗可能改路啦。",
        "狗叫声没啦，暂时不用呲牙了。",
        "爪子声消失啦，呼……虚惊一场。",
    ),
    "acid_rain": (
        "酸雨停啦，衣服应该保住了。",
        "天空恢复正常啦，不用再躲了。",
        "酸水停啦，可以出来了。",
    ),
    "darkness": (
        "亮起来啦，刚才那一下真吓人。",
        "终于看得见路啦。",
        "黑暗退啦，我继续跟着你。",
    ),
    "freezing": (
        "暖和过来啦，手指又能动啦。",
        "不那么冷啦，好舒服。",
        "温度回来啦，我继续跟着你。",
    ),
    "overheating": (
        "终于凉快一点啦。",
        "没那么烫啦，刚才快熟透了。",
        "热气退啦，我回来啦。",
    ),
}


def emergency_category_text(event: dict[str, Any]) -> str:
    category = str(event.get("category") or "")
    return EMERGENCY_CATEGORY_TEXT.get(category, "游戏环境危险")


def emergency_action_text(event: dict[str, Any]) -> str:
    action = str(event.get("action") or "")
    return EMERGENCY_ACTION_TEXT.get(action, "我先按应急规则处理")


def recovery_unavailable_detail(event: dict[str, Any]) -> str:
    reason = str(event.get("reason") or "")
    if reason == "not_enough_hunger_for_sleep":
        hunger_cost = event.get("hunger_cost")
        hunger_after = event.get("hunger_after")
        reserve = event.get("hunger_reserve")
        if (
            hunger_cost is not None
            and hunger_after is not None
            and reserve is not None
        ):
            return (
                "整晚睡眠约要消耗 "
                f"{hunger_cost} 点饥饿，睡完只剩 {hunger_after} 点，"
                f"至少要保留 {reserve} 点"
            )
    if reason == "not_enough_sleep_time":
        sleep_seconds = event.get("sleep_seconds")
        minimum = event.get("minimum_sleep_seconds")
        if sleep_seconds is not None and minimum is not None:
            return (
                f"距离唤醒只剩 {sleep_seconds} 秒，"
                f"这种状态至少需要 {minimum} 秒的睡眠收益"
            )
    if reason == "not_enough_recovery_benefit":
        health_gain = event.get("expected_health_gain")
        sanity_gain = event.get("expected_sanity_gain")
        if health_gain is not None and sanity_gain is not None:
            return (
                "这段时间预计只能恢复 "
                f"{health_gain} 点生命、{sanity_gain} 点精神，收益太少"
            )
    return RECOVERY_REASON_TEXT.get(reason, "当前条件不适合睡觉")


class CompanionService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.memory = MemoryStore(settings.memory_vault, settings.memory_index_db)
        agent_memory_db = settings.agent_memory_db or (
            settings.memory_index_db.parent / "agent_memory.sqlite3"
        )
        self.agent_memory = AgentMemoryStore(agent_memory_db)
        self.agent_memory.seed_implementation_notes(IMPLEMENTATION_NOTES)
        self.character_preferences = CharacterPreferenceStore(
            settings.memory_index_db.parent / "companion_character.json",
            default=settings.companion_character,
        )
        self.journal = CompanionJournal(settings.memory_index_db.parent / "logs")
        self.research = CodexResearchService(
            Path(__file__).resolve().parent.parent,
            timeout=max(30.0, settings.request_timeout * 3),
        )
        self.playbooks = PlaybookMatcher(
            settings.playbook_dir
            or (Path(__file__).resolve().parent.parent / "config" / "playbooks")
        )
        self.arbiter = IntentArbiter(settings.default_lease_seconds)
        prompt = settings.prompt_path.read_text(encoding="utf-8")
        self.planner = DeepSeekPlanner(
            api_key=settings.deepseek_api_key,
            base_url=settings.deepseek_base_url,
            model=settings.deepseek_model,
            timeout=settings.request_timeout,
            system_prompt=prompt,
            memory=self.memory,
            agent_memory=self.agent_memory,
        )
        self._lock = threading.RLock()
        self._wake = threading.Event()
        self._chat_wake = threading.Event()
        self._stopping = threading.Event()
        self._decision_lock = threading.Lock()
        self._chat_lock = threading.Lock()
        self._latest: dict[str, Any] = {}
        self._latest_revision = 0
        self._last_decision_snapshot = 0
        self._pending_instruction: str | None = None
        self._pending_trigger = "instruction"
        self._pending_playbooks: list[dict[str, Any]] = []
        self._pending_chats: deque[str] = deque(maxlen=20)
        self._messages: deque[dict[str, Any]] = deque(maxlen=50)
        self._last_error: str | None = None
        self._last_decision_at: float | None = None
        self._thread: threading.Thread | None = None
        self._ambient_thread: threading.Thread | None = None
        self._chat_thread: threading.Thread | None = None
        self._event_seen: dict[str, float] = {}
        self._last_intent_signature: tuple[Any, ...] | None = None
        self._last_expired_intent_id: str | None = None
        self._cross_world_block_seen: dict[str, float] = {}
        self._agent_memory_closed = False
        self._world_memory_last_scan = 0.0
        self._emergency_line_counts: dict[tuple[str, str, str], int] = {}

    def start(self) -> None:
        if self._thread is not None:
            return
        self._thread = threading.Thread(
            target=self._decision_loop,
            name="companion-decider",
            daemon=True,
        )
        self._thread.start()
        self._ambient_thread = threading.Thread(
            target=self._ambient_loop,
            name="companion-ambient-chat",
            daemon=True,
        )
        self._ambient_thread.start()
        self._chat_thread = threading.Thread(
            target=self._chat_loop,
            name="companion-user-chat",
            daemon=True,
        )
        self._chat_thread.start()
        self.journal.record(
            "service.started",
            "伴侣控制器已启动",
            data={"model": self.settings.deepseek_model, "port": self.settings.port},
        )

    def stop(self) -> None:
        self._stopping.set()
        self._wake.set()
        self._chat_wake.set()
        if self._thread is not None:
            self._thread.join(timeout=3)
        if self._ambient_thread is not None:
            self._ambient_thread.join(timeout=3)
        if self._chat_thread is not None:
            self._chat_thread.join(timeout=3)
        self.journal.record("service.stopped", "伴侣控制器已停止")
        if not self._agent_memory_closed:
            self.agent_memory.close()
            self._agent_memory_closed = True

    def tick(self, snapshot: dict[str, Any]) -> dict[str, Any]:
        self._remember_world_snapshot(snapshot)
        with self._lock:
            self._latest = copy.deepcopy(snapshot)
            self._latest_revision += 1
            revision = self._latest_revision
            important_events = [
                event
                for event in (snapshot.get("events") or [])
                if isinstance(event, dict)
                and str(event.get("type")) in IMPORTANT_EVENTS
                and not (
                    str(event.get("type")) == "task_complete"
                    and str(event.get("mode")) == "collect_loot"
                )
                and not (
                    str(event.get("type")) == "task_failed"
                    and str(event.get("reason")) in {
                        "survival_hunger_low",
                        "survival_health_low",
                    }
                )
            ]
            if important_events:
                self._wake.set()
        self._record_snapshot_events(snapshot)
        state = self.arbiter.snapshot()
        if (
            state["intent"].get("reason") == "intent_lease_expired_follow"
            and state["intent"]["intent_id"] != self._last_expired_intent_id
        ):
            self._last_expired_intent_id = state["intent"]["intent_id"]
            self.journal.record(
                "task.expired",
                "任务租约到期，伴侣返回默认跟随",
                level="warning",
                data={"intent_id": state["intent"]["intent_id"]},
            )
        state["messages"] = list(self._messages)
        state["observed_revision"] = revision
        state["last_error"] = self._last_error
        state["log_path"] = str(self.journal.latest_path)
        character_selection = self.character_selection()
        state["companion_character"] = character_selection["prefab"]
        state["character_selection"] = character_selection
        return state

    def _remember_world_snapshot(self, snapshot: dict[str, Any]) -> None:
        now = time.monotonic()
        if now - self._world_memory_last_scan < 10:
            return
        self._world_memory_last_scan = now
        shard = str((snapshot.get("world") or {}).get("shard") or "")
        if not shard:
            return
        for entity in snapshot.get("nearby") or []:
            if not isinstance(entity, dict):
                continue
            prefab = str(entity.get("prefab") or "")
            x = entity.get("x")
            z = entity.get("z")
            if not prefab or x is None or z is None:
                continue
            if entity.get("container"):
                category = "container"
            elif entity.get("workable"):
                category = "workable"
            elif entity.get("pickable") or entity.get("harvestable"):
                category = "harvestable"
            else:
                continue
            details = {
                "container_items": entity.get("container_items"),
                "hostile": bool(entity.get("hostile")),
            }
            self.agent_memory.remember_world_point(
                shard=shard,
                prefab=prefab,
                category=category,
                x=round(float(x) / 8) * 8,
                z=round(float(z) / 8) * 8,
                details=details,
            )

    def instruction(self, text: str) -> dict[str, Any]:
        text = text.strip()
        if not text:
            raise ValueError("instruction text must not be empty")
        with self._lock:
            self._pending_instruction = text
            self._pending_trigger = "instruction"
            self._pending_playbooks = []
            self._wake.set()
        self.agent_memory.record_chat("chat", "user", text)
        self.journal.record(
            "user.instruction",
            text,
            data={"intent_id": self.arbiter.active().intent_id},
        )
        state = self.arbiter.snapshot()
        state["messages"] = list(self._messages)
        state["instruction_received"] = True
        state["last_error"] = self._last_error
        return state

    def message(self, text: str) -> dict[str, Any]:
        """Queue one in-game chat message that may be dialogue or a task."""
        text = text.strip()
        if not text:
            raise ValueError("message text must not be empty")
        self.agent_memory.record_chat("chat", "user", text)
        snapshot = copy.deepcopy(self._latest)
        match = self.playbooks.match(text, snapshot)
        if match is not None and match.direct:
            return self._apply_playbook_match(match)
        candidates = self.playbooks.candidate_context(text, snapshot)
        with self._lock:
            self._pending_instruction = text
            self._pending_trigger = "chat_or_task"
            self._pending_playbooks = candidates
            self._wake.set()
        self.journal.record(
            "user.message",
            text,
            data={"intent_id": self.arbiter.active().intent_id},
        )
        state = self.arbiter.snapshot()
        state["messages"] = list(self._messages)
        state["message_received"] = True
        state["last_error"] = self._last_error
        return state

    def _apply_playbook_match(self, match: PlaybookMatch) -> dict[str, Any]:
        previous = self.arbiter.active()
        current = previous
        if match.intent is not None:
            current = self.arbiter.set(match.intent, source="playbook")
            self._record_intent_change(previous, current, "playbook")
        self.journal.record(
            "task.playbook_matched",
            f"任务匹配到预写方案：{match.playbook_id}",
            data={
                "playbook_id": match.playbook_id,
                "task_type": match.task_type,
                "character": match.character,
                "direct": match.direct,
                "confidence": match.confidence,
            },
        )
        if match.reply:
            self._publish_reply(
                {"text": match.reply, "expects_response": False},
                current.intent_id,
                "playbook",
            )
        state = self.arbiter.snapshot()
        state["messages"] = list(self._messages)
        state["message_received"] = True
        state["playbook_matched"] = match.playbook_id
        state["last_error"] = self._last_error
        return state

    def chat(self, text: str) -> dict[str, Any]:
        """Queue a reply-only conversational turn.

        Chat never passes through the task mutation path, even if the model
        mistakenly returns an intent.
        """
        text = text.strip()
        if not text:
            raise ValueError("chat text must not be empty")
        with self._lock:
            self._pending_chats.append(text)
            self._chat_wake.set()
        self.agent_memory.record_chat("chat", "user", text)
        self.journal.record(
            "user.chat",
            text,
            data={"intent_id": self.arbiter.active().intent_id},
        )
        state = self.arbiter.snapshot()
        state["messages"] = list(self._messages)
        state["chat_queued"] = True
        state["last_error"] = self._last_error
        return state

    def force_command(self, payload: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(payload, dict):
            raise ValueError("command payload must be an object")
        blocked_target = self._cross_world_target(payload, self._latest)
        if blocked_target is not None:
            self._block_cross_world_intent(
                payload,
                blocked_target,
                source="manual",
                reply_source="safety",
            )
            return self.arbiter.snapshot()
        previous = self.arbiter.active()
        current = self.arbiter.set(payload, source="manual")
        self._record_intent_change(previous, current, "manual")
        return self.arbiter.snapshot()

    def state(self) -> dict[str, Any]:
        result = self.arbiter.snapshot()
        character_selection = self.character_selection()
        result.update(
            {
                "messages": list(self._messages),
                "last_error": self._last_error,
                "last_decision_at": self._last_decision_at,
                "observed_revision": self._latest_revision,
                "log_path": str(self.journal.latest_path),
                "companion_character": character_selection["prefab"],
                "character_selection": character_selection,
            }
        )
        return result

    def character_selection(self) -> dict[str, Any]:
        companion = self._latest.get("companion") or {}
        active_prefab = (
            str(companion.get("prefab"))
            if companion.get("prefab")
            else None
        )
        return self.character_preferences.payload(active_prefab)

    def select_character(self, prefab: str) -> dict[str, Any]:
        self.character_preferences.select(prefab)
        selection = self.character_selection()
        self.journal.record(
            "config.companion_character",
            f"微光角色选择已更新为 {selection['name']}",
            data={"prefab": selection["prefab"]},
        )
        return selection

    @staticmethod
    def _event_signature(event: dict[str, Any]) -> str:
        event_id = event.get("event_id") or event.get("id")
        if event_id is not None:
            return f"id:{event_id}"
        return "data:" + json.dumps(
            event, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        )

    @staticmethod
    def _same_world(target: Any, snapshot: dict[str, Any]) -> bool:
        if target is None:
            return False
        target_text = str(target).strip().lower()
        if not target_text:
            return False
        world = snapshot.get("world") or {}
        current = str(world.get("shard", "")).strip().lower()
        if not current:
            return False

        aliases = {current}
        if world.get("is_master"):
            aliases.update({"1", "master", "forest", "overworld", "地面", "地上", "主世界"})
        else:
            aliases.update({"2", "cave", "caves", "underground", "洞穴", "地洞", "地下"})
        return target_text in aliases

    def _cross_world_target(
        self,
        payload: dict[str, Any],
        snapshot: dict[str, Any],
    ) -> str | None:
        params = payload.get("params") or {}
        if not isinstance(params, dict):
            params = {}

        candidates: list[Any] = []
        for source in (payload, params):
            for key in (
                "target_shard",
                "target_world",
                "destination_shard",
                "world_id",
                "worldid",
                "shard",
            ):
                value = source.get(key)
                if value is not None:
                    candidates.append(value)

        landmark_name = params.get("landmark") or params.get("location_name")
        if landmark_name is not None:
            landmarks = snapshot.get("landmarks") or {}
            landmark = landmarks.get(str(landmark_name))
            if isinstance(landmark, dict):
                candidates.append(landmark.get("shard"))

        world = snapshot.get("world") or {}
        current = world.get("shard")
        for candidate in candidates:
            if candidate is None or str(candidate).strip() == "":
                continue
            if current is None or not self._same_world(candidate, snapshot):
                return str(candidate)

        if str(payload.get("mode") or "").strip().lower() in CROSS_WORLD_MODES:
            return "another_shard"
        return None

    def _block_cross_world_intent(
        self,
        payload: dict[str, Any],
        target: str,
        source: str,
        reply_source: str,
    ) -> None:
        now = time.monotonic()
        original_id = str(payload.get("intent_id") or "")
        mode = str(payload.get("mode") or "")
        world = self._latest.get("world") or {}
        current = str(world.get("shard") or "")
        block_key = f"{original_id}:{mode}:{current}:{target}"
        previous = self.arbiter.active()
        safe = self.arbiter.set(
            {
                "intent_id": f"cross-world-blocked-{uuid.uuid4()}",
                "mode": "hold",
                "lease_seconds": 24 * 60 * 60,
                "reason": "cross_world_forbidden",
                "params": {
                    "blocked_mode": mode,
                    "blocked_target_shard": target,
                },
            },
            source=source,
        )
        self._record_intent_change(previous, safe, "controller_world_guard")

        self._cross_world_block_seen = {
            key: seen_at
            for key, seen_at in self._cross_world_block_seen.items()
            if now - seen_at < 300
        }
        last_seen = self._cross_world_block_seen.get(block_key, 0)
        self._cross_world_block_seen[block_key] = now
        if now - last_seen < 300:
            return
        self.journal.record(
            "controller.cross_world_blocked",
            "控制器阻止了跨世界操作",
            level="warning",
            data={
                "intent_id": original_id or None,
                "mode": mode,
                "current_shard": current or None,
                "target_shard": target,
                "source": source,
            },
        )
        self._publish_reply(
            {"text": CROSS_WORLD_REPLY, "expects_response": False},
            safe.intent_id,
            reply_source,
        )

    def _emergency_announcement(
        self,
        event: dict[str, Any],
        kind: str,
    ) -> str:
        category = str(event.get("category") or "")
        action = str(event.get("action") or "")
        if kind == "resolved":
            lines = EMERGENCY_RESOLVED_LINES.get(
                category,
                ("危险过去啦，我回来啦。",),
            )
            line_key = f"resolved:{category}"
        elif kind == "action":
            lines = EMERGENCY_ACTION_LINES.get(action)
            if not lines:
                return emergency_action_text(event) + "。"
            line_key = f"action:{category}:{action}"
        else:
            lines = EMERGENCY_DETECTED_LINES.get(
                category,
                ("有危险啦！我先按应急规则处理！",),
            )
            line_key = f"detected:{category}"

        count_key = (line_key, category, action)
        count = self._emergency_line_counts.get(count_key, 0)
        self._emergency_line_counts[count_key] = count + 1
        text = lines[count % len(lines)]
        if kind == "detected" and action == "continue_task_override":
            override_lines = EMERGENCY_ACTION_LINES[
                "continue_task_override"
            ]
            override_key = ("override", category, action)
            override_count = self._emergency_line_counts.get(
                override_key,
                0,
            )
            self._emergency_line_counts[override_key] = override_count + 1
            text += (
                " "
                + override_lines[override_count % len(override_lines)]
            )
        return text

    def _record_snapshot_events(self, snapshot: dict[str, Any]) -> None:
        now = time.monotonic()
        cutoff = now - 300
        self._event_seen = {
            key: seen_at
            for key, seen_at in self._event_seen.items()
            if seen_at >= cutoff
        }
        companion = snapshot.get("companion") or {}
        world = snapshot.get("world") or {}
        for event in snapshot.get("events") or []:
            if not isinstance(event, dict):
                continue
            signature = self._event_signature(event)
            if signature in self._event_seen:
                continue
            self._event_seen[signature] = now
            event_type = str(event.get("type") or "unknown")
            reason = event.get("reason")
            level = (
                "error"
                if event_type in {"task_failed", "companion_dead"}
                else "warning"
                if event_type in {
                    "task_blocked",
                    "critical_health",
                    "critical_hunger",
                    "emergency_detected",
                    "emergency_action",
                }
                else "info"
            )
            messages = {
                "task_started": "伴侣开始执行任务",
                "task_progress": "伴侣任务进度更新",
                "task_complete": "伴侣确认任务完成",
                "task_failed": "伴侣任务失败",
                "task_blocked": "伴侣任务被游戏世界限制阻塞",
                "item_acquired": "伴侣已取得目标物品",
                "combat_target_defeated": "伴侣击败了战斗目标",
                "combat_target_lost": "伴侣跟丢了战斗目标",
                "world_transition": "伴侣已随你完成世界切换",
                "recovery_started": "微光开始自主恢复状态",
                "recovery_completed": "微光完成自主恢复",
                "recovery_unavailable": "微光当前无法安全自主恢复",
                "emergency_detected": "微光发现环境危险并启动应急处理",
                "emergency_action": "微光调整了应急处理方式",
                "emergency_resolved": "微光确认应急危险已经解除",
            }
            message = messages.get(event_type, f"游戏事件：{event_type}")
            if (
                event_type == "combat_target_defeated"
                and not event.get("verified")
            ):
                message = "战斗目标已死亡，最后一击不是伴侣完成的"
            elif event_type == "task_failed" and reason == "combat_leash_exceeded":
                message = "伴侣离用户超过战斗安全距离，已停止追击"
            elif event_type == "task_failed" and reason == "shard_transition":
                message = "伴侣随你切换世界，已中断原任务并回到跟随"
            elif event_type == "task_failed" and reason == "lethal_next_hit":
                message = "伴侣判断下一次受击可能致命，已中断战斗并撤向玩家"
            elif event_type == "task_failed" and reason == "survival_hunger_low":
                message = "伴侣饱食度不足且没有可用食物，已取消远行并返回跟随"
            elif event_type == "task_failed" and reason == "survival_health_low":
                message = "伴侣生命值过低，已取消远行并返回跟随"
            elif event_type == "recovery_unavailable":
                message = (
                    "微光无法自行恢复（"
                    + recovery_unavailable_detail(event)
                    + "）"
                )
            elif event_type == "emergency_detected":
                message = self._emergency_announcement(event, "detected")
            elif event_type == "emergency_action":
                message = self._emergency_announcement(event, "action")
            elif event_type == "emergency_resolved":
                message = self._emergency_announcement(event, "resolved")
            elif (
                event_type == "task_complete"
                and event.get("mode") == "collect_loot"
            ):
                item_name = {
                    "silk": "蜘蛛丝",
                    "monstermeat": "怪物肉",
                }.get(
                    str(event.get("item_prefab") or ""),
                    str(event.get("item_prefab") or "物品"),
                )
                message = f"伴侣收集完成：{item_name} {event.get('amount')} 个"
            if reason and event_type not in {
                "recovery_unavailable",
                "emergency_detected",
                "emergency_action",
                "emergency_resolved",
            }:
                message += f"（{reason}）"
            data = {
                key: value
                for key, value in event.items()
                if key not in {"type", "event_id", "id"}
            }
            data.update(
                {
                    "shard": world.get("shard"),
                    "companion_position": [
                        companion.get("x"),
                        companion.get("z"),
                    ],
                    "player_distance": (
                        (snapshot.get("player") or {}).get("distance")
                    ),
                    "inventory_count": len(snapshot.get("inventory") or []),
                }
            )
            self.journal.record(
                f"game.{event_type}",
                message,
                level=level,
                data=data,
            )
            if event_type == "task_failed" and reason == "shard_transition":
                previous = self.arbiter.active()
                current = self.arbiter.set(
                    {
                        "intent_id": (
                            f"transition-follow-"
                            f"{event.get('to_shard') or world.get('shard')}-"
                            f"{event.get('event_id') or event.get('id')}"
                        ),
                        "mode": "follow",
                        "lease_seconds": 24 * 60 * 60,
                        "reason": "shard_transition_follow",
                    },
                    source="shard_transition",
                )
                self._record_intent_change(
                    previous,
                    current,
                    "shard_transition",
                )
            elif event_type == "task_failed" and reason == "lethal_next_hit":
                previous = self.arbiter.active()
                current = self.arbiter.set(
                    {
                        "intent_id": (
                            f"lethal-retreat-follow-"
                            f"{event.get('event_id') or event.get('id')}"
                        ),
                        "mode": "follow",
                        "lease_seconds": 120,
                        "reason": "lethal_retreat_follow",
                    },
                    source="combat_safety",
                )
                self._record_intent_change(
                    previous,
                    current,
                    "combat_safety",
                )
                self._publish_reply(
                    {
                        "text": "我下一次受击可能会倒下，先撤回你身边；需要补血或拿物资时我会先说明再行动。",
                        "expects_response": False,
                    },
                    current.intent_id,
                    "safety",
                )
            elif (
                event_type == "task_complete"
                and event.get("mode") == "collect_loot"
            ):
                previous = self.arbiter.active()
                current = self.arbiter.set(
                    {
                        "intent_id": (
                            f"collect-complete-follow-"
                            f"{event.get('event_id') or event.get('id')}"
                        ),
                        "mode": "follow",
                        "lease_seconds": 86400,
                        "reason": "collect_complete_follow",
                    },
                    source="playbook_completion",
                )
                self._record_intent_change(
                    previous,
                    current,
                    "playbook_completion",
                )
                item_name = {
                    "silk": "蜘蛛丝",
                    "monstermeat": "怪物肉",
                }.get(
                    str(event.get("item_prefab") or ""),
                    str(event.get("item_prefab") or "物品"),
                )
                delivered = event.get("delivered_to_player", False)
                amount = event.get("amount")
                text = f"{item_name}收集好了，共 {amount} 个。"
                if delivered:
                    text += "已经交给你。"
                self._publish_reply(
                    {"text": text, "expects_response": False},
                    current.intent_id,
                    "playbook_completion",
                )
            elif (
                event_type == "task_failed"
                and reason in {"survival_hunger_low", "survival_health_low"}
            ):
                previous = self.arbiter.active()
                current = self.arbiter.set(
                    {
                        "intent_id": (
                            f"survival-follow-"
                            f"{event.get('event_id') or event.get('id')}"
                        ),
                        "mode": "follow",
                        "lease_seconds": 86400,
                        "reason": "survival_return_follow",
                    },
                    source="survival_safety",
                )
                self._record_intent_change(
                    previous,
                    current,
                    "survival_safety",
                )
                if reason == "survival_hunger_low":
                    text = (
                        "我饱食度不够，背包里也没有能吃的食物。"
                        "为了不饿死在路上，我先回来跟着你，等你给我补给。"
                    )
                else:
                    text = (
                        "我生命值太低，继续远行有死亡风险。"
                        "我先回来跟着你，等我恢复后再出发。"
                    )
                self._publish_reply(
                    {"text": text, "expects_response": False},
                    current.intent_id,
                    "safety",
                )
            elif event_type == "recovery_started":
                method = str(event.get("method") or "tent")
                sleep_seconds = event.get("sleep_seconds")
                hunger_cost = event.get("estimated_hunger_cost")
                health_gain = event.get("expected_health_gain")
                sanity_gain = event.get("expected_sanity_gain")
                if method == "food":
                    text = "我有点饿了，先吃些随身食物。"
                elif method == "healing_item":
                    text = "我生命偏低，先用背包里的治疗物品。"
                else:
                    text = (
                        "我状态有些低，先去附近帐篷休息。"
                        f"大约睡 {sleep_seconds} 秒，"
                        f"预计消耗 {hunger_cost} 点饥饿，"
                        f"恢复 {health_gain} 点生命和 {sanity_gain} 点精神。"
                    )
                self._publish_reply(
                    {
                        "text": text,
                        "expects_response": False,
                    },
                    self.arbiter.active().intent_id,
                    "recovery",
                )
            elif event_type == "recovery_completed":
                method = str(event.get("method") or "tent")
                if method == "food":
                    text = f"我吃完东西了，现在饥饿 {event.get('hunger')}。"
                elif method == "healing_item":
                    text = f"治疗物品用完了，现在生命 {event.get('health')}。"
                else:
                    text = (
                        "我休息好了。"
                        f"当前生命 {event.get('health')}，"
                        f"饥饿 {event.get('hunger')}，"
                        f"精神 {event.get('sanity')}。"
                    )
                self._publish_reply(
                    {
                        "text": text,
                        "expects_response": False,
                    },
                    self.arbiter.active().intent_id,
                    "recovery",
                )
            elif event_type == "recovery_unavailable":
                self._publish_reply(
                    {
                        "text": "我想自己恢复，但"
                        + recovery_unavailable_detail(event)
                        + "。",
                        "expects_response": False,
                    },
                    self.arbiter.active().intent_id,
                    "recovery",
                )
            elif event_type == "emergency_detected":
                self._publish_reply(
                    {
                        "text": message,
                        "expects_response": False,
                    },
                    self.arbiter.active().intent_id,
                    "emergency",
                )
            elif event_type == "emergency_action":
                self._publish_reply(
                    {
                        "text": message,
                        "expects_response": False,
                    },
                    self.arbiter.active().intent_id,
                    "emergency",
                )
            elif event_type == "emergency_resolved":
                self._publish_reply(
                    {
                        "text": message,
                        "expects_response": False,
                    },
                    self.arbiter.active().intent_id,
                    "emergency",
                )

    def _record_intent_change(
        self,
        previous: Any,
        current: Any,
        source: str,
    ) -> None:
        signature = (
            current.intent_id,
            current.mode,
            current.target_guid,
            current.target_prefab,
            tuple(current.position or ()),
        )
        if signature == self._last_intent_signature:
            return
        changed_task = previous.intent_id != current.intent_id
        self._last_intent_signature = signature
        kind = "task.started" if changed_task else "task.updated"
        message = (
            f"任务切换到 {current.mode}"
            if changed_task
            else f"任务 {current.mode} 已刷新"
        )
        self.journal.record(
            kind,
            message,
            data={
                "intent_id": current.intent_id,
                "previous_intent_id": previous.intent_id,
                "mode": current.mode,
                "target_guid": current.target_guid,
                "target_prefab": current.target_prefab,
                "position": current.position,
                "lease_seconds": current.lease_seconds,
                "reason": current.reason,
                "source": source,
            },
        )

    def _decision_loop(self) -> None:
        while not self._stopping.is_set():
            timeout = (
                self.settings.replan_interval
                if self.settings.replan_interval > 0
                else None
            )
            self._wake.wait(timeout=timeout)
            self._wake.clear()
            if self._stopping.is_set():
                break

            with self._lock:
                snapshot = copy.deepcopy(self._latest)
                observed_revision = self._latest_revision
                instruction = self._pending_instruction
                trigger = self._pending_trigger
                matched_playbooks = self._pending_playbooks
                self._pending_playbooks = []
            if not snapshot:
                continue
            if instruction and matched_playbooks:
                snapshot["matched_playbooks"] = matched_playbooks
            if observed_revision == self._last_decision_snapshot and not instruction:
                continue

            try:
                snapshot["journal"] = self.journal.context(20)
                with self._decision_lock:
                    response = self.planner.decide(
                        snapshot,
                        self.arbiter.active().to_dict(),
                        instruction,
                        trigger=trigger if instruction else "event",
                    )
                    response = self._run_requested_research(
                        response,
                        snapshot,
                        self.arbiter.active().to_dict(),
                        instruction,
                    )
                self._apply_response(response, force_chat_only=False)
                with self._lock:
                    if instruction == self._pending_instruction:
                        self._pending_instruction = None
                self._last_error = None
                self._last_decision_snapshot = observed_revision
                self._last_decision_at = time.time()
            except (DeepSeekError, ValueError, KeyError, TypeError) as exc:
                self._last_error = str(exc)
                self.journal.record(
                    "model.error",
                    "DeepSeek 任务决策失败",
                    level="error",
                    data={"error": str(exc), "trigger": "task"},
                )
                # Do not switch to an independent survival policy.
                # Existing intent expires naturally and then becomes hold.

    def _run_requested_research(
        self,
        response: dict[str, Any],
        snapshot: dict[str, Any],
        current_intent: dict[str, Any],
        instruction: str | None,
    ) -> dict[str, Any]:
        query = str(response.get("research_query") or "").strip()
        if not query:
            return response
        try:
            result = self.research.research(
                query,
                json.dumps(
                    {
                        "world": snapshot.get("world"),
                        "player": snapshot.get("player"),
                        "companion": snapshot.get("companion"),
                        "inventory": snapshot.get("inventory"),
                        "capabilities": snapshot.get("capabilities"),
                    },
                    ensure_ascii=False,
                    separators=(",", ":"),
                ),
            )
            note = self.research.render_skill_note(result)
            topic = str(result.get("topic") or query).strip()
            self.agent_memory.remember_skill(
                topic,
                note,
                summary=str(result.get("summary") or "")[:180],
                source="codex-web-research",
                confidence=0.8,
            )
            snapshot["research_context"] = result
            self.journal.record(
                "research.completed",
                f"Codex 已完成资料研究：{topic}",
                data={"topic": topic, "query": query},
            )
        except ResearchError as exc:
            snapshot["research_error"] = str(exc)
            self.journal.record(
                "research.failed",
                "Codex 资料研究失败",
                level="warning",
                data={"query": query, "error": str(exc)},
            )
        return self.planner.decide(
            snapshot,
            current_intent,
            instruction,
            trigger="research_followup",
        )

    def _chat_loop(self) -> None:
        while not self._stopping.is_set():
            self._chat_wake.wait(timeout=1.0)
            self._chat_wake.clear()
            if self._stopping.is_set():
                break
            with self._lock:
                if not self._pending_chats:
                    continue
                text = self._pending_chats.popleft()
                snapshot = copy.deepcopy(self._latest)
            if not snapshot or not snapshot.get("player", {}).get("guid"):
                continue
            try:
                snapshot["journal"] = self.journal.context(20)
                with self._chat_lock:
                    response = self.planner.decide(
                        snapshot,
                        self.arbiter.active().to_dict(),
                        text,
                        trigger="chat",
                    )
                self._apply_response(
                    response,
                    force_chat_only=True,
                    reply_source="chat",
                )
                self._last_error = None
            except (DeepSeekError, ValueError, KeyError, TypeError) as exc:
                self._last_error = str(exc)
                self.journal.record(
                    "model.error",
                    "DeepSeek 闲聊失败",
                    level="warning",
                    data={"error": str(exc), "trigger": "chat"},
                )

    def _apply_response(
        self,
        response: dict[str, Any],
        force_chat_only: bool,
        reply_source: str = "task",
    ) -> None:
        current = self.arbiter.active()
        intent = current
        if not force_chat_only:
            gap = response.get("capability_gap")
            if isinstance(gap, dict):
                gap_id = self.agent_memory.record_capability_gap(
                    feature=str(gap.get("feature") or "未命名功能"),
                    request_text=str(
                        gap.get("request_text")
                        or (response.get("reply") or {}).get("text")
                        or current.reason
                    ),
                    missing_capability=str(
                        gap.get("missing_capability") or "未实现"
                    ),
                    suggested_implementation=str(
                        gap.get("suggested_implementation") or ""
                    ),
                )
                safe = self.arbiter.set(
                    {
                        "intent_id": f"capability-gap-{gap_id}",
                        "mode": "hold",
                        "lease_seconds": 300,
                        "reason": "capability_gap",
                        "params": {"gap_id": gap_id},
                    },
                    source="capability_gap",
                )
                self._record_intent_change(current, safe, "capability_gap")
                message = str(
                    gap.get("message")
                    or "这个功能目前做不到，我已经把具体缺口记录下来。"
                )
                self.journal.record(
                    "capability.gap",
                    message,
                    level="warning",
                    data={
                        "gap_id": gap_id,
                        "feature": gap.get("feature"),
                        "missing_capability": gap.get("missing_capability"),
                    },
                )
                self._publish_reply(
                    {"text": message, "expects_response": False},
                    safe.intent_id,
                    "capability_gap",
                )
                return
            skill_note = response.get("skill_note")
            if isinstance(skill_note, dict):
                topic = str(skill_note.get("topic") or "").strip()
                content = str(skill_note.get("content") or "").strip()
                if topic and content:
                    self.agent_memory.remember_skill(
                        topic,
                        content,
                        summary=str(skill_note.get("summary") or "")[:180],
                        source="deepseek-policy",
                        confidence=float(skill_note.get("confidence") or 0.6),
                    )
            plan = response.get("plan")
            if isinstance(plan, dict):
                goal = str(
                    plan.get("goal")
                    or (response.get("reply") or {}).get("text")
                    or current.reason
                    or "companion_task"
                )
                self.agent_memory.save_plan(goal, plan)
            if "intent" in response:
                intent_payload = response.get("intent")
                if intent_payload is not None:
                    if not isinstance(intent_payload, dict):
                        raise ValueError("model intent must be an object or null")
                    intent_payload = dict(intent_payload)
                    if (
                        str(intent_payload.get("intent_id", ""))
                        == current.intent_id
                    ):
                        merged = {
                            "intent_id": current.intent_id,
                            "mode": current.mode,
                            "target_guid": current.target_guid,
                            "target_prefab": current.target_prefab,
                            "position": current.position,
                            "params": dict(current.params),
                            "lease_seconds": current.lease_seconds,
                            "reason": current.reason,
                        }
                        merged.update(intent_payload)
                        intent_payload = merged
                    intent_payload.setdefault(
                        "lease_seconds", self.settings.default_lease_seconds
                    )
                    blocked_target = self._cross_world_target(
                        intent_payload, self._latest
                    )
                    if blocked_target is not None:
                        self._block_cross_world_intent(
                            intent_payload,
                            blocked_target,
                            source="deepseek",
                            reply_source=reply_source,
                        )
                        return
                    intent = self.arbiter.set(intent_payload, source="deepseek")
            elif "mode" in response:
                intent_payload = dict(response)
                intent_payload.pop("reply", None)
                intent_payload.setdefault(
                    "lease_seconds", self.settings.default_lease_seconds
                )
                blocked_target = self._cross_world_target(
                    intent_payload, self._latest
                )
                if blocked_target is not None:
                    self._block_cross_world_intent(
                        intent_payload,
                        blocked_target,
                        source="deepseek",
                        reply_source=reply_source,
                    )
                    return
                intent = self.arbiter.set(intent_payload, source="deepseek")
            else:
                # Chat-only response: retain the task currently being executed.
                intent = current
            if intent is not current:
                self._record_intent_change(current, intent, "deepseek")

        reply = response.get("reply")
        if isinstance(reply, dict) and reply.get("text"):
            self._publish_reply(reply, intent.intent_id, reply_source)

    def _ambient_loop(self) -> None:
        minimum = max(30.0, self.settings.ambient_chat_min_seconds)
        maximum = max(minimum, self.settings.ambient_chat_max_seconds)
        while not self._stopping.wait(random.uniform(minimum, maximum)):
            with self._lock:
                snapshot = copy.deepcopy(self._latest)
                last_revision = self._latest_revision
            if not snapshot or last_revision == self._last_decision_snapshot:
                continue
            if not snapshot.get("player", {}).get("guid"):
                continue
            try:
                snapshot["journal"] = self.journal.context(20)
                with self._chat_lock:
                    response = self.planner.decide(
                        snapshot,
                        self.arbiter.active().to_dict(),
                        "现在进行一轮不改变任务的简短闲聊",
                        trigger="ambient_chat",
                    )
                self._apply_response(
                    response,
                    force_chat_only=True,
                    reply_source="ambient",
                )
                self._last_error = None
            except (DeepSeekError, ValueError, KeyError, TypeError) as exc:
                self._last_error = str(exc)
                self.journal.record(
                    "model.error",
                    "DeepSeek 主动闲聊失败",
                    level="warning",
                    data={"error": str(exc), "trigger": "ambient_chat"},
                )

    def _publish_reply(
        self,
        reply: dict[str, Any],
        intent_id: str,
        source: str,
    ) -> None:
        message = {
            "id": str(uuid.uuid4()),
            "text": str(reply["text"]),
            "expects_response": bool(reply.get("expects_response", False)),
            "intent_id": intent_id,
            "source": source,
            "created_at": time.time(),
        }
        with self._lock:
            self._messages.append(message)
        self.agent_memory.record_chat(
            "tasks" if source == "task" else "chat",
            "companion",
            message["text"],
        )
        self.journal.record(
            f"chat.reply.{source}",
            message["text"],
            data={
                "intent_id": intent_id,
                "expects_response": message["expects_response"],
                "message_id": message["id"],
            },
        )
