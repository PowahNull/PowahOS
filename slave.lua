-- get modem
peripheral.find("modem", rednet.open)
-- loop max iterations to avoid exhaustion
MAX_ITERATIONS = 10000

-- start rednet host
do
    local lookup_name = string.format("slave_%d", os.getComputerID())
    rednet.host("SLAVE_PROTOCOL", lookup_name)
    rednet.host("SLAVE_INIT_PROTOCOL", lookup_name)
end

-- the storage is an inventory which is not a chest (compatable with drawers)
do
    local storage_candidates = {peripheral.find("inventory", function(_, wrapped)
        if peripheral.getType(wrapped) == "minecraft:chest" then return false else return true end
    end)}

    if #storage_candidates > 0 then
        STORAGE = storage_candidates[1]
        print("FOUND SUITABLE STORAGE INVENTORY, PROCEEDING")
    else
        print("NO SUITABLE STORAGE INVENTORY FOUND, EXITING")
        exit()
    end
end

-- the chest must double and be connected to the packager
do
    local chest_candidates = {peripheral.find("inventory", function(_, wrapped)
        if peripheral.getType(wrapped) == "minecraft:chest" then return false else return true end
    end)}

    if #chest_candidates > 0 then
        CHEST = chest_candidates[1]
        print("FOUND SUITABLE CHEST INVENTORY, PROCEEDING")
    else
        print("NO SUITABLE CHEST INVENTORY FOUND, EXITING")
        exit()
    end
end

-- slave init function (do not yield until master respond)
do
    local receive_id, message = rednet.receive("SLAVE_INIT_PROTOCOL")
    local wrapper = peripheral.wrap(message)
    if wrapper then
        PACKAGER = wrapper
        print("SLAVE INIT PACKAGER SUCCESS, PROCEEDING")
        rednet.send(receive_id, "INIT_OK", "SLAVE_INIT_PROTOCOL")
    else
        print("SLAVE INIT PACKAGER FAILED, EXITING")
        rednet.send(receive_id, "INIT_NOT_OK", "SLAVE_INIT_PROTOCOL")
        exit()
    end
end

-- listen function (add to event queue)
QUEUE = {}
function listen()
    while true do
        -- rednet recieving
        local _, message = rednet.receive("SLAVE_PROTOCOL")
        table.insert(QUEUE, message)
    end
end

-- pull a request from the queue and perform it
function perform()
    while true do
        if #QUEUE > 0 then
            -- pull a request
            local request = table.remove(QUEUE, 1)
            -- header is the destination, body is the payload
            local destination = request.header
            local data = request.body

            -- setAddress of packager
            PACKAGER.setAddress(destination)
            
            local requests_todo = #data
            local requests_performed = 0
            -- has to pull n items from slot
            for slot, n in pairs(data) do
                -- items transfered
                local to_transfer = n
                requests_performed = requests_performed + 1
                -- limited loop
                for i = 1, MAX_ITERATIONS do
                    -- transfer if missing items
                    if to_transfer > 0 then
                        local transfered = STORAGE.pushItems("right", slot, to_transfer)
                        to_transfer = to_transfer - transfered
                    end

                    -- slots filled in the chest
                    local filled = #CHEST.list()

                    -- perform packager push if more than 9 slots filled
                    if filled >= 9 then
                        -- the chest has enough items to push to a package
                        for j = 1, MAX_ITERATIONS do
                            -- attempt package until chest has less than 9 items
                            if PACKAGER.makePackage() then
                                -- update chest content
                                filled = filled - 9
                                -- break if less than 9 items
                                if filled < 9 then break end
                            end
                            -- attempt packaging again in a quarter second
                            sleep(0.25)
                        end
                    end

                    -- perform packager push if all requests performed and still items to transfer
                    if requests_todo == requests_performed and to_transfer == 0 and filled > 0 then
                        -- if all items have finished transfering
                        for j = 1, MAX_ITERATIONS do
                            -- attempt package until chest is empty
                            if PACKAGER.makePackage() then
                                -- update chest content
                                filled = filled - 9
                                -- break if all items are transfered
                                if filled <= 0 then break end
                            end
                            -- attempt packaging again in a quarter second
                            sleep(0.25)
                        end
                    else
                        -- sleep for a quarter second before making another transfer
                        sleep(0.25)
                    end

                    -- break if transfer done
                    if to_transfer <= 0 then break end
                end
            end
        else
            -- no requests, sleep for a half second
            sleep(0.5)
        end
    end
end

parallel.waitForAny(listen, perform)
