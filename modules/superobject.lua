local module = {}

module.merge_items = function(array)
    -- merges content_item or match_tag and match_mod tables
    local main = {}
    for _, content in pairs(array) do
        for item_tag, count in pairs(content) do
            if not main[item_tag] then main[item_tag] = 0 end
            main[item_tag] = main[item_tag] + count
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
