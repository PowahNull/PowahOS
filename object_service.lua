local logger = require("logger")
local module = {}

module.new = function(object)
    -- initialise a container object
    local content = {}
    local dictionary = {}
    local wrap_ok, wrap = pcall(peripheral.wrap, object.container)
    if not wrap_ok then
        return {}, false
    end

    local list_ok, list = pcall(function()
        return wrap.list()
    end)

    if not list_ok then
        return {}, false
    end

    for slot, item in pairs(list) do
        local item_count = item.count
        local item_tag = item.name
        local nbt_hash = item.nbt or ""

        if not object.secret then
            -- add to dictionary if object is public
            local detail_ok, detail = pcall(function()
                return wrap.getItemDetail(slot)
            end)

            if detail_ok and detail then
                if detail.displayName then
                    local display_name = detail.displayName
                    if not dictionary[display_name] then dictionary[display_name] = {} end
                    dictionary[display_name][item_tag] = true
                end
            end
        end

        -- add items to content
        if not content[item_tag] then content[item_tag] = {} end
        if not content[item_tag][nbt_hash] then content[item_tag][nbt_hash] = {} end
        content[item_tag][nbt_hash][slot] = item_count
    end

    return {
        name = object.name,
        container = object.container,
        type = object.type,
        secret = object.secret,
        priority = object.priority,

        wrap = wrap,
        content = content,
        dictionary = dictionary
    }, true
end

module.update = function(...)
    for _, object in ipairs({...}) do
        local updated, ok = module.new(object)
        if ok then
            object.wrap = updated.wrap
            object.content = updated.content
            object.dictionary = updated.dictionary
        end
    end
end

module.push = function(from_object, to_object)
    -- attempt to push all items from an object to another (return if all items transfered)
    local failed_to_transfer = 0
    for _, nbt_table in pairs(from_object.content) do
        for _, slots in pairs(nbt_table) do
            for slot, item_count in pairs(slots) do
                local transfer_ok, transfered = pcall(function()
                    return from_object.wrap.pushItems(to_object.container, slot, item_count) 
                end)

                -- immediately exit and raise error
                if not transfer_ok then
                    logger.error("object service push function failed internally")
                    return -1, false
                end
                failed_to_transfer = failed_to_transfer + item_count - transfered
            end
        end
    end
    return failed_to_transfer, true
end

module.get_multi = function(from_object, to_object, items)
    -- attempt to get one type of item from an object to another
    local failed_to_transfer = {}
    for _, data in pairs(items) do
        local item_tag = data.item
        local nbt_hash = data.nbt or ""
        local item_count = data.count
                
        -- data and nbt not present
        if not from_object.content[item_tag] then goto continue end
        if not from_object.content[item_tag][nbt_hash] then goto continue end

        for slot, _ in pairs(from_object.content[item_tag][nbt_hash]) do
            local transfer_ok, transfered = pcall(function()
                return from_object.wrap.pushItems(to_object.container, slot, item_count)
            end)

            if not transfer_ok then
                logger.error("object service get_multi function failed internally")
                return {}, false
            end
            item_count = item_count - transfered

            -- finished transfering or failed to transfer
            if item_count <= 0 or transfered <= 0 then
                break
            end
        end

        -- if failed to transfer all contents
        if item_count > 0 then
            -- insert failed_to_transfer
            table.insert(failed_to_transfer, {item = item_tag, nbt = nbt_hash, count = item_count})
        end
        
        ::continue::
    end

    return failed_to_transfer, true
end

module.get_single = function(from_object, to_object, item, nbt, count)
    -- retrieve a single type of item from a container
    -- data and nbt not present
    if not from_object.content[item] then return count, true end
    if not from_object.content[item][nbt] then return count, true end

    local to_transfer = count
    for slot, _ in pairs(from_object.content[item][nbt]) do
        local transfer_ok, transfered = pcall(function()
            return from_object.wrap.pushItems(to_object.container, slot, to_transfer)
        end)

        if not transfer_ok then
            logger.error("object service get_single function failed internally")
            return -1, false
        end
        to_transfer = to_transfer - transfered

        -- finished transfering or failed to transfer any more (container target is full)
        if to_transfer <= 0 or transfered <= 0 then
            break
        end
    end

    return to_transfer, true
end

module.amount = function(object, item, nbt)
    -- find the amount of one item in a container
    nbt = nbt or ""
    -- data and nbt not present
    if not object.content[item] then return 0 end
    if not object.content[item][nbt] then return 0 end

    local total_items = 0
    for _, item_count in pairs(object.content[item][nbt]) do
        total_items = total_items + item_count
    end

    return total_items
end

module.get_detail = function(object)
    
end

module.find = function(container, searchword)
    -- find matching tags in containers and return valid item amounts
    local candidates = {}
    for name, tags in pairs(container.dictionary) do
        if string.find(string.lower(name), string.lower(searchword), 1, true) then
            for tag, _ in pairs(tags) do
                table.insert(candidates, {
                    name = name,
                    tag = tag,
                })
            end
        end
    end
    return candidates
end

return module
