local AddStategraphState = AddStategraphState
local AddStategraphActionHandler = AddStategraphActionHandler
local AddStategraphPostInit = AddStategraphPostInit
GLOBAL.setfenv(1, GLOBAL)

local TIMEOUT = 2

local actionhandlers = {
    ActionHandler(ACTIONS.HACK, function(inst)
        if inst:HasTag("beaver") then
            return not inst.sg:HasStateTag("gnawing") and "gnaw" or nil
        end
        return not inst.sg:HasStateTag("prehack") and "hack_start" or nil
    end),
    ActionHandler(ACTIONS.PAN, function(inst)
        if not inst.sg:HasStateTag("panning") then
            return "pan_start"
        end
    end),
    ActionHandler(ACTIONS.SHEAR, function(inst)
        return not inst.sg:HasStateTag("preshear") and "shear_start" or nil
    end),
    ActionHandler(ACTIONS.CHARGE_UP, "ironlord_charge"),
    ActionHandler(ACTIONS.CHARGE_RELEASE, function(inst, action)
        if inst.sg:HasStateTag("strafing") then
            inst.sg.statemem.should_shoot = true
            inst.sg.mem.shootpos = action:GetActionPoint()
        end
    end),
}

local states = {
    State{
        name = "hack_start",
        tags = {"prehack", "hacking", "working"},

        onenter = function(inst)
            inst.components.locomotor:Stop()

            if not inst:HasTag("working") then
                local action = inst:GetBufferedAction()
                local tool = action ~= nil and action.invobject or nil
                local hacksymbols = tool ~= nil and tool.hack_overridesymbols or nil
                if hacksymbols ~= nil then
                    hacksymbols[3] = tool:GetSkinBuild()
                    if hacksymbols[3] ~= nil then
                        inst.AnimState:OverrideItemSkinSymbol("swap_machete", hacksymbols[3], hacksymbols[1], tool.GUID, hacksymbols[2])
                    else
                        inst.AnimState:OverrideSymbol("swap_machete", hacksymbols[1], hacksymbols[2])
                    end
                    inst.AnimState:PlayAnimation("hack_pre")
                    inst.AnimState:PushAnimation("hack_lag", false)
                else
                    inst.AnimState:PlayAnimation("chop_pre")
                    inst.AnimState:PushAnimation("chop_lag", false)
                end
            end

            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(TIMEOUT)
        end,

        onupdate = function(inst)
            if inst:HasTag("working") then
                if inst.entity:FlattenMovementPrediction() then
                    inst.sg:GoToState("idle", "noanim")
                end
            elseif inst.bufferedaction == nil then
                inst.sg:GoToState("idle")
            end
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("idle")
        end
    },

    State{
        name = "pan_start",
        tags = {"prepan", "panning", "working"},
        server_states = {"pan_start", "pan"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            if not inst.sg:ServerStateMatches() then
                inst.AnimState:PlayAnimation("pan_pre")
                inst.AnimState:PushAnimation("pan_loop", false) -- TODO: make pan_lag anim
            end

            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(TIMEOUT)
        end,

        onupdate = function(inst)
            if inst.sg:ServerStateMatches() then
                if inst.entity:FlattenMovementPrediction() then
                    inst.sg:GoToState("idle", "noanim")
                end
            elseif inst.bufferedaction == nil then
                inst.AnimState:PlayAnimation("pan_pst")
                inst.sg:GoToState("idle", true)
            end
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("idle")
        end,
    },

    State{
        name = "shear_start",
        tags = {"preshear", "working"},

        onenter = function(inst)
            inst.components.locomotor:Stop()

            if not inst:HasTag("working") then
                inst.AnimState:PlayAnimation("cut_pre")
            end

            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(TIMEOUT)
        end,

        onupdate = function(inst)
            if inst:HasTag("working") then
                if inst.entity:FlattenMovementPrediction() then
                    inst.sg:GoToState("idle", "noanim")
                end
            elseif inst.bufferedaction == nil then
                inst.AnimState:PlayAnimation("cut_pst")
                inst.sg:GoToState("idle", true)
            end
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("idle")
        end
    },

    State{
        name = "castspell_bone",
        tags = {"doing", "busy", "canrotate", "spell"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("staff_pre")
            inst.AnimState:PushAnimation("staff_lag", false)

            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(TIMEOUT)
        end,

        onupdate = function(inst)
            if inst.sg:ServerStateMatches() then
                if inst.entity:FlattenMovementPrediction() then
                    inst.sg:GoToState("idle", "noanim")
                end
            elseif inst.bufferedaction == nil then
                inst.sg:GoToState("idle")
            end
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("idle")
        end,
    },

    State{
        name = "ironlord_idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst, pushanim)
            inst.components.locomotor:StopMoving()

            if pushanim then
                inst.AnimState:PlayAnimation(pushanim)
                inst.AnimState:PushAnimation("idle_loop", true)
            else
                inst.AnimState:PlayAnimation("idle_loop", true)
            end

        end,

       events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("ironlord_idle")
            end),
        },
    },

    State{
        name = "ironlord_charge",
        tags = {"busy", "doing", "strafing"},
        server_states = {"ironlord_charge", "ironlord_charge_full"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("charge_pre")
            inst.AnimState:PushAnimation("charge_grow")
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/iron_lord/charge_up_LP", "chargedup")

            inst.sg.statemem.ready_to_shoot = false
            inst.sg.statemem.should_shoot = false

            inst:PerformPreviewBufferedAction()
        end,

        onexit = function(inst)
            inst.SoundEmitter:KillSound("chargedup")
        end,

        onupdate = function(inst)
            if inst.sg.statemem.should_shoot and inst.sg.statemem.ready_to_shoot then
                if inst.sg.statemem.isfull then
                    inst.SoundEmitter:PlaySoundWithParams("dontstarve_DLC003/creatures/boss/hulk_metal_robot/laser",  {intensity = math.random(0.7, 1)})
                else
                    inst.SoundEmitter:PlaySoundWithParams("dontstarve_DLC003/common/crafted/iron_lord/smallshot", {timeoffset = math.random()})
                end
                inst.SoundEmitter:KillSound("chargedup")
                inst.sg:GoToState("ironlord_shoot", false)
            end
        end,

        timeline =
        {
            TimeEvent(15 * FRAMES, function(inst) inst.sg.statemem.ready_to_shoot = true end),
            TimeEvent(20 * FRAMES, function(inst)
                inst.AnimState:PlayAnimation("charge_super_pre")
                inst.AnimState:PushAnimation("charge_super_loop", true)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/iron_lord/electro")
                inst.sg.statemem.ready_to_shoot = false
                inst.sg.statemem.should_shoot = false
            end),
            TimeEvent(25 * FRAMES, function(inst) inst.sg.statemem.ready_to_shoot = true end),
        },
    },


    State{
        name = "ironlord_shoot",
        tags = {"busy"},
        server_states = {"ironlord_shoot"},

        onenter = function(inst, is_full_charge)
            inst.components.locomotor:Stop()
            if is_full_charge then
                inst.AnimState:PlayAnimation("charge_super_pst")
            else
                inst.AnimState:PlayAnimation("charge_pst")
            end
            inst.sg.statemem.is_full_charge = is_full_charge

            if inst.sg.mem.shootpos ~= nil then
                inst:ForceFacePoint(inst.sg.mem.shootpos:Get())
            end
        end,

        timeline =
        {
            TimeEvent(5 * FRAMES, function(inst) inst.sg:RemoveStateTag("busy") end),

        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("ironlord_idle") end),
        },
    },
}

for _, actionhandler in ipairs(actionhandlers) do
    AddStategraphActionHandler("wilson_client", actionhandler)
end

for _, state in ipairs(states) do
    AddStategraphState("wilson_client", state)
end

AddStategraphPostInit("wilson_client", function(sg)
    local _castspell_deststate = sg.actionhandlers[ACTIONS.CASTSPELL].deststate
    sg.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action)
        local staff = action.invobject or action.doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if staff:HasTag("bonestaff") then
            return "castspell_bone"
        else
            return _castspell_deststate and _castspell_deststate(inst, action)
        end
    end
end)
