local AncientHulkUtil = require("prefabs/ancient_hulk_util")

local setfires = AncientHulkUtil.setfires
local ApplyDamageToEntities = AncientHulkUtil.ApplyDamageToEntities

local assets =
{
	Asset("ANIM", "anim/living_artifact.zip"),
    Asset("ANIM", "anim/living_suit_build.zip"),
}

local function DoDamage(inst, rad, startang, endang, spawnburns)
    local targets = {}
    local x, y, z = GetPlayer().Transform:GetWorldPosition()
    local angle = nil
    if startang and endang then
        startang = startang + 90
        endang = endang + 90

        local down = TheCamera:GetDownVec()
        angle = math.atan2(down.z, down.x)/DEGREES
    end

    setfires(x,y,z, rad)
    for i, v in ipairs(TheSim:FindEntities(x, 0, z, rad, nil, { "laser", "DECOR", "INLIMBO" })) do  --  { "_combat", "pickable", "campfire", "CHOP_workable", "HAMMER_workable", "MINE_workable", "DIG_workable" }
        local dodamage = true
        if startang and endang then
            local dir = inst:GetAngleToPoint(Vector3(v.Transform:GetWorldPosition()))

            local dif = angle - dir
            while dif > 450 do
                dif = dif - 360
            end
            while dif < 90 do
                dif = dif + 360
            end
            if dif < startang or dif > endang then
                dodamage = nil
            end
        end
        if dodamage then
            targets = ApplyDamageToEntities(inst,v, targets, rad)
        end
    end
end

local function IronLordhurt(inst, delta)
    if delta < 0 then
        inst.sg:PushEvent("attacked")
    end

    return true
end

local function SavePlayerData(player)
    local data = {}

    data.build = player.AnimState:GetBuild()
    data.skins = player.components.skinner:GetClothing()

    data.health_redirect = player.components.health.redirect

    -- Wagstaff stuff
    -- data.wasnearsighted = player.components.vision.nearsighted

    return data
end

local function LoadPlayerData(player, data)
    player.AnimState:ClearOverrideBuild("living_suit_build_morph")
    player.AnimState:SetBuild(data.build)
    player.components.skinner:SetSkinName(data.skins.base, true)
    for _, skin in pairs(data.skins) do
        player.components.skinner:SetClothing(skin)
    end

    player.components.health.redirect = data.health_redirect

    -- Wagstaff stuff
    -- player.components.vision.nearsighted = data.wasnearsighted
    -- player.components.vision:CheckForGlasses()
end

local function ironactionstring(inst, action)
    if action.action.id == "CHARGE_UP" then
        return STRINGS.ACTIONS.CHARGE_UP
    end
    return STRINGS.ACTIONS.PUNCH
end

local function ArtifactActionButton(inst)

    local action_target = FindEntity(inst, 6, function(guy) return (guy.components.door and not guy.components.door.disabled and (not guy.components.burnable or not guy.components.burnable:IsBurning())) or
                                                             (guy.components.workable and guy.components.workable.workable and inst.components.worker:CanDoAction(guy.components.workable.action)) or
                                                             (guy.components.hackable and guy.components.hackable:CanBeHacked() and inst.components.worker:CanDoAction(ACTIONS.HACK)) end)

    if not inst.sg:HasStateTag("busy") and action_target then
        if action_target.components.door and not action_target.components.door.disabled and (not action_target.components.burnable or not action_target.components.burnable:IsBurning()) then
            return BufferedAction(inst, action_target, ACTIONS.USEDOOR)
        elseif action_target.components.workable and action_target.components.workable.workable and action_target.components.workable.workleft > 0 then
            return BufferedAction(inst, action_target, action_target.components.workable.action)
        elseif action_target.components.hackable and action_target.components.hackable:CanBeHacked() and action_target.components.hackable.hacksleft > 0 then
            return BufferedAction(inst, action_target, ACTIONS.HACK)
        end
    end

