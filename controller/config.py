from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent


@dataclass(frozen=True)
class Settings:
    host: str
    port: int
    deepseek_api_key: str | None
    deepseek_base_url: str
    deepseek_model: str
    memory_vault: Path
    memory_index_db: Path
    prompt_path: Path
    decision_interval: float
    replan_interval: float
    ambient_chat_min_seconds: float
    ambient_chat_max_seconds: float
    request_timeout: float
    default_lease_seconds: float
    agent_memory_db: Path | None = None
    playbook_dir: Path | None = None
    companion_character: str = "waxwell"

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            host=os.getenv("CODEX_COMPANION_HOST", "127.0.0.1"),
            port=int(os.getenv("CODEX_COMPANION_PORT", "8765")),
            deepseek_api_key=os.getenv("DEEPSEEK_API_KEY"),
            deepseek_base_url=os.getenv(
                "DEEPSEEK_BASE_URL", "https://api.deepseek.com"
            ).rstrip("/"),
            deepseek_model=os.getenv("DEEPSEEK_MODEL", "deepseek-chat"),
            memory_vault=Path(
                os.getenv(
                    "CODEX_COMPANION_MEMORY_VAULT",
                    str(Path.home() / ".dsh" / "memory" / "vault"),
                )
            ),
            memory_index_db=Path(
                os.getenv(
                    "CODEX_COMPANION_MEMORY_INDEX",
                    str(PROJECT_ROOT / "state" / "memory_index.sqlite3"),
                )
            ),
            prompt_path=Path(
                os.getenv(
                    "CODEX_COMPANION_PROMPT",
                    str(PROJECT_ROOT / "config" / "companion_prompt.md"),
                )
            ),
            decision_interval=float(
                os.getenv("CODEX_COMPANION_DECISION_INTERVAL", "1.5")
            ),
            replan_interval=float(
                os.getenv("CODEX_COMPANION_REPLAN_INTERVAL", "0")
            ),
            ambient_chat_min_seconds=float(
                os.getenv("CODEX_COMPANION_CHAT_MIN_SECONDS", "300")
            ),
            ambient_chat_max_seconds=float(
                os.getenv("CODEX_COMPANION_CHAT_MAX_SECONDS", "720")
            ),
            request_timeout=float(
                os.getenv("CODEX_COMPANION_REQUEST_TIMEOUT", "20")
            ),
            default_lease_seconds=float(
                os.getenv("CODEX_COMPANION_LEASE_SECONDS", "5")
            ),
            agent_memory_db=Path(
                os.getenv(
                    "CODEX_COMPANION_AGENT_MEMORY",
                    str(PROJECT_ROOT / "state" / "agent_memory.sqlite3"),
                )
            ),
            playbook_dir=Path(
                os.getenv(
                    "CODEX_COMPANION_PLAYBOOKS",
                    str(PROJECT_ROOT / "config" / "playbooks"),
                )
            ),
            companion_character=os.getenv(
                "CODEX_COMPANION_CHARACTER",
                "waxwell",
            ),
        )
