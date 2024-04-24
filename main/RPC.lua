local AddShardModRPCHandler = AddShardModRPCHandler
GLOBAL.setfenv(1, GLOBAL)

AddShardModRPCHandler("Porkland", "SetAporkalypseClockRewindMult", function(shardid, rewind_mult)
    if not TheWorld.ismastershard then
        return
    end

    TheWorld:PushEvent("ms_setrewindmult", rewind_mult)
end)

AddShardModRPCHandler("Porkland", "SwitchAporkalypse", function(shardid, active)
    if not TheWorld.ismastershard then
        return
    end

    if active then
        TheWorld:PushEvent("ms_startaporkalypse")
    else
        TheWorld:PushEvent("ms_stopaporkalypse")
    end
end)

AddModRPCHandler("Porkland", "ReleaseControlSecondary", function(player, x, z)
    if not (checknumber(x) and checknumber(z)) then
        return
    end
    local playercontroller = player.components.playercontroller
    if playercontroller ~= nil then
        playercontroller:OnRemoteReleaseControlSecondary(x, z)
    end
end)

AddModRPCHandler("Porkland", "StrafeFacing_pl", function(player, dir)
    if not checknumber(dir) then
        printinvalid("StrafeFacing", player)
        return
    end
    local locomotor = player.components.locomotor
    if locomotor then
        locomotor:OnStrafeFacingChanged(dir)
    end
end)
