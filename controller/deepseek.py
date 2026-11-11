from __future__ import annotations

import json
import re
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from .agent_memory import AgentMemoryStore
from .memory import MemoryStore


class DeepSeekError(RuntimeError):
    pass


class DeepSeekPlanner:
    def __init__(
        self,
        api_key: str | None,
        base_url: str,
        model: str,
        timeout: float,
        system_prompt: str,
        memory: MemoryStore,
        agent_memory: AgentMemoryStore | None = None,
    ) -> None:
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.timeout = timeout
        self.system_prompt = system_prompt
        self.memory = memory
        self.agent_memory = agent_memory

    def _endpoint(self) -> str:
        if self.base_url.endswith("/chat/completions"):
            return self.base_url
        if self.base_url.endswith("/v1"):
            return self.base_url + "/chat/completions"
        return self.base_url + "/chat/completions"

    @staticmethod
    def _extract_json(text: str) -> dict[str, Any]:
        text = text.strip()
        fenced = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, re.S)
        if fenced:
            text = fenced.group(1)
        try:
            value = json.loads(text)
        except json.JSONDecodeError as exc:
            raise DeepSeekError("model response was not valid JSON") from exc
        if not isinstance(value, dict):
            raise DeepSeekError("model response must be a JSON object")
        return value

    def decide(
        self,
        snapshot: dict[str, Any],
        current_intent: dict[str, Any],
        user_instruction: str | None = None,
        trigger: str = "instruction",
    ) -> dict[str, Any]:
        if not self.api_key:
            raise DeepSeekError(
                "DEEPSEEK_API_KEY is not set; companion remains in hold mode"
            )

        nearby = snapshot.get("nearby") or []
        prefabs = []
        for entity in nearby[:40]:
            prefab = entity.get("prefab")
            if prefab and prefab not in prefabs:
                prefabs.append(prefab)
        memory_query = " ".join(
            [
                user_instruction or "",
                snapshot.get("world", {}).get("phase", ""),
                snapshot.get("world", {}).get("season", ""),
                " ".join(str(p) for p in prefabs[:12]),
                current_intent.get("reason", ""),
            ]
        )
        memory_context = self.memory.render_context(memory_query, limit=6)
        skill_context = (
            self.agent_memory.render_skill_context(memory_query, limit=8)
            if self.agent_memory is not None
            else ""
        )
        active_plan = (
            self.agent_memory.active_plan()
            if self.agent_memory is not None
            else None
        )
        recent_chat = (
            self.agent_memory.recent_chat("chat", limit=10)
            if self.agent_memory is not None
            else []
        )
        world_context = (
            self.agent_memory.world_context(
                str(snapshot.get("world", {}).get("shard") or ""),
                memory_query,
                limit=30,
            )
            if self.agent_memory is not None
            else []
        )
        model_snapshot = dict(snapshot)
        capabilities = dict(snapshot.get("capabilities") or {})
        recipes = capabilities.get("known_recipes") or []
        query_text = " ".join(
            [
                user_instruction or "",
                json.dumps(active_plan or {}, ensure_ascii=False),
                current_intent.get("target_prefab", ""),
                current_intent.get("reason", ""),
            ]
        ).lower()
        query_terms = {
            term
            for term in re.findall(r"[0-9a-z_]+", query_text)
            if len(term) >= 3
        }
        selected_recipes = []
        for recipe in recipes:
            if not isinstance(recipe, dict):
                continue
            searchable = " ".join(
                [
                    str(recipe.get("name", "")),
                    str(recipe.get("product", "")),
                ]
            ).lower()
            if recipe.get("available") or any(
                term in searchable for term in query_terms
            ):
                selected_recipes.append(recipe)
        if not selected_recipes:
            selected_recipes = [
                recipe
                for recipe in recipes
                if isinstance(recipe, dict) and recipe.get("available")
            ]
        capabilities["recipe_catalog_count"] = len(recipes)
        capabilities["known_recipes"] = selected_recipes[:80]
        model_snapshot["capabilities"] = capabilities

        payload = {
            "model": self.model,
            "temperature": 0.2,
            "max_tokens": 900,
            "messages": [
                {"role": "system", "content": self.system_prompt},
                {
                    "role": "user",
                    "content": (
                        "当前游戏观察：\n"
                        + json.dumps(
                            model_snapshot,
                            ensure_ascii=False,
                            separators=(",", ":"),
                        )
                        + "\n\n当前已锁定意图：\n"
                        + json.dumps(
                            current_intent, ensure_ascii=False, separators=(",", ":")
                        )
                        + "\n\n用户最新指令：\n"
                        + (user_instruction or "无，当前只需处理重大事件")
                        + "\n\n本轮触发原因：\n"
                        + trigger
                        + "\n\n可能相关的长期记忆：\n"
                        + (memory_context or "无")
                        + "\n\n伴侣独立技能记忆（不是用户个人记忆）：\n"
                        + (skill_context or "无")
                        + "\n\n当前多步骤计划：\n"
                        + json.dumps(
                            active_plan or {},
                            ensure_ascii=False,
                            separators=(",", ":"),
                        )
                        + "\n\n伴侣独立聊天室最近对话：\n"
                        + json.dumps(
                            recent_chat,
                            ensure_ascii=False,
                            separators=(",", ":"),
                        )
                        + "\n\n伴侣记录过的当前世界资源与容器位置：\n"
                        + json.dumps(
                            world_context,
                            ensure_ascii=False,
                            separators=(",", ":"),
                        )
                        + "\n\n只返回一个 JSON 意图对象"
                    ),
                },
            ],
        }
        request = Request(
            self._endpoint(),
            data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            method="POST",
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                body = json.loads(response.read().decode("utf-8"))
        except HTTPError as exc:
            detail = exc.read(200).decode("utf-8", "replace")
            raise DeepSeekError(
                f"DeepSeek HTTP {exc.code}: {detail or exc.reason}"
            ) from exc
        except (URLError, TimeoutError, json.JSONDecodeError) as exc:
            raise DeepSeekError(f"DeepSeek request failed: {exc}") from exc

        try:
            content = body["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise DeepSeekError("DeepSeek response did not contain message content") from exc
        return self._extract_json(content)
