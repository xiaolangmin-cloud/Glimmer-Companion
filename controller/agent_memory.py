from __future__ import annotations

import json
import re
import sqlite3
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class SkillHit:
    topic: str
    summary: str
    content: str
    source: str
    updated_at: float


@dataclass(frozen=True)
class ImplementationHit:
    topic: str
    summary: str
    content: str
    tags: str
    updated_at: float


class AgentMemoryStore:
    """Dedicated companion memory isolated from the user's general vault."""

    def __init__(self, database: Path) -> None:
        self.database = database
        self.database.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()
        self._sqlite = sqlite3.connect(self.database, check_same_thread=False)
        self._sqlite.row_factory = sqlite3.Row
        self._create_schema()

    def _create_schema(self) -> None:
        with self._sqlite:
            self._sqlite.execute(
                """
                CREATE TABLE IF NOT EXISTS skill_notes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    topic TEXT NOT NULL,
                    summary TEXT NOT NULL,
                    content TEXT NOT NULL,
                    source TEXT NOT NULL,
                    confidence REAL NOT NULL DEFAULT 0.5,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    UNIQUE(topic, source)
                )
                """
            )
            self._sqlite.execute(
                """
                CREATE TABLE IF NOT EXISTS chat_messages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    room TEXT NOT NULL,
                    role TEXT NOT NULL,
                    text TEXT NOT NULL,
                    created_at REAL NOT NULL
                )
                """
            )
            self._sqlite.execute(
                """
                CREATE TABLE IF NOT EXISTS task_plans (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    goal TEXT NOT NULL,
                    status TEXT NOT NULL,
                    plan_json TEXT NOT NULL,
                    updated_at REAL NOT NULL
                )
                """
            )
            self._sqlite.execute(
                """
                CREATE TABLE IF NOT EXISTS world_notes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    shard TEXT NOT NULL,
                    prefab TEXT NOT NULL,
                    category TEXT NOT NULL,
                    x REAL NOT NULL,
                    z REAL NOT NULL,
                    details_json TEXT NOT NULL,
                    updated_at REAL NOT NULL,
                    UNIQUE(shard, prefab, x, z)
                )
                """
            )
            self._sqlite.execute(
                """
                CREATE TABLE IF NOT EXISTS capability_gaps (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    feature TEXT NOT NULL,
                    request_text TEXT NOT NULL,
                    missing_capability TEXT NOT NULL,
                    suggested_implementation TEXT NOT NULL,
                    status TEXT NOT NULL,
                    created_at REAL NOT NULL
                )
                """
            )
            self._sqlite.execute(
                """
                CREATE TABLE IF NOT EXISTS implementation_notes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    topic TEXT NOT NULL,
                    summary TEXT NOT NULL,
                    content TEXT NOT NULL,
                    tags TEXT NOT NULL,
                    source TEXT NOT NULL,
                    confidence REAL NOT NULL DEFAULT 0.9,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    UNIQUE(topic, source)
                )
                """
            )
            self._sqlite.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_skill_topic
                ON skill_notes(topic)
                """
            )
            self._sqlite.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_chat_room_time
                ON chat_messages(room, created_at)
                """
            )
            self._sqlite.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_world_shard_prefab
                ON world_notes(shard, prefab, updated_at)
                """
            )
            self._sqlite.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_implementation_topic
                ON implementation_notes(topic, updated_at)
                """
            )

    def close(self) -> None:
        with self._lock:
            self._sqlite.close()

    def remember_skill(
        self,
        topic: str,
        content: str,
        *,
        summary: str = "",
        source: str = "deepseek",
        confidence: float = 0.5,
    ) -> None:
        topic = topic.strip()
        content = content.strip()
        if not topic or not content:
            raise ValueError("skill topic and content must not be empty")
        now = time.time()
        summary = summary.strip() or content.splitlines()[0][:180]
        with self._lock, self._sqlite:
            self._sqlite.execute(
                """
                INSERT INTO skill_notes(
                    topic, summary, content, source, confidence,
                    created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(topic, source) DO UPDATE SET
                    summary=excluded.summary,
                    content=excluded.content,
                    confidence=excluded.confidence,
                    updated_at=excluded.updated_at
                """,
                (
                    topic,
                    summary,
                    content,
                    source,
                    max(0.0, min(float(confidence), 1.0)),
                    now,
                    now,
                ),
            )

    def search_skills(self, query: str, limit: int = 8) -> list[SkillHit]:
        query = " ".join(query.split())
        if not query:
            return []
        terms = [
            term
            for term in re.findall(r"[0-9A-Za-z_]+|[\u3400-\u9fff]{2,}", query)
            if term
        ]
        if not terms:
            terms = [query]
        clauses = " OR ".join(
            "(topic LIKE ? OR summary LIKE ? OR content LIKE ?)" for _ in terms
        )
        params: list[Any] = []
        for term in terms:
            pattern = f"%{term}%"
            params.extend((pattern, pattern, pattern))
        params.append(limit)
        with self._lock:
            rows = self._sqlite.execute(
                f"""
                SELECT topic, summary, content, source, updated_at
                FROM skill_notes
                WHERE {clauses}
                ORDER BY confidence DESC, updated_at DESC
                LIMIT ?
                """,
                params,
            ).fetchall()
        return [
            SkillHit(
                topic=row["topic"],
                summary=row["summary"],
                content=row["content"],
                source=row["source"],
                updated_at=row["updated_at"],
            )
            for row in rows
        ]

    def render_skill_context(self, query: str, limit: int = 8) -> str:
        hits = self.search_skills(query, limit)
        return "\n\n".join(
            f"[技能记忆] {hit.topic}（来源 {hit.source}）\n{hit.content}"
            for hit in hits
        )

    def remember_implementation_note(
        self,
        topic: str,
        summary: str,
        content: str,
        *,
        tags: str = "",
        source: str = "project",
        confidence: float = 0.9,
    ) -> None:
        topic = topic.strip()
        summary = summary.strip()
        content = content.strip()
        if not topic or not content:
            raise ValueError(
                "implementation topic and content must not be empty"
            )
        now = time.time()
        with self._lock, self._sqlite:
            self._sqlite.execute(
                """
                INSERT INTO implementation_notes(
                    topic, summary, content, tags, source, confidence,
                    created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(topic, source) DO UPDATE SET
                    summary=excluded.summary,
                    content=excluded.content,
                    tags=excluded.tags,
                    confidence=excluded.confidence,
                    updated_at=excluded.updated_at
                """,
                (
                    topic,
                    summary,
                    content,
                    tags.strip(),
                    source,
                    max(0.0, min(float(confidence), 1.0)),
                    now,
                    now,
                ),
            )

    def seed_implementation_notes(
        self,
        notes: tuple[dict[str, str], ...],
    ) -> None:
        for note in notes:
            self.remember_implementation_note(
                note["topic"],
                note.get("summary", ""),
                note["content"],
                tags=note.get("tags", ""),
                source="glimmer-project",
                confidence=0.95,
            )

    @staticmethod
    def _implementation_terms(query: str) -> list[str]:
        lowered = query.lower()
        markers = (
            "mod",
            "微光",
            "控制器",
            "启动桥",
            "快捷方式",
            "实现",
            "能力",
            "功能",
            "动作",
            "程序",
            "代码",
            "支持",
            "能不能",
            "能否",
            "选人",
            "角色切换",
        )
        if not any(marker in lowered for marker in markers):
            return []
        terms: list[str] = []

        def add(term: str) -> None:
            term = term.strip()
            if term and term not in terms:
                terms.append(term)

        for term in re.findall(r"[0-9A-Za-z_]+", lowered):
            if len(term) >= 2:
                add(term)
        for sequence in re.findall(r"[\u3400-\u9fff]+", lowered):
            add(sequence)
            for width in (2, 3, 4):
                if len(sequence) < width:
                    continue
                for index in range(len(sequence) - width + 1):
                    add(sequence[index : index + width])
            if len(terms) >= 36:
                break
        return terms[:36]

    def search_implementation_notes(
        self,
        query: str,
        limit: int = 4,
    ) -> list[ImplementationHit]:
        terms = self._implementation_terms(query)
        if not terms:
            return []
        clauses = " OR ".join(
            "(topic LIKE ? OR summary LIKE ? OR content LIKE ? OR tags LIKE ?)"
            for _ in terms
        )
        params: list[Any] = []
        for term in terms:
            pattern = f"%{term}%"
            params.extend((pattern, pattern, pattern, pattern))
        params.append(max(limit * 12, 24))
        with self._lock:
            rows = self._sqlite.execute(
                f"""
                SELECT topic, summary, content, tags, updated_at
                FROM implementation_notes
                WHERE {clauses}
                ORDER BY confidence DESC, updated_at DESC
                LIMIT ?
                """,
                params,
            ).fetchall()
        ranked = sorted(
            rows,
            key=lambda row: (
                sum(
                    row["topic"].count(term) * 8
                    + row["tags"].count(term) * 4
                    + row["summary"].count(term) * 3
                    + row["content"].count(term)
                    for term in terms
                ),
                row["updated_at"],
            ),
            reverse=True,
        )[:limit]
        return [
            ImplementationHit(
                topic=row["topic"],
                summary=row["summary"],
                content=row["content"],
                tags=row["tags"],
                updated_at=row["updated_at"],
            )
            for row in ranked
        ]

    def render_implementation_context(
        self,
        query: str,
        limit: int = 2,
        max_chars: int = 1600,
    ) -> str:
        hits = self.search_implementation_notes(query, limit)
        chunks: list[str] = []
        used = 0
        for hit in hits:
            header = f"[Mod实现记忆] {hit.topic}\n"
            body = hit.summary
            if hit.summary and not hit.content.startswith(hit.summary):
                body += "\n" + hit.content
            else:
                body = hit.content
            remaining = max_chars - used
            if remaining <= len(header):
                break
            chunk = header + body[: max(0, remaining - len(header))]
            chunks.append(chunk.rstrip())
            used += len(chunk)
        return "\n\n".join(chunks)

    def record_chat(self, room: str, role: str, text: str) -> None:
        with self._lock, self._sqlite:
            self._sqlite.execute(
                """
                INSERT INTO chat_messages(room, role, text, created_at)
                VALUES (?, ?, ?, ?)
                """,
                (room, role, text, time.time()),
            )

    def recent_chat(self, room: str = "chat", limit: int = 12) -> list[dict[str, Any]]:
        with self._lock:
            rows = self._sqlite.execute(
                """
                SELECT role, text, created_at
                FROM chat_messages
                WHERE room = ?
                ORDER BY id DESC
                LIMIT ?
                """,
                (room, limit),
            ).fetchall()
        return [
            {
                "role": row["role"],
                "text": row["text"],
                "created_at": row["created_at"],
            }
            for row in reversed(rows)
        ]

    def remember_world_point(
        self,
        *,
        shard: str,
        prefab: str,
        category: str,
        x: float,
        z: float,
        details: dict[str, Any] | None = None,
    ) -> None:
        if not shard or not prefab:
            return
        with self._lock, self._sqlite:
            self._sqlite.execute(
                """
                INSERT INTO world_notes(
                    shard, prefab, category, x, z, details_json, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(shard, prefab, x, z) DO UPDATE SET
                    category=excluded.category,
                    details_json=excluded.details_json,
                    updated_at=excluded.updated_at
                """,
                (
                    shard,
                    prefab,
                    category,
                    float(x),
                    float(z),
                    json.dumps(
                        details or {},
                        ensure_ascii=False,
                        separators=(",", ":"),
                    ),
                    time.time(),
                ),
            )

    def world_context(
        self,
        shard: str,
        query: str = "",
        limit: int = 30,
    ) -> list[dict[str, Any]]:
        terms = [
            term
            for term in re.findall(r"[0-9A-Za-z_]+|[\u3400-\u9fff]{2,}", query)
            if term
        ]
        where = "shard = ?"
        params: list[Any] = [shard]
        if terms:
            where += " AND (" + " OR ".join(
                "(prefab LIKE ? OR category LIKE ? OR details_json LIKE ?)"
                for _ in terms
            ) + ")"
            for term in terms:
                pattern = f"%{term}%"
                params.extend((pattern, pattern, pattern))
        params.append(limit)
        with self._lock:
            rows = self._sqlite.execute(
                f"""
                SELECT prefab, category, x, z, details_json, updated_at
                FROM world_notes
                WHERE {where}
                ORDER BY updated_at DESC
                LIMIT ?
                """,
                params,
            ).fetchall()
        return [
            {
                "prefab": row["prefab"],
                "category": row["category"],
                "x": row["x"],
                "z": row["z"],
                "details": json.loads(row["details_json"]),
                "updated_at": row["updated_at"],
            }
            for row in rows
        ]

    def save_plan(self, goal: str, plan: dict[str, Any]) -> None:
        now = time.time()
        status = str(plan.get("status") or "active")
        with self._lock, self._sqlite:
            self._sqlite.execute(
                """
                UPDATE task_plans
                SET status = 'superseded', updated_at = ?
                WHERE status = 'active' AND goal = ?
                """,
                (now, goal),
            )
            self._sqlite.execute(
                """
                INSERT INTO task_plans(goal, status, plan_json, updated_at)
                VALUES (?, ?, ?, ?)
                """,
                (
                    goal,
                    status,
                    json.dumps(plan, ensure_ascii=False, separators=(",", ":")),
                    now,
                ),
            )

    def active_plan(self) -> dict[str, Any] | None:
        with self._lock:
            row = self._sqlite.execute(
                """
                SELECT goal, plan_json, updated_at
                FROM task_plans
                WHERE status = 'active'
                ORDER BY id DESC
                LIMIT 1
                """
            ).fetchone()
        if row is None:
            return None
        plan = json.loads(row["plan_json"])
        plan["goal"] = row["goal"]
        plan["updated_at"] = row["updated_at"]
        return plan

    def close_active_plan(self, goal: str, status: str = "completed") -> None:
        with self._lock, self._sqlite:
            self._sqlite.execute(
                """
                UPDATE task_plans
                SET status = ?, updated_at = ?
                WHERE status = 'active' AND goal = ?
                """,
                (status, time.time(), goal),
            )

    def record_capability_gap(
        self,
        *,
        feature: str,
        request_text: str,
        missing_capability: str,
        suggested_implementation: str,
    ) -> int:
        with self._lock, self._sqlite:
            cursor = self._sqlite.execute(
                """
                INSERT INTO capability_gaps(
                    feature, request_text, missing_capability,
                    suggested_implementation, status, created_at
                )
                VALUES (?, ?, ?, ?, 'open', ?)
                """,
                (
                    feature,
                    request_text,
                    missing_capability,
                    suggested_implementation,
                    time.time(),
                ),
            )
            return int(cursor.lastrowid)

    def open_capability_gaps(self, limit: int = 50) -> list[dict[str, Any]]:
        with self._lock:
            rows = self._sqlite.execute(
                """
                SELECT id, feature, request_text, missing_capability,
                       suggested_implementation, created_at
                FROM capability_gaps
                WHERE status = 'open'
                ORDER BY id DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        return [dict(row) for row in rows]
