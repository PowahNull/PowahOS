local module = {}

module.content_nbt = function(object)
    -- get contents of an object with nbt
    local wrap_ok, wrap = pcall(peripheral.wrap, object.container)
    if not wrap_ok then return {}, "CONTENT_NBT_WRAP_ERROR" end
    local list_ok, list = pcall(wrap.list)
    if not list_ok then return {}, "CONTENT_NBT_LIST_ERROR" end

    local content = {}

    for _, item in pairs(list) do
        local item_count = item.count
        local item_tag = item.name
        local item_nbt = item.nbt or ""

        local compact = string.format("%s<%s>", item_tag, item_nbt)

        -- add items to content
        if not content[compact] then content[compact] = 0 end
        content[compact] = content[compact] + item_count
    end

    return content, "CALL_OK"
end

module.content = function(object)
    -- get contents of an object ignoring nbt
    -- return content compatable with match
    local wrap_ok, wrap = pcall(peripheral.wrap, object.container)
    if not wrap_ok then return {}, "CONTENT_ITEM_WRAP_ERROR" end
    local list_ok, list = pcall(wrap.list)
    if not list_ok then return {}, "CONTENT_ITEM_LIST_ERROR" end

    local content = {}

    for _, item in pairs(list) do
        local item_count = item.count
        local item_tag = item.name

        -- add items to content
        if not content[item_tag] then content[item_tag] = 0 end
        content[item_tag] = content[item_tag] + item_count
    end

    return content, "CALL_OK"
end

module.fill = function(object)
    -- get fill of an object
    local wrap_ok, wrap = pcall(peripheral.wrap, object.container)
    if not wrap_ok then return -1, "FILL_WRAP_ERROR" end
    local list_ok, list = pcall(wrap.list)
    if not list_ok then return -1, "FILL_LIST_ERROR" end

    local fill = 0
    for _, _ in pairs(list) do
        fill = fill + 1
    end

    return fill, "CALL_OK"
end

module.push = function(from_object, to_object)
    -- attempt to push all items from an object to another
    local wrap_ok, wrap = pcall(peripheral.wrap, from_object.container)
    if not wrap_ok then return -1, "PUSH_WRAP_ERROR" end
    local list_ok, list = pcall(wrap.list)
    if not list_ok then return -1, "PUSH_LIST_ERROR" end

    local not_moved = 0

    for slot, item in pairs(list) do
        local push_ok, moved = pcall(wrap.pushItems, to_object.container, slot, item.count)
        if not push_ok then return -1, "PUSH_MOVE_ERROR" end
        not_moved = not_moved + (item.count - moved)
    end

    return not_moved, "CALL_OK"
end

module.get = function(from_object, to_object, transfer)
    -- attempt to get specific items from an object to another
    local wrap_ok, wrap = pcall(peripheral.wrap, from_object.container)
    if not wrap_ok then return {}, "GET_WRAP_ERROR" end
    local list_ok, list = pcall(wrap.list)
    if not list_ok then return {}, "GET_LIST_ERROR" end

    local to_move = {}
    local orders = #transfer
    for _, data in pairs(transfer) do
        local item_tag = data.item
        local item_nbt = data.nbt or ""

        if not to_move[item_tag] then to_move[item_tag] = {} end
        if not to_move[item_tag][item_nbt] then to_move[item_tag][item_nbt] = 0 end
        to_move[item_tag][item_nbt] = to_move[item_tag][item_nbt] + data.count
    end

    for slot, item in pairs(list) do
        local item_tag = item.name
        local item_nbt = item.nbt or ""

        if to_move[item_tag] and to_move[item_tag][item_nbt] and to_move[item_tag][item_nbt] > 0 then
            -- item is correct
            local push_ok, moved = pcall(wrap.pushItems, to_object.container, slot, to_move[item_tag][item_nbt])
            if not push_ok then return {}, "GET_MOVE_ERROR" end
            
            to_move[item_tag][item_nbt] = math.max(0, to_move[item_tag][item_nbt] - moved)
            if to_move[item_tag][item_nbt] <= 0 then
                orders = orders - 1
            end
        end

        if orders <= 0 then break end
    end

    local left_to_move = {}
    local slot = 1
    for item_tag, nbt_table in pairs(to_move) do
        for item_nbt, count in pairs(nbt_table) do
            if count > 0 then
                left_to_move[slot] = {item = item_tag, nbt = item_nbt, count = count}
                slot = slot + 1
            end
        end
    end

    return left_to_move, "CALL_OK"
end

module.amount = function(object, item_tag, nbt)
    -- find the amount of one item in a container
    local wrap_ok, wrap = pcall(peripheral.wrap, object.container)
    if not wrap_ok then return -1, "AMOUNT_WRAP_ERROR" end
    local list_ok, list = pcall(wrap.list)
    if not list_ok then return -1, "AMOUNT_LIST_ERROR" end

    local total_items = 0
    for _, item in pairs(list) do
        if item.name == item_tag and (item.nbt == nbt or nbt == nil) then
            total_items = total_items + item.count
        end
    end

    return total_items, "CALL_OK"
end

module.match = function(object, mod_search, tag_search)
    -- find matching items with mod name OR item tags in containers and return valid items and their count (nbt ignored)
    local wrap_ok, wrap = pcall(peripheral.wrap, object.container)
    if not wrap_ok then return {}, "MATCH_WRAP_ERROR" end
    local list_ok, list = pcall(wrap.list)
    if not list_ok then return {}, "MATCH_LIST_ERROR" end

    -- if one name match then continue
    local candidates = {}
    for _, item in pairs(list) do
        local this_slot_done = false

        local namespace = string.match(item.name, ":([/%w_%-]+)")
        if namespace then namespace = string.lower(namespace) end
        for _, v in pairs(tag_search) do
            if string.find(namespace, v, 1, true) then
                candidates[item.name] = (candidates[item.name] or 0) + item.count
                this_slot_done = true
                break
            end
        end

        if not this_slot_done then
            local mod_name = string.match(item.name, "([%w_%-]+):")
            if mod_name then mod_name = string.lower(mod_name) end
            for _, v in pairs(mod_search) do
                if string.find(mod_name, v, 1, true) then
                    candidates[item.name] = (candidates[item.name] or 0) + item.count
                    break
                end
            end
        end
    end
    return candidates, "CALL_OK"
end

module.match_nbt = function(object, search)
    
end

return module
