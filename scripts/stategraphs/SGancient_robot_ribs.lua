require("stategraphs/commonstates")
local AncientHulkUtil = require("prefabs/ancient_hulk_util")

local SHAKE_DIST = 40

local removemoss = AncientHulkUtil.removemoss
local setfires = AncientHulkUtil.setfires
local DoDamage = AncientHulkUtil.DoDamage
local UpdateHit = AncientHulkUtil.UpdateHit
local powerglow = AncientHulkUtil.powerglow
local SpawnLaser = AncientHulkUtil.SpawnLaser
local SetLightValue = AncientHulkUtil.SetLightValue
local SetLightValueAndOverride = AncientHulkUtil.SetLightValueAndOverride
local SetLightColour = AncientHulkUtil.SetLightColour

local actionhandlers =
{

}

local events =
{
    CommonHandlers.OnStep(),
    CommonHandlers.OnLocomote(true, true),

    EventHandler("doattack", function(inst, data)
        if not inst.sg:HasStateTag("activating") and not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("laserbeam", data.target)
        end
    end),

    EventHandler("attacked", function(inst)
        removemoss(inst)
        inst.hits = inst.hits + 1

        if inst.hits > 2 and math.random() * inst.hits >= 2 then
            local x, y, z= inst.Transform:GetWorldPosition()
            inst.components.lootdropper:SpawnLootPrefab("iron", Vector3(x,y,z))
            inst.hits = 0

            if inst:HasTag("dormant") then
                if  math.random() < 0.6 then
                    inst.wantstodeactivate = nil
                    inst:RemoveTag("dormant")
                    inst:PushEvent("shock")
                    inst.components.timer:SetTimeLeft("discharge", 20)
                    if not TheWorld.state.isaporkalypse then
                        inst.components.timer:ResumeTimer("discharge")
                    end
                end
            elseif not inst.sg:HasStateTag("attack") and not inst.sg:HasStateTag("activating") then
                inst.sg:GoToState("hit")
            end
        end

        if inst:HasTag("dormant") and not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("hit_dormant")
        end
    end),

    EventHandler("shock", function(inst)
        inst.wantstodeactivate = nil
        inst:RemoveTag("dormant")
        inst.sg:GoToState("shock")
    end),

    EventHandler("activate", function(inst)
        inst.wantstodeactivate = nil
        inst:RemoveTag("dormant")
        inst.sg:GoToState("activate")
    end),

    EventHandler("deactivate", function(inst)
        if not inst:HasTag("dormant") then
            inst.wantstodeactivate = nil
            inst:AddTag("dormant")
            inst.sg:GoToState("deactivate")
        end
    end),
}

