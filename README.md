# Electric Refrigerated Wagon

This mod provides a single integrated rolling stock: an electrically powered refrigerated cargo wagon that bridges the "electric-trains" mod (electric locomotives / electric wagons) with the Cold Chain Logistics mod ("Fridge").

This README documents the current implementation, runtime behaviour, settings, files of interest, and quick testing notes.

## Highlights (what the mod currently does)

- Registers a new entity/item/recipe/technology: `electric-refrigerated-cargo-wagon` (and `recipe-electric-refrigerated-cargo-wagon`, `electric-refrigerated-cargo-wagon` technology).
- Data-stage: the wagon prototype is created by deep-copying `electric-cargo-wagon` from `electric-trains` when available; falls back to the vanilla `cargo-wagon` otherwise. The prototype is tinted and configured to match Fridge-style preservation wagons (color, no manual color).
- Recipe: a balanced recipe was created using ingredients inspired by both mods (cargo chassis + processing units + 2x refrigerater + advanced circuits) instead of simply combining two existing wagons.
- Technology: a new technology unlocks the recipe; prerequisites include `railway` plus available electric-trains and Fridge preservation techs where present (robust detection across likely tech names).
- Settings:
  - Startup: `electric-refrigerated-cargo-wagon-capacity-setting` — choose cargo slot capacity (40 / 50 / 120 slots). Requires restart/save reload to take effect.
  - Runtime-global: `electric-refrigerated-wagon-freeze-rate` — fallback freeze-rate when Fridge's `fridge-freeze-rate` is not present.
- Control/runtime behaviour:
  - The mod tracks only its own `electric-refrigerated-cargo-wagon` entities (it does NOT register Fridge's `preservation-wagon` — Fridge manages those itself).
  - Preservation behaviour matches Fridge: spoil timers for spoilable items in wagon cargo are extended unconditionally while the wagon exists (no internal power gating). This mirrors Fridge's preservation-wagon behavior.
  - The freeze-rate value is read only at load/init/config change or when the relevant runtime setting changes — it is cached (avoids reading settings on every tick).
- Localisation: English and German locale files added under `locale/en/base.cfg` and `locale/de/base.cfg` with names/descriptions for item, technology and settings.

## Files of interest (current)

- `data.lua` — creates the `electric-refrigerated-cargo-wagon` prototype (deep-copying electric-trains' electric wagon when present), the item, the balanced recipe and the technology; reads the startup capacity setting for inventory size.
- `control.lua` — runtime code that:
  - maintains a registry of placed refrigerated wagons (by unit_number),
  - scans all surfaces on init to register existing wagons,
  - updates a cached freeze-rate on load/config change or when the runtime setting changes,
  - extends spoil-time for spoilable items in the wagons according to the configured cadence (Fridge-compatible semantics).
- `settings.lua` — contains two settings:
  - `electric-refrigerated-cargo-wagon-capacity-setting` (startup string setting: 40 / 50 / 120 Slots), and
  - `electric-refrigerated-wagon-freeze-rate` (runtime-global int fallback).
- `locale/en/base.cfg` and `locale/de/base.cfg` — English and German localisations for the mod name, item/entity name, recipe, technology and settings.
- `info.json` — mod metadata and dependencies (declares soft dependencies on `electric-trains` and `Fridge`).

## Behaviour & compatibility notes

- If `electric-trains` is present the refrigerated wagon will keep electric-trains visuals and properties (capacity, sprites), but inventory size is configurable via the startup setting.
- If `Fridge` is present, this mod prefers Fridge's runtime `fridge-freeze-rate` (the cached value will be read at load/config change). If Fridge is absent, the mod uses its own runtime `electric-refrigerated-wagon-freeze-rate` setting.
- The refrigerated wagon preserves items like Fridge's preservation-wagon (no power gating). If you later want refrigeration to require stored energy, add an `energy_source`/buffer to the prototype and I can reintroduce a power-check in `control.lua`.

## Quick testing steps (in-game)

1. Ensure the mod is enabled (and optionally enable `electric-trains` and/or `Fridge`).
2. Start or load a game; the mod logs whether it detected Fridge.
3. Research the new technology (if prerequisites satisfied) and craft the `Electric Refrigerated Cargo Wagon`.
4. Place the wagon, insert spoilable items (mods that enable spoiling are required), and observe spoil timers — they will be extended on the Fridge cadence. Change the runtime freeze-rate setting and observe behaviour change (the cached value updates on setting change).

## Developer notes & next steps

- If you want refrigeration to be power-gated:
  - Add an `energy_source` + buffer to the wagon prototype in `data.lua` and I will reintroduce an entity-level power check to `control.lua` so preservation is only active while the wagon has charge.
- If you want a dedicated icon (recommended): add images under `graphics/` and I will wire them into `data.lua` (replacing the current overlay behavior).
- If you want Fridge to directly accept external wagons via a remote API, adding a small remote interface on the Fridge side would allow tight two-way registration; I can implement the consumer side here.

## Credits
- This mod bridges features from `electric-trains` and `Fridge` (see those repositories for full credits and licenses).
