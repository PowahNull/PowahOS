local logger = require("logger")
local module = {}

local workers = {}
local no_workers = 0

module.init = function(OBJECTS)
    local computers = {rednet.lookup("WORKER_INIT_PROTOCOL", nil, 5)}
    for _, id in pairs(computers) do
        logger.ok(string.format("hello to Computer #%d", id))
        rednet.send(id, OBJECTS, "WORKER_INIT_PROTOCOL")
    end
    logger.system(string.format("found %d workers", #computers))
    workers = computers
    no_workers = #computers
    return no_workers
end

module.list = function(list)
    local select = {}
    local _ptr = 0
    for name, _ in pairs(list) do
        local index = _ptr + 1
        if not select[index] then select[index] = {} end
        table.insert(select[index], name)

        _ptr = (_ptr + 1) % no_workers
    end

    local main_pool = {}
    local to_perform = 0
    
    for i = 1, no_workers do
        if select[i] then
            for _, pull_name in pairs(select[i]) do
                rednet.send(workers[i], {pull_name}, "PARALLEL_CALL_PROTOCOL")
                to_perform = to_perform + 1
            end
        end
    end

    while to_perform > 0 do
        local _, message = rednet.receive("PARALLEL_RETURN_PROTOCOL", 2)
        if message ~= "LIST FAILURE" and message ~= "WRAP FAILURE" then
            table.insert(main_pool, message)
        end
        to_perform = to_perform - 1
    end

    return main_pool
end

module.find = function(list, search)
    local select = {}
    local _ptr = 0
    for name, _ in pairs(list) do
        local index = _ptr + 1
        if not select[index] then select[index] = {} end
        table.insert(select[index], name)

        _ptr = (_ptr + 1) % no_workers
    end

    local main_pool = {}
    local to_perform = 0
    
    for i = 1, no_workers do
        if select[i] then
            for _, pull_name in pairs(select[i]) do
                rednet.send(workers[i], {pull_name, search}, "PARALLEL_CALL_PROTOCOL")
                to_perform = to_perform + 1
            end
        end
    end

    while to_perform > 0 do
        local _, message = rednet.receive("PARALLEL_RETURN_PROTOCOL", 2)
        if message ~= "LIST FAILURE" and message ~= "WRAP FAILURE" then
            table.insert(main_pool, message)
        end
        to_perform = to_perform - 1
    end

    return main_pool
end

return module
