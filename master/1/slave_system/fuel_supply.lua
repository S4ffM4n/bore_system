--# imports block #--
package.path = package.path .. ";./?.lua;./?/init.lua;slave_system/?.lua;slave_system/?/init.lua"
local id = require("env")
local log = require("log")
local audio = require("audio")
--##--

--# rednet init #--
if not rednet.isOpen("top") then
    rednet.open("top")
    log.debug("fuel", "opened top modem")
else
    log.debug("fuel", "top modem already open")
end

log.info("fuel", "starting rednet receive")

--##--


--# vars (DYNAMIC NETWORK AUTOMATION) #--
local canisters = {} -- Теперь сюда динамически собираются ВСЕ канистры в сети
local engines = {}
local electric_motors = {}

local function refresh_device_lists()
    canisters = {}
    engines = {}
    electric_motors = {}

    for _, name in ipairs(peripheral.getNames()) do
        if string.find(name, "canister_block_entity") then
            table.insert(canisters, name)
        elseif string.find(name, "diesel_engine_tile_entity") then
            table.insert(engines, name)
        elseif string.find(name, "electric_motor") then
            table.insert(electric_motors, name)
        end
    end

    log.debug("fuel", "discovered %d canisters, %d engines, %d motors", #canisters, #engines, #electric_motors)
end

refresh_device_lists()
--##--

local tracking_status = {}

--# read fuel amount func #--
local function getfuel(block_name, display_label)
    if not peripheral.isPresent(block_name) then
        if tracking_status[block_name] ~= "lost" then
            tracking_status[block_name] = "lost"
            log.warn("fuel", "%s connection lost", string.upper(display_label))
        end
        return 0
    else
        if tracking_status[block_name] == "lost" then
            tracking_status[block_name] = "ok"
            log.info("fuel", "%s restored", string.upper(display_label))
        end
    end

    local success, data = pcall(peripheral.call, block_name, "tanks")
    if success and type(data) == "table" then
        if data[1] and type(data[1]) == "table" then
            return data[1].amount or 0
        end
    end
    return 0
end
--##--

--# engine refueling func #--
local function fill_target(target_engine_name, amount)
    for _, canister_name in ipairs(canisters) do
        if peripheral.isPresent(canister_name) then
            local success, transferred = pcall(peripheral.call, canister_name, "pushFluid", target_engine_name, amount)
            if success and transferred and transferred > 0 then
                return 
            end
        end
    end
end
--##--

--# balance canisters func #--
-- Умная балансировка: ищет канистру с самым большим и самым малым объемом топлива и выравнивает их
local function balance_canisters()
    if #canisters < 2 then return end

    local min_fuel = math.huge
    local max_fuel = -1
    local min_canister = nil
    local max_canister = nil

    for i, name in ipairs(canisters) do
        if peripheral.isPresent(name) then
            local fuel = getfuel(name, "canister " .. i)
            if fuel < min_fuel then
                min_fuel = fuel
                min_canister = name
            end
            if fuel > max_fuel then
                max_fuel = fuel
                max_canister = name
            end
        end
    end

    if min_canister and max_canister and min_canister ~= max_canister then
        if max_fuel > min_fuel then
            local portion = math.min(100, (max_fuel - min_fuel) / 2)
            if portion > 0 then
                pcall(peripheral.call, max_canister, "pushFluid", min_canister, portion)
            end
        end
    end
end
--##--

--# control electric motors func #--
local function set_motors_speed(speed)
    for _, motor in ipairs(electric_motors) do
        if peripheral.isPresent(motor) then
            pcall(peripheral.call, motor, "setSpeed", speed)
        end
    end
end

local function stop_motors()
    for _, motor in ipairs(electric_motors) do
        if peripheral.isPresent(motor) then
            pcall(peripheral.call, motor, "stop")
        end
    end
end
--##--

local function start_fuel_supply()
    refresh_device_lists()
    set_motors_speed(256)
    balance_canisters()

    local fuel_in_canisters = 0
    for i, canister_name in ipairs(canisters) do
        fuel_in_canisters = fuel_in_canisters + getfuel(canister_name, "canister " .. i)
    end

    local active_engines = {}
    for i, engine_name in ipairs(engines) do
        if peripheral.isPresent(engine_name) then
            table.insert(active_engines, { name = engine_name, label = "engine " .. i })
        end
    end

    if #active_engines == 0 then
        log.error("fuel", "no active engines detected")
        os.sleep(2)
        return "NO_ENGINES"
    end

    local target_engine = active_engines[1].name
    local target_label = active_engines[1].label or target_engine
    local min_fuel = getfuel(target_engine, target_label)

    for i = 2, #active_engines do
        local current_fuel = getfuel(active_engines[i].name, active_engines[i].label)
        if current_fuel < min_fuel then
            target_engine = active_engines[i].name
            target_label = active_engines[i].label or target_engine
            min_fuel = current_fuel
        end
    end

    if min_fuel >= 1000 then
        log.debug("fuel", "all engines full, no refuel needed")
        os.sleep(1)
        return "FULL"
    elseif fuel_in_canisters == 0 and min_fuel == 0 then
        log.warn("fuel", "no fuel in canisters")
        os.sleep(3)
        return "NO_FUEL"
    elseif (1000 - min_fuel) >= 100 then
        log.info("fuel", "refueling %s by 100", target_label)
        fill_target(target_engine, 100)
        return "REFUELING"
    else
        local leftovers = 1000 - min_fuel
        log.info("fuel", "refueling %s by %d", target_label, leftovers)
        fill_target(target_engine, leftovers)
        return "REFUELING"
    end
end

local function stop_fuel_supply()
    refresh_device_lists()
    local fuel_L = #engines >= 1 and getfuel(engines[1], "engine 1") or 0
    local fuel_R = #engines >= 2 and getfuel(engines[2], "engine 2") or 0

    if fuel_L == 0 and fuel_R == 0 then
        stop_motors()
        return "STOPPED"
    end

    local drain_target = nil
    local available_space = 0
    
    -- Динамический поиск первой свободной канистры, куда можно откачать топливо
    for i, canister_name in ipairs(canisters) do
        if peripheral.isPresent(canister_name) then
            local c_fuel = getfuel(canister_name, "canister " .. i)
            if c_fuel < 4000 then
                drain_target = canister_name
                available_space = 4000 - c_fuel
                break
            end
        end
    end

    -- Если все канистры полные, но двигатели еще не пусты, аварийно выбираем любую доступную канистру
    if not drain_target then
        for _, canister_name in ipairs(canisters) do
            if peripheral.isPresent(canister_name) then
                drain_target = canister_name
                available_space = 4000
                break
            end
        end
    end

    if not drain_target then
        log.warn("fuel", "no drain target available; engines may still contain fuel")
        return "DRAINING"
    end

    if fuel_L > 0 and #engines >= 1 and peripheral.isPresent(engines[1]) then
        local portion = math.min(100, fuel_L, available_space)
        if portion > 0 then
            local success, transferred = pcall(peripheral.call, engines[1], "pushFluid", drain_target, portion)
            if success and transferred then
                available_space = available_space - transferred
            end
        end
    end

    if fuel_R > 0 and #engines >= 2 and peripheral.isPresent(engines[2]) then
        local portion = math.min(100, fuel_R, available_space)
        if portion > 0 then
            pcall(peripheral.call, engines[2], "pushFluid", drain_target, portion)
        end
    end

    return "DRAINING"
end
--##--

--# calculate total fuel percentage func #--
local function get_total_fuel_percentage()
    -- 1. Calculate current fuel amount in canisters
    local fuel_in_canisters = 0
    for i, canister_name in ipairs(canisters) do
        fuel_in_canisters = fuel_in_canisters + getfuel(canister_name, "canister " .. i)
    end

    -- 2. Calculate current fuel amount in engines
    local fuel_in_engines = 0
    for i, engine_name in ipairs(engines) do
        fuel_in_engines = fuel_in_engines + getfuel(engine_name, "engine " .. i)
    end

    -- 3. Calculate maximum capacity of the entire system
    -- Canister capacity is 4000, active engine capacity is 1000
    local max_capacity = (#canisters * 4000) + (#engines * 1000)

    -- Safety check to avoid division by zero if the network is empty
    if max_capacity == 0 then return 0 end

    -- Sum up current fuel and convert to percentage
    local total_current_fuel = fuel_in_canisters + fuel_in_engines
    local percent = (total_current_fuel / max_capacity) * 100

    -- Round to 1 decimal place to avoid sending long fractions
    return math.floor(percent * 10) / 10
end
--##--

--# main cycle #--
log.info("fuel", "unified network engine control system initialized")
log.info("fuel", "toggle the redstone lever on the top side to control modes")

local is_running = false 
local last_status = ""   
local last_tick_time = os.clock() -- Будем использовать для отсчета времени автоматики

local function handleBoreSysCommand(senderID, message)
    log.debug("fuel", "from PC#%s: %s", tostring(senderID), tostring(message))

    if type(message) == "string" and message:sub(1, 11) == "audio_play:" then
        local eventName = message:sub(12)
        local ok = audio.playEvent(eventName)
        if ok then
            rednet.send(senderID, "AUDIO_OK", "slave_response")
        else
            rednet.send(senderID, "AUDIO_FAILED", "slave_response")
        end
        return
    end

    if message == "engines_start" then
        is_running = true
        rednet.send(senderID, "ENGINES_STARTING", "slave_response")
        log.info("fuel", "received engines_start command")
        return
    end

    if message == "engines_stop" then
        is_running = false
        rednet.send(senderID, "ENGINES_STOPPING", "slave_response")
        log.info("fuel", "received engines_stop command")
        return
    end

    if message == "get_fuel_percent" then
        refresh_device_lists()
        local current_percent = get_total_fuel_percentage()
        rednet.send(senderID, current_percent, "slave_response")
        log.debug("fuel", "reported fuel percent: %s", tostring(current_percent))
        return
    end

    log.warn("fuel", "unknown bore_sys command: %s", tostring(message))
end

local function commandListenerLoop()
    while true do
        local senderID, message, protocol = rednet.receive("bore_sys", 0.1)
        if senderID and protocol == "bore_sys" then
            handleBoreSysCommand(senderID, message)
        end
    end
end

local function automationLoop()
    while true do
        local redstone_active = redstone.getInput("top")

        if redstone_active or is_running then
            if last_status ~= "RUNNING" then
                log.info("fuel", "automation started")
            end
            start_fuel_supply()
            last_status = "RUNNING"
        else
            local status = stop_fuel_supply()
            if status == "STOPPED" and last_status ~= "STOPPED" then
                log.info("fuel", "automation stopped")
                log.info("fuel", "engines fully drained and stopped safely; electric motors powered off")
                last_status = "STOPPED"
            end
        end

        -- Минимальная пауза цикла, чтобы разгрузить процессор
        os.sleep(0.05)
    end
end

parallel.waitForAny(commandListenerLoop, automationLoop)
--##--
