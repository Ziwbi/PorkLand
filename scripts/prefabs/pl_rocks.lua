local basalt_assets =
{
    Asset("ANIM", "anim/rock_basalt.zip"),
}

local prefabs =
{
    "rocks",
    "flint",
}

SetSharedLootTable("rock_basalt",
{
    {"rocks",  1.00},
    {"rocks",  1.00},
    {"rocks",  0.50},
    {"flint",  1.00},
    {"flint",  0.30},
})

local function OnWork(inst, worker, workleft)
    if workleft <= 0 then
        local pt = inst:GetPosition()
        SpawnPrefab("rock_break_fx").Transform:SetPosition(pt.x, pt.y, pt.z)
        inst.components.lootdropper:DropLoot(pt)

        if inst.showCloudFXwhenRemoved then
            local fx = SpawnPrefab("collapse_small")
            fx.Transform:SetPosition(pt.x, pt.y, pt.z)
        end

        inst:Remove()
    else
        inst.AnimState:PlayAnimation(
            (workleft < TUNING.ROCKS_MINE / 3 and "low") or
            (workleft < TUNING.ROCKS_MINE * 2 / 3 and "med") or
            "full"
        )
    end
end

local function basalt_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity() -- TODO
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 1)

    inst.AnimState:SetBank("rock_basalt")
    inst.AnimState:SetBuild("rock_basalt")
    inst.AnimState:PlayAnimation("full")
    local colour = 0.5 + math.random() * 0.5
    inst.AnimState:SetMultColour(colour, colour, colour, 1)

    inst:AddTag("boulder")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("lootdropper")
    inst.components.lootdropper:SetChanceLootTable("rock_basalt")

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.MINE)
    inst.components.workable:SetWorkLeft(TUNING.ROCKS_MINE)
    inst.components.workable:SetOnWorkCallback(OnWork)

    inst:AddComponent("inspectable")

    MakeHauntableWork(inst)

    return inst
end

return Prefab("rock_basalt", basalt_fn, basalt_assets, prefabs)
