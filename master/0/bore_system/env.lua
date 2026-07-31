--# IDs and runtime configuration #--
local id = {

    --# master system ids: #--
    left_borehead = 2,
    right_borehead = 0,

    main_storage = 0,
    ejector = 1,

    main_monitor = 0,
    hud_monitor = 0,

    modem_side = "right",

    bore_redstone_side = "left",

    slave_computer = 1,

    --# logging configuration #--
    log_level = "INFO",

    --# default filter configuration #--
    filters_dir = "/bore_system/filters",
    default_filter = "default_ors.filter",
}
return id
