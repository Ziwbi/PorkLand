-- hack storygen functions is very trouble, so we rewrite it  -- Jerry
require("map/storygen")
local AddPlMaptags = require("map/pl_map_tags")

local task_region_mapping = {}
local function SetTaskRegion(task_name, region)
    task_region_mapping[task_name] = region
end

SetTaskRegion("START",                           "A")
SetTaskRegion("Edge_of_the_unknown",             "A")
SetTaskRegion("painted_sands",                   "A")
SetTaskRegion("plains",                          "A")
SetTaskRegion("rainforests",                     "A")
SetTaskRegion("rainforest_ruins",                "A")
SetTaskRegion("plains_ruins",                    "A")
SetTaskRegion("Edge_of_civilization",            "A")
SetTaskRegion("Deep_rainforest",                 "A")
SetTaskRegion("Pigtopia",                        "A")
SetTaskRegion("Pigtopia_capital",                "A")
SetTaskRegion("Deep_lost_ruins_gas",             "A")
SetTaskRegion("Edge_of_the_unknown_2",           "A")
SetTaskRegion("Lilypond_land",                   "A")
SetTaskRegion("Lilypond_land_2",                 "A")
SetTaskRegion("this_is_how_you_get_ants",        "A")
SetTaskRegion("Deep_rainforest_2",               "A")
SetTaskRegion("Lost_Ruins_1",                    "A")
SetTaskRegion("Lost_Ruins_4",                    "A")

-- SetTaskRegion("Land_Divide_1",                   "A")

SetTaskRegion("Deep_rainforest_3",              "B")
SetTaskRegion("Deep_rainforest_mandrake",       "B")
SetTaskRegion("Path_to_the_others",             "B")
SetTaskRegion("Other_edge_of_civilization",     "B")
SetTaskRegion("Other_pigtopia",                 "B")
SetTaskRegion("Other_pigtopia_capital",         "B")

SetTaskRegion("Deep_lost_ruins4",               "C")
SetTaskRegion("lost_rainforest",                "C")
-- SetTaskRegion("Land_Divide_2",                  "C")

SetTaskRegion("pincale",                        "E")
-- SetTaskRegion("Land_Divide_3",                  "E")


SetTaskRegion("Deep_wild_ruins4",               "F")
SetTaskRegion("wild_rainforest",                "F")
SetTaskRegion("wild_ancient_ruins",             "F")
-- SetTaskRegion("Land_Divide_4",                  "F")

