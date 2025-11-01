-- Electric Refrigerated Wagon
-- Data definitions and prototypes

-- This file will contain the prototype definitions for the electric refrigerated wagon
-- It attempts to inherit from the electric-trains mod when available and to be
-- compatible with the Fridge mod by providing a refrigerated wagon entity and
-- a small runtime compatibility flag. If Fridge is present, runtime behavior
-- (in control.lua) will extend spoil timers for items inside this wagon.

-- Determine base wagon prototype to copy from
local base_wagon_proto
if mods["electric-trains"] and data.raw["cargo-wagon"] and data.raw["cargo-wagon"]["electric-cargo-wagon"] then
  base_wagon_proto = table.deepcopy(data.raw["cargo-wagon"]["electric-cargo-wagon"]) -- prefer electric wagon if present
else
  -- fallback to vanilla cargo-wagon prototype
  base_wagon_proto = table.deepcopy(data.raw["cargo-wagon"]["cargo-wagon"])
end

-- Create the electric refrigerated cargo wagon entity (inherit important fields from the electric wagon)
local refrigerated_wagon = table.deepcopy(base_wagon_proto)
refrigerated_wagon.name = "electric-refrigerated-cargo-wagon"
refrigerated_wagon.minable = refrigerated_wagon.minable or {mining_time = 0.5, result = "electric-refrigerated-cargo-wagon"}
refrigerated_wagon.minable.result = "electric-refrigerated-cargo-wagon"

-- Apply preservation tint and behavior similar to Fridge's preservation_wagon
refrigerated_wagon.color = {r = 0.6, g = 0.8, b = 1.0, a = 0.8}
refrigerated_wagon.allow_manual_color = false

-- Determine base icon (prefer electric-trains' electric-cargo-wagon item icon)
local base_icon = "__base__/graphics/icons/cargo-wagon.png"
local base_icon_size = 64
if data.raw["item-with-entity-data"] and data.raw["item-with-entity-data"]["electric-cargo-wagon"] then
  local eitem = data.raw["item-with-entity-data"]["electric-cargo-wagon"]
  if eitem.icon then
    base_icon = eitem.icon
    base_icon_size = eitem.icon_size or base_icon_size
  elseif eitem.icons and eitem.icons[1] and eitem.icons[1].icon then
    base_icon = eitem.icons[1].icon
    base_icon_size = eitem.icons[1].icon_size or base_icon_size
  end
end

-- Build single icon entry and tint it if Fridge is present
local icons = {}
local base_entry = { icon = base_icon, icon_size = base_icon_size }
if mods["Fridge"] then
  base_entry.tint = { r = 0.6, g = 0.8, b = 1.0, a = 0.9 }
end
table.insert(icons, base_entry)
refrigerated_wagon.icons = icons

-- Ensure inventory size is explicitly set (inherit or default)
-- If the user has a startup setting, use it (strings like "50 Slots (Default)")
local function parse_slots_from_setting(val)
  if not val then return nil end
  -- extract leading number
  local num = tonumber(val:match("(%d+)%s*Slots"))
  return num
end

local setting_val = settings and settings.startup and settings.startup["electric-refrigerated-cargo-wagon-capacity-setting"] and settings.startup["electric-refrigerated-cargo-wagon-capacity-setting"].value or nil

local configured_slots = parse_slots_from_setting(setting_val)
refrigerated_wagon.inventory_size = configured_slots or refrigerated_wagon.inventory_size or (data.raw["cargo-wagon"]["cargo-wagon"] and data.raw["cargo-wagon"]["cargo-wagon"].inventory_size) or 50

-- Register entity and item only. Recipe and technology are created in data-updates.lua
local item = {
  type = "item-with-entity-data",
  name = "electric-refrigerated-cargo-wagon",
  icons = refrigerated_wagon.icons or nil,
  icon = (refrigerated_wagon.icons and refrigerated_wagon.icons[1] and refrigerated_wagon.icons[1].icon) or nil,
  icon_size = (refrigerated_wagon.icons and refrigerated_wagon.icons[1] and refrigerated_wagon.icons[1].icon_size) or 64,
  subgroup = "train-transport",
  order = "c[rolling-stock]-h[electric-refrigerated-cargo-wagon]",
  place_result = "electric-refrigerated-cargo-wagon",
  stack_size = 5
}

-- Register prototypes (entity + item). Recipes and tech registered in data-updates.lua to allow copying other mods' data-updates.
data:extend({ refrigerated_wagon, item })

log("[electric-refrigerated-wagon] data: entity and item registered; recipes & tech will be created in data-updates.lua")
