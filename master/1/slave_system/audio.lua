local id = require("env")
local log = require("log")

local M = {}

local speakerSide = tostring(id.speaker or "left")
local audioFolder = "/slave_system/audio_files"

M.enabledEvents = {
    fuel10 = true,
    fuelEmpty = true,
    storage90 = true,
    storageFull = true,
    diagnosticsPassed = true,
    logInfo = false,
    logWarn = true,
    logError = true,
}

local function findSpeaker()
    if peripheral.isPresent(speakerSide) then
        local speaker = peripheral.wrap(speakerSide)
        if speaker and speaker.playAudio then
            return speaker
        end
    end

    for _, name in ipairs(peripheral.getNames()) do
        local speaker = peripheral.wrap(name)
        if speaker and speaker.playAudio then
            log.info("audio", "falling back to speaker on %s", tostring(name))
            return speaker
        end
    end

    return nil
end

local function playFile(fileName)
    local speaker = findSpeaker()
    if not speaker then
        log.warn("audio", "speaker %s not available", tostring(speakerSide))
        return false
    end

    local path = audioFolder .. "/" .. tostring(fileName) .. ".dfpwm"
    if not fs.exists(path) then
        log.warn("audio", "file %s not found", tostring(path))
        return false
    end

    local handle = io.open(path, "rb")
    if not handle then
        log.warn("audio", "failed to open %s", tostring(path))
        return false
    end

    local decoder = require("cc.audio.dfpwm").make_decoder()
    while true do
        local chunk = handle:read(16 * 1024)
        if not chunk then
            break
        end
        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end
    handle:close()
    return true
end

function M.playEvent(eventName)
    if type(eventName) ~= "string" then
        return false
    end
    local normalized = eventName:gsub("[^%w_-]", "_")
    return playFile(normalized)
end

return M
