# 微光智能体系攻略核对记录

核对日期：2026-11-12

范围：只采用可交叉核对且能转化为执行规则的事实。世界设置在默认长度下才使用日历
数字；实际任务优先相信游戏上报的季节、温度、天气和实体状态。

## 战斗与护甲

- 头部和身体同时穿戴时，伤害按
  `伤害 × (1 - 主护甲减伤) × (1 - 副护甲减伤)` 连续结算。不能把 80% 与 80%
  相加成 160%。
- 护甲耐久会被实际吸收的伤害消耗，因此判断是否开战要看剩余耐久，而不是只看
  图标的减伤百分比。

来源：

- https://dontstarve.wiki.gg/wiki/Armor
- https://dontstarve.wiki.gg/wiki/Durability
- https://dontstarve.wiki.gg/wiki/Guides/Combatting_Bosses
- https://dontstarve.wiki.gg/wiki/Guides/Mob_Killing_Guide

## 猎犬与范围攻击

- 猎犬攻击后可能停顿，适合边退边找反击窗口；大群猎犬存在连续硬直风险，
  不能只用静态生命和平均伤害判断安全。
- 红猎犬死亡会留下火焰，因此要主动远离基地、森林和易燃库存。
- 巨鹿攻击是前方大范围伤害，躲避距离要大于普通近战；控制器和策略层必须把
  基地建筑、玩家与撤退路线一起纳入开战条件。

来源：

- https://dontstarve.wiki.gg/wiki/Hound/DST
- https://dontstarve.wiki.gg/wiki/Guides/Hound_Wave_Survival_Guide
- https://dontstarve.wiki.gg/wiki/Deerclops

## 食物与保鲜

- 食物新鲜度为 50%-100% 时为 Fresh，21%-49% 为 Stale，1%-20% 为 Spoiled。
- 营火或烹饪锅烹饪会把当前腐坏程度减半。
- 冰箱让普通食物的腐坏速度减半；冬天低于 0 度时食物还会额外变慢。
- 烤熟或晾晒不一定总比生食耐放。料理前要按具体食物种类决定，不能一律先烤。
- 没有观察到锅、营火、晾肉架或冰箱时，不能把“可以烹饪/晾晒/冷藏”当成已完成能力。

来源：

- https://dontstarve.wiki.gg/wiki/Food/DST
- https://dontstarve.wiki.gg/wiki/Ice_Box
- https://dontstarve.wiki.gg/wiki/Cooking

## 季节与体温

- 默认 DST 世界：秋 20 天、冬 15 天、春 20 天、夏 15 天；默认第一冬在第 21 天
  开始。
- 春季主要是降雨、潮湿、理智和雷电风险；夏季高温会造成过热并有野火风险；冬季需要
  保暖、可靠火源、光源和食物。
- 版本更新后，体温和隔热机制更复杂；不能用固定“冬季装备万能”规则替代实时体温。

来源：

- https://dontstarve.wiki.gg/wiki/Seasons/DST
- https://dontstarve.wiki.gg/wiki/Time
- https://dontstarve.wiki.gg/wiki/Freezing
- https://dontstarve.wiki.gg/wiki/Overheating

## 麦斯威尔、法典与暗影傀儡

- 法典有 20 次使用耐久，降到 0% 不会损坏，可用噩梦燃料修复。
- 每次召唤会消耗法典耐久和理智。通常最多召 5 个傀儡；第 6 个会增加影怪风险，
  除非明确需要刷噩梦燃料或有不惧低理智的装备。
- 暗影仆从在召唤点周围约 4 格地皮工作，主要处理采矿、伐木和挖掘；它不会长期跟随
  玩家到下一片资源区。
- 暗影决斗者必须已有实际战斗目标再召；约 2 分钟后消失，闲置约 10 秒也会消失。
- 暗影牢笼不会造成伤害并会吸引仇恨。普通生物约 24 秒，Boss 约 12 秒；攻击会缩短
  控制时间，因此必须利用窗口输出或撤退。
- 暗影蝶形态的 Shadow Sneak 是地面陷阱，激活后让普通目标恐慌 12 秒，未激活时约
  存在 3 个游戏日；Boss 免疫。

来源：

- https://dontstarve.wiki.gg/wiki/Codex_Umbra/DST
- https://dontstarve.wiki.gg/wiki/Shadow_Puppet/DST
- https://dontstarve.wiki.gg/wiki/Shadow_Traps
- https://dontstarve.wiki.gg/wiki/Don%27t_Starve_Together/Version_History/2022

## 种植与巨型作物

- 农场作物有种子、幼苗、小、中、成熟五个阶段，每个阶段都可能积累压力。
- 零到一点总压力才会长出巨型作物，因此巨型作物不能等成熟后再补救。
- 相近作物成族种植可降低压力；成熟植株在农场中不会继续腐坏，可以按任务和
  背包空间安排收获时间。

来源：

- https://dontstarve.wiki.gg/wiki/Farming/DST
- https://dontstarve.wiki.gg/wiki/Farm_Plant
- https://dontstarve.wiki.gg/wiki/Giant_Crops

## 已落实为本地规则的结论

1. 战斗预检同时计算头部和身体护甲，不再只取单件最大减伤。
2. 控制器为每次观察生成 `decision_support`，向模型提供风险分数、预计承伤、季节
   准备和麦斯威尔召唤限制。
3. 基地自主维护加入提前温控：冬季体温偏低时先穿保暖并靠近/补充热源；夏季体温偏高
   时穿夏季隔热并寻找真实冷源。
4. 麦斯威尔已有 5 个暗影傀儡时停止自动召唤，避免无意识堆到第 6 个。
5. 游戏观察补上体温、环境温度、潮湿、季节布尔值、双槽护甲耐久、法典耐久和傀儡数量。
6. 观察数据补上装备槽和游戏真实护甲减伤，Mod 护甲不再依赖内置名称表。
7. 战斗提示新增猎犬硬直、红猎犬死后纵火、巨鹿范围攻击和基地结构风险。
8. 观察数据加入成长阶段和巨型作物压力规则，防止成熟后才补救。

## 仍不能只靠攻略硬编码的部分

- 不同自定义世界、Mod、Boss 形态和攻击间隔会改变预计承伤。
- 烹饪和晾晒需要具体配方、设施、空间和食物收益计算，不能只凭“有锅”就自动消耗材料。
- 走位、控制命中和敌人增援必须由游戏事件验证，估算值不能当成实际结果。
