data:extend({
  {
    type = "string-setting",
    name = "electric-refrigerated-cargo-wagon-capacity-setting",
    setting_type = "startup",
    default_value = "50 Slots (Default)",
    allowed_values = {"40 Slots (Vanilla)", "50 Slots (Default)", "120 Slots (Extended)"}
  },
  {
    type = "int-setting",
    name = "electric-refrigerated-wagon-freeze-rate",
    setting_type = "runtime-global",
    default_value = 20,
    minimum_value = 1,
    maximum_value = 100,
    order = "c"
  }
})
