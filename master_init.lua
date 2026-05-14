-- get modem
peripheral.find("modem", rednet.open)
-- loop max iterations to avoid exhaustion
MAX_ITERATIONS = 100

-- Read disk content for slaves
do
    SLAVE_CONNECT_PATH = "disk/slaves.json"
    SLAVE_DATA_FILE = fs.open(SLAVE_CONNECT_PATH, "r")

    if type(SLAVE_DATA_FILE) == "nil" then
        print("ERROR: SLAVE DATA FILE NOT FOUND, EXITING")
        exit()
    elseif type(SLAVE_DATA_FILE) == "string" then
        print("ERROR: COULD NOT OPEN FILE, EXITING")
        exit()
    end

    SLAVE_JSON = SLAVE_DATA_FILE.readAll()
    SLAVE_DATA_FILE.close()
    SLAVE_TABLE = textutils.unserialiseJSON(SLAVE_JSON)

    NUMBER_OF_SLAVES = #SLAVE_TABLE
    SELF_ID = os.getComputerID()
end

-- Slave computers detection
for i = 1, MAX_ITERATIONS do
    local computers = {rednet.lookup("SLAVE_INIT_PROTOCOL")}
    if #computers == NUMBER_OF_SLAVES then
        print(string.format("FOUND ALL SLAVE COMPUTERS: %d/%d REGISTERED", #computers, NUMBER_OF_SLAVES))
        print("PERFORMING NETWORK HANDSHAKE...")
        break
    elseif #computers > NUMBER_OF_SLAVES then
        print(string.format("EXTRA SLAVE COMPUTERS: %d/%d REGISTERED", #computers, NUMBER_OF_SLAVES))
        print("EXITING TO AVOID UNEXPECTED BEHAVIOUR")
        exit()
    elseif #computers < NUMBER_OF_SLAVES and #computers > 0 then
        print(string.format("MISSING SLAVE COMPUTER: %d/%d REGISTERED", #computers, NUMBER_OF_SLAVES))
    else
        print(string.format("NO SLAVE COMPUTERS FOUND: %d/%d REGISTERED", #computers, NUMBER_OF_SLAVES))
    end
end

local term_width, term_height = term.getSize()
print(string.rep("=", term_width))

-- Slave computers handshake
local response_success = 0
local response_timeout = 0
local response_failure = 0
for _, v in pairs(SLAVE_TABLE) do
    rednet.send(v.slave_id, v.packager, "SLAVE_INIT_PROTOCOL")
    local slave_id, status = rednet.receive("SLAVE_INIT_PROTOCOL", 5)

    if not slave_id then
        status = "INIT_TIMEOUT"
    end

    io.write(string.format("Slave %d responded with: "))
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
io.write(string.format("%d/%d (%.1f%%)\n", response_success, NUMBER_OF_SLAVES, response_success/NUMBER_OF_SLAVES))
term.setTextColor(colors.white)
io.write("SLAVE INIT TIMEOUT: ")
term.setTextColor(colors.yellow)
io.write(string.format("%d/%d (%.1f%%)\n", response_timeout, NUMBER_OF_SLAVES, response_timeout/NUMBER_OF_SLAVES))
term.setTextColor(colors.white)
io.write("SLAVE INIT FAILURE: ")
term.setTextColor(colors.red)
io.write(string.format("%d/%d (%.1f%%)", response_failure, NUMBER_OF_SLAVES, response_failure/NUMBER_OF_SLAVES))
term.setTextColor(colors.white)
print(string.rep("=", term_width))
