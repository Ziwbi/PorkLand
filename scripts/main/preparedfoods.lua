local foods = {
    tea =
    {
        test = function(cooker, names, tags) return names.piko_orange and names.piko_orange >= 2 and tags.sweetener and not tags.meat and not tags.veggie and not tags.inedible end,
        priority = 25,
        foodtype = FOODTYPE.VEGGIE,
        secondaryfoodtype = FOODTYPE.GOODIES,
        health = TUNING.HEALING_SMALL,
        hunger = TUNING.CALORIES_SMALL,
        perishtime = TUNING.PERISH_ONE_DAY,
        sanity = TUNING.SANITY_LARGE,
        temperature = TUNING.HOT_FOOD_BONUS_TEMP,
        temperatureduration = TUNING.FOOD_TEMP_LONG,
        cooktime = 0.5,
        spoiled_product = "icedtea",
        yotp = true,
        oneatenfn = function(inst, eater)
            if eater:HasDebuff("buff_speed_icedtea") then
                eater:RemoveDebuff("buff_speed_icedtea")
            end
            eater:AddDebuff("buff_speed_tea", "buff_speed_tea")
        end,
    },

    icedtea =
    {
        test = function(cooker, names, tags) return names.piko_orange and names.piko_orange >= 2 and tags.sweetener and tags.frozen end,
        priority = 30,
        foodtype = FOODTYPE.VEGGIE,
        secondaryfoodtype = FOODTYPE.GOODIES,
        health = TUNING.HEALING_SMALL,
        hunger = TUNING.CALORIES_SMALL,
        perishtime = TUNING.PERISH_FAST,
        sanity = TUNING.SANITY_LARGE,
        temperature = TUNING.COLD_FOOD_BONUS_TEMP,
        temperatureduration = TUNING.FOOD_TEMP_BRIEF * 1.5,
        cooktime = 0.5,
        yotp = true,
        oneatenfn = function(inst, eater)
            if eater:HasDebuff("buff_speed_tea") then
                eater:RemoveDebuff("buff_speed_tea")
            end
            eater:AddDebuff("buff_speed_icedtea", "buff_speed_icedtea")
        end,
    },
}

for k, v in pairs(foods) do
    v.name = k
    v.weight = v.weight or 1
    v.priority = v.priority or 0

    v.cookbook_category = "cookpot"
    v.overridebuild = "pl_cook_pot_food"
end

return foods
