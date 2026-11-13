local Text = require "widgets/text"

local NESTED_RADIUS = 162
local NESTED_FOCUS_RADIUS = 171

local function BuildItems(sources, parent_path, on_select)
    local result = {}
    for _, source in ipairs(sources or {}) do
        local path = parent_path .. "." .. tostring(source.id or #result + 1)
        local icon = source.icon or {
            atlas = "images/inventoryimages.xml",
            normal = "papyrus.tex",
        }
        local node = {
            label = source.label or source.id or "",
            atlas = icon.atlas,
            normal = icon.normal,
            widget_scale = 1.12,
        }
        if source.quantity ~= nil then
            node.postinit = function(button)
                local quantity = button:AddChild(
                    Text(NEWFONT_OUTLINE, 27, tostring(source.quantity))
                )
                quantity:SetPosition(0, -4, 1)
                quantity:SetColour(1, 0.95, 0.68, 1)
                quantity:SetClickable(false)
            end
        end
        if type(source.children) == "table" and #source.children > 0 then
            node.nestedwheel = {
                name = path,
                items = BuildItems(source.children, path, on_select),
                r = NESTED_RADIUS,
                f = NESTED_FOCUS_RADIUS,
            }
        elseif source.command ~= nil then
            node.execute = function()
                on_select(source.command)
                return false
            end
        end
        table.insert(result, node)
    end
    return result
end

return BuildItems
