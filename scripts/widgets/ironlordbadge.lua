local Badge = require("widgets/badge")

local IronlordBadge = Class(Badge, function(self, owner)
    Badge._ctor(self, "livingartifact_meter", owner)

    self.val = TUNING.IRON_LORD_TIME

    owner:ListenForEvent("ironlorddelta", function(_, data)
        local percent =  data.percent
        self:SetPercent(percent, data.max)
    end, owner)
end)

function IronlordBadge:SetPercent(val, max)
    Badge.SetPercent(self, val, max)
    self.val = val
end

return IronlordBadge
