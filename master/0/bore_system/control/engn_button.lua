--# imports block #--
package.path = package.path .. ";./?.lua;./network/slave/?.lua"
local id = require("env")
local base_ntwrk = require("network/slave/base_ntwrk")
local log = require("log/log")
--##--
local M = {}

local previous_eng_state = nil

function M.engn_toggle(state)
    if state == previous_eng_state then
        log.debug("eng", "skipped because state unchanged")
        return
    end
    previous_eng_state = state

    if state == true then
        log.info("eng", "sending engines_start")
        base_ntwrk.sendCommand(id.slave_computer, "engines_start", "bore_sys")
    elseif state == false then
        log.info("eng", "sending engines_stop")
        base_ntwrk.sendCommand(id.slave_computer, "engines_stop", "bore_sys")
    else
        log.error("eng", "invalid engine toggle state: %s", tostring(state))
    end
end

return M