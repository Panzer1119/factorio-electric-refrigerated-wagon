-- Reworked control.lua
-- Integrates refrigeration behaviour for electric-refrigerated-cargo-wagon
-- Copies and adapts wagon handling from Cold Chain Logistics (Fridge)

local ELECTRIC_WAGON_NAME = "electric-refrigerated-cargo-wagon"
local PRESERVATION_WAGON_NAME = "preservation-wagon" -- Fridge preservation wagon

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

-- Wagon power detection (kept from earlier implementation)
local function wagon_is_powered(wagon)
  if not (wagon and wagon.valid) then return false end

  -- Prefer electric-trains remote if present (guarded)
  if remote and remote.interfaces and remote.interfaces["electric-trains"] and remote.interfaces["electric-trains"].is_wagon_charged then
    local ok, result = pcall(function() return remote.call("electric-trains", "is_wagon_charged", wagon) end)
    if ok and result ~= nil then
      return result
    end
  end

  -- Check common energy properties
  if wagon.energy and type(wagon.energy) == "number" then
    return wagon.energy > 0
  end
  if wagon.electric_buffer_size and wagon.energy then
    return wagon.energy > 0
  end

  return false
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

-- Extend spoil ticks for items in wagons (but only if wagon is powered)
local function check_wagons(recover_number)
  if not recover_number or recover_number <= 0 then return end
  for unit_number, wagon in pairs(global[STORAGE_KEY]) do
    if wagon and wagon.valid then
      -- Only apply preservation if the wagon supports cargo inventory
      local inv = wagon.get_inventory and wagon.get_inventory(defines.inventory.cargo_wagon) or nil
      if inv and wagon_is_powered(wagon) then
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
  if entity.name == ELECTRIC_WAGON_NAME or entity.name == PRESERVATION_WAGON_NAME then
    register_wagon(entity)
  end
end

-- Entity removed handler
local function OnEntityRemoved(event)
  local entity = event.entity
  if not (entity) then return end
  if entity.name == ELECTRIC_WAGON_NAME or entity.name == PRESERVATION_WAGON_NAME then
    unregister_wagon(entity)
  end
end

-- Scan surfaces and register existing wagons at init
local function init_entities()
  global[STORAGE_KEY] = global[STORAGE_KEY] or {}
  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered{ name = { ELECTRIC_WAGON_NAME, PRESERVATION_WAGON_NAME } }
    for _, ent in pairs(found) do
      if ent and ent.valid then
        global[STORAGE_KEY][ent.unit_number] = ent
      end
    end
  end
end

-- Handle runtime setting changes
local function on_runtime_setting_changed()
  -- Nothing to store permanently, get_freeze_rate() will read new values when needed
end

-- Main tick handler: uses the freeze rate semantics from Fridge
local function on_tick()
  local freeze_rates = get_freeze_rate()
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
  -- entity filters for creation/removal
  local entity_filter = {
    { filter = "name", name = ELECTRIC_WAGON_NAME },
    { filter = "name", name = PRESERVATION_WAGON_NAME }
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
end)

script.on_init(function()
  init_storages()
  init_entities()
  init_events()

  if has_fridge then
    log("[electric-refrigerated-wagon] Fridge detected: integrating with Fridge settings where possible")
  else
    log("[electric-refrigerated-wagon] Fridge not detected: using local freeze-rate fallback setting if configured")
  end
end)

script.on_configuration_changed(function()
  init_storages()
  init_entities()
  init_events()
end)