end

local function LeftClickPicker(inst, target_ent, pos)

    if target_ent and target_ent.components.door and not target_ent.components.door.disabled and (not target_ent.components.burnable or not target_ent.components.burnable:IsBurning()) then
        return inst.components.playeractionpicker:SortActionList({ACTIONS.USEDOOR}, target_ent, nil)
    end

    if inst.components.combat:CanTarget(target_ent) then
        return inst.components.playeractionpicker:SortActionList({ACTIONS.ATTACK}, target_ent, nil)
    end

    if target_ent and target_ent.components.workable and target_ent.components.workable.workable 
        and target_ent.components.workable.workleft > 0 and inst.components.worker and inst.components.worker:CanDoAction(target_ent.components.workable.action) then
        return inst.components.playeractionpicker:SortActionList({target_ent.components.workable.action}, target_ent, nil)
    end

    if target_ent and target_ent.components.hackable and target_ent.components.hackable:CanBeHacked() and target_ent.components.hackable.hacksleft > 0 and inst.components.worker:CanDoAction(ACTIONS.HACK) then
        return inst.components.playeractionpicker:SortActionList({ACTIONS.HACK}, target_ent, nil)
    end
end

local function RightClickPicker(inst, target_ent, pos)
    if not inst.sg:HasStateTag("charging") then
        return inst.components.playeractionpicker:SortActionList({ACTIONS.CHARGE_UP}, nil, nil)
    end
    return {}
end

local function BecomeIronLord_post(inst)
    inst.player.components.skinner:SetSkinName("", nil, true)
    inst.player.components.skinner:ClearAllClothing()
    inst.player.AnimState:SetBuild("living_suit_build")

    local controller_mode = TheInput:ControllerAttached()
    if controller_mode and inst.components.reticule and not inst.components.reticule.reticule then
        inst.components.reticule:CreateReticule()
        inst.components.reticule.reticule:Show()
    end
end

local function BecomeIronLord(inst, instant)
    local player = inst.player

    inst.player_data = SavePlayerData(player)

    inst.AnimState:Hide("beard")
    player.AnimState:AddOverrideBuild("player_living_suit_morph")

    player:AddTag("fireimmune")
    player:AddTag("has_gasmask")
    player:AddTag("ironlord")
    player:AddTag("laser_immune")
    player:AddTag("mech")

    player.player_classified.living_artifact:set(inst)

    player.ActionStringOverride = ironactionstring
    player.components.playercontroller.actionbuttonoverride = ArtifactActionButton
    player.components.playeractionpicker.leftclickoverride = LeftClickPicker
    player.components.playeractionpicker.rightclickoverride = RightClickPicker

    player.components.combat:SetDefaultDamage(TUNING.IRON_LORD_DAMAGE)
    player.components.inventory:DropEverything()
    player.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED * 1.3

    player.components.grogginess:SetEnableSpeedMod(false)

    if player.components.poisonable then
        player.components.poisonable:SetBlockAll(true)
    end

    player.components.temperature:SetTemp(20)
    player:StopUpdatingComponent(player.components.temperature)

    player.components.health:SetPercent(1)
    player.components.health.redirect = IronLordhurt

    if player.components.oldager then
        player:StopUpdatingComponent(player.components.oldager)
    end

    player.components.hunger:Pause()
    player.components.hunger:SetPercent(1)

    player.components.sanity:SetPercent(1)
    player.components.sanity.ignore = true

    player:AddComponent("worker")
    player.components.worker:SetAction(ACTIONS.DIG, 1)
    player.components.worker:SetAction(ACTIONS.CHOP, 4)
    player.components.worker:SetAction(ACTIONS.MINE, 3)
    player.components.worker:SetAction(ACTIONS.HAMMER, 3)
    player.components.worker:SetAction(ACTIONS.HACK, 2)

    -- Wagstaff stuff
    -- player.components.vision.nearsighted = false
    -- player.components.vision:CheckForGlasses()

    player:PushEvent("livingartifactoveron")

    inst.nightlight = SpawnPrefab("living_artifact_light")
    player:AddChild(inst.nightlight)

    if player:HasTag("lightsource") then
        player:RemoveTag("lightsource")
    end

    inst:AddTag("notslippery")
    inst:AddTag("cantdrop")

    inst:PushEvent("start_flashing")

    inst:AddComponent("reticule")
    inst.components.reticule.targetfn = function()
        local offset = player.components.playercontroller:GetWorldControllerVector()
        if offset then
            local newpt = Vector3(player.Transform:GetWorldPosition())
            newpt.x = newpt.x + offset.x * 8
            newpt.z = newpt.z + offset.z * 8
            return newpt
        end
    end

    inst:StartUpdatingComponent(inst.components.livingartifact)

    if not instant then
        player.sg:GoToState("ironlord_morph")
        player:DoTaskInTime(2, function()
            player.components.talker:Say(GetString(player.prefab, "ANNOUNCE_SUITUP"))
        end)
    else
        BecomeIronLord_post(inst)
    end
