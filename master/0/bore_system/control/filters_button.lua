--# imports block #--
package.path = package.path .. ";./storage/?.lua;./?.lua"
local ejector_filter = require("storage/ejector_filter")
local id = require("env") 
local log = require("log/log")
--##--
local M = {}

--# ids from env#--
local main = peripheral.wrap(
    "create:item_vault_" .. id.main_storage
)

local ejector_name = "create:item_vault_" .. id.ejector

local defaultFilterPath = id.filters_dir .. "/" .. id.default_filter
local filter = ejector_filter.load_filter(defaultFilterPath)

local state = false

function M.filters_toggle(new_state)
    state = new_state
    log.info("fltr", "filters toggle set to %s", tostring(state and "ON" or "OFF"))
end

function M.filters_loop()
    if state == true then
        ejector_filter.check_inventory(main, ejector_name, filter)
    end
end

return M