# Companion Intent Protocol

游戏 Mod 向 `POST http://127.0.0.1:8765/tick` 提交观察，控制器立即返回当前已锁定任务。
DeepSeek 默认不参与逐帧控制，只在用户指令或任务完成、失败、重大事件时重新规划。

用户输入入口是游戏内聊天框。每一句普通文字消息都转发到 `POST /message`，
不需要前缀；DeepSeek 根据内容判断是任务指令还是普通对话。表情、系统公告和
非玩家文字事件不会进入控制器。

控制器同时提供本机角色选择页：

```text
GET /character
GET /companion-character
POST /companion-character  {"prefab":"waxwell"}
```

选择保存在控制器独立状态中，并随每次 `/tick` 返回 `companion_character`。游戏内
执行器检测到角色变化时中断旧任务、丢下旧微光的背包与装备，再按新角色重新生成。

通过微光专用游戏启动入口启动时，只在本次游戏期间启动轻量本地桥
`127.0.0.1:8766`。玩家进入存档后，Mod 调用
`POST /start` 请求拉起完整控制器，并轮询 `GET /status`。连接开始、控制器启动中和
连接成功的状态都会发送到游戏聊天栏；只有控制器 `/health` 就绪后才会生成微光。

伴侣回复通过游戏内对话气泡显示。控制器终端只显示日志和回复，不再接受键盘输入。

用户自然语言指令发送到：

```http
POST /instruction
Content-Type: application/json

{"text":"你去把家里的作物收一下"}
```

## 防冲突规则

1. 模型是唯一任务决策源。
2. 执行器可以在任务范围内自主寻路、走位、攻击、进食、采集和选择下一个同类目标。
3. 执行器不得超出任务范围或更改任务目标。
4. 新任务更新 `intent_id`，最后一个有效任务覆盖旧任务。
5. 任务超过 `lease_seconds` 后自动回到默认 `follow`；明确 `hold` 不受影响。
6. DeepSeek 调用失败时不切换到无关的新任务，只保留旧任务直到过期。
7. 远距离移动由执行器持续寻路；20 秒没有接近目标时报告 `task_failed/path_stuck`。
8. 地面与洞穴切换时，执行器会中断旧世界的任务、携带完整伴侣存档迁移，并报告
   `task_failed/shard_transition`；控制器随后把伴侣切回 `follow`。
9. 控制器在意图写入仲裁器之前检查 `target_shard`、其他世界字段和地标所在世界。
   目标世界与当前 `world.shard` 不同，或模式本身是跨世界迁移时，控制器直接改为
   `hold/cross_world_forbidden`，记录 `controller.cross_world_blocked`，并向用户说明
   必须由用户本人带伴侣过图。该限制同样覆盖手动 `/command`。
10. 伴侣是服务端永不休眠实体，并维护自身附近行动单位的独立唤醒区域。
11. 战斗默认带致命伤保护。估算下一次受击足以致死时，执行器停止战斗、撤回玩家
    并发送 `task_failed/lethal_next_hit`。只有明确设置
    `params.fight_to_death=true` 或 `params.retreat_on_lethal=false` 才关闭。
12. 复杂目标使用持久化 `plan`。计划与技能资料、伴侣聊天、世界资源位置写入
    `state/agent_memory.sqlite3`，不写入用户整体记忆库。
13. 缺少可靠游戏知识时，模型可返回 `research_query`。控制器调用只读 Codex
    研究会话查询网络，结果写入伴侣独立技能记忆后再次规划。
14. 游戏聊天先经过本地角色任务匹配器。高置信度预案直接生成意图，不调用模型；
    复杂或部分匹配预案作为 `matched_playbooks` 提供给 DeepSeek 做小幅适配。
    当前仅启用麦斯威尔 `waxwell` 预案。
15. 模型发现执行器确实缺少能力时返回 `capability_gap`。控制器停止当前动作，
    在游戏聊天中说明原因，并把功能、缺口和建议实现写入 `capability_gaps`。
16. 远距离移动、采集和收集任务开始前及执行中检查生命与饱食度。饥饿低于阈值时
    先尝试吃背包食物；没有食物则取消任务、返回玩家并报告
    `task_failed/survival_hunger_low`。用户明确要求无视这些风险时，意图必须设置
    `params.ignore_survival_safety=true` 或 `params.survival_policy="force"`，
    控制器不得再硬性阻止任务。
17. 伴侣会把已经过的位置持续写入玩家 `MapExplorer`，因此伴侣探索的新区域会同步
    显示在玩家地图上；伴侣自身保留玩家预制体的地图头像标记。附近资源、容器和
    工作对象位置会按约 8 格粒度写入伴侣独立世界记忆。
