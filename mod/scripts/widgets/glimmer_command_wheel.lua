local Wheel = require "widgets/wheel"
local Text = require "widgets/text"
local Menu = require "glimmer_wheel_menu"

local ROOT_RADIUS = 205
local ROOT_FOCUS_RADIUS = 216
local NESTED_RADIUS = 162
local NESTED_FOCUS_RADIUS = 171

local GlimmerCommandWheel = Class(Wheel, function(self, owner, onsubmit)
    Wheel._ctor(self, "glimmer.commandwheel", owner)
    self.onsubmit = onsubmit
    self.pending_command = nil
    self.selected_label:SetColour(1, 1, 1, 1)
    self.selected_label:SetOutlineColour(0, 0, 0, 1)
    self.root_items = self:BuildItems(Menu.branches, "root")
    self:SetItems(
        self.root_items,
        ROOT_RADIUS,
        ROOT_FOCUS_RADIUS
    )
end)

function GlimmerCommandWheel:BuildItems(sources, parent_path)
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
                    Text(UIFONT, 27, tostring(source.quantity))
                )
                quantity:SetPosition(0, -4, 1)
                quantity:SetColour(1, 0.95, 0.68, 1)
                quantity:SetOutlineColour(0, 0, 0, 1)
                quantity:SetClickable(false)
            end
        end
        if type(source.children) == "table" and #source.children > 0 then
            node.nestedwheel = {
                name = path,
                items = self:BuildItems(source.children, path),
                r = NESTED_RADIUS,
                f = NESTED_FOCUS_RADIUS,
            }
        elseif source.command ~= nil then
            node.execute = function()
                self.pending_command = source.command
                return false
            end
        end
        table.insert(result, node)
    end
    return result
end

function GlimmerCommandWheel:OnExecute()
    local command = self.pending_command
    self.pending_command = nil
    self:Close()
    if command ~= nil and self.onsubmit ~= nil then
        self.onsubmit(command)
    end
end

function GlimmerCommandWheel:OnCancel()
    self.pending_command = nil
    self:Close()
end

return GlimmerCommandWheel
