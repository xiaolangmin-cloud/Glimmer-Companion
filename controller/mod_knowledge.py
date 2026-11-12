from __future__ import annotations


IMPLEMENTATION_NOTES: tuple[dict[str, str], ...] = (
    {
        "topic": "微光 Mod - 运行与启动架构",
        "summary": "服务端非玩家角色、本地控制器与按游戏会话启动桥的完整链路",
        "tags": "mod 微光 架构 控制器 启动桥 进程 游戏 存档 聊天 连接",
        "content": (
            "微光是 DST 服务端生成的非玩家幸存者，不建立第二客户端连接，"
            "不使用 AllPlayers 玩家名额，兼容 max_players=1 与独行长路。"
            "Lua 沙箱不能创建 Windows 进程，因此需要本机启动桥。"
            "当前流程是从桌面快捷方式 Don't Starve Together - 微光 启动；"
            "启动器同时启动轻量桥并打开 Steam 客户端游戏。玩家进入存档后，"
            "Mod 在聊天栏报告连接进度，调用桥 POST /start 拉起完整 Python "
            "控制器；桥轮询 /status，只有控制器 /health 就绪后才生成微光。"
            "游戏退出后启动器和桥会停止本局控制器。游戏未运行时不留后台进程。"
        ),
    },
    {
        "topic": "微光 Mod - 角色选择与切换",
        "summary": "默认麦斯威尔，本地网页选人、皮肤继承和运行时安全切换",
        "tags": "mod 选人 麦斯威尔 waxwell 沃尔特 walter 角色 皮肤 服装 切换 窗口 背包 装备",
        "content": (
            "控制器提供 /character 本地网页和 /companion-character 接口，"
            "选择持久保存到 state/companion_character.json。默认角色是 "
            "waxwell（麦斯威尔）。游戏内微光检测到选择变化后中断恢复和当前任务，"
            "把背包及装备丢在脚下，清除旧角色持久档案，再以新角色在玩家身边重生。"
            "首次生成也会读取控制器选择，而不是被旧角色记录覆盖。切换完成后会"
            "在聊天栏说明新角色。微光与玩家同角色时复制玩家当前整套角色皮肤；"
            "角色不同时会读取 Profile:GetSkinsForCharacter 中玩家为该角色配置的"
            "基础、身体、手、腿、脚皮肤并校验所有权，运行时换装也会周期同步。"
        ),
    },
    {
        "topic": "微光 Mod - 任务与动作能力",
        "summary": "任务级 DeepSeek 规划与确定性 Lua 执行器分工",
        "tags": "mod 能力 动作 follow hold move combat craft build deploy plant till "
        "harvest gather collect_loot fetch use_skill eat retreat operate guard",
        "content": (
            "DeepSeek 负责任务级规划和对话，不参与逐帧操作。Lua 执行器支持 "
            "follow、hold、move_to、move_to_landmark、remember_location、"
            "fetch_item、combat、collect_loot、guard、use_skill、harvest、"
            "harvest_area、gather、craft、build、deploy、plant、till、equip、"
            "unequip、eat、deliver_item、retreat、operate。执行器在当前任务范围内负责寻路、"
            "攻击、拾取、选择同类目标、装备选择、卡住检测和战斗安全距离。"
            "制作和建造采用状态锁，带放置物建筑分两阶段制作与部署；进食使用标准 "
            "EAT 动作。当前运行时不能自行修改 Lua 源码；如果能力缺失，模型应返回 "
            "capability_gap 并明确告知用户，由新的 Codex 开发会话实现。"
            "config/playbooks/generic.json 会把跟随、等待、撤退及附近草、树枝、"
            "浆果、胡萝卜、花、"
            "芦苇等简单采集请求直接路由成本地意图，不调用 DeepSeek。"
        ),
    },
    {
        "topic": "微光 Mod - 生存恢复与自主行为",
        "summary": "跟随状态自主吃喝治疗和帐篷恢复，不逐帧调用模型",
        "tags": "mod 饥饿 生命 精神 恢复 帐篷 吃食物 治疗 自动 聊天 睡眠",
        "content": (
            "默认跟随且无任务时，Lua 会自主使用背包食物、治疗物品或附近帐篷。"
            "帐篷判断包括昼夜阶段、剩余睡眠时间、预计生命和精神收益、睡眠饥饿代价、"
            "睡后安全饥饿线、帐篷耐久和附近危险。普通恢复至少约 60 秒，生命低于 "
            "35%或精神低于 20%时才允许 30 秒以上紧急睡眠。新非跟随任务会立即叫醒"
            "微光并中断恢复。恢复事件直接写日志和聊天，不唤醒 DeepSeek。"
        ),
    },
    {
        "topic": "微光 Mod - 任务决策分支与角色技能",
        "summary": "先路由战斗、采集、制作、建造、运输、耕种、生存等分支，再选择预案和技能",
        "tags": "mod 决策 分支 战斗 采集 制作 建造 运输 耕种 生存 探索 基地 "
        "互动 移动 麦斯威尔 暗影法典 技能",
        "content": (
            "控制器先用 config/decision_branches.json 做确定性任务分类，分支包括战斗、"
            "采集、制作、建造、运输、耕种、生存、探索、基地整理、角色互动、移动和"
            "综合兜底。"
            "observation.decision_branch 携带目标、必要检查、执行顺序、禁止事项、完成"
            "信号和知识来源。branch_policies 会直接检查生命、装备、附近敌人和资源，"
            "常见的危险回避、采集、制作阻断、取物、收获、进食和地标移动不经过模型；"
            "DeepSeek 只需在信息不足或需要多步骤适配时继续规划。直接 playbook 仍优先。"
            "麦斯威尔战斗先判断武器、护甲、剩余生命、威胁数量和预计承伤；普通装备足够时"
            "不使用法典。需要技能时，暗影决斗者负责战斗，暗影蝶只让非 Boss 敌人恐慌，"
            "暗影牢笼只定身且会吸引仇恨，三者不能混为一谈。"
        ),
    },
    {
        "topic": "微光 Mod - 原生灾害应急",
        "summary": "本地缓存识别原生危险，独立处置并用轮换可爱文案聊天",
        "tags": "mod 应急 灾害 猎犬 狗 蠕虫 地震 青蛙雨 梦魇 暴乱 酸雨 "
        "黑暗 过冷 过热 袭击 敌对群体 聊天",
        "content": (
            "Lua 约每 0.75 秒缓存评估一次原生灾害，不逐帧调用 DeepSeek。覆盖突然"
            "黑暗、猎犬和洞穴蠕虫、地震、青蛙雨、梦魇暴乱、酸雨、主动袭击、敌对"
            "群体、过冷和过热。警告期先穿甲并向玩家靠拢；来袭时只打附近目标，"
            "不为追击离开玩家过远。黑暗先尝试火把、附近光源或玩家；酸雨检查雨免疫、"
            "遮蔽和防水装备；地震会中断远程任务。控制器为每种灾害、动作变化和解除"
            "准备多套轮换的可爱聊天文案，例如“来狗啦来狗啦”，不唤醒模型。"
            "用户设置 ignore_survival_safety 或 survival_policy=force 时，应急层"
            "汇报风险但不硬性取消任务；未知自定义 Mod 事件不在覆盖范围。"
        ),
    },
    {
        "topic": "微光 Mod - 游戏内轮盘命令",
        "summary": "12 分支图标轮盘直接生成结构化任务，不调用模型",
        "tags": "mod 轮盘 快捷菜单 F8 图标 采集 数量 分支 wheel RPC",
        "content": (
            "客户端按可配置快捷键打开微光命令轮盘，默认 F8。第一层固定 12 个"
            "可执行分支，不显示综合兜底 general；后续按动作、目标、数量展开。"
            "草、树枝、浆果、胡萝卜、金块等使用原版物品图标，数量 5、10、15、20、"
            "30、50 叠在图标上，全部选完后自动发布。客户端只通过 Mod RPC 提交"
            "schema、branch_id、action、target_id、amount，服务端校验发送者和长度，"
            "再调用控制器 POST /wheel-command。控制器按白名单生成意图，不调用"
            "DeepSeek，但仍执行战斗安全、配方材料、生存和跨世界检查。状态查询直接"
            "回复且不替换当前任务。跨世界参数不能由客户端注入。"
        ),
    },
    {
        "topic": "微光 Mod - 安全边界与已知限制",
        "summary": "跨世界、生存覆盖、独行长路和真实客户端验证边界",
        "tags": "mod 限制 跨世界 洞穴 地洞 独行长路 安全 撤退 验证 卡顿",
        "content": (
            "控制器禁止微光自行切换到另一个 shard；必须由玩家本人通过洞口或传送门"
            "带着微光切换，控制器会改为 hold/cross_world_forbidden。独行长路会关闭"
            "玩家不在的世界，因此微光不能在已关闭的地面或洞穴中真实继续复杂任务。"
            "战斗默认有致命伤保护和离玩家距离限制，用户明确说死战到底或别逃跑才关闭。"
            "远行默认检查饥饿和生命，用户明确要求无视生存风险才关闭。开发测试使用"
            "无窗口专用服务器，能验证服务端动画调用、任务、属性、制作、战斗、存档和"
            "日志，但不能完全替代真实客户端的 UI、网络和肉眼动画验收。"
        ),
    },
    {
        "topic": "微光 Mod - 出生与界面表现",
        "summary": "连接成功后播放原版出生烟雾特效并从透明淡入",
        "tags": "mod 出生 特效 spawn_fx_medium_static 天体门 换人 出现 动画 聊天",
        "content": (
            "玩家进入存档后聊天栏依次显示启动控制器、等待接口和连接成功。"
            "连接成功后，微光被放到玩家正常空间附近，生成原版 "
            "spawn_fx_medium_static；微光先隐藏约 6 帧，再显示并用约 19 帧"
            "从黑色淡入。该特效与 DST 玩家出生和天体换人使用的出生烟雾属于同一类"
            "原版效果。"
        ),
    },
    {
        "topic": "微光 Mod - 记忆隔离",
        "summary": "用户主记忆只读，Mod 实现与攻略使用独立数据库",
        "tags": "mod 记忆库 隔离 主库 vault sqlite 状态 文档 隐私",
        "content": (
            "用户主记忆库 C:\\Users\\admin\\.dsh\\memory\\vault 只读，只用于"
            "检索用户事实、偏好和经历，禁止写入 Mod 实现知识。微光的实现知识、"
            "角色与 Boss 攻略、聊天室、世界资源位置、计划和能力缺口保存在项目 "
            "state/agent_memory.sqlite3。实现知识使用 implementation_notes 表，"
            "只在用户询问 Mod 能力、实现、启动链路或可行性时提供给模型。"
        ),
    },
    {
        "topic": "微光 Mod - 运行恢复与存档一致性",
        "summary": "网络请求超时恢复、会话边界清任务和 KLEI 存档解码",
        "tags": "mod 稳定性 恢复 控制器重启 超时 存档 KLEI 会话 任务 污染",
        "content": (
            "Lua 到控制器的请求带有代次和约 5 秒超时；旧控制器退出导致回调不返回时，"
            "执行器会恢复 pending_request 并重新发送未确认事件，避免聊天栏和任务冻结。"
            "快照携带 DST 主会话 ID，控制器发现进入新会话时自动清除旧任务并切回 "
            "follow。微光 profile 以 KLEI 持久化格式保存，解码时会先剥离 `KLEI 1` "
            "头并避免重复添加 return。范围采集会先导航到目标坐标，再连续处理匹配的 "
            "target_prefab；空区域明确报告 target_not_found，不能假报完成。"
        ),
    },
)
