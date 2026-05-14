rednet.open("back")
local lookup_name = string.format("slave_%d", os.getComputerID())
rednet.host("SLAVE_PROTOCOL", lookup_name)
rednet.host("SLAVE_INIT_PROTOCOL", lookup_name)

local VAULT = peripheral.wrap("bottom")
local CHEST = peripheral.wrap("right")
local PACKAGER = peripheral.wrap("Create_Packager_-1") -- Null packager, do not use
local MASTER_ID = 0

-- slave init function (do not yield until master respond)
while true do
    local receive_id, message = rednet.receive("SLAVE_INIT_PROTOCOL")
    if receive_id == MASTER_ID then
        local wrapper = peripheral.wrap(message)
        if wrapper then
            PACKAGER = wrapper
            print("SLAVE INITIALISING PACKAGER SUCCESS, PROCEEDING")
            rednet.send(MASTER_ID, "HANDSHAKE_OK", "SLAVE_INIT_PROTOCOL")
            break
        else
            print("SLAVE INITIALISING PACKAGER FAILED, EXITING")
            rednet.send(MASTER_ID, "HANDSHAKE_NOT_OK", "SLAVE_INIT_PROTOCOL")
            exit()
        end
    end
end

-- listen function (add to event queue)
local Queue = {}
function listen_to_master()
    while true do
        -- rednet recieving
        local receive_id, message = rednet.receive("SLAVE_PROTOCOL")
        if receive_id == MASTER_ID then
            -- make sure it is from the master computer
            table.insert(Queue, message)
        end
    end
end

-- pull a request from the queue and perform it
function perform_request()
    while true do
        if #Queue > 0 then
            -- pull a request
            local request = table.remove(Queue, 1)
            -- header is the destination, body is the payload
            local destination = request.header
            local data = request.body

            -- make sure adress is set
            repeat
                PACKAGER.setAddress(destination)
                -- sleep for abit to prevent thread exhaustion
                sleep(0.1)
            until PACKAGER.getAddress == destination
            
            -- pulls n items from slot
            for slot, n in pairs(data) do
                -- items transfered
                local to_transfer = n
                while to_transfer > 0 do
                    local transfered = VAULT.pushItems("right", slot, n)
                    to_transfer = to_transfer - transfered

                    -- perform packager push
                    local filled = #CHEST.list()
                    if filled >= 9 then
                        -- the chest has enough items to push to a package
                        while filled >= 9 do
                            -- attempt package until chest has less than 9 items
                            if PACKAGER.makePackage() then
                                -- update chest content
                                filled = filled - 9
                            end
                            -- attempt packaging again in a quarter second
                            sleep(0.25)
                        end
                    elseif to_transfer == 0 then
                        -- if all items have finished transfering
                        while filled > 0 do
                            -- attempt package until chest is empty
                            PACKAGER.makePackage()
                            -- update chest content
                            filled = #CHEST.list()
                            -- attempt packaging again in a quarter second
                            sleep(0.25)
                        end
                    else
                        -- sleep for a quarter second before making another transfer
                        sleep(0.25)
                    end
                end
            end
        else
            -- no requests, sleep for a half second
            sleep(0.5)
        end
    end
end

parallel.waitForAny(listen_to_master, perform_request)