function Story:GenerateIslandFromTask(task, randomize)
    if task.room_choices == nil or type(task.room_choices[1]) ~= "table" then
        return nil
    end

    local task_node = Graph(task.id,
        { parent = self.rootNode, default_bg = task.room_bg, colour = task.colour, background = task.background_room, random_set_pieces =
        task.random_set_pieces, set_pieces = task.set_pieces, maze_tiles = task.maze_tiles, treasures = task.treasures, random_treasures =
        task.random_treasures })
    task_node.substitutes = task.substitutes

    WorldSim:AddChild(self.rootNode.id, task.id, task.room_bg, task.colour.r, task.colour.g, task.colour.b, task.colour.a)

    local layout = {}
    local layoutdepth = 1
    local roomID = 0

    for i = 1, #task.room_choices, 1 do
        layout[layoutdepth] = {}

        local rooms = {}
        for room, count in pairs(task.room_choices[i]) do
            -- print("Story:GenerateIslandFromTask adding "..count.." of "..room, self.terrain.rooms[room].contents.fn)
            for id = 1, count do
                table.insert(rooms, room)
            end
        end
        if randomize then
            rooms = shuffleArray(rooms)
        end

        for _, room in ipairs(rooms) do
            -- for room, count in pairs(task.room_choices[i]) do
            -- print("Story:GenerateIslandFromTask adding "..count.." of "..room, self.terrain.rooms[room].contents.fn)
            -- for id = 1, count do
            local new_room = self:GetRoom(room)

            assert(new_room, "Couldn't find room with name " .. room)
            if new_room.contents == nil then
                new_room.contents = {}
            end

            -- Do any special processing for this room
            if new_room.contents.fn then
                new_room.contents.fn(new_room)
            end
            new_room.type = room     --new_room.type or "normal"
            new_room.id = task.id .. ":" .. roomID .. ":" .. new_room.type
            new_room.task = task.id

            self:RunTaskSubstitution(task, new_room.contents.distributeprefabs)

            -- TODO: Move this to
            local extra_contents, extra_tags = self:GetExtrasForRoom(new_room)

            local newNode = task_node:AddNode({
                id = new_room.id,
                data = {
                    type = new_room.entrance and "blocker" or new_room.type,
                    colour = new_room.colour,
                    value = new_room.value,
                    internal_type = new_room.internal_type,
                    tags = ArrayUnion(extra_tags, task.room_tags),
                    custom_tiles = new_room.custom_tiles,
                    custom_objects = new_room.custom_objects,
                    terrain_contents = new_room.contents,
                    terrain_contents_extra = extra_contents,
                    terrain_filter = self.terrain.filter,
                    entrance = new_room.entrance
                }
            })

            table.insert(layout[layoutdepth], newNode)
            roomID = roomID + 1
            -- end
        end
        layoutdepth = layoutdepth + 1
    end

    -- link the nodes in a 'web'
    for depth = #layout, 2, -1 do
        -- print("Linking " .. #layout[depth] .. " at depth " .. depth)
        for i = 1, #layout[depth], 1 do
            -- link each task at this depth with a random task in the previous depth
            local node = math.floor(#layout[depth - 1] * ((i - 1) / #layout[depth]) + 1)
            -- print(node .. " = " .. #layout[depth - 1] .. ", " .. i .. ", " .. #layout[depth])
            assert(1 <= node and node <= #layout[depth - 1])
            local roomnode = layout[depth][i]
            local roomnode2 = layout[depth - 1][node]

            -- print("  Linking " .. roomnode.id .. " -> ".. roomnode2.id)
            task_node:AddEdge({ node1id = roomnode.id, node2id = roomnode2.id })
        end

        -- connect inner layer with itself
        for i = 2, #layout[1], 1 do
            local node1 = layout[1][1]
            local node2 = layout[1][i]
            -- print("  Linking " .. node1.id .. " -> ".. node2.id)
            task_node:AddEdge({ node1id = node1.id, node2id = node2.id })
        end

        -- connect layer nodes
        for i = 2, #layout[depth] - 1, 1 do
            local node1 = layout[depth][i]
            local node2 = layout[depth][i + 1]
            -- print("  Linking " .. node1.id .. " -> ".. node2.id)
            task_node:AddEdge({ node1id = node1.id, node2id = node2.id })
        end
        -- print("  Linking " .. layout[depth][ #layout[depth] ].id .. " -> ".. layout[depth][1].id)
        task_node:AddEdge({ node1id = layout[depth][#layout[depth]].id, node2id = layout[depth][1].id })
    end

    -- print(GetTableSize(task_node))
    return task_node
end

function Story:Pl_GenerateNodesFromTasks(linkFn, tasks, start)
    -- print("Story:GenerateNodesFromTasks creating stories")

    local unusedTasks = {}

    -- Generate all the TERRAIN
    local finalNode
    for _, task in pairs(tasks) do
        -- print("Story:GenerateNodesFromTasks k,task",k,task,  GetTableSize(self.TERRAIN))
        local node = nil
        if task.gen_method == "lagoon" then
            node = self:GenerateIslandFromTask(task, false)
        elseif task.gen_method == "volcano" then
            node = self:GenerateIslandFromTask(task, true)
        else
            node = self:GenerateNodesFromTask(task, task.crosslink_factor or 1) -- 0.5)
        end
        self.TERRAIN[task.id] = node
        unusedTasks[task.id] = node

        if string.find(task.id, "Land_Divide") then
            finalNode = node
        end
    end

    -- print("Story:GenerateNodesFromTasks lock terrain")

    local startTasks = {}
    if self.level.valid_start_tasks ~= nil then
        local randomStartTaskName = GetRandomItem(self.level.valid_start_tasks)
        print("Story:GenerateNodesFromTasks start_task " .. randomStartTaskName)
        startTasks[randomStartTaskName] = self.TERRAIN[randomStartTaskName]
    else
        for k, task in pairs(self.tasks) do
            if #task.locks == 0 or task.locks[1] == LOCKS.NONE then
                startTasks[task.id] = self.TERRAIN[task.id]
            end
        end
    end

    -- print("Story:GenerateNodesFromTasks finding start parent node")

    local startParentNode = GetRandomItem(self.TERRAIN)
    if GetTableSize(startTasks) > 0 then
        startParentNode = GetRandomItem(startTasks)
    end

    unusedTasks[startParentNode.id] = nil

    -- print("Lock and Key")

    self.finalNode = linkFn(self, startParentNode, unusedTasks) -- startParentNode
    local entranceNode = startParentNode:GetRandomNodeForEntrance()
    if not start then
        return {startingTask = startParentNode, finalNode = finalNode}
    end

    local randomStartNode = startParentNode:GetRandomNode()

    local start_node_data = { id = "START" }

    if self.gen_params.start_node ~= nil then
        print("Has start node", self.gen_params.start_node)
        start_node_data.data = self:GetRoom(self.gen_params.start_node)
        start_node_data.data.terrain_contents = start_node_data.data.contents
        table.insert(start_node_data.data.tags, "island_accademy")
    else
        print("No start node! Createing a default room.")
        start_node_data.data = {
            value = WORLD_TILES.GRASS,
            type = NODE_TYPE.Default,
            tags = {"island_accademy"},
            terrain_contents = {
                countprefabs = {
                    spawnpoint = 1,
                    sapling = 1,
                    flint = 1,
                    berrybush = 1,
                    grass = function() return 2 + math.random(2) end
                }
            }
        }
    end

    start_node_data.data.colour = { r = 0, g = 1, b = 1, a = .80 }

    if self.gen_params.start_setpeice ~= nil then
        start_node_data.data.terrain_contents.countstaticlayouts = {}
        start_node_data.data.terrain_contents.countstaticlayouts[self.gen_params.start_setpeice] = 1

        if start_node_data.data.terrain_contents.countprefabs ~= nil then
            start_node_data.data.terrain_contents.countprefabs.spawnpoint = nil
        end
    end

    self.startNode = startParentNode:AddNode(start_node_data)

    -- print("Story:GenerateNodesFromTasks adding start node link", self.startNode.id .. " -> " .. randomStartNode.id)
    startParentNode:AddEdge({ node1id = self.startNode.id, node2id = randomStartNode.id })

    return {startingTask = startParentNode, entranceNode = entranceNode, finalNode = finalNode}
end

function Story:Pl_AddBGNodes(min_count, max_count)
    local tasksnodes = self.rootNode:GetChildren(false)
    local bg_idx = 0

    local function getBGRoom(task)
        local room = nil
        if type(task.data.background) == "table" then
            room = task.data.background[math.random(1, #task.data.background)]
        else
            room = task.data.background
        end
        return room
    end

    local function getBGRoomCount(task)
        local a = (task.background_node_range and task.background_node_range[1]) or min_count
        local b = (task.background_node_range and task.background_node_range[2]) or max_count
        return math.random(a, b)
    end

    for taskid, task in pairs(tasksnodes) do
        for nodeid, node in pairs(task:GetNodes(false)) do
            local background = getBGRoom(task)
            if background then
                local background_template = self:GetRoom(background) --self:GetRoom(task.data.background)
                assert(background_template, "Couldn't find room with name " .. background)
                local blocker_blank_template = self:GetRoom(self.level.blocker_blank_room_name)
                if blocker_blank_template == nil then
                    blocker_blank_template = {
                        type = "blank",
                        tags = { "RoadPoison", "ForceDisconnected" },
                        colour = { r = 0.3, g = .8, b = .5, a = .50 },
                        value = self.impassible_value
                    }
                end

                self:RunTaskSubstitution(task, background_template.contents.distributeprefabs)

                if not node.data.entrance then
                    local count = getBGRoomCount(task) --math.random(min_count,max_count)
                    local prevNode = nil
                    for i = 1, count do
                        local new_room = deepcopy(background_template)
                        new_room.id = nodeid .. ":BG_" .. bg_idx .. ":" .. background
                        new_room.task = task.id


                        -- this has to be inside the inner loop so that things like teleportato tags
                        -- only get processed for a single node.
                        local extra_contents, extra_tags = self:GetExtrasForRoom(new_room)


                        local newNode = task:AddNode({
                            id = new_room.id,
                            data = {
                                type = "background",
                                colour = new_room.colour,
                                value = new_room.value,
                                internal_type = new_room.internal_type,
                                tags = ArrayUnion(extra_tags, task.room_tags),
                                terrain_contents = new_room.contents,
                                terrain_contents_extra = extra_contents,
                                terrain_filter = self.terrain.filter,
                                entrance = new_room.entrance
                            }
                        })

                        task:AddEdge({ node1id = newNode.id, node2id = nodeid })
                        -- This will probably cause crushng so it is commented out for now
                        -- if prevNode then
                        --     task:AddEdge({node1id=newNode.id, node2id=prevNode.id})
                        -- end

                        bg_idx = bg_idx + 1
                        prevNode = newNode
                    end
                else -- this is an entrance node
                    for i = 1, 2 do
                        local new_room = deepcopy(blocker_blank_template)
                        new_room.task = task.id

                        local extra_contents, extra_tags = self:GetExtrasForRoom(new_room)

                        local blank_subnode = task:AddNode({
                            id = nodeid .. ":BLOCKER_BLANK_" .. tostring(i),
                            data = {
                                type = new_room.type or NODE_TYPE.BLANK,
                                colour = new_room.colour,
                                value = new_room.value,
                                internal_type = new_room.internal_type,
                                tags = ArrayUnion(extra_tags, task.room_tags),
                                terrain_contents = new_room.contents,
                                terrain_contents_extra = extra_contents,
                                terrain_filter = self.terrain.filter,
                                blocker_blank = true,
                            }
                        })

                        task:AddEdge({ node1id = nodeid, node2id = blank_subnode.id })
                    end
                end
            end
        end
    end
end

function Story:Pl_InsertAdditionalSetPieces(task_nodes)
    local obj_layout = require("map/object_layout")

    local function is_water_ok(room, layout)
        local water_room = room.data.type == "water" or IsOceanTile(room.data.value)
        local water_layout = layout and layout.water == true
        return (water_room and water_layout) or (not water_room and not water_layout)
    end
    local function is_target_tile(room, layout)
        local tile = room.data.value ~= nil and room.data.value
        local need_tiles = layout and layout.only_in_tiles
        if need_tiles == nil then
            return true
        end
        local has_target_tile = false
        for i, v in ipairs(need_tiles) do
            if v == tile then
                has_target_tile = true
            end
        end
        return has_target_tile
    end

    local tasks = task_nodes or self.rootNode:GetChildren()
    for id, task in pairs(tasks) do
        if task.set_pieces ~= nil and #task.set_pieces > 0 then
            for i, setpiece_data in ipairs(task.set_pieces) do
                local is_entrance = function(room)
                    -- return true if the room is an entrance
                    return room.data.entrance ~= nil and room.data.entrance == true
                end
                local is_background_ok = function(room)
                    -- return true if the piece is not backround restricted, or if it is but we are on a background
                    return setpiece_data.restrict_to ~= "background" or room.data.type == "background"
                end
                local isnt_blank = function(room)
                    return room.data.type ~= "blank" and not TileGroupManager:IsImpassableTile(room.data.value)
                end

                local layout = obj_layout.LayoutForDefinition(setpiece_data.name)
                local choicekeys = shuffledKeys(task.nodes)
                local choice = nil
                for _, choicekey in ipairs(choicekeys) do
                    if not is_entrance(task.nodes[choicekey]) and is_background_ok(task.nodes[choicekey]) and is_water_ok(task.nodes[choicekey], layout) and isnt_blank(task.nodes[choicekey]) and is_target_tile(task.nodes[choicekey], layout) then
                        choice = choicekey
                        break
                    end
                end

                if choice == nil then
                    print("Warning! Couldn't find a spot in " .. task.id .. " for " .. setpiece_data.name)
                    break
                end

                -- print("Placing " .. setpiece_data.name .. " in " .. task.id .. ":" .. task.nodes[choice].id)

                if task.nodes[choice].data.terrain_contents.countstaticlayouts == nil then
                    task.nodes[choice].data.terrain_contents.countstaticlayouts = {}
                end
                -- print ("Set peice", name, choice, room_choices._et[choice].contents, room_choices._et[choice].contents.countstaticlayouts[name])
                task.nodes[choice].data.terrain_contents.countstaticlayouts[setpiece_data.name] = 1
            end
        end
        if task.random_set_pieces ~= nil and #task.random_set_pieces > 0 then
            for k, setpiece_name in ipairs(task.random_set_pieces) do
                local layout = obj_layout.LayoutForDefinition(setpiece_name)
                local choicekeys = shuffledKeys(task.nodes)
                local choice = nil
                for i, choicekey in ipairs(choicekeys) do
                    local is_entrance = function(room)
                        -- return true if the room is an entrance
                        return room.data.entrance ~= nil and room.data.entrance == true
                    end
                    local isnt_blank = function(room)
                        return room.data.type ~= "blank"
                    end

                    if not is_entrance(task.nodes[choicekey]) and isnt_blank(task.nodes[choicekey]) and is_water_ok(task.nodes[choicekey], layout) and is_target_tile(task.nodes[choicekey], layout) then
                        choice = choicekey
                        break
                    end
                end

                if choice == nil then
                    print("Warning! Couldn't find a spot in " .. task.id .. " for " .. setpiece_name)
                    break
                end

                -- print("Placing " .. setpiece_data.name .. " in " .. task.id .. ":" .. task.nodes[choice].id)

                if task.nodes[choice].data.terrain_contents.countstaticlayouts == nil then
                    task.nodes[choice].data.terrain_contents.countstaticlayouts = {}
                end
                -- print ("Set peice", name, choice, room_choices._et[choice].contents, room_choices._et[choice].contents.countstaticlayouts[name])
                task.nodes[choice].data.terrain_contents.countstaticlayouts[setpiece_name] = 1
            end
        end
    end
end

function Story:Pl_PlaceTeleportatoParts()
    local RemoveExitTag = function(node)
        local newtags = {}
        for i, tag in ipairs(node.data.tags) do
            if tag ~= "ExitPiece" then
                table.insert(newtags, tag)
            end
        end
        node.data.tags = newtags
    end

    local IsNodeAnExit = function(node)
        if not node.data.tags then
            return false
        end
        for i, tag in ipairs(node.data.tags) do
            if tag == "ExitPiece" then
                return true
            end
        end
        return false
    end

    local iswaternode = function(node)
        local water_node = node.data.type == "water" or IsOceanTile(node.data.value)
        return water_node
    end

    local AddPartToTask = function(part, task)
        local nodeNames = shuffledKeys(task.nodes)
        for i, name in ipairs(nodeNames) do
            if IsNodeAnExit(task.nodes[name]) and not iswaternode(task.nodes[name]) then
                local extra = task.nodes[name].data.terrain_contents_extra
                if not extra then
                    extra = {}
                end
                if not extra.static_layouts then
                    extra.static_layouts = {}
                end
                table.insert(extra.static_layouts, part)
                RemoveExitTag(task.nodes[name])
                return true
            end
        end
        return false
    end

    local InsertPartnumIntoATask = function(targetDepth, part, tasks)
        for id, task in pairs(tasks) do
            if task.story_depth == targetDepth then
                local success = AddPartToTask(part, task)
                -- Not sure why we need this, was causeing crash
                -- assert( success or task.id == "TEST_TASK"or task.id == "MaxHome", "Could not add an exit part to task "..task.id)
                return success
            end
        end
        return false
    end

    local parts = self.level.ordered_story_setpieces or {}
    local maxdepth = -1

    for id, task_node in pairs(self.rootNode:GetChildren()) do
        if task_node.story_depth > maxdepth then
            maxdepth = task_node.story_depth
        end
    end


    local partSpread = maxdepth / #parts
    local range = math.ceil(maxdepth / 10)
    local plusminus = math.ceil(range / 2)

    for partnum = 1, #parts do
        -- local minDepth = partnum * partSpread - plusminus
        -- local maxDepth = partnum * partSpread + plusminus
        local targetDepth = math.ceil(partnum * partSpread)
        local success = InsertPartnumIntoATask(targetDepth, parts[partnum], self.rootNode:GetChildren())
        if success == false then
            for i = 1, plusminus do
                local tryDepth = targetDepth - i
                if InsertPartnumIntoATask(tryDepth, parts[partnum], self.rootNode:GetChildren()) then
                    break
                end
                tryDepth = targetDepth + i
                if InsertPartnumIntoATask(tryDepth, parts[partnum], self.rootNode:GetChildren()) then
                    break
                end
            end
        end
    end
end

local function RestrictNodesByKey(story, startParentNode, unusedTasks)
    local lastNode = startParentNode
    print("Startparent node:", startParentNode.id)
    local usedTasks = {}
    usedTasks[startParentNode.id] = startParentNode
    startParentNode.story_depth = 0
    local story_depth = 1
    local currentNode = nil

    local last_parent = 1 -- this is a desperate attempt to distribute the nodes better

    local function FindAttachNodes(taskid, node, target_tasks)
        local unlockingNodes = {}

        for target_taskid, target_node in pairs(target_tasks) do
            local locks = {}
            for i, v in ipairs(story.tasks[taskid].locks) do
                local lock = { keys = LOCKS_KEYS[v], unlocked = false }
                locks[v] = lock
            end

            local availableKeys = {}                                    --What are we allowed to connect to this task?

            for i, v in ipairs(story.tasks[target_taskid].keys_given) do --Get the keys that the last area we generated gives
                availableKeys[v] = {}
                table.insert(availableKeys[v], target_node)
            end

            for lock, lockData in pairs(locks) do                     --For each lock:
                for key, keyNodes in pairs(availableKeys) do          --Do we have a key...
                    for reqKeyIdx, reqKey in ipairs(lockData.keys) do --...for this lock?
                        if reqKey == key then                         --If yes, get the nodes
                            lockData.unlocked = true                  --Unlock the lock.
                        end
                    end
                end
            end

            local unlocked = true
            for lock, lockData in pairs(locks) do
                if lockData.unlocked == false then
                    unlocked = false
                    break
                end
            end

            if unlocked then
                unlockingNodes[target_taskid] = target_node
            else
            end
        end

        return unlockingNodes
    end

    while GetTableSize(unusedTasks) > 0 do
        local effectiveLastNode = lastNode

        local candidateTasks = {}


        for taskid, node in pairs(unusedTasks) do
            local unlockingNodes = FindAttachNodes(taskid, node, usedTasks)

            if GetTableSize(unlockingNodes) > 0 then
                candidateTasks[taskid] = unlockingNodes
            end
        end

        local function AppendNode(in_node, parents)
            currentNode = in_node

            local lowest = { i = 999, node = nil }
            local highest = { i = -1, node = nil }
            for id, node in pairs(parents) do
                if node.story_depth >= highest.i then
                    highest.i = node.story_depth
                    highest.node = node
                end
                if node.story_depth < lowest.i then
                    lowest.i = node.story_depth
                    lowest.node = node
                end
            end

            if story.gen_params.branching == nil or story.gen_params.branching == "default" then
                last_parent = ((last_parent - 1) % GetTableSize(parents)) + 1
                local parent_i = 1
                for k, v in pairs(parents) do
                    if parent_i < last_parent then
                        parent_i = parent_i + 1
                    else
                        last_parent = last_parent + 1
                        effectiveLastNode = v
                        break
                    end
                end
            elseif story.gen_params.branching == "most" then
                effectiveLastNode = lowest.node
            elseif story.gen_params.branching == "least" then
                effectiveLastNode = highest.node
            elseif story.gen_params.branching == "never" then
                effectiveLastNode = lastNode
            end

            currentNode.story_depth = story_depth
            story_depth = story_depth + 1

            local lastNodeExit = effectiveLastNode:GetRandomNode()
            local currentNodeEntrance = currentNode:GetRandomNode()
            if currentNode.entrancenode then
                currentNodeEntrance = currentNode.entrancenode
            end

            assert(lastNodeExit)
            assert(currentNodeEntrance)

            if story.gen_params.island_percent ~= nil
                and story.gen_params.island_percent >= math.random()
                and currentNodeEntrance.data.entrance == false then
                    story:SeperateStoryByBlanks(lastNodeExit, currentNodeEntrance)
            else
                story.rootNode:LockGraph(effectiveLastNode.id .. '->' .. currentNode.id, lastNodeExit, currentNodeEntrance,
                    { type = "none", key = story.tasks[currentNode.id].locks, node = nil })
            end

            -- print_lockandkey_ex("\t\tAdding keys to keyring:")
            -- for i,v in ipairs(self.tasks[currentNode.id].keys_given) do
            --     if availableKeys[v] == nil then
            --         availableKeys[v] = {}
            --     end
            --     table.insert(availableKeys[v], currentNode)
            --     print_lockandkey_ex("\t\t",KEYS_ARRAY[v])
            -- end

            unusedTasks[currentNode.id] = nil
            usedTasks[currentNode.id] = currentNode
            lastNode = currentNode
            currentNode = nil
        end

        if next(candidateTasks) == nil then
            AppendNode(story:GetRandomNodeFromTasks(unusedTasks), usedTasks)
        else
            for taskid, unlockingNodes in pairs(candidateTasks) do
                AppendNode(unusedTasks[taskid], unlockingNodes)
            end
        end
    end

    return lastNode:GetRandomNode()
end

local function BuildPorkLandStory(tasks, story_gen_params, level)
    print("Building PorkLand Story", tasks)

    local story = Story("GAME", tasks, terrain, story_gen_params, level)
    story.region_tasksets = {}
    for task_id, task in pairs(story.tasks) do
        local region_id = task_region_mapping[task_id]
        if task_region_mapping[task_id] == "A" then
            region_id = "mainland"
        end
        if story.region_tasksets[region_id] == nil then
            story.region_tasksets[region_id] = {}
        end
        story.region_tasksets[region_id][task_id] = task
    end
    AddPlMaptags(story.map_tags)

    -- 用于存储每个岛屿的起始节点
    -- local startNodes = {}

    -- -- 生成五个岛屿的故事节点
    -- local island_ids = {"A", "B", "C", "E", "F"}
    -- for i, island_id in ipairs(island_ids) do
    --     local b = story:Pl_GenerateNodesFromTasks(RestrictNodesByKey, story.region_tasksets[island_id], i==1)
    --     table.insert(startNodes, b.startingTask)
    -- end

    -- -- 将每个岛屿的结尾连接到下一个岛屿的起始
    -- for i = 1, #startNodes do
    --     local currentIsland = startNodes[i]
    --     local nextIsland = startNodes[(i % #startNodes) + 1] -- 环形链接

    --     -- 创建一个随机节点作为当前岛屿的结尾
    --     local endNode = currentIsland:GetRandomNode()
    --     -- 创建一个随机节点作为下一个岛屿的起始
    --     local nextStartNode = nextIsland:GetRandomNode()

    --     -- 添加边连接
    --     currentIsland:AddEdge({node1id = endNode.id, node2id = nextStartNode.id})
    -- end

    local world_size = 0
    if story_gen_params.world_size == "medium" then
        world_size = 1
    elseif story_gen_params.world_size == "large" or story_gen_params.world_size == "default" then
        world_size = 2
    elseif story_gen_params.world_size == "huge" then
        world_size = 3
    end

    story.min_bg = (level.background_node_range and level.background_node_range[1] or 0) + world_size
    story.max_bg = (level.background_node_range and level.background_node_range[2] or 2) + world_size

    story:Pl_GenerateNodesFromTasks(RestrictNodesByKey, story.region_tasksets["mainland"], true)

    story:Pl_AddBGNodes(story.min_bg, story.max_bg)
    -- story:Pl_InsertAdditionalSetPieces()
    -- story:Pl_PlaceTeleportatoParts()

    return { root = story.rootNode, startNode = story.startNode, GlobalTags = story.GlobalTags }, story
end

return BuildPorkLandStory