end

local function Revert(inst)
    inst.nightlight:Remove()
    inst:PushEvent("stop_flashing")
    inst.components.reticule:DestroyReticule()

    local player = inst.player

    LoadPlayerData(player, inst.player_data)

    player.ActionStringOverride = nil
    player.components.playercontroller.actionbuttonoverride = nil
    player.components.playeractionpicker.leftclickoverride = nil
    player.components.playeractionpicker.rightclickoverride = nil

    player.AnimState:SetBank("wilson")
    player.AnimState:Show("beard")

    player.SoundEmitter:KillSound("chargedup")

    player:RemoveTag("ironlord")
    player:RemoveTag("laser_immune")
    player:RemoveTag("mech")
    player:RemoveTag("has_gasmask")
    player:RemoveTag("fireimmune")

    player.player_classified.living_artifact:set(nil)

    player:RemoveComponent("worker")

    player.components.locomotor:Stop()
    player.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED

    player.components.combat:SetDefaultDamage(TUNING.UNARMED_DAMAGE)

    player.components.grogginess:SetEnableSpeedMod(true)

    player.components.moisture.moisture = 0

    player.components.temperature:SetTemperature(TUNING.STARTING_TEMP)
    player.components.temperature:SetTemp(nil)
    player:StartUpdatingComponent(player.components.temperature)

    if player.components.poisonable then
        player.components.poisonable:SetBlockAll(nil)
    end

    player.components.hunger:Resume()
    player.components.sanity.ignore = false

    if player.components.oldager then
        player:StartUpdatingComponent(player.components.oldager)
    end

    player:PushEvent("livingartifactoveroff")
    player:ClearBufferedAction()
    player:DoTaskInTime(0, function() player.sg:GoToState("bucked_post") end)

    inst:Remove()
end

local function OnActivate(inst, player, instant)
    if player.components.inventory:FindItem(function(item) if inst == item then return true end end) then
        player.components.inventory:RemoveItem(inst)
        local x, y, z = player.Transform:GetWorldPosition()
        inst.Transform:SetPosition(x, y, z)
    end

    inst:AddTag("enabled")
    inst.player = player

    inst.AnimState:PlayAnimation("activate")
    inst:ListenForEvent("animover", function()
        if inst.AnimState:IsCurrentAnimation("activate") then
            inst:Hide()
        end
    end)

    inst:ListenForEvent("ironlord_morph_complete", function() BecomeIronLord_post(inst) end, player)
    inst:ListenForEvent("revert", function() Revert(inst) end, player)

    BecomeIronLord(inst, instant)
end

local function OnFinished(inst)
    inst.player.sg:GoToState("ironlord_explode")
end

