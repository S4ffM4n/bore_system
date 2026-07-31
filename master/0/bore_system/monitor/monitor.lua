-- Imports
package.path = package.path .. ";./?.lua;./?/init.lua;./control/?.lua;./storage/?.lua;./log/?.lua"
local id = require("env")
local bore_button = require("bore_button")
local boreheads = require("storage/boreheads")
local drop_button = require("drop_button")
local engn_button = require("engn_button")
local filters_button = require("filters_button")
local interest_display = require("interest_display")
local log = require("log/log")

local M = {}

-- Setup monitor
local monitor_name = "monitor_" .. id.main_monitor
local monitor = peripheral.wrap(monitor_name)
monitor.setTextScale(0.5)

-- Button states (toggle)
local dropState   = false
local filterState = false
local bhState     = false
local engState    = false
local extraState  = false
local shutState   = false

local width, height = monitor.getSize()

-- Top button dimensions
-- Shut up label (moved to bottom row as a normal button)
-- Button labels
local btnDropText   = "drop"
local btnShutUpText = "shhh"
local btnTrText     = "trch"

-- Bottom button labels (shortened to fit)
local btnFilterText = "fltr"
local btnBhText     = "bore"
local btnEngText    = "engn"

local dropLen   = #btnDropText + 4
local filterLen = #btnFilterText + 4
local bhLen     = #btnBhText + 4
local engLen    = #btnEngText + 4
local trchLen   = #btnTrText + 4

-- Two rows: top (3), bottom (3)
local topRowY = height - 1
local bottomRowY = height

-- compute equal segments per row (3 slots)
local function thirds(width)
    local w1 = math.floor(width / 3)
    local w2 = math.floor((width - w1) / 2)
    local w3 = width - w1 - w2
    return w1, w2, w3
end

local t1w, t2w, t3w = thirds(width)
local topX1 = 1
local topX2 = topX1 + t1w
local topX3 = topX2 + t2w

local b1w, b2w, b3w = t1w, t2w, t3w
local bottomX1 = 1
local bottomX2 = bottomX1 + b1w
local bottomX3 = bottomX2 + b2w

-- Global data variables
local currentStorage = 0
local currentFuel = 0
local currentSecondaryPercent = nil

-- Draw a light line using dashes
local function drawDottedLine(y)
    monitor.setCursorPos(1, y)
    monitor.setTextColor(colors.gray)
    monitor.write(string.rep("- ", math.floor(width / 2)))
end

