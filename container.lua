local module = {}

module.new = function(properties)
    -- initialise a container object
    local content = {}
    local dictionary = {}
    local wrap = peripheral.wrap(properties.container)

    if properties.secret then
        -- create a simpler container object with minimal data as it will not be searched
        for slot, item in pairs(wrap.list()) do
            local item_count = item.count
            local item_tag = item.name
            local nbt_hash = item.nbt or ""

            -- add items to content
            if not content[item_tag] then content[item_tag] = {} end
            if not content[item_tag][nbt_hash] then content[item_tag][nbt_hash] = {} end
            content[item_tag][nbt_hash][slot] = {
                count = item_count,
                name = "null"
            }
        end
    else
        -- create a detailed container with a dictionary
        for slot, item in pairs(wrap.list()) do
            -- get advanced inventory details
            local detail = wrap.getItemDetail(slot)
            local display_name = detail.displayName
            local item_count = item.count
            local item_tag = item.name
            local nbt_hash = item.nbt or ""

            -- add to dictionary (different tags may share the same display name)
            if not dictionary[display_name] then dictionary[display_name] = {} end
            dictionary[display_name][item_tag] = true

            -- add items to content
            if not content[item_tag] then content[item_tag] = {} end
            if not content[item_tag][nbt_hash] then content[item_tag][nbt_hash] = {} end
            content[item_tag][nbt_hash][slot] = {
                count = item_count,
                name = display_name
            }
        end
    end

    return {
        type = properties.type,
        name = properties.name,
        secret = properties.secret,
        priority = properties.priority,
        container = properties.container,

        wrap = wrap,
        content = content,
        dictionary = dictionary
    }
end

module.push = function(from_container, to_container)
    -- attempt to push all items from a container to another (return if all items transfered)
    local transfer_partial = false
    for _, nbt_table in pairs(from_container.content) do
        for _, slots in pairs(nbt_table) do
            for slot, item in pairs(slots) do
                local transfered = from_container.wrap.pushItems(to_container.container, slot, item.count)
                if transfered < item.count then
                    transfer_partial = true
                end
            end
        end
    end

    -- update containers
    from_container, to_container = module.new(from_container), module.new(to_container)
    return transfer_partial
end

module.get = function(from_container, to_container, items)
    -- attempt to get one type of item from a container to another
    local transfer_partial = false
    for item, metadata in pairs(items) do
        local nbt = metadata.nbt or ""
        local count = metadata.count
                
        if not from_container[item] then goto continue end
        if not from_container[item][nbt] then goto continue end

        for slot, _ in pairs(from_container[item][nbt]) do
            local transfered = from_container.wrap.pushItems(to_container.container, slot, count)
            count = count - transfered
        end

        if count > 0 then
            transfer_partial = true
        end
        ::continue::
    end

    -- return updated inventories
    from_container, to_container = module.new(from_container), module.new(to_container)
    return transfer_partial
end

module.find = function(container, searchword)
    -- find matching tags in containers and return valid item nbts
    local candidates = {}
    for name, tag in pairs(container.dictionary) do
        if string.find(name, searchword) then
            table.insert(candidates, {
                name = name,
                tag = tag,
                nbt_contents = container.content[tag]
            })
        end
    end
    return candidates
end

return module