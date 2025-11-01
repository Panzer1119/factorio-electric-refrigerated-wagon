# Electric Refrigerated Wagon

This mod provides a single integrated rolling stock: an electrically powered refrigerated cargo wagon that bridges the "electric-trains" mod (electric locomotives / electric wagons) with the Cold Chain Logistics mod ("Fridge").

This README documents the integration, runtime behaviour, and manual steps you may want to follow when using or extending the mod.

## Features

- `electric-refrigerated-cargo-wagon` entity (and item/recipe/technology).
- Data-stage prototype reuses `electric-cargo-wagon` from the `electric-trains` mod when available, otherwise falls back to the vanilla `cargo-wagon` prototype.
- If the `Fridge` mod is present, the wagon is designed to be compatible with Fridge's preservation mechanics (items that spoil inside preservation containers/wagons will have their spoil timers extended when preserved by the Fridge systems).
- If `Fridge` is not present, the mod implements a small local fallback: while the wagon is powered it will extend spoil timers for spoilable items in the cargo inventory.
- All integrations are guarded; the mod will load and operate (with reduced functionality) whether or not either dependency is present.

## Files of interest

- `data.lua` — registers the entity, item, recipe, and technology. It tries to deep-copy the `electric-cargo-wagon` prototype from the `electric-trains` mod if present.
- `control.lua` — runtime code that tracks placed wagons and extends spoil timers when appropriate. It:
  - Detects whether `Fridge` is loaded via `script.active_mods["Fridge"]`.
  - If `Fridge` is present: ensures wagons are discoverable; Fridge's own runtime logic (which scans preservation entities on init and on_tick) will handle spoil extensions.
  - If `Fridge` is not present: uses a local fallback to extend spoil timers on powered wagons every 80 ticks.

## Dependencies

- This mod declares soft dependencies on `electric-trains` and `Fridge` (see `info.json`).
- Behaviour at runtime:
  - If `electric-trains` is present, `data.lua` will use its `electric-cargo-wagon` prototype as the base for the refrigerated wagon.
  - If `Fridge` is present, the mod expects Fridge to scan surfaces and handle spoil extensions; the mod will register wagons so Fridge can find them. If Fridge exposes a remote interface in the future, this mod attempts to call a hypothetical `remote.call("electric-trains", "is_wagon_charged", wagon)` function (guarded by `pcall`) to detect wagon charge — this is defensive and will not error if the remote interface doesn't exist.

## How integration works (summary)

1. Data stage (`data.lua`):
   - If `electric-trains` provides `electric-cargo-wagon`, create `electric-refrigerated-cargo-wagon` by deep-copying it. Otherwise deep-copy the vanilla `cargo-wagon`.
   - Register an item, recipe and a technology. All references are guarded so `data.lua` will not fail if other mods are absent.

2. Runtime (`control.lua`):
   - On mod init/config change, scan all surfaces and register any existing `electric-refrigerated-cargo-wagon` and `preservation-wagon` entities in a local registry `global.ERW.wagons`.
   - When an `electric-refrigerated-cargo-wagon` is placed, register it.
   - On remove/destroy, unregister it.
   - Every 80 ticks (fallback behaviour): if `Fridge` isn't loaded, extend spoil timers for spoilable items inside powered wagons. If `Fridge` is loaded, the mod leaves spoil handling to Fridge and just keeps its registry up-to-date.

## Testing / verification steps (in-game)

- With both `electric-trains` and `Fridge` enabled:
  - Start a game, research the required techs, craft and place an `electric-refrigerated-cargo-wagon`.
  - Put spoilable items (from a mod that enables spoiling) into the cargo inventory and observe that spoil timers are extended while refrigeration is active (Fridge's UI/logging can help verify).

- With `Fridge` disabled (but `electric-trains` present):
  - Place spoilable items into the wagon while it is powered (e.g. near a charging locomotive or if the wagon provides its own energy buffer). The local fallback will attempt to extend spoil time every 80 ticks while powered.

- With `electric-trains` disabled: the mod will use the vanilla cargo wagon base and still provide refrigeration compatibility (Fridge-aware) or fallback behaviour.

## Assumptions and limitations

- Fridge currently manages spoil extension via its own `storage` tables and scans entities on init; this mod does not (and should not) directly mutate Fridge's internal `storage` tables.
- The remote-call to check wagon charge is speculative and wrapped in a `pcall`. If a future version of `electric-trains` exposes a documented remote interface, we can switch to that formally.
- The local fallback is intentionally conservative: it only adds a small amount (80 ticks) per 80-tick interval to spoil timers to avoid surprising effects. If you want stronger preservation in the fallback, adjust the increment in `control.lua`.
- Icon overlay uses `Fridge`'s refrigerater icon if present. You may want to replace this with a dedicated icon in this mod's `graphics` folder for a cleaner look.

## Troubleshooting

- If the wagon recipe or technology doesn't appear in-game:
  - Verify `info.json` lists correct dependencies and the mod order (Factorio loads mods sorted by dependencies).
  - Check the Factorio log for prototype errors; the data-stage is guarded but mismatched names in other mods could prevent prereqs from resolving.

- If spoil extension doesn't appear to work:
  - Confirm items in your game actually have spoil mechanics enabled (Fridge sets `spoiling_required` in its info.json and may provide the necessary item prototypes).
  - Check that the wagon is powered. The fallback checks `wagon.energy` or `electric_buffer_size` if available; if your electric wagons store charge in a different property, we can adapt the detection.

## Developer notes & next steps

- If you want closer integration, consider adding a small remote interface in Fridge to allow external mods to register preservation-capable wagons. This mod already attempts to be compatible with that approach.
- Add a localized `locale/en.cfg` and appropriate icons under `graphics/` and wire them in `data.lua`.
- If you want the mod to support charging behavior or energy consumption metrics in more detail (mirroring `electric-trains` more closely), we can add remote-call-based hooks once the `electric-trains` remote API is stable/documented.

## Credits
- This mod bridges work done in the `electric-trains` and `Fridge` mods (see their respective repositories for full authorship and licenses).

---

If you want, I can also:
- Add a small `locale/en.cfg` with the new name/description strings.
- Create a proper icon set under `graphics/` and replace the overlay icon behavior.
- Add an optional remote registration routine for Fridge if you want two-way registration (requires Fridge to provide a remote target).

Tell me which of the above you'd like next.
