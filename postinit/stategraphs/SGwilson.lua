local AddStategraphState = AddStategraphState
local AddStategraphEvent = AddStategraphEvent
local AddStategraphActionHandler = AddStategraphActionHandler
local AddStategraphPostInit = AddStategraphPostInit
GLOBAL.setfenv(1, GLOBAL)

require("stategraphs/commonstates")

local function shoot(inst, is_full_charge)
    local player = inst
    local rotation = player.Transform:GetRotation()
    local pt = Vector3(player.Transform:GetWorldPosition())
    local angle = rotation * DEGREES
    local radius = 2.5
    local offset = Vector3(radius * math.cos( angle ), 0, -radius * math.sin( angle ))
    local newpt = pt+offset

    if is_full_charge then
        local beam = SpawnPrefab("ancient_hulk_orb")
        beam.AnimState:PlayAnimation("spin_loop", true)
        beam.Transform:SetPosition(newpt.x, newpt.y, newpt.z)
        beam.host = player

        local targetpos = TheInput:GetWorldPosition()
        local controller_mode = TheInput:ControllerAttached()
        if controller_mode then
            targetpos = Vector3(player.player_classified.livingartifact:value().components.reticule.reticule.Transform:GetWorldPosition())
        end

        beam.components.pl_complexprojectile:SetHorizontalSpeed(60)
        beam.components.pl_complexprojectile:SetGravity(-1)
        beam.components.pl_complexprojectile:Launch(targetpos, player)
        beam.components.combat.proxy = inst
        beam.owner = inst
    else
        local beam = SpawnPrefab("ancient_hulk_orb_small")
        beam.Transform:SetPosition(newpt.x, 1, newpt.z)
        beam.Transform:SetRotation(rotation)
        beam.AnimState:PlayAnimation("spin_loop",true)
        beam.components.combat.proxy = inst
        beam.host = player
    end
end

local actionhandlers = {
    ActionHandler(ACTIONS.HACK, function(inst)
        if inst:HasTag("ironlord") then
            return not inst.sg:HasStateTag("working") and "ironlord_work" or nil
        end
        if inst:HasTag("beaver") then
            return not inst.sg:HasStateTag("gnawing") and "gnaw" or nil
        end
        return not inst.sg:HasStateTag("prehack") and (inst.sg:HasStateTag("hacking") and "hack" or "hack_start") or nil
    end),
    ActionHandler(ACTIONS.PAN, function(inst)
        if not inst.sg:HasStateTag("panning") then
            return "pan_start"
        end
    end),
    ActionHandler(ACTIONS.SHEAR, function(inst)
        if not inst.sg:HasStateTag("preshear") then
            if inst.sg:HasStateTag("shearing") then
                return "shear"
            else
                return "shear_start"
            end
        end
    end),
    ActionHandler(ACTIONS.USE_LIVING_ARTIFACT, "give"),
}

local eventhandlers = {
    EventHandler("sneeze", function(inst, data)
        if not inst.components.health:IsDead() and not inst.components.health:IsInvincible() then
            if inst.sg:HasStateTag("busy") then
                inst.sg.wantstosneeze = true
            else
                inst.sg:GoToState("sneeze")
            end
        end
    end),
}

local plant_symbols =
{
    "waterpuddle",
    "sparkle",
    "puddle",
    "plant",
    "lunar_mote3",
    "lunar_mote",
    "glow",
    "blink"
}

