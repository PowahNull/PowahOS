rednet.open("back")

-- Read disk content for slaves
local SLAVE_CONNECT_PATH = "disk/slaves.txt"
local SLAVE_DATA_FILE = fs.open(SLAVE_CONNECT_PATH, "r")
local SLAVE_JSON = SLAVE_DATA_FILE.readAll()
SLAVE_DATA_FILE.close()
local SLAVE_TABLE = textutils.unserialiseJSON(SLAVE_JSON)
local NUMBER_OF_SLAVES = #SLAVE_TABLE
SELF_ID = os.getComputerID()

-- Slave computers handshake
while true do
    local computers = {rednet.lookup("SLAVE_INIT_PROTOCOL")}
    if #computers == NUMBER_OF_SLAVES then
        print(string.format("found all slave computers: %d/%d registered", #computers, NUMBER_OF_SLAVES))
        print("performing network handshake...")
        break
    elseif #computers > NUMBER_OF_SLAVES then
        print(string.format("extra slave computers: %d/%d registered", #computers, NUMBER_OF_SLAVES))
        print("stopping execution to avoid unexpected behavior, goodbye!")
        exit()
    elseif #computers < NUMBER_OF_SLAVES and #computers > 0 then
        print(string.format("missing slave computers: %d/%d registered", #computers, NUMBER_OF_SLAVES))
    else
        print(string.format("no slave computers found: %d/%d registered", #computers, NUMBER_OF_SLAVES))
    end
end

-- Network handshake
local all_response_ok = true
for _, v in pairs(SLAVE_TABLE) do
    rednet.send(v.slave_id, v.packager, "SLAVE_INIT_PROTOCOL")
    local slave_id, status = rednet.receive("SLAVE_INIT_PROTOCOL", 5)
    if not slave_id then
        status = "HANDSHAKE_TIMEOUT"
    end

    io.write(string.format("Slave #%d responded with: ", v.slave_id))
    if status == "HANDSHAKE_OK" then
        term.setTextColor(colors.green)
    elseif status == "HANDSHAKE_NOT_OK" then
        term.setTextColor(colors.red)
        all_response_ok = false
    elseif status == "HANDSHAKE_TIMEOUT" then
        term.setTextColor(colors.yellow)
        all_response_ok = false
    end
    io.write(status)
    -- terminatate print
    term.setTextColor(colors.white)
    io.write("\n")
end

if all_response_ok then
    term.setTextColor(colors.green)
    print("FULL SLAVE DIAGNOSTICS: NETWORK OK")
    term.setTextColor(colors.white)
    _G.NETWORK_OK = all_response_ok
else
    term.setTextColor(colors.red)
    print("FULL SLAVE DIAGNOSTICS: NETWORK NOT OK")
    term.setTextColor(colors.white)
    _G.NETWORK_OK = all_response_ok
end
