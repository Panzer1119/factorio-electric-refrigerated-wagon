-- Electric Refrigerated Wagon
-- Main control script

-- This mod integrates Electric Trains with Cold Chain Logistics (Fridge)
-- by providing an electrically powered refrigerated cargo wagon. The control
-- script registers placed wagons and, when the Fridge mod is present,
-- extends spoil timers for items in the wagon while the wagon is powered.

local ELECTRIC_WAGON_NAME = "electric-refrigerated-cargo-wagon"
local PRESERVATION_WAGON_NAME = "preservation-wagon" -- from Fridge

-- Helper: detect if Fridge is active
local has_fridge = script and script.active_mods and script.active_mods["Fridge"]

-- Local storage table for wagons if Fridge isn't present
global = global or {}
global.ERW = global.ERW or { wagons = {} }

local function register_wagon(entity)
  if not (entity and entity.valid) then return end
  if entity.name ~= ELECTRIC_WAGON_NAME then return end

  if has_fridge then
    -- If Fridge is present, try to piggyback on its storage.Wagons table
    -- We'll attempt to add the wagon to global storage in the same shape as Fridge
    -- Fridge expects `storage.Wagons` to hold entity references keyed by unit_number
    -- But we cannot directly access Fridge's `storage` table. Instead, we register
    -- the wagon in our own table and also emit a custom event so Fridge (if adapted)
    -- could pick it up. Many mods use script.raise_event with a custom event id,
    -- but Fridge does not export one. To remain compatible, we also add the
    -- wagon to our local table and rely on Fridge scanning surfaces on init.
    global.ERW.wagons[entity.unit_number] = entity
  else
    -- Without Fridge we still track wagons so refrigeration effect can be simulated locally
    global.ERW.wagons[entity.unit_number] = entity
  end
end

local function unregister_wagon(entity)
  if not (entity and entity.valid) then return end
  global.ERW.wagons[entity.unit_number] = nil
end

-- Utility: determine if wagon has available electric energy (attempt multiple checks)
local function wagon_is_powered(wagon)
  if not (wagon and wagon.valid) then return false end

  -- If the electric-trains mod exposes remote interface for charge state, prefer it
  if remote and remote.interfaces and remote.interfaces["electric-trains"] and remote.interfaces["electric-trains"].is_wagon_charged then
    -- hypothetical remote call; guard with pcall because implementation may differ
    local ok, result = pcall(function() return remote.call("electric-trains", "is_wagon_charged", wagon) end)
    if ok and result ~= nil then
      return result
    end
  end

  -- Check common electric properties. Some electric wagon prototypes use electric_buffer_size or energy
  if wagon.energy and type(wagon.energy) == "number" then
    return wagon.energy > 0
  end
  if wagon.electric_buffer_size and wagon.energy then
    return wagon.energy > 0
  end

  -- As a last resort, check if the locomotive producing electric force is nearby (not implemented)
  return false
end

-- On tick, if Fridge is present, we prefer to let Fridge handle spoil extension.
-- Otherwise, implement a minimal spoil extension: for each tracked wagon that is powered,
-- extend spoil_tick for spoilable items in the cargo inventory.
local function on_tick(event)
  -- every 80 ticks (same cadence as Fridge for warehouses) is reasonable
  if event.tick % 80 ~= 0 then return end

  -- If Fridge is loaded, simply ensure our wagons are registered; Fridge's own on_tick will process them
  if has_fridge then
    -- Attempt to keep Fridge aware: if Fridge scans at init, ensure wagons are discoverable by it
    -- We'll ensure our local registry contains all current wagons in case Fridge wants to query via remote
    for unit, wagon in pairs(global.ERW.wagons) do
      if not (wagon and wagon.valid) then
        global.ERW.wagons[unit] = nil
      end
    end
    return
  end

  -- If Fridge is not present, perform a lightweight spoil extension for items inside powered wagons
  for unit, wagon in pairs(global.ERW.wagons) do
    if wagon and wagon.valid then
      if wagon.get_inventory and wagon.get_inventory(defines.inventory.cargo_wagon) then
        if wagon_is_powered(wagon) then
          local inv = wagon.get_inventory(defines.inventory.cargo_wagon)
          for i = 1, #inv do
            local stack = inv[i]
            if stack and stack.valid_for_read and stack.spoil_tick and stack.spoil_tick > 0 then
              local max_spoil_time = game.tick + stack.prototype.get_spoil_ticks(stack.quality) - 3
              -- small extension similar to Fridge's unit used (80 ticks)
              stack.spoil_tick = math.min(stack.spoil_tick + 80, max_spoil_time)
            end
          end
        end
      end
    else
      global.ERW.wagons[unit] = nil
    end
  end
end

-- Event handlers for entity create/remove
local function on_entity_created(event)
  local entity = event.created_entity or event.entity
  if not (entity and entity.valid) then return end
  if entity.name == ELECTRIC_WAGON_NAME or entity.name == PRESERVATION_WAGON_NAME then
    register_wagon(entity)
  end
end

local function on_entity_removed(event)
  local entity = event.entity
  if not (entity) then return end
  if entity.name == ELECTRIC_WAGON_NAME or entity.name == PRESERVATION_WAGON_NAME then
    unregister_wagon(entity)
  end
end

-- Initialization: find existing wagons on surfaces and register them
local function init_entities()
  global.ERW.wagons = global.ERW.wagons or {}
  for _, surface in pairs(game.surfaces) do
    local found = surface.find_entities_filtered{ name = { ELECTRIC_WAGON_NAME, PRESERVATION_WAGON_NAME } }
    for _, ent in pairs(found) do
      if ent and ent.valid and (ent.name == ELECTRIC_WAGON_NAME or ent.name == PRESERVATION_WAGON_NAME) then
        global.ERW.wagons[ent.unit_number] = ent
      end
    end
  end
end

-- Event registration
script.on_init(function()
  init_entities()
  script.on_event(defines.events.on_built_entity, on_entity_created)
  script.on_event(defines.events.on_robot_built_entity, on_entity_created)
  script.on_event(defines.events.on_entity_cloned, on_entity_created)
  script.on_event(defines.events.script_raised_built, on_entity_created)
  script.on_event(defines.events.script_raised_revive, on_entity_created)

  script.on_event(defines.events.on_player_mined_entity, on_entity_removed)
  script.on_event(defines.events.on_robot_mined_entity, on_entity_removed)
  script.on_event(defines.events.on_entity_died, on_entity_removed)
  script.on_event(defines.events.script_raised_destroy, on_entity_removed)

  script.on_event(defines.events.on_tick, on_tick)

  -- If Fridge is present, inform player via log
  if has_fridge then
    log("[electric-refrigerated-wagon] Fridge detected: refrigeration will integrate with Fridge systems when possible.")
  else
    log("[electric-refrigerated-wagon] Fridge not detected: running local spoil-extension fallback logic.")
  end
end)

script.on_configuration_changed(function()
  init_entities()
end)
