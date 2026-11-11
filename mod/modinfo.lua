name = "微光旅伴"
description = [[
由本地 DeepSeek 控制器实时驱动的非玩家幸存者。

不建立第二名玩家连接，不修改服务器人数，兼容独行长路。
伴侣拥有独立的服务端模拟区域，远距离任务不会因玩家离开而停摆。
执行层执行控制器下发的任务；无任务跟随时会按确定性规则自行进食、治疗和睡觉，
不会另行改变任务目标。
]]
author = "xiaolangmin-cloud"
version = "0.11.1"
forumthread = ""

api_version = 10

dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
hamlet_compatible = false
dst_compatible = true

client_only_mod = false
server_only_mod = true
all_clients_require_mod = false

server_filter_tags = {}

configuration_options = {
    {
        name = "companion_character",
        label = "Companion character",
        options = {
            { description = "Same as player (recommended)", data = "player" },
            { description = "Wendy", data = "wendy" },
            { description = "Wilson", data = "wilson" },
            { description = "Willow", data = "willow" },
            { description = "Wolfgang", data = "wolfgang" },
            { description = "WX-78", data = "wx78" },
            { description = "Wickerbottom", data = "wickerbottom" },
            { description = "Woodie", data = "woodie" },
            { description = "Wes", data = "wes" },
            { description = "Maxwell", data = "waxwell" },
            { description = "Wigfrid", data = "wathgrithr" },
            { description = "Webber", data = "webber" },
            { description = "Warly", data = "warly" },
            { description = "Wormwood", data = "wormwood" },
            { description = "Winona", data = "winona" },
            { description = "Wortox", data = "wortox" },
            { description = "Wurt", data = "wurt" },
            { description = "Walter", data = "walter" },
            { description = "Wanda", data = "wanda" },
            { description = "Wonkey", data = "wonkey" },
        },
        default = "player",
    },
    {
        name = "bridge_url",
        label = "Controller URL",
        options = {
            { description = "127.0.0.1:8765", data = "http://127.0.0.1:8765" },
        },
        default = "http://127.0.0.1:8765",
    },
    {
        name = "area_radius",
        label = "Companion active radius",
        options = {
            { description = "12", data = 12 },
            { description = "16", data = 16 },
            { description = "18 (recommended)", data = 18 },
            { description = "22", data = 22 },
            { description = "26", data = 26 },
        },
        default = 18,
    },
    {
        name = "combat_leash_distance",
        label = "Combat distance from player",
        options = {
            { description = "20", data = 20 },
            { description = "26", data = 26 },
            { description = "30 (recommended)", data = 30 },
            { description = "40", data = 40 },
        },
        default = 30,
    },
}
