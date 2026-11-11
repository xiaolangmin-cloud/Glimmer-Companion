from __future__ import annotations

import sqlite3
import re
import threading
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class MemoryHit:
    path: str
    title: str
    section: str
    snippet: str


class MemoryStore:
    """Read-only index over the user's Markdown memory vault."""

    def __init__(self, vault: Path, index_db: Path) -> None:
        self.vault = vault
        self.index_db = index_db
        self.index_db.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()
        self._sqlite = sqlite3.connect(self.index_db, check_same_thread=False)
        self._sqlite.row_factory = sqlite3.Row
        self._fts_enabled = self._create_schema()
        self.refresh()

    def _create_schema(self) -> bool:
        self._sqlite.execute(
            """
            CREATE TABLE IF NOT EXISTS documents (
                path TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                section TEXT NOT NULL,
                body TEXT NOT NULL,
                mtime_ns INTEGER NOT NULL
            )
            """
        )
        try:
            self._sqlite.execute(
                """
                CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
                    path UNINDEXED,
                    title,
                    section UNINDEXED,
                    body,
                    tokenize='trigram'
                )
                """
            )
            self._sqlite.commit()
            return True
        except sqlite3.OperationalError:
            self._sqlite.commit()
            return False

    def close(self) -> None:
        with self._lock:
            self._sqlite.close()

    @staticmethod
    def _split_title(path: Path, text: str) -> str:
        for line in text.splitlines():
            stripped = line.strip()
            if stripped.startswith("title:"):
                return stripped.split(":", 1)[1].strip().strip("\"'")
        return path.stem

    def refresh(self) -> int:
        with self._lock:
            if not self.vault.exists():
                return 0

            files = sorted(self.vault.rglob("*.md"))
            changed = 0
            with self._sqlite:
                # The vault is small enough to rebuild atomically. This also keeps
                # derived fields such as the index section correct after upgrades.
                self._sqlite.execute("DELETE FROM documents")
                if self._fts_enabled:
                    self._sqlite.execute("DELETE FROM documents_fts")
                for path in files:
                    stat = path.stat()
                    relative = path.relative_to(self.vault).as_posix()

                    try:
                        text = path.read_text(encoding="utf-8")
                    except UnicodeDecodeError:
                        text = path.read_text(encoding="utf-8-sig")

                    title = self._split_title(path, text)
                    section = path.parent.relative_to(self.vault).as_posix()
                    self._sqlite.execute(
                        """
                        INSERT INTO documents(path, title, section, body, mtime_ns)
                        VALUES (?, ?, ?, ?, ?)
                        ON CONFLICT(path) DO UPDATE SET
                            title=excluded.title,
                            section=excluded.section,
                            body=excluded.body,
                            mtime_ns=excluded.mtime_ns
                        """,
                        (relative, title, section, text, stat.st_mtime_ns),
                    )
                    if self._fts_enabled:
                        self._sqlite.execute(
                            "DELETE FROM documents_fts WHERE path = ?", (relative,)
                        )
                        self._sqlite.execute(
                            """
                            INSERT INTO documents_fts(path, title, section, body)
                            VALUES (?, ?, ?, ?)
                            """,
                            (relative, title, section, text),
                        )
                    changed += 1
            return changed

    def search(self, query: str, limit: int = 6) -> list[MemoryHit]:
        with self._lock:
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
                "(title LIKE ? OR body LIKE ?)" for _ in terms
            )
            params: list[str] = []
            for term in terms:
                pattern = f"%{term}%"
                params.extend((pattern, pattern))
            params.append(str(limit * 4))
            rows = self._sqlite.execute(
                f"""
                SELECT path, title, section, body, substr(body, 1, 320) AS snippet
                FROM documents
                WHERE {clauses}
                ORDER BY CASE WHEN section = 'index' THEN 0 ELSE 1 END, path
                LIMIT ?
                """,
                params,
            ).fetchall()

            def score(row: sqlite3.Row) -> tuple[int, int]:
                title_hits = sum(row["title"].count(term) for term in terms)
                body_hits = sum(row["body"].count(term) for term in terms)
                section_priority = 0 if row["section"] == "index" else 1
                return (section_priority, -(title_hits * 10 + body_hits))

            rows = sorted(rows, key=score)[:limit]

            return [
                MemoryHit(
                    path=row["path"],
                    title=row["title"],
                    section=row["section"],
                    snippet=row["snippet"],
                )
                for row in rows
            ]

    def render_context(self, query: str, limit: int = 6) -> str:
        hits = self.search(query, limit)
        if not hits:
            return ""
        chunks = []
        for hit in hits:
            chunks.append(
                f"[{hit.section}] {hit.title} ({hit.path})\n{hit.snippet}"
            )
        return "\n\n".join(chunks)