local function OnDelta(inst)
    inst._time_left:set(inst.components.livingartifact.time_left)
    inst.player:PushEvent("ironlorddelta", {percent = inst.components.livingartifact:GetPercent()})
end

local function DoFlashTask(inst)
    local time = 0
    local nextflash = 0
    local intensity = 0

    local per = inst._time_left:value()/TUNING.IRON_LORD_TIME
    if per > 0.5 then
        time = 1
        nextflash = 2
        intensity = 0
    elseif per > 0.3 then
        time = 0.5
        nextflash = 1
        intensity = 0.25
    elseif per > 0.05 then
        time = 0.3
        nextflash = 0.6
        intensity = 0.5
    else
        time = 0.13
        nextflash = 0.26
        intensity = 0.8
    end

    ThePlayer:PushEvent("livingartifactoverpulse", {time = time})
    ThePlayer.SoundEmitter:PlaySoundWithParams("dontstarve_DLC003/common/crafted/iron_lord/pulse", {intensity = intensity})
    inst.flash_task = inst:DoTaskInTime(nextflash, DoFlashTask)
end

local function OnStartFlashing(inst, data)
    inst.flash_task = inst:DoTaskInTime(3, DoFlashTask)
end

local function OnStopFlashing(inst, data)
    if inst.flash_task then
        inst.flash_task:Cancel()
        inst.flash_task = nil
    end
end

local function OnSave(inst, data)
    if inst:HasTag("enabled") then
        data.enabled = true
    end

    if inst.player_data then
        data.player_data = deepcopy(inst.player_data)
        data.playerID = inst.player.GUID
        return {inst.player.GUID}
    end
end

local function OnLoad(inst, data)
    if data.enabled then
        inst:Hide()
    end

    if data.player_data then
        inst.player_data = data.player_data
    end
end

local function OnLoadPostPass(inst, newents, data)
    if data and data.playerID then
        inst.player = newents[data.playerID].entity
        inst.player.AnimState:Hide("beard")
    end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst)
    inst.components.floater:UpdateAnimations("idle_water", "idle")

    inst.AnimState:SetBank("living_artifact")
    inst.AnimState:SetBuild("living_artifact")
    inst.AnimState:PlayAnimation("idle")

    inst._time_left = net_float(inst.GUID, "ironlord_time_left")

    inst.entity:SetPristine()

    if not TheNet:IsDedicated() then
        -- Dedicated server does not need screen flashing
        inst:ListenForEvent("start_flashing", OnStartFlashing)
        inst:ListenForEvent("stop_flashing", OnStopFlashing)
    end

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")

    inst:AddComponent("tradable")

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.ANCIENT_HULK_MINE_DAMAGE)

    inst:AddComponent("livingartifact")
    inst.components.livingartifact:SetOnActivateFn(OnActivate)
    inst.components.livingartifact:SetOnDeltaFn(OnDelta)
    inst.components.livingartifact:SetOnFinishedFn(OnFinished)

    MakeHauntableLaunch(inst)
    MakeBlowInHurricane(inst, TUNING.WINDBLOWN_SCALE_MIN.MEDIUM, TUNING.WINDBLOWN_SCALE_MAX.MEDIUM)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnLoadPostPass = OnLoadPostPass

    inst.Revert = Revert
    inst.DoDamage = DoDamage

    return inst
end

local function displaynamefn(inst)
	return ""
end

local function lightfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst.Light:Enable(true)
    inst.Light:SetRadius(5)
    inst.Light:SetFalloff(0.5)
    inst.Light:SetIntensity(0.6)
    inst.Light:SetColour(245/255, 150/255, 0/255)

	inst.displaynamefn = displaynamefn

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:DoTaskInTime(0, function()
        if inst:HasTag("lightsource") then
            inst:RemoveTag("lightsource")
        end
    end)

    return inst
end

return Prefab("living_artifact", fn, assets),
       Prefab("living_artifact_light", lightfn, assets)

