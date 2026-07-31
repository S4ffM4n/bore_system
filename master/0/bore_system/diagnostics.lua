local id = require("env")
local log = require("log/log")
local base_ntwrk = require("network/slave/base_ntwrk")

local M = {}

local function checkPeripheral(label, peripheralName)
    local wrapped = peripheral.wrap(peripheralName)
    if not wrapped then
        log.error("diag", "%s peripheral '%s' not available", tostring(label), tostring(peripheralName))
        return false
    end

    log.info("diag", "%s peripheral '%s' available", tostring(label), tostring(peripheralName))
    return true
end

function M.checkMonitor()
    local monitorName = "monitor_" .. tostring(id.main_monitor)
    local monitorDevice = peripheral.wrap(monitorName)
    if not monitorDevice then
        log.error("diag", "monitor '%s' is not available", tostring(monitorName))
        return false
    end

    local width, height = monitorDevice.getSize()
    if not width or not height or width < 6 or height < 4 then
        log.warn("diag", "monitor '%s' size appears invalid: %s x %s", tostring(monitorName), tostring(width), tostring(height))
    else
        log.info("diag", "monitor '%s' available: %sx%s", tostring(monitorName), tostring(width), tostring(height))
    end

    return true
end

function M.checkStorageDevices()
    local mainStorage = "create:item_vault_" .. tostring(id.main_storage)
    local ejector = "create:item_vault_" .. tostring(id.ejector)
    local leftBorehead = "offroad:borehead_bearing_" .. tostring(id.left_borehead)
    local rightBorehead = "offroad:borehead_bearing_" .. tostring(id.right_borehead)

    local ok = true
    ok = checkPeripheral("main storage", mainStorage) and ok
    ok = checkPeripheral("ejector", ejector) and ok
    ok = checkPeripheral("left borehead", leftBorehead) and ok
    ok = checkPeripheral("right borehead", rightBorehead) and ok

    return ok
end

function M.checkFilterConfig()
    local filterDir = tostring(id.filters_dir)
    local defaultFilter = filterDir .. "/" .. tostring(id.default_filter)

    if not fs.exists(filterDir) or not fs.isDir(filterDir) then
        log.error("diag", "filters directory '%s' is missing or not a directory", filterDir)
        return false
    end

    if not fs.exists(defaultFilter) then
        log.error("diag", "default filter file '%s' is missing", defaultFilter)
        return false
    end

    log.info("diag", "filters configured: %s / %s", filterDir, tostring(id.default_filter))
    return true
end

function M.checkNetwork()
    local modemSide = tostring(id.modem_side)
    local modemDevice = peripheral.wrap(modemSide)
    if not modemDevice then
        log.error("diag", "modem side '%s' is not present", modemSide)
        return false
    end

    if not rednet.isOpen(modemSide) then
        rednet.open(modemSide)
        log.info("diag", "opened rednet on %s", modemSide)
    end

    if not rednet.isOpen(modemSide) then
        log.error("diag", "failed to open rednet on %s", modemSide)
        return false
    end

    log.info("diag", "rednet modem '%s' is ready", modemSide)
    return true
end

function M.checkSlaveConnection()
    local ok, response = base_ntwrk.sendCommand(id.slave_computer, "get_fuel_percent", "bore_sys")
    if not ok or not response then
        log.error("diag", "slave computer #%s did not answer health check", tostring(id.slave_computer))
        return false
    end

    local percent = tonumber(response)
    if not percent then
        log.error("diag", "slave health check returned invalid payload: %s", tostring(response))
        return false
    end

    log.info("diag", "slave communication OK, fuel percent %s", tostring(percent))
    return true
end

function M.run()
    log.info("diag", "starting system diagnostics")

    local passed = true
    passed = M.checkMonitor() and passed
    passed = M.checkStorageDevices() and passed
    passed = M.checkFilterConfig() and passed
    passed = M.checkNetwork() and passed
    passed = M.checkSlaveConnection() and passed

    if passed then
        log.info("diag", "all diagnostics passed")
    else
        log.error("diag", "system diagnostics failed")
    end

    return passed
end

return M
