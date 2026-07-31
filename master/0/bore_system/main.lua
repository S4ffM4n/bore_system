--# unified startup entrypoint #--
package.path = package.path .. ";./?.lua;./?/init.lua;control/?.lua;storage/?.lua;monitor/?.lua"

local id = require("env")
local log = require("log/log")
local diagnostics = require("diagnostics")
local monitor = require("monitor/monitor")
local hud_glesses = require("monitor/hud_glesses")
local audio_controller = require("audio_controller")

audio_controller.setup()
audio_controller.setMuteProvider(function()
    return monitor.isShutUpEnabled()
end)

local function hudLoop()
    while true do
        local ok, err = hud_glesses.render()
        if not ok and err then
            log.debug("hud", "hud render failed: %s", tostring(err))
        end
        os.sleep(1)
    end
end

log.addLogCallback(function(level, module, message, entry)
    audio_controller.onLog(level, module, message, entry)
end)

-- Configure logging level from env
if id.log_level then
    log.setLevel(id.log_level)
    log.info("main", "log level set to %s", tostring(id.log_level))
end

-- Startup diagnostics before monitor and control logic begin
local diagnosticsPassed = diagnostics.run()
if diagnosticsPassed then
    audio_controller.diagnosticsPassed()
else
    log.warn("main", "system diagnostics found issues before startup")
end

-- Startup message and entrypoint
log.info("main", "starting bore system")
parallel.waitForAny(monitor.start, hudLoop)
