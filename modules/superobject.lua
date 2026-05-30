local module = {}

module.merge_items = function(array)
    -- merges content_item or match_tag and match_mod tables
    local main = {}
    for _, content in pairs(array) do
        for item_tag, count in pairs(content) do
            main[item_tag] = (main[item_tag] or 0) + count
        end
    end

    return main
end

module.merge_items_nbt = function(array)
    -- merges content_item or match_tag and match_mod tables
    local main = {}
    for _, content in pairs(array) do
        for _, value in pairs(content) do
            local combine = string.format("%s<%s>", value.item, value.nbt)
            if not main[combine] then
                main[combine] = {
                    display = value.display,
                    item = value.item,
                    nbt = value.nbt,
                    count = value.count,
                    -- shallow clone
                    extra = {table.unpack(value.extra)}
                }
            else
                main[combine].count = main[combine].count + value.count
            end
        end
    end

    return main
end

module.shuffle = function(array)
    -- randomise seed
    math.randomseed(os.epoch("local"))
    -- randomise array
    local assignment = {}
    local slot = 1
    for name, property in pairs(array) do
        if not property.secret then
            assignment[slot] = {
                priority = property.priority,
                random = math.random(),
                name = name
            }
            slot = slot + 1
        end
    end

    table.sort(assignment, function(a, b)
        if a.priority == b.priority then
            return a.random > b.random
        end
        return a.priority > b.priority
    end)

    return assignment
end

return module
