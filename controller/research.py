from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any


class ResearchError(RuntimeError):
    pass


class CodexResearchService:
    """Runs a constrained, read-only Codex research session."""

    def __init__(self, project_root: Path, timeout: float = 90.0) -> None:
        self.project_root = project_root
        self.timeout = timeout

    @staticmethod
    def _executable() -> str | None:
        return shutil.which("codex.cmd") or shutil.which("codex")

    def research(self, query: str, context: str = "") -> dict[str, Any]:
        query = query.strip()
        if not query:
            raise ResearchError("research query must not be empty")
        executable = self._executable()
        if executable is None:
            raise ResearchError("Codex CLI is not available")
        if os.name == "nt" and executable.lower().endswith(".cmd"):
            command_prefix = [
                os.environ.get("COMSPEC", "cmd.exe"),
                "/d",
                "/s",
                "/c",
                executable,
            ]
        else:
            command_prefix = [executable]

        prompt = (
            "你是《饥荒联机版》伴侣的资料研究员。只做只读资料查询，不修改任何文件，"
            "不执行游戏，不调用本地控制器。优先查官方或可靠攻略，并交叉核对。"
            "只输出 JSON，结构为："
            '{"topic":"", "summary":"", "steps":[], "ingredients":'
            '[{"prefab":"","amount":0}], "station":"", "dangers":[], '
            '"sources":[{"title":"","url":""}]}。'
            "如果没有可靠资料，明确写 summary 为未找到可靠资料，不要编造。\n\n"
            f"研究问题：{query}\n"
            f"当前游戏上下文：{context[:4000]}"
        )
        with tempfile.TemporaryDirectory(prefix="codex_companion_research_") as tmp:
            output_path = Path(tmp) / "research.json"
            creationflags = (
                subprocess.CREATE_NO_WINDOW
                if os.name == "nt" and hasattr(subprocess, "CREATE_NO_WINDOW")
                else 0
            )
            command = command_prefix + [
                "exec",
                "--ephemeral",
                "--skip-git-repo-check",
                "--sandbox",
                "read-only",
                "-C",
                str(self.project_root),
                "-o",
                str(output_path),
                "-",
            ]
            try:
                completed = subprocess.run(
                    command,
                    cwd=self.project_root,
                    input=prompt,
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    timeout=self.timeout,
                    check=False,
                    creationflags=creationflags,
                )
            except (OSError, subprocess.TimeoutExpired) as exc:
                raise ResearchError(f"Codex research failed: {exc}") from exc
            if completed.returncode != 0:
                detail = (completed.stderr or completed.stdout).strip()[-1000:]
                raise ResearchError(
                    f"Codex research exited with {completed.returncode}: {detail}"
                )
            if not output_path.exists():
                raise ResearchError("Codex research did not return an output file")
            raw = output_path.read_text(encoding="utf-8").strip()

        if raw.startswith("```"):
            raw = raw.strip("`")
            if raw.startswith("json"):
                raw = raw[4:].lstrip()
        try:
            result = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ResearchError("Codex research output was not valid JSON") from exc
        if not isinstance(result, dict):
            raise ResearchError("Codex research output must be a JSON object")
        return result

    @staticmethod
    def render_skill_note(result: dict[str, Any]) -> str:
        lines = [str(result.get("summary") or "").strip()]
        steps = result.get("steps") or []
        if isinstance(steps, list) and steps:
            lines.append("步骤：" + "；".join(str(step) for step in steps))
        ingredients = result.get("ingredients") or []
        if isinstance(ingredients, list) and ingredients:
            parts = []
            for ingredient in ingredients:
                if isinstance(ingredient, dict):
                    parts.append(
                        f"{ingredient.get('prefab', '?')} x"
                        f"{ingredient.get('amount', 0)}"
                    )
            if parts:
                lines.append("材料：" + "，".join(parts))
        station = str(result.get("station") or "").strip()
        if station:
            lines.append(f"制作站/地点：{station}")
        dangers = result.get("dangers") or []
        if isinstance(dangers, list) and dangers:
            lines.append("风险：" + "；".join(str(item) for item in dangers))
        sources = result.get("sources") or []
        if isinstance(sources, list) and sources:
            source_lines = []
            for source in sources:
                if isinstance(source, dict):
                    source_lines.append(
                        f"{source.get('title', '')} {source.get('url', '')}".strip()
                    )
            if source_lines:
                lines.append("来源：" + "；".join(source_lines))
        return "\n".join(line for line in lines if line)
