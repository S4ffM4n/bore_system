--# imports block #--
package.path = package.path .. ";./?.lua;./log/?.lua"
local id = require("env")
local log = require("log/log")
--##--

local M = {}
local modem_side = id.modem_side

local function ensureModemOpen()
    if not rednet.isOpen(modem_side) then
        rednet.open(modem_side)
        log.debug("net", "opened modem on %s", tostring(modem_side))
    end
end

ensureModemOpen()

function M.sendCommand(targetID, message, protocol, expectResponse)
    ensureModemOpen()

    rednet.send(targetID, message, protocol)
    log.debug("net", "sent '%s' to PC#%s via %s", tostring(message), tostring(targetID), tostring(protocol))

    if expectResponse == false then
        return true, nil
    end

    local tries = 3
    local resID, resMessage
    for i = 1, tries do
        resID, resMessage = rednet.receive("slave_response", 1)
        if resID then
            break
        end
        log.warn("net", "no response on try %d for PC#%s", i, tostring(targetID))
    end

    if resID == nil then
        log.warn("net", "no response from PC#%s after %d tries", tostring(targetID), tries)
        return false, nil
    else
        log.debug("net", "response from PC#%s: %s", tostring(resID), tostring(resMessage))
        return true, resMessage
    end
end

return M

--sendCommand(1, "engines_start", "bore_sys")
--sendCommand(1, "get_fuel_percent", "bore_sys")

