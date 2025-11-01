-- Reworked control.lua
-- Integrates refrigeration behaviour for electric-refrigerated-cargo-wagon
-- Copies and adapts wagon handling from Cold Chain Logistics (Fridge)

local ELECTRIC_WAGON_NAME = "electric-refrigerated-cargo-wagon"

-- Local/global storage keys
local STORAGE_KEY = "ERW_Wagons"

-- Detect if Fridge mod is active
local has_fridge = script and script.active_mods and script.active_mods["Fridge"]

-- Helper: parse freeze rate setting from Fridge or local fallback
local function get_freeze_rate()
  -- Prefer Fridge's runtime-global setting if available
  if settings and settings.global and settings.global["fridge-freeze-rate"] then
    return settings.global["fridge-freeze-rate"].value
  end
  -- Fallback to our mod's runtime setting if present
  if settings and settings.global and settings.global["electric-refrigerated-wagon-freeze-rate"] then
    return settings.global["electric-refrigerated-wagon-freeze-rate"].value
  end
  -- Final fallback default
  return 20
end

-- Cached freeze-rate: read only on init/config change or when runtime setting changes
local cached_freeze_rate = nil
local function update_cached_freeze_rate()
  cached_freeze_rate = get_freeze_rate()
  -- optional debug log
  -- log("[electric-refrigerated-wagon] cached_freeze_rate = " .. tostring(cached_freeze_rate))
end

-- Initialize custom storages (keeps list of wagons we care about)
local function init_storages()
  global = global or {}
  global[STORAGE_KEY] = global[STORAGE_KEY] or {}
end

-- Add a wagon to our registry
local function register_wagon(entity)
  if not (entity and entity.valid) then return end
  global[STORAGE_KEY][entity.unit_number] = entity
end

-- Remove a wagon from our registry
local function unregister_wagon(entity)
  if not entity then return end
  global[STORAGE_KEY][entity.unit_number] = nil
end

-- Extend spoil ticks for items in wagons (Fridge preserves items without checking power)
local function check_wagons(recover_number)
  if not recover_number or recover_number <= 0 then return end
  for unit_number, wagon in pairs(global[STORAGE_KEY]) do
    if wagon and wagon.valid then
      -- Only apply preservation if the wagon supports cargo inventory
      local inv = wagon.get_inventory and wagon.get_inventory(defines.inventory.cargo_wagon) or nil
      if inv then
        for i = 1, #inv do
          local itemStack = inv[i]
          if itemStack and itemStack.valid_for_read and itemStack.spoil_tick and itemStack.spoil_tick > 0 then
            local max_spoil_time = game.tick + itemStack.prototype.get_spoil_ticks(itemStack.quality) - 3
            itemStack.spoil_tick = math.min(itemStack.spoil_tick + recover_number, max_spoil_time)
          end
        end
      end
    else
      -- cleanup invalid entries
      global[STORAGE_KEY][unit_number] = nil
    end
  end
end

-- Entity created handler
local function OnEntityCreated(event)
  local entity = event.created_entity or event.entity
  if not (entity and entity.valid) then return end
  -- Only register our electric refrigerated wagons; Fridge manages its own preservation-wagon entities
  if entity.name == ELECTRIC_WAGON_NAME then
    register_wagon(entity)
  end
end

-- Entity removed handler
local function OnEntityRemoved(event)
  local entity = event.entity
  if not (entity) then return end
  if entity.name == ELECTRIC_WAGON_NAME then
    unregister_wagon(entity)
  end
end

-- Scan surfaces and register existing wagons at init
local function init_entities()
  global[STORAGE_KEY] = global[STORAGE_KEY] or {}
  for _, surface in pairs(game.surfaces) do
    -- Only find our electric refrigerated wagons; don't touch Fridge's preservation-wagon entities
    local found = surface.find_entities_filtered{ name = ELECTRIC_WAGON_NAME }
    for _, ent in pairs(found) do
      if ent and ent.valid then
        global[STORAGE_KEY][ent.unit_number] = ent
      end
    end
  end
end

-- Handle runtime setting changes
local function on_runtime_setting_changed(event)
  -- Only refresh cached freeze_rate when the relevant setting changed
  local setting_name = event and event.setting
  if setting_name == "fridge-freeze-rate" or setting_name == "electric-refrigerated-wagon-freeze-rate" then
    update_cached_freeze_rate()
  end
end

-- Main tick handler: uses the cached freeze rate (updated on init/change)
local function on_tick()
  local freeze_rates = cached_freeze_rate
  if not freeze_rates then return end
  if freeze_rates == 1 then return end

  if freeze_rates < 10 then
    if game.tick % (10 * freeze_rates) == 0 then
      -- scale recover number similarly to Fridge: (freeze_rates - 1) * 10
      check_wagons((freeze_rates - 1) * 10)
    end
  else
    if game.tick % freeze_rates == 0 then
      check_wagons(freeze_rates - 1)
    end
  end
end

-- Register events
local function init_events()
  -- entity filter for creation/removal: only our wagon name
  local entity_filter = {
    { filter = "name", name = ELECTRIC_WAGON_NAME }
  }

  local creation_events = {
    defines.events.on_built_entity,
    defines.events.on_entity_cloned,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
  }
  for _, ev in pairs(creation_events) do
    script.on_event(ev, OnEntityCreated, entity_filter)
  end

  local removal_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy
  }
  for _, ev in pairs(removal_events) do
    script.on_event(ev, OnEntityRemoved, entity_filter)
  end

  script.on_event(defines.events.on_tick, on_tick)
  script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_setting_changed)
end

-- Lifecycle handlers
script.on_load(function()
  init_events()
  -- ensure cached freeze rate is available when a save is loaded
  update_cached_freeze_rate()
end)

script.on_init(function()
  init_storages()
  init_entities()
  init_events()

  -- initialize cached freeze rate once at startup
  update_cached_freeze_rate()

  if has_fridge then
    log("[electric-refrigerated-wagon] Fridge detected: we'll prefer Fridge settings where possible; our wagon will still be tracked for local preservation/fallbacks.")
  else
    log("[electric-refrigerated-wagon] Fridge not detected: using local freeze-rate fallback setting if configured")
  end
end)

script.on_configuration_changed(function()
  init_storages()
  init_entities()
  init_events()
  -- refresh cached freeze rate after configuration change
  update_cached_freeze_rate()
end)
