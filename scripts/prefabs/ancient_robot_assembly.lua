local assets =
{
	Asset("ANIM", "anim/metal_hulk_merge.zip"),
}

local prefabs =
{
    "iron",
    "sparks_fx",
    "sparks_green_fx",
    "laser_ring",
}

local function RefreshBuild(inst)
    local anim = inst.AnimState
    if inst.components.mechassembly.parts.LEG == 0 then
        anim:Hide("leg01")
        anim:Hide("leg02")
    elseif inst.components.mechassembly.parts.LEG == 1 then
        anim:Show("leg01")
        anim:Hide("leg02")
    else
        anim:Show("leg01")
        anim:Show("leg02")
    end
    if inst.components.mechassembly.parts.CLAW == 0 then
        anim:Hide("arm01")
        anim:Hide("arm02")
    elseif inst.components.mechassembly.parts.CLAW == 1 then
        anim:Show("arm01")
        anim:Hide("arm02")
    else
        anim:Show("arm01")
        anim:Show("arm02")
    end
    if inst.components.mechassembly.parts.HEAD == 0 then
        anim:Hide("head")
    else
        anim:Show("head")
    end
    if inst.components.mechassembly.parts.RIBS == 0 then
        anim:Hide("spine")
    else
        anim:Show("spine")
    end
    if inst.components.mechassembly.parts.RIBS == 1 and inst.components.mechassembly.parts.HEAD == 1 then
        anim:Show("spine_head")
    else
        anim:Hide("spine_head")
    end
end

local function OnAssemble(inst)
    RefreshBuild(inst)
    inst.AnimState:PlayAnimation("merge")
    inst.AnimState:PushAnimation("idle",true)
    local pos = Vector3(inst.Transform:GetWorldPosition())
    TheWorld:PushEvent("ms_sendlightningstrike", pos)
    SpawnPrefab("ancient_hulk_laserhit"):SetTarget(inst)

    if inst.components.mechassembly:ShouldSpawnHulk() then
        local hulk = SpawnPrefab("ancient_hulk")
        local x, y, z = inst.Transform:GetWorldPosition()
        hulk.Transform:SetPosition(x, y, z)
        hulk:PushEvent("activate")
        inst:Remove()
    end
end

local function OnAttacked(inst, data)
    inst.hits = inst.hits + 1

    if inst.hits > 2 and math.random() * inst.hits >= 2 then
        inst.components.lootdropper:SpawnLootPrefab("iron")
        inst.hits = 0

        if math.random() < 0.6 then
            inst.components.mechassembly:Dissemble()
        end
    end

    inst.AnimState:PlayAnimation("merge")
    inst.AnimState:PushAnimation("idle", true)

    local fx = SpawnPrefab("sparks_green_fx")
    local x, y, z = inst.Transform:GetWorldPosition()
    fx.Transform:SetPosition(x, y + 1, z)
end

local function OnWorkCallback(inst, worker, work_left)
    OnAttacked(inst, {attacker = worker})
    inst.components.workable:SetWorkLeft(1)
    inst:PushEvent("attacked")
end

local function OnSave(inst,data)
    if inst.hits then
        data.hits = inst.hits
    end
end

local function OnLoad(inst, data)
    if data and data.hits then
        inst.hits = data.hits
    end

    RefreshBuild(inst)
end

local function OnLoadPostPass(inst, newents, data)
    if inst.spawned then
        if inst.spawntask then
            inst.spawntask:Cancel()
            inst.spawntask = nil
        end
    end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
    inst.entity:AddLight()
    inst.entity:AddMiniMapEntity()
	inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("metal_hulk_merge")
    inst.AnimState:SetBuild("metal_hulk_merge")
    inst.AnimState:PlayAnimation("idle", true)

    inst.Light:SetIntensity(.6)
    inst.Light:SetRadius(5)
    inst.Light:SetFalloff(3)
    inst.Light:SetColour(1, 0, 0)
    inst.Light:Enable(false)

    inst.MiniMapEntity:SetIcon("metal_spider.tex")

    inst.collisionradius = 2
    MakeObstaclePhysics(inst, inst.collisionradius)

    inst.Transform:SetFourFaced()

    inst:AddTag("lightningrod")
    inst:AddTag("laser_immune")
    inst:AddTag("ancient_robot")
    inst:AddTag("mech")
    inst:AddTag("monster")
    inst:AddTag("ancient_robots_assembly")
    inst:AddTag("dontteleporttointerior")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("timer")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.MINE)
    inst.components.workable:SetWorkLeft(1)
    inst.components.workable:SetOnWorkCallback(OnWorkCallback)
    inst.components.workable.undestroyable = true

    inst:AddComponent("inspectable")

    inst:AddComponent("knownlocations")

    inst:AddComponent("lootdropper")

    inst:AddComponent("locomotor")

    inst:AddComponent("mechassembly")

    inst:ListenForEvent("assemble", OnAssemble)

    inst.hits = 0

    RefreshBuild(inst)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    inst.OnLoadPostPass = OnLoadPostPass

    return inst
end

return Prefab("ancient_robots_assembly", fn, assets, prefabs)
