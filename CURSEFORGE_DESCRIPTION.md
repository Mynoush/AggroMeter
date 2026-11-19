**AggroMeter** attaches a sleek, real-time proximity and pull-margin bar directly beneath hostile enemy nameplates—helping you judge safe movement space, avoid accidental body pulls in Hardcore runs, navigate crowded camps, and sneak past enemies more reliably.

> **Important:** Make sure **Enemy Nameplates** are turned on in-game (`V` by default). Type `/am config` or Left-Click the minimap/screen radar button to customize every detail.

---

## Why Use AggroMeter?

Enemy aggro radius is normally invisible and changes dynamically based on level differences and stealth state. **AggroMeter** turns that hidden mechanic into clear visual feedback directly on every nearby hostile nameplate:

* **Green** — Comfortable safety margin remaining.
* **Amber / Yellow** — Approaching the estimated pull threshold.
* **Red (`DANGER`)** — Right on or inside the estimated aggro radius.

This makes it especially useful for **Hardcore characters**, **Rogues & Druids** sneaking through dense camps or caves, and players navigating higher-level zones.

---

## Key Features

### Real-Time Proximity & Pull Estimation
* **Level-Scaled Pull Radius:** Adjusts estimated detection range according to player-vs-mob level differences (plus per-NPC override support by NPC ID).
* **Rogue Stealth & Druid Prowl Mode:** Automatically switches to a tighter stealth detection estimate whenever Stealth or Prowl is active, and flashes a crimson **`!`** pre-detection alert as you cross into danger range.
* **Proximity Countdown & Pull Alerts:** Shows an optional target proximity countdown banner (`5 m / 5 yd`) with tiered audio cues and flashes **`AGGRO! - Mob Name`** if combat threat initiates. Alerts are automatically suppressed while dead or a ghost.

### Full Visual Customization (`/am config`)
* **3-Tab Configuration GUI:** Organized into **Appearance**, **Alerts & Text**, and **Visibility** tabs with descriptive hover tooltips and a **Reset Defaults** button.
* **41 Bar Textures & 23 Fonts (+ `LibSharedMedia-3.0`):** Interactive preview dropdown grids and `<` / `>` cyclers, plus independent **Outline**, **Bold** (`THICKOUTLINE`), **Shadow**, and **Mono** text flags.
* **Smooth Motion & Danger Fill Mode:** Smoothly animates bar fill and color interpolation (`5–60 Hz`, default `25 Hz`), or enable **Fill Bar on Danger** so the bar starts empty when safe and fills up red as you move closer.
* **Custom Sizing & Positioning:** Sliders for **Width**, **Height**, **Scale**, **Vertical Offset (Y)**, and **Font Size**.

### Smart Combat, Group & Declutter Controls
* **Nameplate `AGGRO!` Indicator + Group Retention:** Temporarily flashes red indicators and `AGGRO!` on newly pulled nameplates, or enable **Keep `AGGRO!` on Bar in Group** to keep that mob marked clearly for as long as it is targeting you in party/raid.
* **Combat Hide Filters:** Independently hide proximity bars on mobs already fighting **you**, **your party/raid**, or **other players**.
* **Focus on Target:** Keeps your target, mouseover, and `DANGER` mobs at 100% opacity while dimming safe background mobs to 55%.
* **Hide Far Safe Mobs:** Hides bars on distant enemies (`>20 yd / 18 m` margin), showing them only when you approach.

### Quality of Life & Localization
* **Minimap & Floating Quick-Access Buttons:** Both display a green/red status dot, open Settings on **Left-Click**, toggle AggroMeter On/Off on **Right-Click**, can be repositioned freely, and can be hidden individually.
* **Meters (`M`) & Yards (`yd`) Toggle:** Switch all distance numbers instantly between Yards and Meters.
* **Bilingual Interface (`EN` / `PT-BR`):** Full English and Portuguese menus, tooltips, and bar labels.

---

## Important Note on Accuracy

World of Warcraft does not expose raw world coordinates or exact NPC aggro radii to addons. **AggroMeter** estimates distance brackets using legal client item, spell, and interaction range checks combined with level-difference and stealth heuristics. Treat the bar as an extra situational-awareness buffer—especially on Hardcore characters or near patrols, social-aggro packs, and bosses.

---

## Quick Slash Commands (`/am` or `/aggrometer`)

Type `/am config` to open Settings, `/am unit` to switch Meters/Yards, `/am lang` for English/PT-BR, or `/am help` for the complete command list.

---

## License, Inspiration & Notices

* **License:** **MIT License** (`Copyright (c) 2026 Mynou`).
* **Visual Inspiration:** Nameplate bar styling and typography curation were visually inspired by **Platynator** (by *plusmouse*) alongside the community `LibSharedMedia-3.0` ecosystem.
* **Third-Party Data & Assets:** Distance-range item data derives from **LibRangeCheck-3.0** (MIT License); bundled fonts originate from open-source font libraries (`SIL OFL 1.1` / `Apache 2.0`). This addon is strictly free and non-commercial under Blizzard's AddOn policy, with no ownership claimed over third-party assets. See `THIRD_PARTY_NOTICES.txt` or [GitHub Issues](https://github.com/Mynoush/AggroMeter/issues) for notices and rights-holder contact.
