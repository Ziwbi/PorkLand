
local AddClassPostConstruct = AddClassPostConstruct
GLOBAL.setfenv(1, GLOBAL)

local IronLordBadge = require("widgets/ironlordbadge")
AddClassPostConstruct("widgets/statusdisplay", function(self)
    self.ironlord = self:AddChild(IronLordBadge(self.owner))
    self.ironlord:SetPosition(self.column4, 20, 0)
    self.ironlord:Hide()

    local _ShowStatusNumbers = self.ShowStatusNumbers
    function self:ShowStatusNumbers()
        if _ShowStatusNumbers then
            _ShowStatusNumbers(self)
        end
        --self.ironlord.num:Show()
    end
    --HideStatusNumbers

    function self:SetIronLordPercent(percent)
        self.ironlord:SetPercent(percent)
    end

    function self:IronLordDelta(data)
        self:SetIronLordPercent(data.newpercent)
    end

    self.onironlorddelta = function(owner, data) self:IronLordDelta(data) end
    self.inst:ListenForEvent("ironlorddelta", self.onironlorddelta, self.owner)
end)


--[[
if inst.ironlord and not player.HUD.controls.ironlordbadge then
    player.HUD.controls.ironlordbadge = GetPlayer().HUD.controls.sidepanel:AddChild(IronlordBadge(player))
    player.HUD.controls.ironlordbadge:SetPosition(0,-100,0)
    player.HUD.controls.ironlordbadge:SetPercent(1)


    player.HUD.controls.crafttabs:Hide()
    player.HUD.controls.inv:Hide()
    player.HUD.controls.status:Hide()
    player.HUD.controls.mapcontrols.minimapBtn:Hide()

elseif not inst.ironlord and player.HUD.controls.ironlordbadge then
    if player.HUD.controls.ironlordbadge then
        player.HUD.controls.ironlordbadge:Kill()
        player.HUD.controls.ironlordbadge = nil
    end

    player.HUD.controls.crafttabs:Show()
    player.HUD.controls.inv:Show()
    player.HUD.controls.status:Show()
    player.HUD.controls.mapcontrols.minimapBtn:Show()
end
]]