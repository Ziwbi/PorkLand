local Assets = Assets
GLOBAL.setfenv(1, GLOBAL)

local function FinalOffset1(inst)
    inst.AnimState:SetFinalOffset(1)
end

local function TintOceantFx(inst)
    inst.AnimState:SetOceanBlendParams(TUNING.OCEAN_SHADER.EFFECT_TINT_AMOUNT)
end

local function Scorch_OnUpdateFade(inst)
    inst.alpha = math.max(0, inst.alpha - (1/90))
    inst.AnimState:SetMultColour(1, 1, 1,  inst.alpha)
    if inst.alpha == 0 then
        inst:Remove()
    end
end

local pl_fx = {
    {
	    name = "groundpound_nosound_fx",
	    bank = "bearger_ground_fx",
	    build = "bearger_ground_fx",
    	anim = "idle",
    },
    {
        name = "hacking_tall_grass_fx",
        bank = "hacking_fx",
        build = "hacking_tall_grass_fx",
        anim = "idle",
        tint = Vector3(.6, .7, .6),
    },
    {
        name = "shock_machines_fx",
        bank = "shock_machines_fx",
        build = "shock_machines_fx",
        anim = "shock",
        -- sound = "dontstarve_DLC002/creatures/palm_tree_guard/coconut_explode",
        fn = FinalOffset1,
    },
    {
    	name = "snake_scales_fx",
    	bank = "snake_scales_fx",
    	build = "snake_scales_fx",
    	anim = "idle",
	},
    {
        name = "splash_water_drop",
        bank = "splash_water_drop",
        build = "splash_water_drop",
        anim = "idle",
        sound = "dontstarve_DLC002/common/item_float",
        fn = TintOceantFx,
    },
    {
        name = "splash_water_sink",
        bank = "splash_water_drop",
        build = "splash_water_drop",
        anim = "idle_sink",
        sound = "dontstarve_DLC002/common/item_sink"
    },
    {
        name = "robot_leaf_fx",
        bank = "robot_leaf_fx",
        build = "robot_leaf_fx",
        anim = "idle",
    },
    {
        name = "sparks_green_fx",
        bank = "sparks",
        build = "sparks_green",
        anim = "sparks_1", --TODO "sparks_2", "sparks_3"},
    },
    {
        name = "metal_hulk_ring_fx",
        bank = "metal_hulk_ring_fx",
        build = "metal_hulk_ring_fx",
        anim = "idle",
        fn = function(inst)
            inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
            inst.AnimState:SetLayer(LAYER_BACKGROUND)
            inst.AnimState:SetSortOrder(2)
        end,
    },
    {
	    name = "groundpound_fx_hulk",
	    bank = "bearger_ground_fx",
	    build = "bearger_ground_fx",
	    sound = "dontstarve_DLC003/creatures/boss/hulk_metal_robot/dust",
    	anim = "idle",
    },
    {
        name = "laser_burst_fx",
        bank = "laser_ring_fx",
        build = "laser_ring_fx",
        anim = "idle",
    },
    {
        name = "laser_ring",
        bank = "laser_ring_fx",
        build = "laser_ring_fx",
        anim = "idle",
        fn = function(inst)
            inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
            inst.Transform:SetRotation(math.random() * 360)
            inst.Transform:SetScale(0.85, 0.85, 0.85)

            inst.alpha = 1
            inst:DoTaskInTime(0.7, function()
                inst:DoPeriodicTask(0, Scorch_OnUpdateFade)
            end)
        end
    },
    {
        name = "laser_explosion",
        build = "laser_explosion",
        bank = "laser_explosion",
        anim = "idle",
        fn = function(inst)
            inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
            inst.Transform:SetScale(0.85, 0.85, 0.85)
        end,
    },
    {
        name = "living_suit_explode_fx",
        bank = "living_suit_explode_fx",
        build = "living_suit_explode_fx",
        anim = "idle",
    },
}

-- Sneakily add these to the FX table
-- Also force-load the assets because the fx file won't do for some reason

local fx = require("fx")

for _, v in ipairs(pl_fx) do
    table.insert(fx, v)
    if Settings.last_asset_set ~= nil then
        table.insert(Assets, Asset("ANIM", "anim/" .. v.build .. ".zip"))
    end
end
