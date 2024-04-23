local AddComponentPostInit = AddComponentPostInit
GLOBAL.setfenv(1, GLOBAL)
local PlayerController = require("components/playercontroller")

local _GetPickupAction = ToolUtil.GetUpvalue(PlayerController.GetActionButtonAction, "GetPickupAction")
local GetPickupAction = function(self, target, tool, ...)
    if target:HasTag("smolder") then
        return ACTIONS.SMOTHER
    elseif tool ~= nil then
        for action, _ in pairs(TOOLACTIONS) do
            if target:HasTag(action .. "_workable") then
                if tool:HasTag(action .. "_tool") then
                    return ACTIONS[action]
                end
                -- break
            end
        end
    end

    return _GetPickupAction(self, target, tool, ...)
end
ToolUtil.SetUpvalue(PlayerController.GetActionButtonAction, GetPickupAction, "GetPickupAction")

function PlayerController:ReleaseControlSecondary(x, z)
    if not self.ismastersim then
        SendModRPCToServer(MOD_RPC["Porkland"]["ReleaseControlSecondary"], x, z)
    end
    local position = Vector3(x, 0, z)
    if self.inst.sg ~= nil and self.inst.sg:HasStateTag("strafing") then
        self.inst:PushBufferedAction(BufferedAction(self.inst, nil, ACTIONS.CHARGE_RELEASE, nil, position))
    end
end

function PlayerController:OnRemoteReleaseControlSecondary(x, z)
    local position = Vector3(x, 0, z)
    if self.inst.sg ~= nil and self.inst.sg:HasStateTag("strafing") then
        self.inst:PushBufferedAction(BufferedAction(self.inst, nil, ACTIONS.CHARGE_RELEASE, nil, position))
    end
end

local _OnUpdate = PlayerController.OnUpdate
function PlayerController:OnUpdate(dt)
    local ret = {_OnUpdate(self, dt)}

    local isenabled, ishudblocking = self:IsEnabled()

    if self.handler then
        if self.lasttick_controlpressed[CONTROL_SECONDARY] ~= nil
            and self.lasttick_controlpressed[CONTROL_SECONDARY] == true
            and self:IsControlPressed(CONTROL_SECONDARY) == false then
            local x, z = TheInput:GetWorldXZWithHeight(1)
            self:ReleaseControlSecondary(x, z)
        end
        self.lasttick_controlpressed[CONTROL_SECONDARY] = self:IsControlPressed(CONTROL_SECONDARY)
    end

    return unpack(ret)
end

AddComponentPostInit("playercontroller", function(self)
    self.vulnerabletopoisondamage = true
    self.poison_damage_scale = 1

    self.lasttick_controlpressed = {}
end)
