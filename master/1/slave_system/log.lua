local M = {}

local LEVELS = {
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4,
}

local levelNames = {
    [LEVELS.DEBUG] = "D",
    [LEVELS.INFO]  = "I",
    [LEVELS.WARN]  = "W",
    [LEVELS.ERROR] = "E",
}

local globalLevel = LEVELS.INFO
local moduleLevels = {}
local maxEntries = 50
local entries = {}

local function normalizeLevel(level)
    if type(level) == "string" then
        level = level:upper()
        return LEVELS[level] or LEVELS.INFO
    elseif type(level) == "number" then
        return math.max(LEVELS.DEBUG, math.min(LEVELS.ERROR, level))
    end
    return LEVELS.INFO
end

local function moduleName(name)
    local label = tostring(name or "gen")
    label = label:gsub("%s+", "_")
    return label:lower()
end

local function shouldLog(level, module)
    local mod = moduleName(module)
    local threshold = moduleLevels[mod] or globalLevel
    return level >= threshold
end

local function formatMessage(level, module, message)
    local code = levelNames[level] or "I"
    local mod = moduleName(module)
    return string.format("[%s][%s]: %s", code, mod, tostring(message))
end

local function addEntry(entry)
    table.insert(entries, 1, entry)
    while #entries > maxEntries do
        table.remove(entries)
    end
end

function M.log(level, module, message, ...)
    local normalizedLevel = normalizeLevel(level)
    if not shouldLog(normalizedLevel, module) then
        return nil
    end

    if select('#', ...) > 0 then
        message = string.format(message, ...)
    end

    local entry = formatMessage(normalizedLevel, module, message)
    addEntry(entry)
    return entry
end

function M.debug(module, message, ...)
    return M.log(LEVELS.DEBUG, module, message, ...)
end

function M.info(module, message, ...)
    return M.log(LEVELS.INFO, module, message, ...)
end

function M.warn(module, message, ...)
    return M.log(LEVELS.WARN, module, message, ...)
end

function M.error(module, message, ...)
    return M.log(LEVELS.ERROR, module, message, ...)
end

function M.getRecentEntries(limit)
    limit = limit or #entries
    local result = {}
    for i = 1, math.min(limit, #entries) do
        result[i] = entries[i]
    end
    return result
end

function M.getEntries()
    return M.getRecentEntries(#entries)
end

function M.setLevel(level)
    globalLevel = normalizeLevel(level)
end

function M.setModuleLevel(module, level)
    moduleLevels[moduleName(module)] = normalizeLevel(level)
end

function M.clearModuleLevel(module)
    moduleLevels[moduleName(module)] = nil
end

function M.setMaxEntries(value)
    maxEntries = math.max(1, tonumber(value) or 50)
    while #entries > maxEntries do
        table.remove(entries)
    end
end

function M.getLevels()
    return {
        DEBUG = LEVELS.DEBUG,
        INFO  = LEVELS.INFO,
        WARN  = LEVELS.WARN,
        ERROR = LEVELS.ERROR,
    }
end

return M
