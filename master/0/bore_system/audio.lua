local M = {}

M.enabledEvents = {
    fuel10 = true,
    fuelEmpty = true,
    storage90 = true,
    storageFull = true,
    diagnosticsPassed = true,
    logInfo = false,
    logWarn = false,
    logError = false,
}

function M.set(eventName, value)
    if M.enabledEvents[eventName] ~= nil then
        M.enabledEvents[eventName] = not not value
    end
end

function M.get()
    return M.enabledEvents
end

return M
