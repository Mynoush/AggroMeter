# Changelog

All notable changes to **AggroMeter** will be documented in this file.

---

## [1.0.0] - Initial Public Release

- **Core Nameplate Proximity & Pull-Margin Engine:**
  - Real-time safety-margin bar attached to hostile enemy nameplates with progressive **Green -> Amber -> Red** state colors.
  - Level-difference radius scaling plus per-NPC override support via `AggroMeter_Overrides.lua`.
  - Dedicated **Rogue Stealth / Druid Prowl** reduced detection model and crimson `!` pre-detection alert.
  - Target 5 m / 5 yd countdown banner and center-screen `AGGRO! - Mob Name` pull alert, with automatic suppression while dead or a ghost.
- **Full 3-Tab Settings UI (`/am config`):**
  - **Appearance**, **Alerts & Text**, and **Visibility** tabs with hover tooltips and **Reset Defaults**.
  - **41 StatusBar textures** (`Media\Textures\` + `Media\Textures\Styles\` + WoW built-in bars; bar styling visually inspired by Platynator) with visual grid preview and `<` / `>` cyclers.
  - **23 fonts** (`Media\Fonts\` + WoW built-in fonts) plus `LibSharedMedia-3.0` integration and **Outline**, **Bold**, **Shadow**, and **Mono** toggles.
  - **Smooth Bar Motion**, **Fill Bar on Danger** (`invertBar`), configurable **Width / Height / Scale / Y-Offset / Font Size**, and **5–60 Hz** update rate (default `25 Hz`).
- **Quick-Access Controls & Declutter Filters:**
  - Draggable **Minimap Button** and **Floating Quick-Access Button** (`Left-Click`: Config, `Right-Click`: Enable/Disable).
  - Nameplate `AGGRO!` flash and **Keep `AGGRO!` on Bar in Group** option.
  - Independent combat filters (My Combat / Group Combat / Others' Combat), **Focus on Target** (`fadeNonTarget`), and **Hide Far Safe Mobs** (`hideFarMobs`).
- **Units & Bilingual Support:**
  - Instant **Yards (`yd`) / Meters (`M`)** switch and full **English (`en`) / Portuguese (`pt`)** localization.
- **Packaging & Licensing:**
  - Open-source release under the **MIT License** (`LICENSE`) with automatic legacy `AggroWarningDB` preference import on first load.
