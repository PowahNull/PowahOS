local logger = require("logger")
return {
    init_containers = function(PROPERTIES)
        local PATH = "disk/inventory.txt"
        local file = fs.open(PATH, "r")

        if type(file) == "nil" then
            logger.fatal_error("inventory.txt file not found")
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
                    parsed_file[current_header][string.lower(index)] = 
                    {
                        value = string.lower(value),
                        line = file_line
                    }
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
                    type = data.value
                elseif key == "container" then
                    container = data.value
                elseif key == "secret" then
                    secret = (data.value == "true")
                elseif key == "priority" then
                    priority = tonumber(data.value) or 0
                else
                    logger.warn(string.format("inventory.txt contained unexpected key '%s' at line %d for header %s", key, data.line, header))
                end
            end

            if not type then
                logger.error(string.format("inventory.txt missing field 'type' for header %s", header))
                OK = false
            elseif type ~= "generic" and type ~= "drawer" then
                logger.error(string.format("inventory.txt field 'type' is invalid in header %s", header))
                OK = false
            end

            if not container then
                logger.error(string.format("inventory.txt missing field 'container' for header %s", header))
                OK = false
            elseif not peripheral.wrap(container) then
                logger.error(string.format("inventory.txt field 'container' in header %s is not registered", header))
                OK = false
            elseif not peripheral.hasType(container, "inventory") then
                logger.error(string.format("inventory.txt field 'container' in header %s is not a valid container", header))
                OK = false
            end

            if OK then
                PROPERTIES[header] = {
                    container = container,
                    type = type,
                    secret = secret,
                    priority = priority
                }
                logger.ok(string.format("successfully registered container %s", header))
            else
                logger.warn(string.format("ignored container %s for registration", header))
            end
        end
    end,

    init_crafting = function(CRAFTING, PATH)
        
    end
}
