-- Electric Refrigerated Wagon
-- Main control script

-- This mod integrates Electric Trains with Cold Chain Logistics (Fridge)
-- by providing an electrically powered refrigerated cargo wagon

-- Initialize mod on load
script.on_init(function()
  log("Electric Refrigerated Wagon initialized")
end)

script.on_configuration_changed(function(data)
  log("Electric Refrigerated Wagon configuration changed")
end)
