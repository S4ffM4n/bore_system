package.path = package.path .. ";./?.lua;./?/init.lua;slave_system/?.lua;slave_system/?/init.lua"

local id = require("slave_system/env")
local log = require("slave_system/log")

if id.log_level then
    log.setLevel(id.log_level)
    log.info("main", "slave log level set to %s", tostring(id.log_level))
end

log.info("main", "starting slave system")

shell.run("slave_system/fuel_supply")

log.error("main", "slave_system/fuel_supply exited unexpectedly")