local states = {
    State{
        name = "mounted_poison_idle",
        tags = {"idle", "canrotate"},

        onenter = function(inst)
            if inst.components.poisonable and inst.components.poisonable:IsPoisoned() then
                inst.AnimState:PlayAnimation("idle_poison_pre")
                inst.AnimState:PushAnimation("idle_poison_loop")
                inst.AnimState:PushAnimation("idle_poison_pst", false)
            end
        end,

        events =
        {
            EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "hack_start",
        tags = {"prehack", "working"},

        onenter = function(inst)
            inst.components.locomotor:Stop()

            local buffaction = inst:GetBufferedAction()
            local tool = buffaction ~= nil and buffaction.invobject or nil
            local hacksymbols = tool ~= nil and tool.hack_overridesymbols or nil

            if hacksymbols ~= nil then
                hacksymbols[3] = tool:GetSkinBuild()
                if hacksymbols[3] ~= nil then
                    inst.AnimState:OverrideItemSkinSymbol("swap_machete", hacksymbols[3], hacksymbols[1], tool.GUID, hacksymbols[2])
                else
                    inst.AnimState:OverrideSymbol("swap_machete", hacksymbols[1], hacksymbols[2])
                end
                inst.AnimState:PlayAnimation("hack_pre")
            else
                inst.AnimState:PlayAnimation("chop_pre")
            end

        end,

        events = {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("hack")
                end
            end),
        },
    },

    State{
        name = "hack",
        tags = {"prehack", "hacking", "working"},

        onenter = function(inst)
            inst.sg.statemem.action = inst:GetBufferedAction()
            local tool = inst.sg.statemem.action ~= nil and inst.sg.statemem.action.invobject or nil
            local hacksymbols = tool ~= nil and tool.hack_overridesymbols or nil

            -- Note this is used to make sure the tool symbol is still the machete even when inventory hacking
            if hacksymbols ~= nil then
                -- This code only needs to run when hacking a coconut but im running it regardless to prevent hiding issues
                hacksymbols[3] = tool:GetSkinBuild()
                if hacksymbols[3] ~= nil then
                    inst.AnimState:OverrideItemSkinSymbol("swap_machete", hacksymbols[3], hacksymbols[1], tool.GUID, hacksymbols[2])
                else
                    inst.AnimState:OverrideSymbol("swap_machete", hacksymbols[1], hacksymbols[2])
                end
                inst.AnimState:PlayAnimation("hack_loop")
            else
                inst.AnimState:PlayAnimation("chop_loop")
            end
        end,

        timeline = {
            TimeEvent(2 * FRAMES, function(inst)
                inst:PerformBufferedAction()
            end),


            TimeEvent(9 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("prehack")
            end),

            TimeEvent(14 * FRAMES, function(inst)
                if inst.components.playercontroller ~= nil and
                inst.components.playercontroller:IsAnyOfControlsPressed(
                CONTROL_PRIMARY, CONTROL_ACTION, CONTROL_CONTROLLER_ACTION) and
                inst.sg.statemem.action ~= nil and
                inst.sg.statemem.action:IsValid() and
                inst.sg.statemem.action.target ~= nil and
                inst.sg.statemem.action.target.components.hackable ~= nil and
                inst.sg.statemem.action.target.components.hackable:CanBeHacked() and
                inst.sg.statemem.action.target:IsActionValid(inst.sg.statemem.action.action) and
                CanEntitySeeTarget(inst, inst.sg.statemem.action.target) then
                    inst:ClearBufferedAction()
                    inst:PushBufferedAction(inst.sg.statemem.action)
                end
            end),

            TimeEvent(16 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("hacking")
            end),
        },

        events = {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "pan_start",
        tags = {"prepan", "working"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("pan_pre")
        end,

        events =
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg.statemem.panning = true
                    inst.sg:GoToState("pan")
                end
            end),
        },

        onexit = function(inst)
            if not inst.sg.statemem.panning then
                inst:RemoveTag("prepan")
            end
        end,
    },

    State{
        name = "pan",
        tags = {"prepan", "panning", "working"},

        onenter = function(inst)
            inst.sg.statemem.action = inst:GetBufferedAction()
            inst.AnimState:PlayAnimation("pan_loop", true)
            inst.sg:SetTimeout(1 + math.random())
        end,

        timeline=
        {
            TimeEvent(6 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/harvested/pool/pan") end),
            TimeEvent(14 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/harvested/pool/pan") end),
            TimeEvent(21 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/harvested/pool/pan") end),
            TimeEvent(29 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/harvested/pool/pan") end),
            TimeEvent(36 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/harvested/pool/pan") end),
            TimeEvent(44 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/harvested/pool/pan") end),
            TimeEvent(51 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/harvested/pool/pan") end),
            TimeEvent(59 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/harvested/pool/pan") end),
            TimeEvent(66 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/harvested/pool/pan") end),
            TimeEvent(74 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/harvested/pool/pan") end),
        },

        ontimeout = function(inst)
            inst:PerformBufferedAction()
            inst.AnimState:PlayAnimation("pan_pst")
            inst.sg:GoToState("idle", true)
        end,

        events =
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "shear_start",
        tags = {"preshear", "working"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("cut_pre")
        end,

        events =
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("shear")
                end
            end),
        },
    },

    State{
        name = "shear",
        tags = {"preshear", "shearing", "working"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("cut_loop")
            inst.sg.statemem.action = inst:GetBufferedAction()
        end,

        timeline =
        {
            TimeEvent(4 * FRAMES, function(inst)
                inst:PerformBufferedAction()
                inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/harvested/grass_tall/shears")
            end),

            TimeEvent(9 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("preshear")
            end),

            TimeEvent(14 * FRAMES, function(inst)
                if inst.components.playercontroller ~= nil
                    and inst.components.playercontroller:IsAnyOfControlsPressed(CONTROL_PRIMARY, CONTROL_ACTION, CONTROL_CONTROLLER_ACTION) and
                    inst.sg.statemem.action and
                    inst.sg.statemem.action:IsValid() and
                    inst.sg.statemem.action.target and
                    inst.sg.statemem.action.target.components.shearable and
                    inst.sg.statemem.action.target.components.shearable:CanShear() and
                    inst.sg.statemem.action.target:IsActionValid(inst.sg.statemem.action.action) and
                    CanEntitySeeTarget(inst, inst.sg.statemem.action.target)
                then
                    inst:ClearBufferedAction()
                    inst:PushBufferedAction(inst.sg.statemem.action)
                end
            end),

            TimeEvent(16 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("shearing")
            end),
        },

        events =
        {
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.AnimState:PlayAnimation("cut_pst")
                    inst.sg:GoToState("idle", true)
                end
            end),
        },
    },

    State{
        name = "sneeze",
        tags = {"busy", "sneeze", "nopredict"},

        onenter = function(inst)
            if inst.components.drownable ~= nil and inst.components.drownable:ShouldDrown() then
                inst.sg:GoToState("sink_fast")
                return
            end

            inst.sg.wantstosneeze = false
            inst.components.locomotor:Stop()
            inst.components.locomotor:Clear()

            inst.SoundEmitter:PlaySound("dontstarve/wilson/hit", nil, .02)
            inst.AnimState:PlayAnimation("sneeze")
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/characters/sneeze")
            inst:ClearBufferedAction()

            if not inst:HasTag("mime") then
                local sound_name = inst.soundsname or inst.prefab
                local path = inst.talker_path_override or "dontstarve/characters/"

                local sound_event = path .. sound_name .. "/hurt"
                inst.SoundEmitter:PlaySound(inst.hurtsoundoverride or sound_event)
            end

            inst.components.talker:Say(GetString(inst, "ANNOUNCE_SNEEZE"))
        end,

        timeline =
        {
            TimeEvent(10 * FRAMES, function(inst)
                if inst.components.hayfever then
                    inst.components.hayfever:DoSneezeEffects()
                end
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "rebirth_floweroflife",
        tags = {"nopredict", "silentmorph"},

        onenter = function(inst, source)
            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:Enable(false)
            end
            inst.AnimState:PlayAnimation("rebirth2")

            local skin_build = source and source:GetSkinBuild() or nil
            if skin_build ~= nil then
                for k,v in pairs(plant_symbols) do
                    inst.AnimState:OverrideItemSkinSymbol(v, skin_build, v, inst.GUID, "lifeplant")
                end
            else
                for k,v in pairs(plant_symbols) do
                    inst.AnimState:OverrideSymbol(v, "lifeplant", v)
                end
            end

            inst.components.health:SetInvincible(true)
            inst:ShowHUD(false)
            inst:SetCameraDistance(12) -- TODO: Do not set to 12 if interior
        end,

        timeline =
        {
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            for k, v in pairs(plant_symbols) do
                inst.AnimState:ClearOverrideSymbol(v)
            end

            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:Enable(true)
            end

            inst.components.health:SetInvincible(false)
            inst:ShowHUD(true)
            inst:SetCameraDistance()

            SerializeUserSession(inst)
        end,
    },

    State{
        name = "castspell_bone",
        tags = {"doing", "busy", "canrotate", "spell"},

        onenter = function(inst)
            if inst.components.playercontroller ~= nil then
                inst.components.playercontroller:Enable(false)
            end
            inst.AnimState:PlayAnimation("staff_pre")
            inst.AnimState:PushAnimation("staff", false)
            inst.components.locomotor:Stop()

            --Spawn an effect on the player's location
            local staff = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local colour = staff and staff.fxcolour or {1, 1, 1}

            inst.sg.statemem.stafffx = SpawnPrefab(inst.components.rider:IsRiding() and "staffcastfx_mount" or "staffcastfx")
            inst.sg.statemem.stafffx.entity:SetParent(inst.entity)
            inst.sg.statemem.stafffx:SetUp(colour)

            inst.sg.statemem.stafflight = SpawnPrefab("staff_castinglight")
            inst.sg.statemem.stafflight.Transform:SetPosition(inst.Transform:GetWorldPosition())
            inst.sg.statemem.stafflight:SetUp(colour, 1.9, 0.33)

            inst.sg.statemem.castsound = (staff and staff.skin_castsound or staff.castsound) or "dontstarve/wilson/use_gemstaff"
        end,

        onexit = function(inst)
            if inst.components.playercontroller then
                inst.components.playercontroller:Enable(true)
            end
            if inst.sg.statemem.stafffx and inst.sg.statemem.stafffx:IsValid() then
                inst.sg.statemem.stafffx:Remove()
            end
            if inst.sg.statemem.stafflight and inst.sg.statemem.stafflight:IsValid() then
                inst.sg.statemem.stafflight:Remove()
            end
        end,

        timeline =
        {
            TimeEvent(13 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/use_gemstaff")
                inst:PerformBufferedAction()
            end),
            TimeEvent(60 * FRAMES, function(inst)
                local staff = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if staff and staff.endcast then
                    staff.endcast(staff)
                end

                inst.sg:RemoveStateTag("busy")
				if inst.components.playercontroller ~= nil then
					inst.components.playercontroller:Enable(true)
				end
            end),
        },

        events = {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
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

            if inst.rightbuttondown then
                inst.sg:GoToState("ironlord_charge")
            end
        end,

       events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("ironlord_idle")
            end),
        },
    },

    State {
        name = "ironlord_morph",
        tags = {"busy"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("morph_idle")
            inst.AnimState:PushAnimation("morph_complete", false)
        end,

        timeline =
        {
            TimeEvent(0   * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/music/iron_lord") end),
            TimeEvent(15  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/iron_lord/morph") end),
            TimeEvent(105 * FRAMES, function(inst) ShakeAllCameras(CAMERASHAKE.FULL, 0.7, 0.02, 0.5, inst, 40) end),
            TimeEvent(105 * FRAMES, function(inst) inst.AnimState:Hide("beard") end),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                inst.sg:GoToState("ironlord_idle")
            end),
        },

        onexit = function(inst)
            inst:PushEvent("ironlord_morph_complete")
        end,
    },

    State{
        name = "ironlord_work",
        tags = {"busy", "working"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("power_punch")
            inst.sg.statemem.action = inst:GetBufferedAction()
        end,

        timeline =
        {
            TimeEvent(8  * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/iron_lord/punch", nil, 0.5) end),
            TimeEvent(6  * FRAMES, function(inst) inst:PerformBufferedAction() end),
            TimeEvent(14 * FRAMES, function(inst) inst.sg:RemoveStateTag("working") inst.sg:RemoveStateTag("busy") inst.sg:AddStateTag("idle") end),
            TimeEvent(15 * FRAMES, function(inst)
                if (TheInput:IsMouseDown(MOUSEBUTTON_LEFT) or -- TODO
                   TheInput:IsKeyDown(KEY_SPACE)) and
                    inst.sg.statemem.action and
                    inst.sg.statemem.action:IsValid() and
                    inst.sg.statemem.action.target and
                    inst.sg.statemem.action.target:IsActionValid(inst.sg.statemem.action.action) and
                    (inst.sg.statemem.action.target.components.workable or inst.sg.statemem.action.target.components.hackable) then
                        inst:ClearBufferedAction()
                        inst:PushBufferedAction(inst.sg.statemem.action)
                end
            end),
        },

        -- events =
        -- {
        --     EventHandler("animover", function(inst)
        --         if inst.AnimState:AnimDone() then
        --             inst.sg:GoToState("ironlord_idle")
        --         end
        --     end),
        -- },
    },

    State{
        name = "ironlord_usedoor",
        tags = {"doing", "canrotate"},

        onenter = function(inst)
            inst.sg.statemem.action = inst:GetBufferedAction()
            inst.components.locomotor:Stop()
            inst:PerformBufferedAction()
            inst.sg:GoToState("ironlord_idle")
        end,
    },

    State{
        name = "ironlord_charge",
        tags = {"busy", "doing"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("charge_pre")
            inst.AnimState:PushAnimation("charge_grow")
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/iron_lord/charge_up_LP", "chargedup")

            inst.sg.statemem.ready_to_shoot = false
            inst.sg.statemem.should_shoot = false
        end,

        onexit = function(inst)
            inst:ClearBufferedAction()
        end,

        onupdate = function(inst)
            if not (TheInput:IsKeyDown(CONTROL_SECONDARY) or TheInput:IsKeyDown(CONTROL_CONTROLLER_ALTACTION)) then
                inst.sg.statemem.should_shoot = true
            end

            if inst.sg.statemem.should_shoot and inst.sg.statemem.ready_to_shoot then
                inst.SoundEmitter:PlaySoundWithParams("dontstarve_DLC003/common/crafted/iron_lord/smallshot", {timeoffset = math.random()})
                inst.SoundEmitter:KillSound("chargedup")
                inst.sg:GoToState("ironlord_shoot", false)
            end

            local controller_mode = TheInput:ControllerAttached()
            if controller_mode then
                local reticulepos = Vector3(inst.livingartifact.components.reticule.reticule.Transform:GetWorldPosition())
                inst:ForceFacePoint(reticulepos)
            else
                local mousepos = TheInput:GetWorldPosition()
                inst:ForceFacePoint(mousepos)
            end
        end,

        timeline =
        {
            TimeEvent(15 * FRAMES, function(inst) inst.sg.statemem.ready_to_shoot = true end),
            TimeEvent(20 * FRAMES, function(inst) inst.sg:GoToState("ironlord_charge_full") end),
        },
    },

    State{
        name = "ironlord_chage_full",
        tags = {"busy", "doing"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("charge_super_pre")
            inst.AnimState:PushAnimation("charge_super_loop", true)
            inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/iron_lord/electro")

            inst.sg.statemem.ready_to_shoot = false
            inst.sg.statemem.should_shoot = false
        end,

        onexit = function(inst)
            inst:ClearBufferedAction()
            inst.SoundEmitter:KillSound("chargedup")
        end,

        onupdate = function(inst)
            if not (TheInput:IsKeyDown(CONTROL_SECONDARY) or TheInput:IsKeyDown(CONTROL_CONTROLLER_ALTACTION)) then
                inst.sg.statemem.should_shoot = true
            end

            if inst.sg.statemem.should_shoot and inst.sg.statemem.ready_to_shoot then
                inst.SoundEmitter:PlaySoundWithParams("dontstarve_DLC003/creatures/boss/hulk_metal_robot/laser",  {intensity = math.random(0.7, 1)})

                inst.sg:GoToState("ironlord_shoot", true)
            end

            local controller_mode = TheInput:ControllerAttached()
            if controller_mode then
                local reticulepos = Vector3(inst.livingartifact.components.reticule.reticule.Transform:GetWorldPosition())
                inst:ForceFacePoint(reticulepos)
            else
                local mousepos = TheInput:GetWorldPosition()
                inst:ForceFacePoint(mousepos)
            end
        end,

        timeline =
        {
            TimeEvent(5 * FRAMES, function(inst) inst.sg.statemem.ready_to_shoot = true end),
        },
    },

    State{
        name = "ironlord_shoot",
        tags = {"busy"},

        onenter = function(inst, is_full_charge)
            inst.components.locomotor:Stop()
            if is_full_charge then
                inst.AnimState:PlayAnimation("charge_super_pst")
            else
                inst.AnimState:PlayAnimation("charge_pst")
            end
            inst.sg.statemem.is_full_charge = is_full_charge
        end,

        timeline =
        {
            TimeEvent(1 * FRAMES, function(inst) shoot(inst, inst.sg.statemem.is_full_charge) end),
            TimeEvent(5 * FRAMES, function(inst) inst.sg:RemoveStateTag("busy") end),

        },

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("ironlord_idle") end),
        },
    },

    State{
        name = "ironlord_explode",
        tags = {"busy"},

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("suit_destruct")
        end,

        timeline =
        {
            TimeEvent(4  * FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve_DLC003/common/crafted/iron_lord/small_explosion", {intensity = 0.2}) end),
            TimeEvent(8  * FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve_DLC003/common/crafted/iron_lord/small_explosion", {intensity = 0.4}) end),
            TimeEvent(12 * FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve_DLC003/common/crafted/iron_lord/small_explosion", {intensity = 0.6}) end),
            TimeEvent(19 * FRAMES, function(inst) inst.SoundEmitter:PlaySoundWithParams("dontstarve_DLC003/common/crafted/iron_lord/small_explosion", {intensity = 1.0}) end),
            TimeEvent(26 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/iron_lord/electro", nil, 0.5) end),
            TimeEvent(35 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/iron_lord/electro", nil, 0.5) end),
            TimeEvent(54 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/iron_lord/explosion") end),

            TimeEvent(52 * FRAMES, function(inst)
                local explosion = SpawnPrefab("living_suit_explode_fx")
                explosion.Transform:SetPosition(inst.Transform:GetWorldPosition())
                --inst.livingartifact.DoDamage(inst.livingartifact, 5)
            end),
        },

        onexit = function(inst)
            inst:PushEvent("revert")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("ironlord_idle")
            end),
        },
    },

    State{
        name = "ironlord_hit",
        tags = {"hit", "busy"},

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("hit")
			CommonHandlers.UpdateHitRecoveryDelay(inst)
        end,

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("ironlord_idle")
                end
            end),
        },
    },

    State{
        name = "ironlord_attack",
        tags = {"attack", "busy"},

        onenter = function(inst, target)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PlayAnimation("power_punch")
            inst.components.combat:StartAttack()
            inst.sg.statemem.target = target
        end,

        timeline =
        {
            TimeEvent(0 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/iron_lord/punch_pre") end),
            TimeEvent(8 * FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/iron_lord/punch") end),
            TimeEvent(6 * FRAMES, function(inst) inst:PerformBufferedAction() end),
            TimeEvent(7 * FRAMES, function(inst) inst.sg:RemoveStateTag("attack") inst.sg:RemoveStateTag("busy") inst.sg:AddStateTag("idle") end),
        },

        events =
        {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("ironlord_idle")
                end
            end),
        },
    },
}

for _, actionhandler in ipairs(actionhandlers) do
    AddStategraphActionHandler("wilson", actionhandler)
end

for _, eventhandler in ipairs(eventhandlers) do
    AddStategraphEvent("wilson", eventhandler)
end

for _, state in ipairs(states) do
    AddStategraphState("wilson", state)
end

AddStategraphPostInit("wilson", function(sg)
    local _attack_deststate = sg.actionhandlers[ACTIONS.ATTACK].deststate
    sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, ...)
        if inst:HasTag("ironlord") then
            return "ironlord_attack"
        end
        if not inst.sg:HasStateTag("sneeze") then
            return _attack_deststate and _attack_deststate(inst, ...)
        end
    end

    local _idle_onenter = sg.states["idle"].onenter
    sg.states["idle"].onenter = function(inst, ...)
        if not (inst.components.drownable ~= nil and inst.components.drownable:ShouldDrown()) then
            if inst.sg.wantstosneeze then
                inst.components.locomotor:Stop()
                inst.components.locomotor:Clear()

                inst.sg:GoToState("sneeze")
                return
            end
        end

        if _idle_onenter ~= nil then
            return _idle_onenter(inst, ...)
        end
    end

    local _mounted_idle_onenter = sg.states["mounted_idle"].onenter
    sg.states["mounted_idle"].onenter = function(inst, ...)
        if inst.sg.wantstosneeze then
            inst.sg:GoToState("sneeze")
            return
        end

        local equippedArmor = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
        if (equippedArmor ~= nil and equippedArmor:HasTag("band")) or
            not (inst.components.poisonable and inst.components.poisonable:IsPoisoned()) then
            if _mounted_idle_onenter ~= nil then
                return _mounted_idle_onenter(inst, ...)
            end
        else
            inst.sg:GoToState("mounted_poison_idle")
        end
    end

    local _funnyidle_onenter = sg.states["funnyidle"].onenter
    sg.states["funnyidle"].onenter = function(inst, ...)
        if inst.components.poisonable and inst.components.poisonable:IsPoisoned() then
            inst.AnimState:PlayAnimation("idle_poison_pre")
            inst.AnimState:PushAnimation("idle_poison_loop")
            inst.AnimState:PushAnimation("idle_poison_pst", false)
        elseif _funnyidle_onenter then
            _funnyidle_onenter(inst, ...)
        end
    end

    local _castspell_deststate = sg.actionhandlers[ACTIONS.CASTSPELL].deststate
    sg.actionhandlers[ACTIONS.CASTSPELL].deststate = function(inst, action)
        local staff = action.invobject or action.doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if staff:HasTag("bonestaff") then
            return "castspell_bone"
        else
            return _castspell_deststate and _castspell_deststate(inst, action)
        end
    end

    local _chop_deststate = sg.actionhandlers[ACTIONS.CHOP].deststate
    sg.actionhandlers[ACTIONS.CHOP].deststate = function(inst, action)
        if inst:HasTag("ironlord") then
            return "ironlord_work"
        else
            return _chop_deststate(inst, action)
        end
    end

    local _mine_deststate = sg.actionhandlers[ACTIONS.MINE].deststate
    sg.actionhandlers[ACTIONS.MINE].deststate = function(inst, action)
        if inst:HasTag("ironlord") then
            return "ironlord_work"
        else
            return _mine_deststate(inst, action)
        end
    end

    local _dig_deststate = sg.actionhandlers[ACTIONS.DIG].deststate
    sg.actionhandlers[ACTIONS.DIG].deststate = function(inst, action)
        if inst:HasTag("ironlord") then
            return "ironlord_work"
        else
            return _dig_deststate(inst, action)
        end
    end

    local _hammer_deststate = sg.actionhandlers[ACTIONS.HAMMER].deststate
    sg.actionhandlers[ACTIONS.HAMMER].deststate = function(inst, action)
        if inst:HasTag("ironlord") then
            return "ironlord_work"
        else
            return _hammer_deststate(inst, action)
        end
    end

    local _attacked_handler_fn = sg.events["attacked"].fn
    sg.events["attacked"] = EventHandler("attacked", function(inst, data)
        if inst:HasTag("ironlord") then
            inst.sg:GoToState("ironlord_hit")
        else
            _attacked_handler_fn(inst, data)
        end
    end)
end)
