local logger = require("logger")

local module = {}
module.init_objects = function(PROPERTIES)
    local PATH = "disk/inventory.txt"
    local file = fs.open(PATH, "r")

    if type(file) == "nil" then
        logger.fatal_error("inventory.txt not found")
    elseif type(file) == "string" then
        logger.fatal_error("inventory.txt could not be opened")
    else
        file.close()
    end

    local parsed_file = {}
    local current_header = ""
    local file_line = 1
    for line in io.lines(PATH) do
        local header = string.match(line, "%[([^%s]+)%]")
        if header then
            parsed_file[header] = {}
            current_header = header
        else
            -- the nightmare regex
            for index, value in string.gmatch(line, "%s*([^%s]+)%s*=%s*([^%s]+)%s*") do
                if current_header ~= "" then
                    parsed_file[current_header][string.lower(index)] = string.lower(value)
                end
            end
            file_line = file_line + 1
        end
    end

    for header, values in pairs(parsed_file) do
        local OK = true

        local type =  nil
        local container = nil
        local secret = false
        local priority = 0

        for key, data in pairs(values) do
            if key == "type" then
                type = data
            elseif key == "container" then
                container = data
            elseif key == "secret" then
                secret = (data == "true")
            elseif key == "priority" then
                priority = tonumber(data) or 0
            else
                logger.warn(string.format("header %s has unexpected field '%s'", key, header))
            end
        end

        if not type then
            logger.error(string.format("header %s is missing field 'type'", header))
            OK = false
        elseif type ~= "generic" and type ~= "drawer" then
            logger.error(string.format("header %s field 'type' is invalid", header))
            OK = false
        end

        if not container then
            logger.error(string.format("header %s is missing field 'container'", header))
            OK = false
        elseif not peripheral.wrap(container) then
            logger.error(string.format("header %s field 'container' is not registered", header))
            OK = false
        elseif not peripheral.hasType(container, "inventory") then
            logger.error(string.format("header %s field 'container' is not an inventory", header))
            OK = false
        end

        if OK then
            PROPERTIES[header] = {
                container = container,
                priority = priority,
                secret = secret,
                name = header,
                type = type
            }
            logger.ok(string.format("header %s registered", header))
        else
            logger.warn(string.format("header %s failed to register", header))
        end
    end
end

module.init_dictionary = function(DICTIONARY)
    local PATH = "disk2/dictionary.txt"
    local file = fs.open(PATH, "r")

    if type(file) == "nil" then
        logger.fatal_error("dictionary.txt not found")
    elseif type(file) == "string" then
        logger.fatal_error("dictionary.txt could not be opened")
    else
        file.close()
    end

    for line in io.lines(PATH) do
        -- the nightmare regex
        for registry, name in string.gmatch(line, "%s*([^%s]+)%s*=%s*([^%s]+)%s*") do
            DICTIONARY[registry] = name
        end
    end
end

module.init_crafting = function(CRAFTING)
    
end

return module
