-- Electric Refrigerated Wagon
-- Data definitions and prototypes

-- This file will contain the prototype definitions for the electric refrigerated wagon
-- It attempts to inherit from the electric-trains mod when available and to be
-- compatible with the Fridge mod by providing a refrigerated wagon entity and
-- a small runtime compatibility flag. If Fridge is present, runtime behavior
-- (in control.lua) will extend spoil timers for items inside this wagon.

-- Determine base wagon prototype to copy from
local base_wagon_proto = nil
if mods["electric-trains"] and data.raw["cargo-wagon"] and data.raw["cargo-wagon"]["electric-cargo-wagon"] then
  base_wagon_proto = table.deepcopy(data.raw["cargo-wagon"]["electric-cargo-wagon"]) -- prefer electric wagon if present
else
  -- fallback to vanilla cargo-wagon prototype
  base_wagon_proto = table.deepcopy(data.raw["cargo-wagon"]["cargo-wagon"])
end

-- Create the electric refrigerated cargo wagon entity
local refrigerated_wagon = table.deepcopy(base_wagon_proto)
refrigerated_wagon.name = "electric-refrigerated-cargo-wagon"
refrigerated_wagon.minable = refrigerated_wagon.minable or {mining_time = 0.5, result = "electric-refrigerated-cargo-wagon"}
refrigerated_wagon.minable.result = "electric-refrigerated-cargo-wagon"

-- Mark entity with a small custom flag so other scripts can quickly detect compatibility
-- Note: this is a custom field and does not affect Factorio's internal prototype fields.
refrigerated_wagon.__electric_refrigerated_wagon = true

-- If Fridge is present we add a subtle tint to the icon by providing multiple icons
local icons = {}
if data.raw["item-with-entity-data"] and data.raw["item-with-entity-data"]["electric-cargo-wagon"] then
  -- Use electric-trains icon as base when available
  table.insert(icons, { icon = data.raw["item-with-entity-data"]["electric-cargo-wagon"].icon or "__electric-trains__/graphics/icons/electric-cargo-wagon.png", icon_size = data.raw["item-with-entity-data"]["electric-cargo-wagon"].icon_size or 64 })
else
  -- Fallback to a generic cargo-wagon icon if necessary
  table.insert(icons, { icon = "__base__/graphics/icons/cargo-wagon.png", icon_size = 64 })
end

-- If Fridge mod is present, include a small fridge icon overlay (tinted)
if mods["Fridge"] and (data.raw["item"] and (data.raw["item"]["refrigerater"] or data.raw["item"]["preservation-wagon"])) then
  table.insert(icons, { icon = "__Fridge__/graphics/icon/refrigerater.png", icon_size = 64, tint = {r=0.6, g=0.8, b=1.0, a=0.9}, scale = 0.5, shift = {8, -8} })
end

if #icons > 0 then
  refrigerated_wagon.icons = icons
end

-- Ensure inventory size is explicitly set (inherit or default)
refrigerated_wagon.inventory_size = refrigerated_wagon.inventory_size or (data.raw["cargo-wagon"]["cargo-wagon"] and data.raw["cargo-wagon"]["cargo-wagon"].inventory_size) or 50

-- Register entity, item, recipe, and technology
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

-- Build recipe ingredients in a guarded way so the recipe is valid whether or not
-- electric-trains or Fridge are present.
local recipe_ingredients = {}
if data.raw["item-with-entity-data"] and data.raw["item-with-entity-data"]["electric-cargo-wagon"] then
  table.insert(recipe_ingredients, {"electric-cargo-wagon", 1})
else
  table.insert(recipe_ingredients, {"steel-plate", 20})
  table.insert(recipe_ingredients, {"iron-gear-wheel", 20})
end

-- If Fridge provides a preservation-wagon item we can require it; otherwise use alternative components
if data.raw["item"] and data.raw["item"]["preservation-wagon"] then
  table.insert(recipe_ingredients, {"preservation-wagon", 1})
else
  table.insert(recipe_ingredients, {"steel-plate", 10})
  table.insert(recipe_ingredients, {"advanced-circuit", 5})
end

local recipe = {
  type = "recipe",
  name = "recipe-electric-refrigerated-cargo-wagon",
  enabled = false,
  energy_required = 10,
  ingredients = recipe_ingredients,
  result = "electric-refrigerated-cargo-wagon"
}

-- Technology: require preservation and electric-trains techs when available
local tech_prereqs = {"railway"}
if data.raw["technology"] and data.raw["technology"]["preservation-wagon"] then
  table.insert(tech_prereqs, "preservation-wagon")
end
-- electric-trains' main technology name is unknown; attempt common candidate names
if mods["electric-trains"] then
  -- try a few reasonable tech names that the electric-trains mod might provide
  if data.raw["technology"]["electric-trains"] then
    table.insert(tech_prereqs, "electric-trains")
  elseif data.raw["technology"]["electric-locomotive"] then
    table.insert(tech_prereqs, "electric-locomotive")
  end
end

local technology = {
  type = "technology",
  name = "electric-refrigerated-cargo-wagon",
  icon_size = 64,
  icons = refrigerated_wagon.icons and {refrigerated_wagon.icons[1]} or nil,
  prerequisites = tech_prereqs,
  unit = { count = 150, ingredients = { {"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1} }, time = 30 },
  effects = { { type = "unlock-recipe", recipe = "recipe-electric-refrigerated-cargo-wagon" } }
}

-- Register prototypes
data:extend({ refrigerated_wagon, item, recipe, technology })

log("[electric-refrigerated-wagon] data: electric-refrigerated-cargo-wagon registered")
