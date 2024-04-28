GLOBAL.setfenv(1, GLOBAL)

local params = require("containers").params

local widget_smelter =
{
    widget = {
        slotpos = {
            Vector3(0, 64 + 32 + 8 + 4, 0),
            Vector3(0, 32 + 4, 0),
            Vector3(0, -(32 + 4), 0),
            Vector3(0, -(64 + 32 + 8 + 4), 0),
        },
        animbank = "ui_cookpot_1x4",
        animbuild = "ui_cookpot_1x4",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
        buttoninfo = {
            text = STRINGS.ACTIONS.SMELT,
            position = Vector3(0, -165, 0),
        }
    },
    acceptsstacks = false,
    type = "cooker",
}

function widget_smelter.itemtestfn(container, item, slot)
    return item:HasTag("smeltable") and not container.inst:HasTag("burnt")
end

function widget_smelter.widget.buttoninfo.fn(inst, doer)
    if inst.components.container ~= nil then
        BufferedAction(doer, inst, ACTIONS.COOK):Do()
    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
        SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.COOK.code, inst, ACTIONS.COOK.mod_name)
    end
end

function widget_smelter.widget.buttoninfo.validfn(inst)
    return inst.replica.container ~= nil and inst.replica.container:IsFull()
end

params["smelter"] = widget_smelter

local widget_antchest = {
    widget = {
        slotpos = {},
        animbank = "ui_chest_3x3",
        animbuild = "ui_chest_3x3",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

for y = 2, 0, -1 do
    for x = 0, 2 do
        table.insert(widget_antchest.widget.slotpos, Vector3(80 * x - 80 * 2 + 80, 80 * y - 80 * 2 + 80, 0))
    end
end

function widget_antchest.itemtestfn(contanier, item, slot)
	return item.prefab == "honey" or item.prefab == "nectar_pod"
end

params["antchest"] = widget_antchest

local widget_corkchest = {
    widget = {
        slotpos = {
            Vector3(-162 + 75 / 2, -75 * 0 + 114, 0),
            Vector3(-162 + 75 / 2, -75 * 1 + 114, 0),
            Vector3(-162 + 75 / 2, -75 * 2 + 114, 0),
            Vector3(-162 + 75 / 2, -75 * 3 + 114, 0),
        },
        animbank = "ui_thatchpack_1x4",
        animbuild = "ui_thatchpack_1x4",
        pos = Vector3(75, 200, 0),
        side_align_tip = 160,
    },
    type = "chest",
}

params["corkchest"] = widget_corkchest

params["roottrunk"] = deepcopy(params["shadowchester"])
function params.roottrunk.itemtestfn(container, item, slot)
    return not item:HasTag("irreplaceable")
end
