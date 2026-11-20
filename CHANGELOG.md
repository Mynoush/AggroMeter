# Changelog

All notable changes to **AggroMeter** will be documented in this file.

---

## [1.1.0] - Live Preview, Custom Icon, Native Options & Performance Upgrade

### New Features
- **Interactive Live Preview (`/am config`):** Added a real-time enemy nameplate preview inside the **Appearance** tab that reflects every font, texture, opacity, dimension, anchor position, compact-text, invert, unit, and language change immediately. Click the preview bar to cycle **SAFE → CAUTION → DANGER → AGGRO!**.
- **Bar Anchor Position (`Below` / `Above`):** Added option to place the AggroMeter bar either **Below Nameplate** or **Above Nameplate** (`/am pos [below|above]` or in Settings).
- **Bar Opacity Slider (`25%–100%`):** Added configurable base transparency for nameplate bars (`/am alpha <0.25-1.00>` or in Settings).
- **Compact Text Mode (Margin Only):** Added toggle to show only remaining safety margin on bars without repeating total aggro radius (`/am compact [on|off]`).
- **`LibSharedMedia-3.0` StatusBar Textures:** Expanded texture discovery to import custom `statusbar` textures registered by other addons via `LibSharedMedia-3.0` alongside the 41 built-in bar styles.
- **Test Alert & Test Stealth Cue Buttons:** Added **`Test Alert & Sound`** and **`Test Stealth Cue (!)`** buttons in the **Alerts & Text** tab (plus `/am test [stealth]`).
- **WoW Native Sound Option & Zero-Copyright Stealth Audio:** Removed `Sounds\stealth_notice.ogg` and switched stealth pre-detection cues to World of Warcraft's built-in SoundKit alerts, plus added a **Use WoW Native Sounds Only** toggle (`/am nativesound [on|off]`).
- **Custom AddOn Icon & Blizzard Options Integration:**
  - Bundled `Media\Textures\icon.tga` for the WoW AddOns list (`## IconTexture:`), Addon Compartment button (`## AddonCompartmentFunc:`), floating button, and circular-masked minimap button.
  - Registered an entry under WoW's native **Options → AddOns → AggroMeter** menu with a shortcut to open Settings.

### Fixes & Performance
- **Unit-Aware & Bilingual Proximity Banner:** Fixed the 5 yd / 5 m target proximity alert banner to respect the chosen unit (**Yards `yd`** vs **Meters `M`**) and **English / PT-BR** localization (`ALERTA DE AGGRO`).
- **Zero-Allocation Nameplate Updates:** Reused `row.lastSnapshot` tables in-place inside `UpdateRow` to eliminate per-frame garbage collection allocations during `25–60 Hz` polling.
- **Immediate Scan After `/reload`:** Added `PLAYER_ENTERING_WORLD` handling and `ScanVisibleNameplates()` so bars appear right away on visible hostile nameplates after login or `/reload`.
- **Complete Reset Defaults:** Clicking **Reset Defaults** now restores all `v1.1.0` controls, alert toggles, minimap angle, and floating button screen position.

---

## [1.0.0] - Initial Public Release

- **Core Nameplate Proximity & Pull-Margin Engine:**
  - Real-time safety-margin bar attached to hostile enemy nameplates with progressive **Green → Amber → Red** state colors.
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
