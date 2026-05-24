::start::
local logger = require("logger")
local file_service = require("file_service")
local object_service = require("object_service")

local PROPERTIES = {} -- stores properties of objects
local CRAFTING = {} -- stores crafting recipe
local OBJECTS = {} -- stores objects

-- initialise containers
file_service.init_containers(PROPERTIES)
logger.system("finished reading from file")
for name, property in pairs(PROPERTIES) do
    local new_object, ok = object_service.new({
        name = name, -- name of object will be used as an abstraction layer in requests
        type = property.type, -- type of object is generic (chests) or drawer (storage drawers)
        secret = property.secret, -- is the object secret (cannot perform GET, LIST or FIND request on container)
        priority = property.priority, -- priority of insertion/extraction (highest -> lowest insert), (lowest -> highest extract)
        container = property.container, -- container peripheral name
    })
    if ok then
        OBJECTS[name] = new_object
    end
end
logger.system("initialised container objects")

-- listen for requests
peripheral.find("modem", rednet.open)
function listen()
    while true do
        -- rednet recieving
        local sender, message = rednet.receive("STORAGE_REQUEST_PROTOCOL")
        if message then
            if type(message) == "table" then
                os.queueEvent("request_event", sender, message)
            end
        end
    end
end

-- perform requests
function perform()
    while true do
        local internal_error = false
        -- pull an event
        local _, sender, message = os.pullEvent("request_event")

        -- ignore bad requests
        local header = message.header
        if not header or type(header) ~= "string" then 
            logger.warn(string.format("invalid request header received by: %d", sender))
            goto continue
        end

        local body = message.body
        if not body or type(body) ~= "table" then
            logger.warn(string.format("invalid request body received by: %d", sender))
            goto continue 
        end

        if header == "PUSH" then
            -- perform push request
            local source = body[1]
            local dest = body[2]

            if not source then
                logger.error(string.format("PUSH request by %s failed due to missing source information", sender))
                rednet.send(sender, "MISSING SOURCE", "STORAGE_RESPONSE_PROTOCOL")
                goto continue
            elseif type(source) ~= "string" then
                logger.error(string.format("PUSH request by %s failed due to incorrect source data type: %s", sender, type(source)))
                rednet.send(sender, "INVALID SOURCE TYPE", "STORAGE_RESPONSE_PROTOCOL")
                goto continue
            elseif not OBJECTS[source] then
                logger.error(string.format("PUSH request by %s failed due to an invalid source", sender))
                rednet.send(sender, "INVALID SOURCE", "STORAGE_RESPONSE_PROTOCOL")
                goto continue
            end

            local failed_to_transfer
            if dest then
                if type(dest) ~= "string" then
                    logger.error(string.format("PUSH request by %s failed due to incorrect destination data type: %s", sender, type(dest)))
                    rednet.send(sender, "INVALID DESTINATION TYPE", "STORAGE_RESPONSE_PROTOCOL")
                    goto continue
                elseif not OBJECTS[dest] then
                    logger.error(string.format("PUSH request by %s failed due to an invalid destination", sender))
                    rednet.send(sender, "INVALID DESTINATION", "STORAGE_RESPONSE_PROTOCOL")
                    goto continue
                end

                -- push to inventory
                local ok
                failed_to_transfer, ok = object_service.push(OBJECTS[source], OBJECTS[dest])
                if not ok then
                    internal_error = true
                    goto continue
                end
                object_service.update(OBJECTS[source], OBJECTS[dest])
            else
                -- push to main storage's highest priority and smallest amounts of items
                local candidates = {}
                for name, object in pairs(OBJECTS) do
                    if not object.secret then
                        local size = 0
                        for _, _ in pairs(object.content) do size = size + 1 end
                        table.insert(candidates, {
                            priority = object.priority,
                            unique_items = size,
                            name = name
                        })
                    end
                end

                -- sort from top to bottom (highest priority to lowest and shortest container name)
                table.sort(candidates, function (a, b)
                    if a.priority > b.priority then
                        return true
                    elseif a.priority == b.priority then
                        if a.unique_items < b.unique_items then
                            return true
                        else
                            return false
                        end
                    else
                        return false
                    end
                end)

                for _, property in ipairs(candidates) do
                    local ok
                    failed_to_transfer, ok = object_service.push(OBJECTS[source], OBJECTS[property.name])
                    if not ok then
                        internal_error = true
                        goto continue
                    end
                    object_service.update(OBJECTS[property.name])
                    -- no transfer failed so break or else continue pushing
                    if failed_to_transfer <= 0 then
                        break
                    end
                end
                object_service.update(OBJECTS[source])
            end

            -- response
            rednet.send(sender, failed_to_transfer, "STORAGE_RESPONSE_PROTOCOL")
            if failed_to_transfer > 0 then
                logger.warn(string.format("PUSH request by %s failed to transfer %d items", sender, failed_to_transfer))
            else
                logger.ok(string.format("PUSH request by %s completely transfered", sender))
            end
        elseif header == "GET" then
            -- perform get request
            local items = body[1] -- items to pull
            local dest = body[2] -- destination to push to
            local source = body[3] -- source to pull from

            if not dest then
                logger.error(string.format("GET request by %s failed due to missing destination information", sender))
                rednet.send(sender, "MISSING DESTINATION", "STORAGE_RESPONSE_PROTOCOL")
                goto continue
            elseif type(dest) ~= "string" then
                logger.error(string.format("GET request by %s failed due to incorrect destination data type: %s", sender, type(dest)))
                rednet.send(sender, "INVALID DESTINATION TYPE", "STORAGE_RESPONSE_PROTOCOL")
                goto continue
            elseif not OBJECTS[dest] then
                logger.error(string.format("GET request by %s failed due to an invalid destination", sender))
                rednet.send(sender, "INVALID DESTINATION", "STORAGE_RESPONSE_PROTOCOL")
                goto continue
            end

            --[[ item request must follow a strict format:
                items = {
                    {item = item1, ?nbt = nbt1, count = count1},
                    {item = item2, ?nbt = nbt2, count = count2},
                    {item = item3, ?nbt = nbt3, count = count3},
                    {item = item4, ?nbt = nbt4, count = count4},
                    ...
                }

                if nbt is missing then it is assumed to be "" (no nbt)
            ]]

            if not items then
                logger.error(string.format("GET request by %s failed due to missing item request information", sender))
                rednet.send(sender, "MISSING ITEM REQUEST", "STORAGE_RESPONSE_PROTOCOL")
                goto continue
            elseif type(items) ~= "table" then
                logger.error(string.format("GET request by %s failed due to incorrect items data type: %s", sender, type(dest)))
                rednet.send(sender, "INVALID ITEMS TYPE", "STORAGE_RESPONSE_PROTOCOL")
                goto continue
            else
                local items_ok = true
                for _, v in pairs(items) do
                    if not (v.item and v.count) then
                        logger.error(string.format("GET request by %s failed due to missing data in request", sender))
                        rednet.send(sender, "MISSING REQUEST DATA", "STORAGE_RESPONSE_PROTOCOL")
                        items_ok = false
                        break
                    elseif type(v.item) ~= "string" then
                        logger.error(string.format("GET request by %s failed due to incorrect item type: %s", sender, type(v.item)))
                        rednet.send(sender, "INVALID ITEM TYPE", "STORAGE_RESPONSE_PROTOCOL")
                        items_ok = false
                        break
                    elseif type(v.count) ~= "number" then
                        -- attempt to convert to a number
                        logger.error(string.format("GET request by %s failed due to incorrect count type: %s", sender, type(v.count)))
                        rednet.send(sender, "INVALID COUNT TYPE", "STORAGE_RESPONSE_PROTOCOL")
                        items_ok = false
                        break
                    elseif v.count < 0 then 
                        logger.error(string.format("GET request by %s failed due to negative count value: %d", sender, v.count))
                        rednet.send(sender, "NEGATIVE COUNT VALUE", "STORAGE_RESPONSE_PROTOCOL")
                        items_ok = false
                        break
                    else
                        v.count = math.floor(v.count)
                    end
                end

                if not items_ok then goto continue end
            end

            local failed_to_transfer = {}
            if source then
                if type(source) ~= "string" then
                    logger.error(string.format("GET request by %s failed due to incorrect source data type: %s", sender, type(source)))
                    rednet.send(sender, "INVALID SOURCE TYPE", "STORAGE_RESPONSE_PROTOCOL")
                    goto continue
                elseif not OBJECTS[source] then
                    logger.error(string.format("GET request by %s failed due to an invalid source", sender))
                    rednet.send(sender, "INVALID SOURCE", "STORAGE_RESPONSE_PROTOCOL")
                    goto continue
                else
                    -- get request for that specific container
                    local ok
                    failed_to_transfer, ok = object_service.get_multi(OBJECTS[source], OBJECTS[dest], items)
                    if not ok then
                        internal_error = true
                        goto continue
                    end
                    object_service.update(OBJECTS[source], OBJECTS[dest])
                end
            else
                -- get from main storage's lowest priority and least items
                for _, item in pairs(items) do
                    local candidates = {}
                    for name, object in pairs(OBJECTS) do
                        if not object.secret then
                            table.insert(candidates, {
                                priority = object.priority,
                                amount = object_service.amount(object, item.item, item.nbt),
                                name = name
                            })
                        end
                    end

                    -- sort from bottom to top (lowest priority to highest and least items to most)
                    table.sort(candidates, function (a, b)
                        if a.priority < b.priority then
                            return true
                        elseif a.priority == b.priority then
                            if a.amount < b.amount then
                                return true
                            else
                                return false
                            end
                        else
                            return false
                        end
                    end)

                    local to_transfer = item.count
                    for _, property in ipairs(candidates) do
                        -- try to transfer all item of this type from this container
                        local ok
                        to_transfer, ok = object_service.get_single(OBJECTS[property.name], OBJECTS[dest], item.item, item.nbt, to_transfer)
                        if not ok then
                            internal_error = true
                            goto continue
                        end

                        -- break if can no longer transfer or finished transfering
                        if to_transfer <= 0 then
                            break
                        end
                    end

                    if to_transfer > 0 then
                        table.insert(failed_to_transfer, {item = item.item, nbt = item.nbt, count = to_transfer})
                    end
                end
                object_service.update(OBJECTS[dest])
            end

            -- response
            rednet.send(sender, failed_to_transfer, "STORAGE_RESPONSE_PROTOCOL")
            if #failed_to_transfer > 0 then
                local sum_failed = 0
                for _, v in pairs(failed_to_transfer) do
                    sum_failed = sum_failed + v.count
                end
                logger.warn(string.format("GET request by %s failed to transfer %d items", sender, sum_failed))
            else
                logger.ok(string.format("GET request by %s completely transfered", sender))
            end
        elseif header == "LIST" then
            -- to be added
        elseif header == "FIND" then
            -- to be added
        elseif header == "CRAFT" then
            -- to be added
        else
            -- ignore invalid header
        end
        ::continue::

        if internal_error then
            -- sort out internal error
            -- perform full reload of data
            break
        end
    end
end

parallel.waitForAny(listen, perform)
