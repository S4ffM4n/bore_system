--# imports block #--
package.path = package.path .. ";./?.lua;./storage/?.lua"
local boreheads = require("storage/boreheads")
local id = require("env")
local log = require("log/log")
--##--
local M = {}
local current_redstone_state = nil

local function setRedstone(state)
    if current_redstone_state == state then
        return
    end
    current_redstone_state = state
    redstone.setOutput(id.bore_redstone_side, state)
end

function M.bore_toggle(state)
    if state == true then
        setRedstone(true)
        boreheads.boreheads2main(true)
        log.info("bor", "boreheads enabled")
    elseif state == false then
        setRedstone(false)
        boreheads.boreheads2main(false)
        log.info("bor", "boreheads disabled")
    else
        log.error("bor", "invalid bore toggle state: %s", tostring(state))
    end
end
    
return M