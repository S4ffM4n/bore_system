local log = require("log/log")
local M = {}

--# list storage func #--
-- slot name count
function list_storage(storage_name)
    local storage = peripheral.wrap(storage_name)
    local items = storage and storage.list() or {}
    if next(items) == nil then
        log.debug("stg", "storage '%s' is empty", tostring(storage_name))
    else
        for slot, item in pairs(items) do
            log.debug("stg", "slot=%s name=%s count=%s", tostring(slot), tostring(item.name), tostring(item.count))
        end
    end    
end
--##--

function M.storage_fill_percent(storage_name)
    local storage = peripheral.wrap(storage_name)
    if not storage then return 0 end

    local size = 0
    if type(storage.size) == "function" then
        size = storage.size()
    end
    if size == 0 then return 0 end

    local items = storage.list() or {}
    local total_count = 0
    for _, item in pairs(items) do
        total_count = total_count + (item.count or 0)
    end

    local max_capacity = size * 64
    local percent = (total_count / max_capacity) * 100
    if percent < 0 then percent = 0 end
    if percent > 100 then percent = 100 end
    return math.floor(percent * 10 + 0.5) / 10
end
--##--

--# storage size request func #--
function M.storage_size(storage_name)
    local storage = peripheral.wrap(storage_name)
    if not storage or type(storage.size) ~= "function" then
        log.warn("stg", "storage '%s' unavailable for size query", tostring(storage_name))
        return 0
    end
    local size = storage.size()
    log.debug("stg", "storage '%s' size=%s", tostring(storage_name), tostring(size))
    return size
end
--##--

--# all storage transfer #--
function M.transfer_to(from_name, to_name)
    -- 1. Dynamically wrap both peripherals to handle physical movement and chunk updates
    local from_storage = peripheral.wrap(from_name)
    local to_storage   = peripheral.wrap(to_name)
    
    -- Safety check: exit if either block is temporarily missing or detached
    if not from_storage or not to_storage then 
        log.warn("stg", "transfer_to failed: missing %s or %s", tostring(from_name), tostring(to_name))
        return false 
    end
    
    -- Method check: ensure the source peripheral has initialized inventory methods
    if type(from_storage.list) ~= "function" then
        log.warn("stg", "transfer_to failed: source storage '%s' has no list method", tostring(from_name))
        return false
    end

    -- Fetch the table of occupied slots inside the source inventory
    local items = from_storage.list()
    if not items or next(items) == nil then
        log.debug("stg", "transfer_to no items in %s", tostring(from_name))
        return true 
    end

    -- Retrieve network names for alternative routing methods
    local to_net_name = peripheral.getName(to_storage)
    local from_net_name = peripheral.getName(from_storage)

    -- Iterate through active slots and execute all available transfer fallback methods
    for slot in pairs(items) do
        local ok, err = pcall(function()
            -- METHOD 1: Target via network name string (Standard CC:Tweaked syntax)
            if to_net_name then
                from_storage.pushItems(to_net_name, slot)
            end
            
            -- METHOD 2: Direct object referencing (Required by specific forge/fabric bridges)
            from_storage.pushItems(to_storage, slot)
            
            -- METHOD 3: Reverse pulling from the destination storage end
            if from_net_name and type(to_storage.pullItems) == "function" then
                to_storage.pullItems(from_net_name, slot)
            end
        end)
        if not ok then
            log.warn("stg", "transfer_to slot=%s failed: %s", tostring(slot), tostring(err))
        end
    end
    
    return true
end
--##--

-- вывести список предметов функция

return M
