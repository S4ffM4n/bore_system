--# imports block #--
package.path = package.path .. ";../?.lua;../?/init.lua"
local id = require("env")
local log = require("log/log")
--##--

local M = {}

--## load block filter func ##--
function M.load_filter(file_path)
    local filter = {
        whitelist = false,
        items = {}
    }
    local file = fs.open(file_path, "r")
    if not file then
        error("Filter file not found: " .. file_path)
    end
    while true do
        local line = file.readLine()
        if not line then
            break
        end
        -- remove spaces near edges
        line = line:gsub("^%s*(.-)%s*$", "%1")
        -- skip empty lines
        if line ~= "" then
            -- skip comments
            if not line:match("^#") then
                -- check whitelist (using match to prevent formatting bugs)
                if line:match("^whitelist:%s*true") then
                    filter.whitelist = true
                elseif line:match("^whitelist:%s*false") then
                    filter.whitelist = false
                -- items marks
                else
                    filter.items[line] = true
                end
            end
        end
    end
    file.close()
    return filter
end
--##--
--# compare func #--
local function check_filter(filter, item)
    local exists = filter.items[item] == true
    if filter.whitelist then
        -- whitelist: true -> move everything EXCEPT items in the list
        return not exists
    else
        -- whitelist: false -> move ONLY items in the list
        return exists
    end
end
--##--
--# inventory manipulation func #--
local function has_free_slot(storage)
    if not storage or type(storage.size) ~= "function" then
        return true
    end

    local size = storage.size()
    if size <= 0 then
        return true
    end

    local items = storage.list() or {}
    local slot_count = 0
    for _ in pairs(items) do
        slot_count = slot_count + 1
    end

    return slot_count < size
end

local function can_accept_item(storage, itemName)
    if not storage then
        return true
    end

    local items = storage.list() or {}
    for _, item in pairs(items) do
        if item.name == itemName and (item.count or 0) < 64 then
            return true
        end
    end

    return has_free_slot(storage)
end

local function push_slot_until_full(storage, ejector, slot)
    local total_moved = 0
    while true do
        local moved = storage.pushItems(ejector, slot, 64)
        if not moved or moved == 0 then
            break
        end
        total_moved = total_moved + moved
        if moved < 64 then
            break
        end
    end
    return total_moved
end

function M.check_inventory(storage, ejector, filter)
    if not storage or not ejector then
        log.warn("ef", "check_inventory missing storage or ejector")
        return
    end

    local items = storage:list()
    if not items then
        log.warn("ef", "storage list unavailable")
        return
    end

    local ejector_full = false
    for slot, item in pairs(items) do
        if ejector_full then
            break
        end

        local need_move = check_filter(filter, item.name)
        if need_move then
            local moved = push_slot_until_full(storage, ejector, slot)
            if moved == 0 then
                if not can_accept_item(ejector, item.name) then
                    log.debug("ef", "ejector full or item blocked for %s, stopping filter transfers", tostring(item.name))
                    ejector_full = true
                else
                    log.warn("ef", "failed to move item %s from slot %s", tostring(item.name), tostring(slot))
                end
            end
        end
    end
end
--##--

--# drop func #--
function M.drop(storage, ejector)
    if not storage or not ejector then
        log.warn("ef", "drop missing storage or ejector")
        return
    end

    local items = storage:list()
    if not items then
        log.warn("ef", "drop storage list unavailable")
        return
    end

    for slot, item in pairs(items) do
        local moved = push_slot_until_full(storage, ejector, slot)
        if moved == 0 then
            if not can_accept_item(ejector, item.name) then
                log.debug("ef", "ejector full or item blocked for slot %s, stopping drop transfers", tostring(slot))
                return
            end
            log.warn("ef", "failed to drop item %s from slot %s", tostring(item.name), tostring(slot))
        end
    end
end
--##--


--local main = peripheral.wrap(
--    "create:item_vault_" .. id.main_storage
--)
--
--local ejector_name = "create:item_vault_" .. id.ejector
--
--local filter = load_filter(
--    "/bore_system/filters/default_ors.filter"
--)
--while true do
--    check_inventory(main, ejector_name, filter)
--    sleep(1)
--end
--

return M
