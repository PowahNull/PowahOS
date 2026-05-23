local logger = require("logger")
local file_service = require("file_service")
local container_service = require("container")
local mass_container_service = require("mass_container")

-- Read disk for inventory segments
local CONTAINERS = {}
local CRAFTING = {}
local OBJECTS = {} -- stores basic contents of an inventory

-- initialise containers
file_service.init_containers(CONTAINERS)
for name, property in pairs(CONTAINERS) do
    OBJECTS[name] = container_service.new({
        name = name,
        type = property.type,
        secret = property.secret,
        priority = property.priority,
        container = property.container,
    })
end

-- listen for requests
local QUEUE = {}
function listen()
    while true do
        -- rednet recieving
        local sender, message = rednet.receive("STORAGE_REQUEST_PROTOCOL")
        table.insert(QUEUE, {
            sender_id = sender,
            message = message
        })
    end
end

-- perform requests
function perform()
    while true do
        if #QUEUE > 0 then
            local pull = table.remove(QUEUE, 1)
            local header = pull.message.header
            local body = pull.message.body

            if header == "PUSH" then
                local source = body[1]
                local dest = body[2]

                if dest then
                    -- push to inventory
                    local transfer_partial = container_service.push(OBJECTS[source], OBJECTS[dest])
                    if transfer_partial then
                        rednet.send(pull.sender_id, "TRANSFERED PARTIAL", "STORAGE_RESPONSE_PROTOCOL")
                    else
                        rednet.send(pull.sender_id, "TRANSFERED FULL", "STORAGE_RESPONSE_PROTOCOL")
                    end
                else
                    -- push to main storage's highest priority and smallest amounts of items
                    local candidates = {}
                    for name, object in pairs(OBJECTS) do
                        if not object.secret then
                            candidates[name] = {
                                priority = object.priority,
                                size = #object.content
                            }
                        end
                    end

                    -- sort from top to bottom (highest priority to lowest)
                    table.sort(candidates, function (a, b)
                        if a.priority > b.priority then
                            return true
                        elseif a.priority == b.priority then
                            if a.size < b.size then
                                return true
                            else
                                return false
                            end
                        else
                            return false
                        end
                    end)

                    local transfer_partial = true
                    for name, _ in pairs(candidates) do
                        local container = OBJECTS[name]
                        if not container_service.push(OBJECTS[source], OBJECTS[name]) then
                            transfer_partial = false
                            break
                        end
                    end

                    if transfer_partial then
                        rednet.send(pull.sender_id, "TRANSFERED PARTIAL", "STORAGE_RESPONSE_PROTOCOL")
                    else
                        rednet.send(pull.sender_id, "TRANSFERED FULL", "STORAGE_RESPONSE_PROTOCOL")
                    end
                end
            elseif header == "GET" then
                -- perform get request
                local items = body[1] -- items to pull
                local dest = body[2] -- destination to push to
                local source = body[3] -- source to pull from

                if source then
                    -- push to inventory
                    local transfer_partial = container_service.get(OBJECTS[source], OBJECTS[dest], items)
                    if transfer_partial then
                        rednet.send(pull.sender_id, "TRANSFERED PARTIAL", "STORAGE_RESPONSE_PROTOCOL")
                    else
                        rednet.send(pull.sender_id, "TRANSFERED FULL", "STORAGE_RESPONSE_PROTOCOL")
                    end
                else
                    -- push to main storage's highest priority and smallest amounts of items
                    local candidates = {}
                    for name, object in pairs(OBJECTS) do
                        if not object.secret then
                            candidates[name] = {
                                priority = object.priority,
                                size = #object.content
                            }
                        end
                    end

                    -- sort from bottom to top (lowest priority to highest)
                    table.sort(candidates, function (a, b)
                        if a.priority < b.priority then
                            return true
                        elseif a.priority == b.priority then
                            if a.size > b.size then
                                return true
                            else
                                return false
                            end
                        else
                            return false
                        end
                    end)

                    local transfer_partial = true
                    for name, _ in pairs(candidates) do
                        local container = OBJECTS[name]
                        if not container_service.push(OBJECTS[source], OBJECTS[name]) then
                            transfer_partial = false
                            break
                        end
                    end

                    if transfer_partial then
                        rednet.send(pull.sender_id, "TRANSFERED PARTIAL", "STORAGE_RESPONSE_PROTOCOL")
                    else
                        rednet.send(pull.sender_id, "TRANSFERED FULL", "STORAGE_RESPONSE_PROTOCOL")
                    end
                end

            elseif header == "LIST" then

            elseif header == "FIND" then

            elseif header == "CRAFT" then
                -- to be added
            else
                -- ignore invalid header
            end
        else
            sleep(0.5)
        end
    end
end

parallel.waitForAny(listen, perform)