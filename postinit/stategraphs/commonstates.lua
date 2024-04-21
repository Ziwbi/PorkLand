GLOBAL.setfenv(1, GLOBAL)
require("stategraphs/commonstates")

local _PlayMiningFX = PlayMiningFX
function PlayMiningFX(inst, target, nosound, ...)
    if target and target:IsValid() and target:HasTag("mech") and not nosound then
        inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_mech_med_sharp")
        inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/green")
    else
       _PlayMiningFX(inst, target, nosound, ...)
    end
end
