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

local state = false

function M.drop_toggle(new_state)
    state = new_state
    log.info("drop", "drop toggle set to %s", tostring(state and "ON" or "OFF"))
end

function M.drop_loop()
    if state == true then
        ejector_filter.drop(main, ejector_name)
    end
end

return M