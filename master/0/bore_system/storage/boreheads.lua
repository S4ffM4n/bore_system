--# imports block #--
package.path = package.path .. ";./?.lua;./?/init.lua"
local id = require("env")
local storage_helper = require("storage/storage_helper")
local log = require("log/log")
--##--
 
local M = {}

--# names of storages (string IDs) #--
local left_name  = "offroad:borehead_bearing_" .. id.left_borehead
local right_name = "offroad:borehead_bearing_" .. id.right_borehead
local main_name  = "create:item_vault_" .. id.main_storage
--##--

--# boreheads statment func#--
local is_running = false 
function M.boreheads2main(state)
    is_running = state
end
--##--

function M.update()
    if not is_running then
        log.debug("bor", "boreheads update skipped; not running")
        return
    end

    log.debug("bor", "boreheads update active")
    storage_helper.transfer_to(left_name, main_name)
    storage_helper.transfer_to(right_name, main_name)
end

return M