local states =
{
    State{
        name = "idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst, pushanim)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("idle", true)
            inst.sg:SetTimeout(2 + 2 * math.random())
        end,

        ontimeout = function(inst)
            inst.sg:GoToState("taunt")
        end,
    },

    State{
        name = "idle_dormant",
        tags = {"idle", "dormant"},

        onenter = function(inst, pushanim)
            inst.components.locomotor:StopMoving()
            inst.SoundEmitter:SetParameter("gears", "intensity", 1)
            inst.SoundEmitter:KillSound("gears")

            if inst:HasTag("mossy") then
                inst.AnimState:PlayAnimation("mossy_full")
            else
                inst.AnimState:PlayAnimation("full")
            end
        end,

        timeline=
        {
        },

        events=
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle_dormant") end),
        },

    },

    State{
        name = "fall",
        tags = {"busy"},

        onenter = function(inst, pushanim)
            inst.Physics:SetDamping(0)
            inst.Physics:SetMotorVel(0, -35, 0)
            inst.AnimState:PlayAnimation("idle_fall", true)
        end,

        onupdate = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()

            if y < 2 then
                inst.Physics:SetMotorVel(0, 0, 0)
            end

            if y <= 0.1 then
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/boss/hulk_metal_robot/explode_small", nil, 0.25)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/boss/hulk_metal_robot/head/step")

                inst.Physics:Stop()
                inst.Physics:SetDamping(5)
                inst.Physics:Teleport(x, 0, z)
                inst.sg:GoToState("separate")

                ShakeAllCameras(CAMERASHAKE.FULL, 0.7, 0.02, 2, inst, SHAKE_DIST)
            end
        end,

        onexit = function(inst)
            local x, y, z = inst.Transform:GetWorldPosition()
            inst.Transform:SetPosition(x, 0, z)
        end,
    },

    State{
        name = "separate",
        tags = {"busy", "dormant"},

        onenter = function(inst, pushanim)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("separate")
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle_dormant") end),
        },
    },

    State{
        name = "hit_dormant",
        tags = {"busy", "dormant"},

        onenter = function(inst, pushanim)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("dormant_hit")
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle_dormant") end),
        },
    },

    State{
        name = "shock",
        tags = {"busy", "activating"},

        onenter = function(inst, pushanim)
            removemoss(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("shock")
        end,

        timeline =
        {
            TimeEvent(9  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro", nil, 0.5) end),
            TimeEvent(13 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro", nil, 0.5) end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("activate")
            end),
        },
    },

    State{
        name = "activate",
        tags = {"busy", "activating"},

        onenter = function(inst, pushanim)
            removemoss(inst)

            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("activate")
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/gears_LP", "gears")
            inst.SoundEmitter:SetParameter("gears", "intensity", 0.5)
            inst:AddTag("hostile")
        end,

        timeline =
        {
            TimeEvent(2 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/active")
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/start")
            end),
            TimeEvent(4  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/active") end),
            TimeEvent(6  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/active") end),
            TimeEvent(8  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/active") end),
            TimeEvent(9  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(10 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/active") end),
            TimeEvent(12 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/active") end),
            TimeEvent(13 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(14 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/active") end),
            TimeEvent(16 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/active") end),
            TimeEvent(18 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(21 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(30 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(33 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(36 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(39 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("taunt")
            end),
        },
    },

    State{
        name = "deactivate",
        tags = {"busy", "deactivating"},

        onenter = function(inst, pushanim)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("deactivate")
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/stop")
            inst:RemoveTag("hostile")
        end,

        timeline =
        {
            TimeEvent(0  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/green") end),
            TimeEvent(9  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/green") end),
            TimeEvent(14 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/green") end),
            TimeEvent(21 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/green") end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle_dormant") end),
        },
    },

    State{
        name = "taunt",
        tags = {"busy", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("taunt")
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },

        timeline =
        {
            TimeEvent(4  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/servo") end),
            TimeEvent(17 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/servo") end),
            TimeEvent(21 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/taunt") end),
            TimeEvent(45 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/servo") end),
        },
    },

    State{
        name = "laserbeam",
        tags = { "busy", "attack" },

        onenter = function(inst, target)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("atk")
            inst.Transform:SetEightFaced()

            if target and target:IsValid() then
                if inst.components.combat:TargetIs(target) then
                    inst.components.combat:StartAttack()
                end
                inst:ForceFacePoint(target.Transform:GetWorldPosition())
                inst.sg.statemem.target = target
                inst.sg.statemem.targetpos = Vector3(target.Transform:GetWorldPosition())
            end

            inst.components.timer:StopTimer("laserbeam_cd")
            inst.components.timer:StartTimer("laserbeam_cd", TUNING.DEERCLOPS_ATTACK_PERIOD * (math.random(3) - 0.5))
        end,

        onupdate = function(inst)
            if inst.sg.statemem.lightval then
                inst.sg.statemem.lightval = inst.sg.statemem.lightval * 0.99
                SetLightValueAndOverride(inst, inst.sg.statemem.lightval, (inst.sg.statemem.lightval - 1) * 3)
            end
        end,

        timeline =
        {
            TimeEvent(2  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/laser_pre") end),
            TimeEvent(4  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/servo") end),
            TimeEvent(19 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/servo") end),
            TimeEvent(22 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/laser", "laserfilter")
                inst.SoundEmitter:SetParameter("laserfilter", "intensity", 0.12)
            end),
            TimeEvent(24 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/laser", "laserfilter")
                inst.SoundEmitter:SetParameter("laserfilter", "intensity", 0.24)
            end),
            TimeEvent(26 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/laser", "laserfilter")
                inst.SoundEmitter:SetParameter("laserfilter", "intensity", 0.48)
            end),
            TimeEvent(28 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/laser", "laserfilter")
                inst.SoundEmitter:SetParameter("laserfilter", "intensity", 0.60)
            end),
            TimeEvent(30 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/laser", "laserfilter")
                inst.SoundEmitter:SetParameter("laserfilter", "intensity", 0.72)
            end),
            TimeEvent(32 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/laser", "laserfilter")
                inst.SoundEmitter:SetParameter("laserfilter", "intensity", 0.84)
            end),
            TimeEvent(34 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/laser", "laserfilter")
                inst.SoundEmitter:SetParameter("laserfilter", "intensity", 0.96)
            end),
            TimeEvent(36 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/laser", "laserfilter")
                inst.SoundEmitter:SetParameter("laserfilter", "intensity", 1)
            end),

            TimeEvent(6 * FRAMES, function(inst) SetLightValue(inst, 0.97) end),
            TimeEvent(8  * FRAMES, function(inst) inst.Light:Enable(true) end),
            TimeEvent(8  * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.05, 0.2) end),
            TimeEvent(9  * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.10, 0.15) end),
            TimeEvent(10 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.15, 0.05) end),
            TimeEvent(11 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.20, 0.00) end),
            TimeEvent(12 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.25, 0.35) end),
            TimeEvent(13 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.30, 0.30) end),
            TimeEvent(14 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.35, 0.05) end),
            TimeEvent(15 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.40, 0.00) end),
            TimeEvent(16 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.45, 0.30) end),
            TimeEvent(17 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.50, 0.15) end),
            TimeEvent(18 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.55, 0.05) end),
            TimeEvent(19 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.60, 0.00) end),
            TimeEvent(20 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.65, 0.35) end),
            TimeEvent(21 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.70, 0.30) end),
            TimeEvent(22 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.75, 0.05) end),
            TimeEvent(23 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.80, 0.00) end),
            TimeEvent(24 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.85, 0.30) end),
            TimeEvent(25 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.90, 0.15) end),
            TimeEvent(26 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.95, 0.05) end),
            TimeEvent(27 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.00, 0.35) end),
            TimeEvent(28 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.01, 0.35) end),
            TimeEvent(29 * FRAMES, function(inst) SetLightValueAndOverride(inst, 0.90, 0.00) end),
            TimeEvent(30 * FRAMES, function(inst)
                SpawnLaser(inst)
                inst.sg.statemem.target = nil
                SetLightValueAndOverride(inst, 1.08, 0.70)
            end),
            TimeEvent(31 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.12, 1.00) end),
            TimeEvent(32 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.10, 0.90) end),
            TimeEvent(33 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.06, 0.40) end),
            TimeEvent(34 * FRAMES, function(inst) SetLightValueAndOverride(inst, 1.10, 0.60) end),
            TimeEvent(35 * FRAMES, function(inst) inst.sg.statemem.lightval = 1.1 end),
            TimeEvent(36 * FRAMES, function(inst)
                inst.sg.statemem.lightval = 1.035
                SetLightColour(inst, .9)
            end),
            TimeEvent(37 * FRAMES, function(inst)
                inst.sg.statemem.lightval = nil
                SetLightValueAndOverride(inst, .9, 0)
                SetLightColour(inst, .9)
            end),
            TimeEvent(38 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
                SetLightValue(inst, 1)
                SetLightColour(inst, 1)
                inst.Light:Enable(false)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg.statemem.keepfacing = true
                inst.sg:GoToState("idle")
            end),
        },

        onexit = function(inst)
            inst.Transform:SetFourFaced()
            SetLightValueAndOverride(inst, 1, 0)
            SetLightColour(inst, 1)

            inst.Light:Enable(false)
        end,
    },
}

