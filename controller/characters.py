from __future__ import annotations

import json
import os
import threading
from pathlib import Path
from typing import Any


CHARACTER_OPTIONS: tuple[dict[str, str], ...] = (
    {"prefab": "player", "name": "与玩家相同"},
    {"prefab": "waxwell", "name": "麦斯威尔"},
    {"prefab": "walter", "name": "沃尔特"},
    {"prefab": "wendy", "name": "温蒂"},
    {"prefab": "wilson", "name": "威尔逊"},
    {"prefab": "willow", "name": "薇洛"},
    {"prefab": "wolfgang", "name": "沃尔夫冈"},
    {"prefab": "wx78", "name": "WX-78"},
    {"prefab": "wickerbottom", "name": "薇克巴顿"},
    {"prefab": "woodie", "name": "伍迪"},
    {"prefab": "wes", "name": "韦斯"},
    {"prefab": "wathgrithr", "name": "薇格弗德"},
    {"prefab": "webber", "name": "韦伯"},
    {"prefab": "warly", "name": "沃利"},
    {"prefab": "wormwood", "name": "沃姆伍德"},
    {"prefab": "winona", "name": "薇诺娜"},
    {"prefab": "wortox", "name": "沃拓克斯"},
    {"prefab": "wurt", "name": "沃特"},
    {"prefab": "wanda", "name": "旺达"},
    {"prefab": "wonkey", "name": "猴子"},
)

CHARACTER_NAMES = {
    option["prefab"]: option["name"] for option in CHARACTER_OPTIONS
}
VALID_CHARACTERS = frozenset(CHARACTER_NAMES)
DEFAULT_CHARACTER = "waxwell"


class CharacterPreferenceStore:
    def __init__(self, path: Path, default: str | None = None) -> None:
        self.path = path
        self._lock = threading.RLock()
        self._default = (
            default
            or os.getenv("CODEX_COMPANION_CHARACTER")
            or DEFAULT_CHARACTER
        )
        if self._default not in VALID_CHARACTERS:
            self._default = DEFAULT_CHARACTER
        self._selected = self._load()

    def _load(self) -> str:
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return self._default
        prefab = raw.get("prefab") if isinstance(raw, dict) else None
        return prefab if prefab in VALID_CHARACTERS else self._default

    def selected(self) -> str:
        with self._lock:
            return self._selected

    def select(self, prefab: str) -> str:
        if prefab not in VALID_CHARACTERS:
            raise ValueError(f"unsupported companion character: {prefab}")
        with self._lock:
            self._selected = prefab
            self.path.parent.mkdir(parents=True, exist_ok=True)
            temporary = self.path.with_suffix(self.path.suffix + ".tmp")
            temporary.write_text(
                json.dumps(
                    {"prefab": prefab, "name": CHARACTER_NAMES[prefab]},
                    ensure_ascii=False,
                    indent=2,
                )
                + "\n",
                encoding="utf-8",
            )
            temporary.replace(self.path)
            return self._selected

    def payload(self, active_prefab: str | None = None) -> dict[str, Any]:
        selected = self.selected()
        return {
            "prefab": selected,
            "name": CHARACTER_NAMES[selected],
            "active_prefab": active_prefab,
            "active_name": CHARACTER_NAMES.get(active_prefab or ""),
            "options": list(CHARACTER_OPTIONS),
        }


def render_character_selector(page: dict[str, Any]) -> str:
    state = json.dumps(page, ensure_ascii=False).replace("</", "<\\/")
    return f"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>微光旅伴 - 选择角色</title>
<style>
:root {{ color-scheme: dark; font-family: "Microsoft YaHei UI", sans-serif; }}
body {{ margin: 0; min-height: 100vh; background: radial-gradient(circle at 30% 10%, #28475c, #10151d 62%); color: #edf4f7; }}
main {{ width: min(920px, calc(100% - 32px)); margin: 36px auto; }}
h1 {{ margin: 0 0 8px; font-size: 30px; letter-spacing: 2px; }}
.subtitle {{ color: #aebdc7; margin-bottom: 24px; }}
.status {{ padding: 12px 16px; border-radius: 12px; background: #1d2934; border: 1px solid #354759; margin-bottom: 18px; }}
.status strong {{ color: #ffd892; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fit,minmax(150px,1fr)); gap: 12px; }}
button {{ border: 1px solid #466074; border-radius: 12px; background: #182630; color: #eaf2f5; padding: 16px 12px; font-size: 17px; cursor: pointer; transition: .15s; }}
button:hover {{ transform: translateY(-2px); border-color: #8ecae6; background: #223746; }}
button.selected {{ border-color: #ffd892; box-shadow: 0 0 0 2px #ffd89255 inset; color: #ffe6ad; }}
.warning {{ margin-top: 18px; color: #f1c88c; line-height: 1.7; }}
#message {{ min-height: 24px; margin-top: 16px; color: #9ee6b7; }}
</style>
</head>
<body>
<main>
  <h1>微光旅伴</h1>
  <div class="subtitle">选择微光使用的角色。选择会持久保存，并发送给正在运行的游戏。</div>
  <div class="status" id="status"></div>
  <div class="grid" id="grid"></div>
  <div class="warning">切换现有微光时会中断它当前的任务，并把背包和装备丢在它脚下。建议在基地或安全位置切换。</div>
  <div id="message"></div>
</main>
<script>
let state = {state};
const grid = document.getElementById('grid');
const statusNode = document.getElementById('status');
const messageNode = document.getElementById('message');
function render() {{
  const active = state.active_prefab;
  statusNode.innerHTML = `已选择：<strong>${{state.name}}</strong>` +
    (active ? `　当前游戏中的微光：<strong>${{state.active_name || active}}</strong>` : '　当前未检测到已生成的微光');
  grid.innerHTML = '';
  for (const option of state.options) {{
    const button = document.createElement('button');
    button.textContent = option.name;
    button.className = option.prefab === state.prefab ? 'selected' : '';
    button.onclick = () => choose(option);
    grid.appendChild(button);
  }}
}}
async function refresh() {{
  const response = await fetch('/companion-character');
  state = await response.json();
  render();
}}
async function choose(option) {{
  if (state.active_prefab && option.prefab !== state.prefab) {{
    const ok = confirm(`切换到“${{option.name}}”？\\n\\n当前微光会中断任务，背包和装备会掉在它脚下。`);
    if (!ok) return;
  }}
  const response = await fetch('/companion-character', {{
    method: 'POST',
    headers: {{'Content-Type': 'application/json; charset=utf-8'}},
    body: JSON.stringify({{prefab: option.prefab}})
  }});
  if (!response.ok) {{
    messageNode.textContent = '保存失败：' + (await response.text());
    return;
  }}
  state = await response.json();
  render();
  messageNode.textContent = '已保存，返回游戏后微光会切换身份。';
}}
render();
setInterval(refresh, 3000);
</script>
</body>
</html>
"""
