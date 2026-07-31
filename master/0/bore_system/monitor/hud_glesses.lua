local id = require("env")

local M = {}

local function prettyItemName(name)
    if not name or name == "" then
        return "Unknown"
    end

    local shortName = name
    local namespaceIndex = name:find(":")
    if namespaceIndex then
        shortName = name:sub(namespaceIndex + 1)
    end

    shortName = shortName:gsub("_", " ")
    shortName = shortName:gsub("(%a)([%a%d_]*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)

    return shortName
end

local function formatCount(count)
    count = tonumber(count) or 0
    if count >= 1000000 then
        local value = count / 1000000
        if value == math.floor(value) then
            return string.format("%.0fm", value)
        end
        return string.format("%.1fm", value)
    elseif count >= 1000 then
        local value = count / 1000
        if value == math.floor(value) then
            return string.format("%.0fk", value)
        end
        return string.format("%.1fk", value)
    end
    return tostring(count)
end

local function writeHudLine(hud, line, text, width)
    hud.setCursorPos(1, line)
    hud.write(text .. string.rep(" ", math.max(0, width - #text)))
end

local function clearHudLine(hud, line, width)
    hud.setCursorPos(1, line)
    hud.write(string.rep(" ", width))
end

local function itemSort(a, b)
    local aCount = tonumber(a.count) or 0
    local bCount = tonumber(b.count) or 0
    return aCount > bCount
end

local function collectStorageItems()
    local storageName = "create:item_vault_" .. tostring(id.main_storage)
    local storage = peripheral.wrap(storageName)
    if not storage or type(storage.list) ~= "function" then
        return {}
    end

    local rawItems = storage.list() or {}
    local aggregated = {}
    for slot, item in pairs(rawItems) do
        if item and item.name and (item.count or 0) > 0 then
            local key = item.displayName or item.name
            if not aggregated[key] then
                aggregated[key] = { name = key, count = 0 }
            end
            aggregated[key].count = aggregated[key].count + tonumber(item.count)
        end
    end

    local items = {}
    for _, entry in pairs(aggregated) do
        table.insert(items, entry)
    end
    table.sort(items, itemSort)
    return items
end

function M.render()
    local hud = peripheral.find("hud_glasses")
    if not hud then
        return false, "hud_glasses peripheral not found"
    end

    local width, height = hud.getSize()
    if type(width) == "table" then
        width, height = width[1], width[2]
    end
    width = tonumber(width) or 0
    height = tonumber(height) or 0
    if width <= 0 or height <= 0 then
        return false, "invalid hud size"
    end

    local items = collectStorageItems()
    local maxLines = height
    local line = 1
    for i = 1, math.min(#items, maxLines) do
        local item = items[i]
        local label = prettyItemName(item.name)
        local countText = formatCount(item.count)
        local text = string.format("%s | %s", label, countText)
        writeHudLine(hud, line, text, width)
        line = line + 1
    end

    for i = line, maxLines do
        clearHudLine(hud, i, width)
    end

    return true
end

return M
