-- data-updates.lua
-- Create recipe and technology that depend on other mods' data-updates registrations

-- Create or copy recipe for electric refrigerated cargo wagon
local recipe
if data.raw and data.raw["recipe"] and data.raw["recipe"]["recipe-electric-cargo-wagon"] then
  recipe = table.deepcopy(data.raw["recipe"]["recipe-electric-cargo-wagon"]) -- copy properties like category, energy_required, etc.
  recipe.name = "recipe-electric-refrigerated-cargo-wagon"

  -- Adjust results to produce our refrigerated wagon instead of electric-cargo-wagon
  if recipe.result then
    recipe.result = "electric-refrigerated-cargo-wagon"
  else
    if recipe.results then
      local replaced = false
      for _, r in ipairs(recipe.results) do
        if r.name == "electric-cargo-wagon" then
          r.name = "electric-refrigerated-cargo-wagon"
          replaced = true
        end
      end
      if not replaced then
        table.insert(recipe.results, { type = "item", name = "electric-refrigerated-cargo-wagon", amount = 1 })
      end
    else
      recipe.results = { { type = "item", name = "electric-refrigerated-cargo-wagon", amount = 1 } }
    end
  end

  -- Ensure ingredients field exists and append 2 refrigeraters
  recipe.ingredients = recipe.ingredients or {}
  local use_type = false
  for _, ing in ipairs(recipe.ingredients) do
    if type(ing) == "table" and ing.type then
      use_type = true
      break
    end
  end
  if use_type then
    table.insert(recipe.ingredients, { type = "item", name = "refrigerater", amount = 2 })
  else
    table.insert(recipe.ingredients, { "refrigerater", 2 })
  end
else
  -- Fallback balanced recipe when electric-trains recipe is not present
  recipe = {
    type = "recipe",
    name = "recipe-electric-refrigerated-cargo-wagon",
    enabled = false,
    energy_required = 80,
    ingredients = {
      { type = "item", name = "cargo-wagon", amount = 1 },
      { type = "item", name = "processing-unit", amount = 12 },
      { type = "item", name = "refrigerater", amount = 2 },
      { type = "item", name = "advanced-circuit", amount = 5 }
    },
    results = { { type = "item", name = "electric-refrigerated-cargo-wagon", amount = 1 } },
    order = "c[rolling-stock]-h[electric-refrigerated-cargo-wagon]"
  }
end

-- Register the recipe
data:extend({ recipe })

-- Technology: create technology that unlocks the refrigerated wagon recipe
local tech_prereqs = { "railway" }
if data.raw["technology"] then
  if data.raw["technology"]["tech-electric-trains"] then
    table.insert(tech_prereqs, "tech-electric-trains")
  elseif data.raw["technology"]["electric-trains"] then
    table.insert(tech_prereqs, "electric-trains")
  elseif data.raw["technology"]["electric-locomotive"] then
    table.insert(tech_prereqs, "electric-locomotive")
  end
end
if data.raw["technology"] and data.raw["technology"]["preservation-wagon"] then
  table.insert(tech_prereqs, "preservation-wagon")
elseif data.raw["technology"] and data.raw["technology"]["preservation-warehouse-tech"] then
  table.insert(tech_prereqs, "preservation-warehouse-tech")
end

local technology = {
  type = "technology",
  name = "electric-refrigerated-cargo-wagon",
  icons = data.raw["item-with-entity-data"]["electric-refrigerated-cargo-wagon"] and data.raw["item-with-entity-data"]["electric-refrigerated-cargo-wagon"].icons or nil,
  icon_size = 64,
  prerequisites = tech_prereqs,
  unit = {
    count = 250,
    ingredients = {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"production-science-pack", 1}
    },
    time = 30
  },
  effects = {
    { type = "unlock-recipe", recipe = "recipe-electric-refrigerated-cargo-wagon" }
  }
}

data:extend({ technology })

log("[electric-refrigerated-wagon] data-updates: recipe and technology registered (copied from electric-trains when available)")