CommonStates.AddWalkStates(states)
CommonStates.AddRunStates(states,
{
    starttimeline =
    {
        TimeEvent(0 * FRAMES, function(inst) inst.Physics:Stop() end ),
        TimeEvent(1 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step", "steps")
            inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
        end),
    },
    runtimeline =
    {
        TimeEvent(0 * FRAMES, function(inst)
            inst.Physics:Stop()
            inst.components.locomotor:WalkForward()
        end),
        TimeEvent(6 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step", "steps")
            inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/servo","servo")
            inst.SoundEmitter:SetParameter("servo", "intensity", math.random())
        end),
        TimeEvent(16 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step_wires", "steps")
            inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/servo", "servo")
            inst.SoundEmitter:SetParameter("servo", "intensity", math.random())
        end),
        TimeEvent(21 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step", "steps")
            inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/servo", "servo")
            inst.SoundEmitter:SetParameter("servo", "intensity", math.random())
        end),
        TimeEvent(25 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step", "steps")
            inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/servo", "servo")
            inst.SoundEmitter:SetParameter("servo", "intensity", math.random())
        end),
        TimeEvent(38 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step", "steps")
            inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/servo", "servo")
            inst.SoundEmitter:SetParameter("servo", "intensity", math.random())
        end),
        TimeEvent(48 * FRAMES, function(inst)
            inst.Physics:Stop()
        end),
    },
    endtimeline =
    {
        TimeEvent(3 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step", "steps")
            inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/servo", "servo")
            inst.SoundEmitter:SetParameter("servo", "intensity", math.random())
        end),
        TimeEvent(48 * FRAMES, function(inst)
            inst.Physics:Stop()
        end),
    },
},
{
    startrun = "walk_pre",
    run = "walk_loop",
    stoprun = "walk_pst"
}, true, nil,
{
    startonexit = function(inst)
        if not inst.AnimState:AnimDone()  then
            inst.SoundEmitter:KillSound("robo_walk_LP")
        end
    end,
    runonexit = function(inst)
        if not inst.AnimState:AnimDone()  then
            inst.SoundEmitter:KillSound("robo_walk_LP")
        end
    end,
    endonexit = function(inst)
        inst.SoundEmitter:KillSound("robo_walk_LP")
    end,
})

CommonStates.AddSimpleState(states,"hit", "hit")

return StateGraph("ancient_robot_ribs", states, events, "idle", actionhandlers)
