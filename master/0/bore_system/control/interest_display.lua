package.path = package.path .. ";../?.lua;../storage/?.lua;../network/slave/?.lua"
local id = require("env")
local storage_helper = require("storage/storage_helper")
local base_ntwrk = require("network/slave/base_ntwrk")
local audio_controller = require("audio_controller")
local log = require("log/log")

local M = {}

function M.get_storage_percent()
    local storage_name = "create:item_vault_" .. id.main_storage
    return storage_helper.storage_fill_percent(storage_name)
end

function M.get_fuel_percent()
    local ok, response = base_ntwrk.sendCommand(id.slave_computer, "get_fuel_percent", "bore_sys")
    if not ok or not response then
        log.warn("int", "failed to get fuel percent from slave")
        return 0
    end

    local percent = tonumber(response)
    if not percent then
        log.warn("int", "invalid fuel percent response: %s", tostring(response))
        return 0
    end

    if percent < 0 then percent = 0 end
    if percent > 100 then percent = 100 end
    local result = math.floor(percent * 10 + 0.5) / 10
    log.debug("int", "fuel percent read %s", tostring(result))
    return result
end

function M.get_display_percents()
    local fuelPercent = M.get_fuel_percent()
    local storagePercent = M.get_storage_percent()
    audio_controller.updatePercents(fuelPercent, storagePercent)
    return fuelPercent, storagePercent
end

return M