18. 默认跟随且没有新任务时，执行器可以自主使用随身食物和治疗物品，并在安全时
    前往附近帐篷恢复生命与精神。普通恢复要求至少约 60 秒可睡；生命低于 35%
    或精神低于 20% 时，才允许在剩余 30 秒以上时紧急休息。执行器会计算预计恢复量、
    实际饥饿消耗和睡后必须保留的安全饥饿线，并检查时段、帐篷耐久和附近敌对生物。
    自主恢复事件只记录日志并在游戏聊天栏汇报，不唤醒 DeepSeek；新的非跟随任务会
    立即叫醒微光并中断恢复。用户明确要求不要自动恢复时，`follow` 意图设置
    `params.ignore_autonomous_recovery=true`。

## 战斗契约

```json
{
  "intent_id": "fight-001",
  "mode": "combat",
  "target_guid": "12345",
  "params": {
    "auto_dodge": true,
    "retreat_hp": null
  },
  "lease_seconds": 6,
  "reason": "用户要求攻击该目标"
}
```

`retreat_hp` 为 `null` 表示没有授权撤退。执行器可以闪避，但不能自行退出战斗。
`retreat` 在没有指定 `position` 时表示停止战斗并返回玩家身边。战斗目标导致伴侣
离玩家超过模组配置的安全距离时，执行器会上报
`task_failed/combat_leash_exceeded` 并停止追击。

## 回复与任务

模型响应同时包含 `reply` 和 `intent`。`reply` 用于向用户汇报或提问，
`intent` 决定伴侣接下来执行什么。

```json
{
  "reply": {
    "text": "用户酱，作物收完了。你打算种什么？",
    "expects_response": true
  },
  "intent": {
    "intent_id": "follow-after-harvest",
    "mode": "follow",
    "lease_seconds": 120,
    "reason": "等待用户选择作物"
  }
}
```

普通闲聊可以只返回 `reply`。控制器会保留当前任务，不会因为聊天而停下：

```json
{
  "reply": {
    "text": "用户酱，农场都快被你种满了",
    "expects_response": false
  }
}
```

## 远距离取物

```json
{
  "intent_id": "fetch-gold-001",
  "mode": "fetch_item",
  "target_prefab": "goldnugget",
  "position": [420, -180],
  "params": {
    "search_radius": 18,
    "give_to_player": true,
    "target_shard": "1"
  },
  "lease_seconds": 1800,
  "reason": "回家拿金块并带给玩家"
}
```

执行器会先移动到 `position`，在附近的箱子和地面查找 `target_prefab`，
取得后返回玩家身边。找不到、背包满、路径卡住或目标世界未运行时会发送
明确的失败或阻塞事件。

## 连续击杀并拾取掉落

“帮我打些蜘蛛丝”这类目标使用 `collect_loot`。执行器在一个任务内连续寻找来源、
战斗、拾取和计数，不需要每击杀一只就调用一次模型：

```json
{
  "intent_id": "collect-silk-001",
  "mode": "collect_loot",
  "target_prefab": "silk",
  "params": {
    "source_prefab": "spider",
    "source_tag": "spider",
    "amount": 10,
    "give_to_player": true,
    "ignore_player_leash": true,
    "progress_reports": false,
    "patrol_radius": 48,
    "no_source_timeout": 60
  },
  "lease_seconds": 1800,
  "reason": "帮用户击杀蜘蛛并收集蜘蛛丝"
}
```

执行器优先拾取附近已有掉落，再寻找来源生物。找不到时会扩大范围巡逻搜索，默认
60 秒仍无来源才报告 `task_failed/loot_source_not_found`。默认不逐只播报击杀，
完成交付时直接汇报一次；背包已满、路径卡住、玩家背包满和致命伤保护仍会分别报告
明确原因。

## 支持模式

- `hold`
- `follow`
- `move_to`
- `move_to_landmark`
- `remember_location`
- `fetch_item`
- `combat`
- `collect_loot`
- `guard`
- `use_skill`
- `harvest`
- `harvest_area`
- `gather`
- `craft`
- `build`
- `deploy`
- `plant`
- `till`
- `equip`
- `unequip`
- `eat`
- `retreat`
- `operate`
- `speak`

## 角色能力与生产

伴侣与玩家使用相同角色时会复制玩家当前技能树选择。观察中的
`capabilities.skills` 是当前已激活技能，`capabilities.skill_actions` 是执行器
可以调用的角色特殊动作白名单。

```json
{
  "intent_id": "skill-1",
  "mode": "use_skill",
  "target_guid": "12345",
  "params": {
    "action": "CAST_POCKETWATCH",
    "item_prefab": "wanda_clock_1"
  },
  "lease_seconds": 60,
  "reason": "使用角色特殊物品"
}
```

`craft` 只接受 `capabilities.craftable_recipes` 中存在且材料满足的配方。
`build` 会对带放置物的建筑先制作再部署；`plant`/`deploy`、`till`、
`equip`、`unequip` 分别处理种植放置、耕地和装备切换。
