local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)
local IronlordBadge = require("widgets/ironlordbadge")

local function OnPoisonDamage(parent, data)
    parent.player_classified.poisonpulse:set_local(true)
    parent.player_classified.poisonpulse:set(true)
end

local function OnPoisonPulseDirty(inst)
    if inst._parent ~= nil then
        inst._parent:PushEvent("poisondamage")
    end
end

local function OnLivingArtifactDirty(inst)
    if not inst._parent or not inst._parent:IsValid() then
        return
    end

    local player = inst._parent
    local living_artifact = inst.living_artifact:value()
    if living_artifact and living_artifact:IsValid() then

        player:DoTaskInTime(152 * FRAMES, function()
            TheWorld:PushEvent("enabledynamicmusic", false)
            if not TheFocalPoint.SoundEmitter:PlayingSound("ironlordmusic") then
                TheFocalPoint.SoundEmitter:PlaySound("dontstarve_DLC003/music/fight_epic_4", "ironlordmusic")
            end
        end)

        player.HUD.controls.ironlordbadge = player.HUD.controls.sidepanel:AddChild(IronlordBadge(player))
        player.HUD.controls.ironlordbadge:SetPosition(0,-100,0)
        player.HUD.controls.ironlordbadge:SetPercent(1)

        player.HUD.controls.crafttabs:Hide()
        player.HUD.controls.inv:Hide()
        player.HUD.controls.status:Hide()
        player.HUD.controls.mapcontrols.minimapBtn:Hide()
    else
        TheWorld:PushEvent("enabledynamicmusic", true)
        TheFocalPoint.SoundEmitter:KillSound("ironlordmusic")

        if player.HUD.controls.ironlordbadge then
            player.HUD.controls.ironlordbadge:Kill()
            player.HUD.controls.ironlordbadge = nil
        end

        player.HUD.controls.crafttabs:Show()
        player.HUD.controls.inv:Show()
        player.HUD.controls.status:Show()
        player.HUD.controls.mapcontrols.minimapBtn:Show()
    end
end

local function RegisterNetListeners(inst)
    if TheWorld.ismastersim then
        inst._parent = inst.entity:GetParent()
        inst:ListenForEvent("poisondamage", OnPoisonDamage, inst._parent)
    else
        inst.poisonpulse:set_local(false)
        inst:ListenForEvent("poisonpulsedirty", OnPoisonPulseDirty)
        inst.living_artifact:set_local(nil)
    end

    if not TheNet:IsDedicated() then
        inst:ListenForEvent("livingartifactdirty", OnLivingArtifactDirty)
    end
end

AddPrefabPostInit("player_classified", function(inst)
    inst.ispoisoned = inst.ispoisoned or net_bool(inst.GUID, "poisonable.ispoisoned")
    inst.poisonpulse = inst.poisonpulse or net_bool(inst.GUID, "poisonable.poisonpulse", "poisonpulsedirty")
    inst.living_artifact = net_entity(inst.GUID, "ThePlayer.living_artifact", "livingartifactdirty")

    inst:DoTaskInTime(0, RegisterNetListeners)
end)
