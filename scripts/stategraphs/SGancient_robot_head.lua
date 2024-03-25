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

    EventHandler("doattack", function(inst,data)
        if not inst.sg:HasStateTag("activating") and not inst.sg:HasStateTag("busy") then
            inst.sg:GoToState("leap_attack_pre", data.target)
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

        timeline =
        {
        },

        events =
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

            TimeEvent(2  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro", nil, 0.5) end),
            TimeEvent(5  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(7  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro", nil, 0.5) end),
            TimeEvent(10 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
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
            TimeEvent(0 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/active")
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/start")
            end),
            TimeEvent(1  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/active") end),
            TimeEvent(3  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/active") end),
            TimeEvent(5  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/active") end),
            TimeEvent(6  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/active") end),
            TimeEvent(9  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/active") end),
            TimeEvent(12 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/active") end),
            TimeEvent(14 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(16 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/active") end),
            TimeEvent(17 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(27 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(30 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(37 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(40 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(54 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
            TimeEvent(57 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/electro") end),
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
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/stop")
            inst:RemoveTag("hostile")
        end,

        timeline =
        {
            TimeEvent(5  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/green") end),
            TimeEvent(13 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/green") end),
            TimeEvent(19 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/green") end),
            TimeEvent(23 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/green") end),
            TimeEvent(38 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/green") end),
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
            TimeEvent(0  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/servo") end),
            TimeEvent(2  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/taunt") end),
            TimeEvent(12 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/step","steps")
                inst.SoundEmitter:SetParameter("steps", "intensity", .05)
            end),
            TimeEvent(17 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/servo") end),
            TimeEvent(19 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/taunt") end),
            TimeEvent(24 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/step","steps")
                inst.SoundEmitter:SetParameter("steps", "intensity", 0.08)
            end),
            TimeEvent(32 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/servo") end),
        },
    },

    State{
        name = "leap_attack_pre",
        tags = {"attack", "canrotate", "busy", "leapattack"},

        onenter = function(inst, target)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("atk_pre")
            inst.sg.statemem.startpos = Vector3(inst.Transform:GetWorldPosition())
            inst.sg.statemem.targetpos = Vector3(target.Transform:GetWorldPosition())
        end,

        timeline =
        {
            TimeEvent(7  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/servo") end),
            TimeEvent(9  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/servo") end),
            TimeEvent(11 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/servo") end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("leap_attack", {startpos = inst.sg.statemem.startpos, targetpos = inst.sg.statemem.targetpos}) end),
        },
    },

    State{
        name = "leap_attack",
        tags = {"attack", "canrotate", "busy", "leapattack"},

        onenter = function(inst, data)
            inst.sg.statemem.startpos = data.startpos
            inst.sg.statemem.targetpos = data.targetpos
            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            inst.SoundEmitter:PlaySound("dontstarve_DLC001/creatures/bearger/swhoosh")

            inst.components.combat:StartAttack()
            inst.AnimState:PlayAnimation("atk_loop")

            local range = 2
            local theta = inst.Transform:GetRotation() * DEGREES
            local offset = Vector3(range * math.cos(theta), 0, -range * math.sin(theta))
            local newloc = Vector3(inst.sg.statemem.targetpos.x + offset.x, 0, inst.sg.statemem.targetpos.z + offset.z)

            local time = inst.AnimState:GetCurrentAnimationLength()
            local dist = math.sqrt(distsq(inst.sg.statemem.startpos.x, inst.sg.statemem.startpos.z, newloc.x, newloc.z))
            local vel = dist/time

            inst.sg.statemem.vel = vel

            inst.components.locomotor:EnableGroundSpeedMultiplier(false)
            inst.Physics:SetMotorVelOverride(vel, 0, 0)

            inst.Physics:ClearCollisionMask()
            inst.Physics:CollidesWith(COLLISION.WORLD)
        end,

        timeline =
        {
            TimeEvent(0  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/servo") end),
            TimeEvent(3  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/attack") end),
            TimeEvent(25 * FRAMES, powerglow),
        },

        onexit = function(inst)
            inst.Physics:ClearMotorVelOverride()
            MakeCharacterPhysics(inst, 99999, inst.collisionradius)

            inst.components.locomotor:Stop()
            inst.components.locomotor:EnableGroundSpeedMultiplier(true)
            inst.sg.statemem.startpos = nil
            inst.sg.statemem.targetpos = nil
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("leap_attack_pst") end),
        },
    },

    State{
        name = "leap_attack_pst",
        tags = {"busy"},

        onenter = function(inst, target)
            ShakeAllCameras(CAMERASHAKE.VERTICAL, 0.5, 0.03, 2, inst, SHAKE_DIST)

            SpawnPrefab("laser_ring").Transform:SetPosition(inst.Transform:GetWorldPosition())

            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("atk_pst")
        end,

        timeline =
        {
            TimeEvent(5  * FRAMES, function(inst)DoDamage(inst, 1.5) end),
            TimeEvent(10 * FRAMES, function(inst)DoDamage(inst, 2.5) end),
            TimeEvent(15 * FRAMES, function(inst)DoDamage(inst, 3.3) end),

            TimeEvent(0  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/smash") end),
            TimeEvent(13 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/servo") end),
            TimeEvent(17 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/step") end),
            TimeEvent(31*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/step", "steps")
                inst.SoundEmitter:SetParameter("steps", "intensity", 0.08)
            end),
        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },
}

CommonStates.AddWalkStates(
    states,
    {
        walktimeline =
        {
            --------------------------------------------
            -- TimeEvent(6*FRAMES, function(inst)       
            --     if inst:HasTag("robot_ribs") then
            --        inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step" "steps")
            --        inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
            --     end
            -- end),
            -- TimeEvent(16*FRAMES, function(inst)       
            --     if inst:HasTag("robot_ribs") then
            --        inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step" "steps")
            --        inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
            --     end
            -- end),
            -- TimeEvent(21*FRAMES, function(inst)       
            --     if inst:HasTag("robot_ribs") then
            --        inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step" "steps")
            --        inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
            --     end
            -- end),
            -- TimeEvent(25*FRAMES, function(inst)       
            --     if inst:HasTag("robot_ribs") then
            --        inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step" "steps")
            --        inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
            --     end
            -- end),
            -- TimeEvent(38*FRAMES, function(inst)       
            --     if inst:HasTag("robot_ribs") then
            --        inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/ribs/step" "steps")
            --        inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
            --     end
            -- end),

            -- TimeEvent(16*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.walk) end),
            -- TimeEvent(21*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.walk) end),
            -- TimeEvent(25*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.walk) end),
            -- TimeEvent(38*FRAMES, function(inst) inst.SoundEmitter:PlaySound(inst.sounds.walk) end),    
            --------------------------------------------
        }
    })

CommonStates.AddRunStates( states,
{
    starttimeline =
    {
        TimeEvent(0*FRAMES, function(inst)
            inst.Physics:Stop()
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/servo", "servo")
            inst.SoundEmitter:SetParameter("servo", "intensity", math.random())
        end),
    },
    runtimeline =
    {
        TimeEvent(0 * FRAMES, function(inst)
            inst.Physics:Stop()
            inst.components.locomotor:WalkForward()
        end),
        TimeEvent(1 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/servo", "servo")
            inst.SoundEmitter:SetParameter("servo", "intensity", math.random())
        end),
        TimeEvent(17 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/creatures/enemy/metal_robot/head/step", "steps")
            inst.SoundEmitter:SetParameter("steps", "intensity", math.random())
        end),
        TimeEvent(48*FRAMES, function(inst)
            inst.Physics:Stop()
        end),
    },
    endtimeline =
    {
        TimeEvent(48*FRAMES, function(inst)
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

CommonStates.AddSimpleState(states, "hit", "hit")

return StateGraph("ancient_robot_head", states, events, "idle", actionhandlers)
