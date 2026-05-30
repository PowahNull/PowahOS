local logger = require("logger")
local typecheck = require("typecheck")
local file = require("file")
local object = require("object")
local superobject = require("superobject")
local manager = require("manager")
logger.system("loaded all modules")

local MAX_QUEUE_SIZE = 512
local CRAFTING = {} -- stores crafting recipe
local OBJECTS = {} -- stores objects

-- initialise containers
file.init_objects(OBJECTS)
logger.system("finished reading from file")
peripheral.find("modem", rednet.open)
logger.system("connected to rednet")
local amount_of_workers = manager.init(OBJECTS)
if amount_of_workers <= 0 then
    logger.fatal_error("no workers found in system")
end
logger.system("initialised workers")

-- to be added: superfind, craft
local switch = {
    PUSH = function(sender, body)
        -- perform push request
        local source = body[1]
        local dest = body[2]

        local source_ok = typecheck.is_object(OBJECTS, source, "MISSING SOURCE", "BAD SOURCE TYPE", "UNKNOWN SOURCE", "OK")
        if source_ok ~= "OK" then
            logger.warn(string.format("PUSH by #%d failed with error ", sender, source_ok))
            rednet.send(sender, source_ok, "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        end

        local not_moved
        if dest then
            local dest_ok = typecheck.is_object(OBJECTS, dest, "MISSING DESTINATION", "BAD DESTINATION TYPE", "UNKNOWN DESTINATION", "OK")
            if dest_ok == "OK" then
                -- push to inventory
                local ok
                not_moved, ok = object.push(OBJECTS[source], OBJECTS[dest])
                if ok ~= "CALL_OK" then
                    return ok
                end
            else
                logger.warn(string.format("PUSH by #%d failed with error ", sender, dest_ok))
                rednet.send(sender, dest_ok, "STORAGE_RESPONSE_PROTOCOL")
                return "CALL_OK"
            end
        else
            -- push to main storage's highest priority and randomise
            local candidates = superobject.shuffle(OBJECTS)

            for _, property in ipairs(candidates) do
                local ok
                not_moved, ok = object.push(OBJECTS[source], OBJECTS[property.name])
                if ok ~= "CALL_OK" then
                    return ok
                end
                -- no transfer failed so break or else continue pushing
                if not_moved <= 0 then
                    break
                end
            end
        end

        -- response
        rednet.send(sender, not_moved, "STORAGE_RESPONSE_PROTOCOL")
        if not_moved > 0 then
            logger.warn(string.format("PUSH by #%d has not moved %d items", sender, not_moved))
        else
            logger.ok(string.format("PUSH by #%d has moved all items", sender))
        end

        return "CALL_OK"
    end,

    GET = function(sender, body)
        -- perform get request
        local items = body[1] -- items to pull
        local dest = body[2] -- destination to push to
        local source = body[3] -- source to pull from

        local dest_ok = typecheck.is_object(OBJECTS, dest, "MISSING DESTINATION", "BAD DESTINATION TYPE", "UNKNOWN DESTINATION", "OK")
        if dest_ok ~= "OK" then
            logger.warn(string.format("GET by #%d failed with error ", sender, dest_ok))
            rednet.send(sender, dest_ok, "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        end

        --[[ item request must follow a strict format:
            items = {
                {item = item1, ?nbt = nbt1, count = count1},
                {item = item2, ?nbt = nbt2, count = count2},
                {item = item3, ?nbt = nbt3, count = count3},
                {item = item4, ?nbt = nbt4, count = count4},
                ...
            }

            if nbt is missing then match any nbt
        ]]

        local check_ok = typecheck.is_items(items, "MISSING ITEMS", "BAD ITEM TYPE", "MISSING ITEM DATA", "BAD ITEM DATA TYPE", "OK")
        if check_ok ~= "OK" then
            logger.warn(string.format("GET by #%d failed with error ", sender, check_ok))
            rednet.send(sender, check_ok, "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        end

        local not_moved = {}
        if source then
            -- get request for that specific container
            local source_ok = typecheck.is_object(OBJECTS, source, "MISSING SOURCE", "BAD SOURCE TYPE", "UNKNOWN SOURCE", "OK")
            if source_ok ~= "OK" then
                logger.warn(string.format("GET by #%d failed with error ", sender, source_ok))
                rednet.send(sender, source_ok, "STORAGE_RESPONSE_PROTOCOL")
                return "CALL_OK"
            end

            local ok
            not_moved, ok = object.get(OBJECTS[source], OBJECTS[dest], items)
            if ok ~= "CALL_OK" then
                return ok
            end
        else
            -- get from main storage's highest priority and randomise
            local candidates = superobject.shuffle(OBJECTS)
            local left_to_move = items
            for _, property in ipairs(candidates) do
                -- try to transfer all item of this type from this container
                local ok
                left_to_move, ok = object.get(OBJECTS[property.name], OBJECTS[dest], left_to_move)
                if ok ~= "CALL_OK" then
                    return ok
                end

                -- break if can no longer transfer or finished transfering
                if #left_to_move == 0 then
                    break
                end
            end
            not_moved = left_to_move
        end

        -- response
        rednet.send(sender, not_moved, "STORAGE_RESPONSE_PROTOCOL")
        if #not_moved > 0 then
            local sum_failed = 0
            for _, v in pairs(not_moved) do
                sum_failed = sum_failed + v.count
            end
            logger.warn(string.format("GET by #%d has not moved %d items", sender, sum_failed))
        else
            logger.ok(string.format("GET by #%d moved all items", sender))
        end
        return "CALL_OK"
    end,

    LIST = function(sender, body)
        -- list all items without nbt
        local to_list = {}
        if #body > 0 then
            -- list from specific inventories if inventory is valid
            for _, v in pairs(body) do
                local source = OBJECTS[v]
                if source then
                    to_list[v] = OBJECTS[v]
                end
            end
        else
            to_list = OBJECTS
        end

        local contents = {}
        for name, property in pairs(to_list) do
            if not property.secret then
                contents[name] = object.content(OBJECTS[name])
            end
        end

        local merged = superobject.merge_items(contents)

        local to_sort = {}
        local slot = 1
        for item, count in pairs(merged) do
            to_sort[slot] = {item = item, count = count}
            slot = slot + 1
        end

        table.sort(to_sort, function(a, b)
            return a.count > b.count
        end)

        -- mass send
        rednet.send(sender, to_sort, "STORAGE_RESPONSE_PROTOCOL")

        logger.ok(string.format("LIST by #%d succeeded", sender))
        return "CALL_OK"
    end,

    FIND = function(sender, body)
        -- find an item from a searchword without nbt
        local search_ok = typecheck.is_string(body[1], "MISSING SEARCHWORD", "BAD SEARCHWORD TYPE", "OK")
        if search_ok ~= "OK" then
            logger.warn(string.format("FIND by #%d failed with error ", sender, search_ok))
            rednet.send(sender, search_ok, "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        end

        local mod_search = {}
        local tag_search = {}
        for word in body[1]:gmatch("%S+") do
            if string.find(word, "@") then
                table.insert(mod_search, string.lower(string.gsub(word, "@", "")))
            else
                table.insert(tag_search, string.lower(word))
            end
        end

        local objects_to_find = {}
        if body[2] then
            if type(body[2]) == "table" then
                -- list from specific inventories if inventory is valid
                for _, v in pairs(body[2]) do
                    local source = OBJECTS[v]
                    if source then
                        objects_to_find[v] = OBJECTS[v]
                    end
                end
            end
        else
            objects_to_find = OBJECTS
        end

        local contents = {}
        for name, property in pairs(objects_to_find) do
            if not property.secret then
                contents[name] = object.match(OBJECTS[name], mod_search, tag_search)
            end
        end

        local merged = superobject.merge_items(contents)

        local to_sort = {}
        local slot = 1
        for item, count in pairs(merged) do
            to_sort[slot] = {item = item, count = count}
            slot = slot + 1
        end

        table.sort(to_sort, function(a, b)
            return a.count > b.count
        end)

        -- mass send
        rednet.send(sender, to_sort, "STORAGE_RESPONSE_PROTOCOL")

        logger.ok(string.format("FIND by #%d succeeded", sender))
        return "CALL_OK"
    end,

    SUPERLIST = function(sender, body)
        -- list all items with nbt
        local to_list = {}
        if #body > 0 then
            -- list from specific inventories if inventory is valid
            for _, v in pairs(body) do
                local source = OBJECTS[v]
                if source then
                    to_list[v] = OBJECTS[v]
                end
            end
        else
            to_list = OBJECTS
        end

        local main_pool = manager.list(to_list)
        local merged = superobject.merge_items_nbt(main_pool)

        local sort = {}
        local slot = 1
        for _, details in pairs(merged) do
            sort[slot] = details
            slot = slot + 1
        end

        table.sort(sort, function(a, b)
            return a.count > b.count
        end)

        -- mass send
        rednet.send(sender, sort, "STORAGE_RESPONSE_PROTOCOL")

        logger.ok(string.format("SUPERLIST by #%d succeeded", sender))
        return "CALL_OK"
    end,

    SUPERFIND = function(sender, body)
        -- find an item from a searchword with nbt and display name
        local search_ok = typecheck.is_string(body[1], "MISSING SEARCHWORD", "BAD SEARCHWORD TYPE", "OK")
        if search_ok ~= "OK" then
            logger.warn(string.format("FIND by #%d failed with error ", sender, search_ok))
            rednet.send(sender, search_ok, "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        end

        local search = {}
        for word in body[1]:gmatch("%w+") do
            table.insert(search, string.lower(word))
        end

        local objects = {}
        if body[2] then
            if type(body[2]) == "table" then
                -- list from specific inventories if inventory is valid
                for _, v in pairs(body[2]) do
                    local source = OBJECTS[v]
                    if source then
                        objects[v] = OBJECTS[v]
                    end
                end
            end
        else
            objects = OBJECTS
        end

        local main_pool = manager.find(objects, search)
        local merged = superobject.merge_items_nbt(main_pool)

        local sort = {}
        local slot = 1
        for _, details in pairs(merged) do
            sort[slot] = details
            slot = slot + 1
        end

        table.sort(sort, function(a, b)
            return a.count > b.count
        end)

        -- mass send
        rednet.send(sender, sort, "STORAGE_RESPONSE_PROTOCOL")

        logger.ok(string.format("SUPERFIND by #%d succeeded", sender))
        return "CALL_OK"
    end,

    CRAFT = function(sender, body)
        -- dispatch a crafting request to a crafting cpu
    end
}

-- listen for requests
local QUEUE = {}

local function listen()
    while true do
        -- rednet recieving
        local sender, message = rednet.receive("STORAGE_REQUEST_PROTOCOL")
        if #QUEUE >= MAX_QUEUE_SIZE then
            rednet.send(sender, "SERVER BUSY", "STORAGE_RESPONSE_PROTOCOL")
        elseif message then
            if type(message) == "table" then
                table.insert(QUEUE, {sender, message})
            end
        end
    end
end

local function perform()
    while true do
        if #QUEUE > 0 then
            -- ignore bad requests
            local pull = table.remove(QUEUE, 1)
            local sender = pull[1]
            local message = pull[2]

            local content_ok = true
            local header = message.header
            if not header or type(header) ~= "string" or not switch[header] then 
                logger.warn(string.format("missing or invalid request header received by: %d", sender))
                rednet.send(sender, "BAD HEADER", "STORAGE_RESPONSE_PROTOCOL")
                content_ok = false
            end

            local body = message.body
            if not body or type(body) ~= "table" then
                logger.warn(string.format("missing or invalid request body received by: %d", sender))
                rednet.send(sender, "BAD BODY", "STORAGE_RESPONSE_PROTOCOL")
                content_ok = false
            end

            if content_ok then
                local ret = switch[header](sender, body)
                if ret ~= "CALL_OK" then
                    logger.fatal_error("worker quit execution due to an internal error")
                    return "INTERNAL_ERROR"
                end
            end
        else
            sleep(0.05)
        end
    end
end

parallel.waitForAny(listen, perform)
-- this can only yield due to internal_error
