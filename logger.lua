local function timestamp(msg)
    local day = os.day()
    local time = textutils.formatTime(os.time(), true)
    local format = string.format("Day %d; %s: %s", day, time, msg)
    return format
end

return {
    fatal_error = function(message)
        error(timestamp(message), 0)
    end,

    error = function(message)
        term.setTextColor(colors.orange)
        print(timestamp(message))
        term.setTextColor(colors.white)
    end,

    warn = function(message)
        term.setTextColor(colors.yellow)
        print(timestamp(message))
        term.setTextColor(colors.white)
    end,

    ok = function(message)
        term.setTextColor(colors.green)
        print(timestamp(message))
        term.setTextColor(colors.white)
    end,

    system = function(message)
        term.setTextColor(colors.blue)
        print(timestamp(message))
        term.setTextColor(colors.white)
    end
}