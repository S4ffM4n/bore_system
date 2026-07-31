local log = require("log/log")
local id = require("env")
local base_ntwrk = require("network/slave/base_ntwrk")
local audio = require("audio")

local M = {}
local muteProvider = nil
local currentFuelPercent = 0
local currentStoragePercent = 0
local lastFuelEvent = nil
local lastStorageEvent = nil

local function isMuted()
    return muteProvider and muteProvider() or false
end

local function isEventEnabled(eventName)
    return audio.enabledEvents and audio.enabledEvents[eventName]
end

local function play(eventName)
    if isMuted() then
        return
    end

    if not isEventEnabled(eventName) then
        return
    end

    log.info("audio", "triggering event %s on slave", tostring(eventName))
    base_ntwrk.sendCommand(id.slave_computer, "audio_play:" .. tostring(eventName), "bore_sys", false)
end

function M.setup()
    -- nothing to prepare on master; audio files live on slave
end

function M.setMuteProvider(provider)
    muteProvider = provider
end

function M.getAudioConfig()
    return audio.enabledEvents
end

function M.setAudioConfig(newConfig)
    for k, v in pairs(newConfig) do
        if audio.enabledEvents[k] ~= nil then
            audio.enabledEvents[k] = not not v
        end
    end
end

function M.updatePercents(fuelPercent, storagePercent)
    currentFuelPercent = fuelPercent
    currentStoragePercent = storagePercent

    if fuelPercent <= 0 and lastFuelEvent ~= "fuelEmpty" then
        play("fuelEmpty")
        lastFuelEvent = "fuelEmpty"
    elseif fuelPercent > 0 and fuelPercent <= 10 and lastFuelEvent ~= "fuel10" then
        play("fuel10")
        lastFuelEvent = "fuel10"
    elseif fuelPercent > 10 then
        lastFuelEvent = nil
    end

    if storagePercent >= 100 and lastStorageEvent ~= "storageFull" then
        play("storageFull")
        lastStorageEvent = "storageFull"
    elseif storagePercent >= 90 and storagePercent < 100 and lastStorageEvent ~= "storage90" then
        play("storage90")
        lastStorageEvent = "storage90"
    elseif storagePercent < 90 then
        lastStorageEvent = nil
    end
end

function M.diagnosticsPassed()
    play("diagnosticsPassed")
end

function M.onLog(level, module, message, entry)
    if level == 2 then
        play("logInfo")
    elseif level == 3 then
        play("logWarn")
    elseif level == 4 then
        play("logError")
    end
end

return M
