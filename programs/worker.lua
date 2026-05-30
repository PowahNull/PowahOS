peripheral.find("modem", rednet.open)
local THREADS = 240
rednet.host("WORKER_INIT_PROTOCOL", string.format("Computer #%d", os.getComputerID()))
print("hosted to rednet")
local _, OBJECTS = rednet.receive("WORKER_INIT_PROTOCOL")
print("recieved object table")

-- process an entire inventory at once
local QUEUE = {}
local function listen()
    while true do
        -- rednet recieving
        local sender, message = rednet.receive("PARALLEL_CALL_PROTOCOL")
        if message then
            if type(message) == "table" then
                table.insert(QUEUE, {sender, message})
            end
        end
    end
end

local function detail(wrap, list, searchwords)
    local _ptr = 0
    local dispatch = {}
    for slot, _ in pairs(list) do
        local index = _ptr + 1
        if not dispatch[index] then dispatch[index] = {} end
        table.insert(dispatch[index], slot)
        _ptr = (_ptr + 1) % THREADS
    end

    local return_pool = {}
    local coworkers = {}

    local function coworker(i)
        local bucket = dispatch[i]
        if not bucket then return end
        while true do
            local pull = table.remove(bucket)
            if not pull then return end

            local ok, detail = pcall(wrap.getItemDetail, pull)

            if ok and detail then
                local display = detail.displayName
                local continue = false
                if searchwords then
                    for _, v in pairs(searchwords) do
                        if string.find(string.lower(detail.name), v, 1, true) or string.find(string.lower(display), v, 1, true) then
                            continue = true
                            break
                        end
                    end
                else
                    continue = true
                end

                if continue then
                    local nbt = detail.nbt
                    local extra = {}
                    if nbt then
                        if detail.enchantments then
                            for _, enchant in pairs(detail.enchantments) do
                                table.insert(extra, enchant.displayName)
                            end
                        elseif detail.potionEffects then
                            for _, potion in pairs(detail.potionEffects) do
                                local duration = potion.duration
                                local minute = math.floor(duration / 60)
                                local second = duration % 60

                                local format = string.format("%s (%02d:%02d)", potion.displayName, minute, second)
                                table.insert(extra, format)
                            end
                        end
                    end
                    return_pool[pull] = {
                        display = display,
                        nbt = nbt or "",
                        count = detail.count,
                        item = detail.name,
                        extra = extra
                    }
                end
            end
        end
    end

    for i = 1, THREADS do
        coworkers[i] = function() coworker(i) end
    end

    -- wait for all threads to finish
    parallel.waitForAll(table.unpack(coworkers))
    return return_pool
end

local function dispatch()
    while true do
        if #QUEUE > 0 then
            -- ignore bad requests
            local pull = table.remove(QUEUE, 1)
            local sender = pull[1]
            local msg = pull[2]
            local object = msg[1]
            local searchwords = msg[2]

            local wrap_ok, wrap = pcall(peripheral.wrap, OBJECTS[object].container)
            if not wrap_ok then
                print(string.format("peripheral wrap of %s failed", object))
                rednet.send(sender, "WRAP FAILURE", "PARALLEL_RETURN_PROTOCOL")
                return
            end
            local list_ok, list = pcall(wrap.list)
            if not list_ok then
                print(string.format("peripheral list of %s failed", object))
                rednet.send(sender, "LIST FAILURE", "PARALLEL_RETURN_PROTOCOL")
                return
            end

            local result = detail(wrap, list, searchwords)
            rednet.send(sender, result, "PARALLEL_RETURN_PROTOCOL")
        else
            sleep(0.05)
        end
    end
end

parallel.waitForAny(listen, dispatch)
-- can only exit if there is a fatal error
error("fatal error occured")
