local module = {}

module.list = function(container_list)
    -- list items in a storage network
    local mass_table = {}
    for _, container in pairs(container_list) do
        for item_tag, nbt_table in pairs(container.content) do
            if not mass_table[item_tag] then mass_table[item_tag] = {} end
            for nbt, slots in pairs(nbt_table) do
                if not mass_table[item_tag][nbt] then mass_table[item_tag][nbt] = {} end
                for slot, item in pairs(slots) do
                    -- add items to content
                    if not mass_table[item_tag][nbt][slot] then mass_table[item_tag][nbt][slot] = {} end
                    table.insert(mass_table[item_tag][nbt][slot], {
                        count = item.count,
                        name = item.name,
                        container = container.name
                    })
                end
            end
        end
    end

    return mass_table
end

return module