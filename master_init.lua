local G = {}
-- get modem
peripheral.find("modem", rednet.open)
-- loop max iterations to avoid exhaustion
G.MAX_ITERATIONS = 100

-- Read disk content for slaves
do
    local file = fs.open("disk/slaves.json", "r")

    if type(file) == "nil" then
        error("SLAVE DATA FILE NOT FOUND", 0)
    elseif type(file) == "string" then
        error("COULD NOT OPEN FILE", 0)
    end

    local json = file.readAll()
    file.close()
    G.SLAVE_TABLE = textutils.unserialiseJSON(json)

    if not G.SLAVE_TABLE then
        error("SLAVE DATA JSON PARSE FAILURE", 0)
    end

    G.NUMBER_OF_SLAVES = #G.SLAVE_TABLE
    G.SELF_ID = os.getComputerID()
end

-- Slave computers detection
for i = 1, G.MAX_ITERATIONS do
    local computers = {rednet.lookup("SLAVE_INIT_PROTOCOL")}
    if #computers == G.NUMBER_OF_SLAVES then
        print(string.format("FOUND ALL SLAVE COMPUTERS: %d/%d REGISTERED", #computers, G.NUMBER_OF_SLAVES))
        print("PERFORMING NETWORK HANDSHAKE...")
        break
    elseif #computers > G.NUMBER_OF_SLAVES then
        error(string.format("UNEXPECTED SLAVE COMPUTERS: %d/%d REGISTERED", #computers, G.NUMBER_OF_SLAVES), 0)
    elseif #computers < G.NUMBER_OF_SLAVES and #computers > 0 then
        warn(string.format("MISSING SLAVE COMPUTER: %d/%d REGISTERED", #computers, G.NUMBER_OF_SLAVES))
    else
        warn(string.format("NO SLAVE COMPUTERS FOUND: %d/%d REGISTERED", #computers, G.NUMBER_OF_SLAVES))
    end
end

local term_width, _ = term.getSize()
print(string.rep("=", term_width))

-- Slave computers handshake
local response_success = 0
local response_timeout = 0
local response_failure = 0
for _, v in pairs(G.SLAVE_TABLE) do
    rednet.send(v.slave_id, v.packager, "SLAVE_INIT_PROTOCOL")
    local slave_id, status = rednet.receive("SLAVE_INIT_PROTOCOL", 5)

    if not slave_id then
        status = "INIT_TIMEOUT"
    end

    io.write(string.format("SLAVE %d RESPONDED WITH: ", v.slave_id))
    if status == "INIT_OK" then
        term.setTextColor(colors.green)
        response_success = response_success + 1
    elseif status == "INIT_NOT_OK" then
        term.setTextColor(colors.red)
        response_failure = response_failure + 1
    elseif status == "INIT_TIMEOUT" then
        term.setTextColor(colors.yellow)
        response_timeout = response_timeout + 1
    end

    io.write(status)
    -- terminatate print
    term.setTextColor(colors.white)
    io.write("\n")
end
print(string.rep("=", term_width))
io.write("SLAVE NETWORK DIAGNOSTICS REPORT\n")
io.write("SLAVE INIT SUCCESS: ")
term.setTextColor(colors.green)
io.write(string.format("%d/%d (%.1f%%)\n", response_success, G.NUMBER_OF_SLAVES, response_success/G.NUMBER_OF_SLAVES * 100))
term.setTextColor(colors.white)
io.write("SLAVE INIT TIMEOUT: ")
term.setTextColor(colors.yellow)
io.write(string.format("%d/%d (%.1f%%)\n", response_timeout, G.NUMBER_OF_SLAVES, response_timeout/G.NUMBER_OF_SLAVES * 100))
term.setTextColor(colors.white)
io.write("SLAVE INIT FAILURE: ")
term.setTextColor(colors.red)
io.write(string.format("%d/%d (%.1f%%)\n", response_failure, G.NUMBER_OF_SLAVES, response_failure/G.NUMBER_OF_SLAVES * 100))
if response_success == G.NUMBER_OF_SLAVES then
    term.setTextColor(colors.blue)
    print("ALL SYSTEMS OPERATIONAL")
end
term.setTextColor(colors.white)
print(string.rep("=", term_width))
