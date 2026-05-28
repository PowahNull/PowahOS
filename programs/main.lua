local logger = require("logger")
local file = require("file")
local object = require("object")
local superobject = require("superobject")
local dictionary = require("dictionary")
logger.system("loaded all modules")

local MAX_QUEUE_SIZE = 512
local CRAFTING = {} -- stores crafting recipe
local OBJECTS = {} -- stores objects
local DICTIONARY = {} -- stores specific nbt

-- initialise containers
file.init_objects(OBJECTS)
file.init_dictionary(OBJECTS)
logger.system("finished reading from file")
peripheral.find("modem", rednet.open)
logger.system("connected to rednet")

-- listen for requests
local QUEUE = {}

function mass_send(array, sender, protocol)
    -- send 512 elements at a time to recipient (break if no more element to send)
    for i = 1, #array, 512 do
        local section = {}
        for j = 1, 512 do
            local value = array[i + j - 1]
            if value then
                section[j] = value
            else
                break
            end
        end
        rednet.send(sender, section, protocol)
        sleep(0.05)
    end
end

-- to be added: superfind, craft
local switch = {
    PUSH = function(sender, body)
        -- perform push request
        local source = body[1]
        local dest = body[2]

        if not source then
            logger.warn(string.format("PUSH by #%d is missing source information", sender))
            rednet.send(sender, "MISSING SOURCE", "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        elseif type(source) ~= "string" then
            logger.warn(string.format("PUSH by #%d source data type '%s' is invalid", sender, type(source)))
            rednet.send(sender, "INVALID SOURCE TYPE", "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        elseif not OBJECTS[source] then
            logger.error(string.format("PUSH by #%d source is unknown", sender))
            rednet.send(sender, "INVALID SOURCE", "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        end

        local not_moved
        if dest then
            if type(dest) ~= "string" then
                logger.warn(string.format("PUSH by #%d destination data type '%s' is invalid", sender, type(dest)))
                rednet.send(sender, "INVALID DESTINATION TYPE", "STORAGE_RESPONSE_PROTOCOL")
                return "CALL_OK"
            elseif not OBJECTS[dest] then
                logger.error(string.format("PUSH by #%d destination is unknown", sender))
                rednet.send(sender, "INVALID DESTINATION", "STORAGE_RESPONSE_PROTOCOL")
                return "CALL_OK"
            end

            -- push to inventory
            local ok
            not_moved, ok = object.push(OBJECTS[source], OBJECTS[dest])
            if ok ~= "CALL_OK" then
                return ok
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

        if not dest then
            logger.warn(string.format("GET by #%d is missing destination information", sender))
            rednet.send(sender, "MISSING DESTINATION", "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        elseif type(dest) ~= "string" then
            logger.warn(string.format("GET by #%d destination data type '%s' is invalid", sender, type(dest)))
            rednet.send(sender, "INVALID DESTINATION TYPE", "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        elseif not OBJECTS[dest] then
            logger.error(string.format("GET by #%d destination is unknown", sender))
            rednet.send(sender, "INVALID DESTINATION", "STORAGE_RESPONSE_PROTOCOL")
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

        if not items then
            logger.warn(string.format("GET by #%d is missing item(s) information", sender))
            rednet.send(sender, "MISSING ITEM", "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        elseif type(items) ~= "table" then
            logger.warn(string.format("GET by #%d item(s) data type '%s' is invalid", sender, type(dest)))
            rednet.send(sender, "INVALID ITEM TYPE", "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        else
            for _, v in pairs(items) do
                if not (v.item and v.count) then
                    logger.warn(string.format("GET by #%d is missing data information", sender))
                    rednet.send(sender, "MISSING DATA", "STORAGE_RESPONSE_PROTOCOL")
                    return "CALL_OK"
                elseif type(v.item) ~= "string" then
                    logger.warn(string.format("GET by #%d data type '%s' is invalid", sender, type(v.item)))
                    rednet.send(sender, "INVALID DATA TYPE", "STORAGE_RESPONSE_PROTOCOL")
                    return "CALL_OK"
                elseif type(v.count) ~= "number" then
                    -- attempt to convert to a number
                    logger.warn(string.format("GET by #%d count type '%s' is invalid", sender, type(v.count)))
                    rednet.send(sender, "INVALID COUNT TYPE", "STORAGE_RESPONSE_PROTOCOL")
                    return "CALL_OK"
                elseif v.count < 0 then 
                    logger.warn(string.format("GET by #%d count value %d is invalid", sender, v.count))
                    rednet.send(sender, "INVALID COUNT VALUE", "STORAGE_RESPONSE_PROTOCOL")
                    return "CALL_OK"
                else
                    v.count = math.floor(v.count)
                end
            end
        end

        local not_moved = {}
        if source then
            if type(source) ~= "string" then
                logger.error(string.format("GET by #%d data type '%s' is invalid", sender, type(source)))
                rednet.send(sender, "INVALID SOURCE TYPE", "STORAGE_RESPONSE_PROTOCOL")
                return "CALL_OK"
            elseif not OBJECTS[source] then
                logger.error(string.format("GET by #%d source is unknown", sender))
                rednet.send(sender, "INVALID SOURCE", "STORAGE_RESPONSE_PROTOCOL")
                return "CALL_OK"
            else
                -- get request for that specific container
                local ok
                not_moved, ok = object.get(OBJECTS[source], OBJECTS[dest], items)
                if ok ~= "CALL_OK" then
                    return ok
                end
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

    LIST = function(sender, _)
        -- list all items in inventory, without nbt and return its amounts
        local contents = {}
        for name, property in pairs(OBJECTS) do
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
        mass_send(to_sort, sender, "STORAGE_RESPONSE_PROTOCOL")

        logger.ok(string.format("LIST by #%d succeeded", sender))
        return "CALL_OK"
    end,

    FIND = function(sender, body)
        -- find an item from a searchword, without nbt, and return its amount
        local search = body
        if not search then
            logger.warn(string.format("FIND by #%d is missing searchword(s) information", sender))
            rednet.send(sender, "MISSING SOURCE", "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        elseif type(search) ~= "string" then
            logger.warn(string.format("FIND by #%d searchword(s) data type '%s' is invalid", sender, type(search)))
            rednet.send(sender, "INVALID SOURCE TYPE", "STORAGE_RESPONSE_PROTOCOL")
            return "CALL_OK"
        end

        local mod_search = {}
        local tag_search = {}
        for word in search:gmatch("%S+") do
            if string.find(word, "@") then
                table.insert(mod_search, string.lower(string.gsub(word, "@", "")))
            else
                table.insert(tag_search, string.lower(word))
            end
        end

        local contents = {}
        for name, property in pairs(OBJECTS) do
            if not property.secret then
                contents[name] = object.match(OBJECTS[name], mod_search, tag_search)
            end
        end

        local all_items = superobject.merge_items(contents)

        -- mass send
        mass_send(all_items, sender, "STORAGE_RESPONSE_PROTOCOL")

        logger.ok(string.format("FIND by #%d succeeded", sender))
        return "CALL_OK"
    end,

    SUPERFIND = function(sender, body)
        -- find an item from a searchword, with nbt and dictionary and return its amounts
    end,

    UPDATE = function(sender, body)
        -- update dictionary
    end
}

function listen()
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

function perform()
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
