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
                CREATE TABLE IF NOT EXISTS scheduled_tasks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    kind TEXT NOT NULL,
                    goal TEXT NOT NULL,
                    status TEXT NOT NULL,
                    due_day INTEGER,
                    due_phase TEXT,
                    due_moon_phase TEXT,
                    shard TEXT,
                    x REAL,
                    z REAL,
                    details_json TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    last_triggered_at REAL
                )
                """
            )
            self._sqlite.execute(
                """
                CREATE TABLE IF NOT EXISTS chat_summaries (
                    room TEXT PRIMARY KEY,
                    summary TEXT NOT NULL,
                    summarized_through_id INTEGER NOT NULL DEFAULT 0,
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
            self._sqlite.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_scheduled_status
                ON scheduled_tasks(status, updated_at)
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
        self._compact_chat_if_needed(room)

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

    @staticmethod
    def _compact_chat_text(text: str, max_chars: int = 220) -> str:
        compact = re.sub(r"\s+", " ", text).strip()
        if len(compact) <= max_chars:
            return compact
        return compact[: max_chars - 1].rstrip() + "…"

    @staticmethod
    def _clip_chat_summary(summary: str, max_chars: int) -> str:
        if len(summary) <= max_chars:
            return summary
        prefix = "[更早摘要已折叠]\n"
        if max_chars <= len(prefix):
            return prefix[:max_chars]
        return prefix + summary[-(max_chars - len(prefix)) :].lstrip()

    def _compact_chat_if_needed(
        self,
        room: str,
        *,
        keep_recent: int = 10,
        trigger_messages: int = 12,
        max_unsummarized_chars: int = 6000,
        max_summary_chars: int = 2500,
    ) -> bool:
        """Fold older completed chat into a bounded result summary.

        Raw messages remain in chat_messages. Only the model-visible summary is
        compacted, so exact chat history can still be inspected or recovered.
        """
        with self._lock:
            summary_row = self._sqlite.execute(
                """
                SELECT summary, summarized_through_id
                FROM chat_summaries
                WHERE room = ?
                """,
                (room,),
            ).fetchone()
            summarized_through_id = (
                int(summary_row["summarized_through_id"]) if summary_row else 0
            )
            rows = self._sqlite.execute(
                """
                SELECT id, role, text
                FROM chat_messages
                WHERE room = ? AND id > ?
                ORDER BY id ASC
                """,
                (room, summarized_through_id),
            ).fetchall()

        if len(rows) <= keep_recent:
            return False
        candidates = rows[:-keep_recent]
        candidate_chars = sum(len(str(row["text"])) for row in candidates)
        if (
            len(candidates) < trigger_messages
            and candidate_chars < max_unsummarized_chars
        ):
            return False

        compact_lines = ["[较早已完成对话摘要]"]
        for row in candidates:
            role = "用户" if row["role"] == "user" else "微光"
            compact_lines.append(
                f"- {role}: {self._compact_chat_text(str(row['text']))}"
            )
        new_summary = "\n".join(compact_lines)
        existing = str(summary_row["summary"]) if summary_row else ""
        combined = "\n".join(
            part for part in (existing.strip(), new_summary) if part
        )
        combined = self._clip_chat_summary(combined, max_summary_chars)

        with self._lock, self._sqlite:
            self._sqlite.execute(
                """
                INSERT INTO chat_summaries(
                    room, summary, summarized_through_id, updated_at
                )
                VALUES (?, ?, ?, ?)
                ON CONFLICT(room) DO UPDATE SET
                    summary = excluded.summary,
                    summarized_through_id = excluded.summarized_through_id,
                    updated_at = excluded.updated_at
                """,
                (
                    room,
                    combined,
                    int(candidates[-1]["id"]),
                    time.time(),
                ),
            )
        return True

    def chat_context(
        self,
        room: str = "chat",
        *,
        recent_limit: int = 10,
        max_recent_chars: int = 6000,
        max_summary_chars: int = 2500,
    ) -> dict[str, Any]:
        """Return the bounded model-visible chat context.

        The complete transcript stays in chat_messages. This method is the only
        chat view intended for model prompts: an older-result summary plus the
        newest messages under a hard character budget.
        """
        self._compact_chat_if_needed(
            room,
            keep_recent=recent_limit,
            trigger_messages=1,
            max_unsummarized_chars=0,
            max_summary_chars=max_summary_chars,
        )
        with self._lock:
            summary_row = self._sqlite.execute(
                """
                SELECT summary, summarized_through_id
                FROM chat_summaries
                WHERE room = ?
                """,
                (room,),
            ).fetchone()
            rows = self._sqlite.execute(
                """
                SELECT id, role, text, created_at
                FROM chat_messages
                WHERE room = ? AND id > ?
                ORDER BY id DESC
                LIMIT ?
                """,
                (
                    room,
                    int(summary_row["summarized_through_id"]) if summary_row else 0,
                    recent_limit,
                ),
            ).fetchall()
            raw_count = int(
                self._sqlite.execute(
                    "SELECT COUNT(*) FROM chat_messages WHERE room = ?",
                    (room,),
                ).fetchone()[0]
            )

        selected: list[dict[str, Any]] = []
        used = 0
        for row in rows:
            text = str(row["text"])
            remaining = max_recent_chars - used
            if remaining <= 0:
                break
            if len(text) > remaining:
                if remaining < 24:
                    break
                text = "[前文截断] " + text[-(remaining - len("[前文截断] ")) :]
            selected.append(
                {
                    "role": row["role"],
                    "text": text,
                    "created_at": row["created_at"],
                }
            )
            used += len(text)
        selected.reverse()

        summary = self._clip_chat_summary(
            str(summary_row["summary"]) if summary_row else "",
            max_summary_chars,
        )

        return {
            "summary": summary,
            "summarized_through_id": (
                int(summary_row["summarized_through_id"]) if summary_row else 0
            ),
            "recent": selected,
            "raw_count": raw_count,
        }

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

    def save_scheduled_task(
        self,
        *,
        kind: str,
        goal: str,
        due_day: int | None = None,
        due_phase: str | None = None,
        due_moon_phase: str | None = None,
        shard: str | None = None,
        x: float | None = None,
        z: float | None = None,
        details: dict[str, Any] | None = None,
        status: str = "active",
    ) -> int:
        kind = kind.strip()
        goal = goal.strip()
        if not kind or not goal:
            raise ValueError("schedule kind and goal must not be empty")
        now = time.time()
        with self._lock, self._sqlite:
            current = self._sqlite.execute(
                """
                SELECT id
                FROM scheduled_tasks
                WHERE status = 'active' AND kind = ? AND goal = ?
                ORDER BY id DESC
                LIMIT 1
                """,
                (kind, goal),
            ).fetchone()
            values = (
                due_day,
                due_phase,
                due_moon_phase,
                shard,
                x,
                z,
                json.dumps(
                    details or {},
                    ensure_ascii=False,
                    separators=(",", ":"),
                ),
                status,
                now,
            )
            if current is not None:
                self._sqlite.execute(
                    """
                    UPDATE scheduled_tasks
                    SET due_day = ?,
                        due_phase = ?,
                        due_moon_phase = ?,
                        shard = ?,
                        x = ?,
                        z = ?,
                        details_json = ?,
                        status = ?,
                        updated_at = ?
                    WHERE id = ?
                    """,
                    values + (int(current["id"]),),
                )
                return int(current["id"])
            cursor = self._sqlite.execute(
                """
                INSERT INTO scheduled_tasks(
                    due_day, due_phase, due_moon_phase, shard, x, z,
                    details_json, status, updated_at, kind, goal, created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                values + (kind, goal, now),
            )
            return int(cursor.lastrowid)

    def scheduled_tasks(
        self,
        *,
        status: str = "active",
        limit: int = 30,
    ) -> list[dict[str, Any]]:
        with self._lock:
            rows = self._sqlite.execute(
                """
                SELECT id, kind, goal, status, due_day, due_phase,
                       due_moon_phase, shard, x, z, details_json,
                       created_at, updated_at, last_triggered_at
                FROM scheduled_tasks
                WHERE status = ?
                ORDER BY COALESCE(due_day, 2147483647), id
                LIMIT ?
                """,
                (status, limit),
            ).fetchall()
        result = []
        for row in rows:
            task = dict(row)
            task["details"] = json.loads(task.pop("details_json") or "{}")
            result.append(task)
        return result

    def due_scheduled_tasks(
        self,
        *,
        day: int | None,
        phase: str | None,
        moon_phase: str | None,
        shard: str | None,
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        result = []
        for task in self.scheduled_tasks(limit=limit * 2):
            if (
                task.get("due_day") is not None
                and (day is None or int(task["due_day"]) > int(day))
            ):
                continue
            if (
                task.get("due_phase")
                and str(task["due_phase"]).lower()
                != str(phase or "").lower()
            ):
                continue
            if (
                task.get("due_moon_phase")
                and str(task["due_moon_phase"]).lower()
                != str(moon_phase or "").lower()
            ):
                continue
            if task.get("shard") and task["shard"] != shard:
                continue
            result.append(task)
            if len(result) >= limit:
                break
        return result

    def update_scheduled_task(
        self,
        task_id: int | None,
        *,
        status: str | None = None,
        shard: str | None = None,
        x: float | None = None,
        z: float | None = None,
        details: dict[str, Any] | None = None,
        mark_triggered: bool = False,
    ) -> None:
        assignments = ["updated_at = ?"]
        params: list[Any] = [time.time()]
        if status is not None:
            assignments.append("status = ?")
            params.append(status)
        if shard is not None:
            assignments.append("shard = ?")
            params.append(shard)
        if x is not None:
            assignments.append("x = ?")
            params.append(float(x))
        if z is not None:
            assignments.append("z = ?")
            params.append(float(z))
        if details is not None:
            assignments.append("details_json = ?")
            params.append(
                json.dumps(
                    details,
                    ensure_ascii=False,
                    separators=(",", ":"),
                )
            )
        if mark_triggered:
            assignments.append("last_triggered_at = ?")
            params.append(time.time())
        params.append(task_id)
        with self._lock, self._sqlite:
            self._sqlite.execute(
                f"""
                UPDATE scheduled_tasks
                SET {", ".join(assignments)}
                WHERE id = ?
                """,
                params,
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