-- Render button text with dynamic color inside default brackets
-- Draw a button centered inside a slot of width `w`
local function drawButtonSlot(x, y, w, label, state)
    local inner = w - 4
    if inner < 0 then inner = 0 end
    local text = label
    if #text > inner then text = string.sub(text, 1, inner) end
    local padLeft = math.floor((inner - #text) / 2)
    local padRight = inner - #text - padLeft

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.gray)
    monitor.setCursorPos(x, y)
    monitor.write("[ ")

    monitor.setTextColor(state and colors.green or colors.red)
    monitor.write(string.rep(" ", padLeft) .. text .. string.rep(" ", padRight))

    monitor.setTextColor(colors.gray)
    monitor.write(" ]")
end

-- Main render function
local function drawInterface(storage, fuel, logs, isShutUpPressed)
    local displayStorage = storage or 0
    local displayFuel    = fuel or 0
    local displaySecondary = currentSecondaryPercent or 0
    
    -- Clear screen then Top percent bar: three fixed columns "fu: X% | st X% | tr X%"
    monitor.setBackgroundColor(colors.black)
    monitor.clear()

    local fuText = "fu: " .. tostring(displayFuel) .. "%"
    local stText = "st: " .. tostring(displayStorage) .. "%"
    local trText = "tr: " .. tostring(displaySecondary) .. "%"

    -- each column width
    local c1w, c2w, c3w = t1w, t2w, t3w
    local function centerInCol(colX, colW, txt, color)
        local pad = math.max(0, colW - #txt)
        local left = math.floor(pad / 2)
        monitor.setCursorPos(colX + left, 1)
        monitor.setTextColor(color or colors.lightGray)
        monitor.write(txt)
    end

    monitor.setBackgroundColor(colors.black)
    centerInCol(1, c1w, fuText, colors.lightGray)
    centerInCol(1 + c1w, c2w, stText, colors.lightGray)
    centerInCol(1 + c1w + c2w, c3w, trText, colors.lightGray)
    -- separators between columns (after each column)
    monitor.setTextColor(colors.gray)
    monitor.setCursorPos(1 + c1w, 1)
    monitor.write("|")
    monitor.setCursorPos(1 + c1w + c2w, 1)
    monitor.write("|")

    -- Logs area: rows between dotted lines (reserve two bottom rows for buttons)
    local logsTop = 3
    local logsBottom = topRowY - 2
    local maxLogLines = math.max(0, logsBottom - logsTop + 1)

    local function logColorForEntry(entry)
        local level = entry:match("^%[([DIWE])%]")
        if level == "E" then
            return colors.red
        elseif level == "W" then
            return colors.yellow
        elseif level == "D" then
            return colors.purple
        else
            return colors.white
        end
    end

    for i = 1, maxLogLines do
        local currentY = logsTop + i - 1
        monitor.setCursorPos(1, currentY)
        monitor.setBackgroundColor(colors.black)
        local entry = logs[i]
        if entry then
            local color = logColorForEntry(entry)
            monitor.setTextColor(color)
            monitor.write("> " .. entry)
            local remainingSpaces = width - 2 - #entry
            if remainingSpaces > 0 then monitor.write(string.rep(" ", remainingSpaces)) end
        else
            monitor.write(string.rep(" ", width))
        end
    end

    -- top dotted line under percent bar
    drawDottedLine(2)

    -- dotted line above button rows
    if topRowY - 1 > 2 then
        drawDottedLine(topRowY - 1)
    end

    -- Draw top row slots
    drawButtonSlot(topX1, topRowY, t1w, btnDropText, dropState)
    drawButtonSlot(topX2, topRowY, t2w, btnShutUpText, shutState)
    drawButtonSlot(topX3, topRowY, t3w, btnTrText, extraState)

    -- Draw bottom row slots
    drawButtonSlot(bottomX1, bottomRowY, b1w, btnFilterText, filterState)
    drawButtonSlot(bottomX2, bottomRowY, b2w, btnBhText, bhState)
    drawButtonSlot(bottomX3, bottomRowY, b3w, btnEngText, engState)
end

-- Thread 1: Handle all screen interactions (Touch event loop)
local function inputEventLoop()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")

        if y == topRowY then
            if x >= topX1 and x < (topX1 + t1w) then
                dropState = not dropState
                drop_button.drop_toggle(dropState)
                log.debug("mon", "drop toggled %s", dropState and "ON" or "OFF")

            elseif x >= topX2 and x < (topX2 + t2w) then
                shutState = not shutState
                log.debug("mon", "shhh toggled %s", shutState and "ON" or "OFF")

            elseif x >= topX3 and x < (topX3 + t3w) then
                extraState = not extraState
                log.debug("mon", "trch toggled %s", extraState and "ON" or "OFF")
            end

        elseif y == bottomRowY then
            if x >= bottomX1 and x < (bottomX1 + b1w) then
                filterState = not filterState
                filters_button.filters_toggle(filterState)

            elseif x >= bottomX2 and x < (bottomX2 + b2w) then
                bhState = not bhState
                bore_button.bore_toggle(bhState)

            elseif x >= bottomX3 and x < (bottomX3 + b3w) then
                engState = not engState
                engn_button.engn_toggle(engState)
            end
        end
    end
end

local function refreshPercents()
    local fuelPercent, storagePercent = interest_display.get_display_percents()
    currentFuel = fuelPercent
    currentStorage = storagePercent
end

function M.isShutUpEnabled()
    return shutState
end

-- Thread 2: Background task manager for drill automation
local function backgroundDrillLogic()
    while true do
        drop_button.drop_loop()
        filters_button.filters_loop()
        boreheads.update()
        refreshPercents()
        os.sleep(2.0)
    end
end

-- Thread 3: Asynchronous screen update task
local function screenUpdateLoop()
    while true do
        local logs = log.getRecentEntries()
        drawInterface(currentStorage, currentFuel, logs, false)
        os.sleep(0.5)
    end
end

function M.start()
    -- Initial render call to prevent a blank monitor on startup
    drawInterface(currentStorage, currentFuel, log.getRecentEntries(), false)

    -- Execute input handling, background machine tasks, and UI rendering concurrently
    parallel.waitForAny(inputEventLoop, backgroundDrillLogic, screenUpdateLoop)
end

return M
