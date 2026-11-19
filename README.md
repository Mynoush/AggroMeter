# AggroMeter

**Nameplate Proximity & Pull-Radius Bar for World of Warcraft**

**AggroMeter** attaches a sleek, highly customizable safety-margin bar beneath hostile enemy nameplates. Instead of guessing how close you can walk before pulling a mob—or accidentally body-pulling extra packs in Hardcore, caves, or crowded quest hubs—AggroMeter turns invisible aggro radii into clear visual distance feedback in real time.

---

## Core Features

- **Real-Time Nameplate Proximity Bars:** Displays remaining safety distance and estimated pull radius directly under hostile enemy nameplates using progressive **Green → Amber → Red** transitions.
- **Level-Scaled & Stealth-Aware Estimation:** Automatically adjusts estimated pull distance based on level differences between you and each enemy, and switches to a tighter detection estimate while Rogues are in **Stealth** or Druids are in **Prowl**.
- **Full In-Game Settings Window (`/am config`):** Clean 3-tab interface (**Appearance**, **Alerts & Text**, **Visibility**) with hover tooltips for every control and a one-click **Reset Defaults** button.
- **41 Bar Textures & 23 Fonts (+ `LibSharedMedia-3.0`):** Interactive grid-dropdown menus with live visual previews, `<` / `>` quick cyclers, and independent **Outline**, **Bold** (`THICKOUTLINE`), **Shadow**, and **Mono** text options.
- **Smooth Bar Motion & Danger Fill Mode:** Smoothly interpolates bar fill and color changes at **5–60 Hz** (default `25 Hz`), or invert the bar (**Fill Bar on Danger**) so it starts empty when safe and fills in red as danger increases.
- **Proximity Alerts, Pull Flashes & Stealth Cue:**
  - Target proximity warning banner (`5 m / 5 yd`) with optional tiered sound alerts.
  - Center-screen pull alert (`AGGRO! - Mob Name`) plus flashing red nameplate pull indicator.
  - **Keep `AGGRO!` on Bar in Group:** Keeps the red `AGGRO!` indicator lit on nameplates while in party or raid for any mob currently targeting you.
  - **Stealth Pre-Detection Cue (`!`):** Flashes a crimson `!` with an optional audio cue right as you cross into a stealthed mob's detection zone.
  - Automatically suppresses screen banners and alert sounds while you are dead or a ghost.
- **Minimap & Floating Quick-Access Buttons:** Both buttons display a live green/red status dot, open Settings on **Left-Click**, toggle the addon On/Off on **Right-Click**, can be dragged anywhere, and can be hidden independently.
- **Smart Combat & Screen Declutter Filters:**
  - Independently hide bars on mobs already in combat with **you**, with **your group/raid**, or pulled/tapped by **other players**.
  - **Focus on Target:** Keeps your target, mouseover, and `DANGER` mobs at 100% opacity while dimming safe background mobs to 55%.
  - **Hide Far Safe Mobs:** Hides bars on distant enemies (`>20 yd / 18 m` margin) until you get closer.
- **Instant Yards (`yd`) / Meters (`M`) & Bilingual UI (`EN` / `PT-BR`):** Switch distance units and interface language anytime from `/am config` or via slash commands.

---

## Accuracy Note

World of Warcraft addons do not receive exact coordinates or raw server-side aggro radii for hostile units. **AggroMeter** calculates safe-margin brackets dynamically from Blizzard's legal item, spell, and interaction distance checks paired with level-difference and stealth heuristics. Treat the display as an informational safety margin—especially on **Hardcore** characters, patrols, social pulls, or scripted NPCs with special truesight/abilities.

---

## Installation

1. Ensure **Enemy Nameplates** are enabled in-game (default keybind: `V`).
2. Extract or place the `AggroMeter` folder into `World of Warcraft\_...\Interface\AddOns\AggroMeter\`.
3. Type `/am config` in chat or **Left-Click** the radar icon on your minimap/screen to customize the bar.

---

## Slash Commands (`/am` or `/aggrometer`)

| Command | Description |
| :--- | :--- |
| `/am config` *(or `ui`, `menu`, `options`)* | Open or close the Settings window |
| `/am on` / `/am off` | Enable or disable AggroMeter |
| `/am unit [meters\|yards]` | Switch readout between **Meters (`M`)** and **Yards (`yd`)** |
| `/am lang [en\|pt]` | Switch menus and bar labels between **English** and **Portuguese** |
| `/am text` | Toggle distance text inside nameplate bars |
| `/am status [on\|off]` | Toggle `SAFE` / `CAUTION` / `DANGER` prefix before distance |
| `/am warning [on\|off]` | Toggle 5 m / 5 yd target proximity countdown banner |
| `/am alerts [all\|icon\|off]` | Cycle alert mode (`all`, `icon`, `off`) |
| `/am sound [on\|off]` | Toggle warning sound cues |
| `/am pullalert [on\|off]` | Toggle center-screen `AGGRO!` pull banner |
| `/am stealthnotice [on\|off]` | Toggle Rogue/Druid stealth red `!` detection alert |
| `/am scale <0.75-1.50>` | Set bar widget scale |
| `/am width <80-220>` | Set bar width in pixels |
| `/am height <4-20>` | Set bar height in pixels |
| `/am offsety <-50 to 50>` | Set vertical bar offset relative to the nameplate |
| `/am fontsize <6-24>` | Set bar font size |
| `/am font <friz\|arial\|morpheus\|skurri\|2002\|2002b\|friends\|nimrod\|path>` | Set bar font |
| `/am rate <5-60>` | Set update frequency in Hz (default `25`) |
| `/am invert [on\|off]` | Toggle Fill Bar on Danger mode |
| `/am smooth [on\|off]` | Toggle smooth fill & color animation |
| `/am dim [on\|off]` | Toggle Focus on Target (dims non-target safe bars to 55%) |
| `/am hidefar [on\|off]` | Toggle hiding bars on distant safe mobs |
| `/am hideself [on\|off]` | Hide bar on mobs already fighting you/your pet |
| `/am hidegroup [on\|off]` | Hide bar on mobs already fighting your party/raid |
| `/am hideother [on\|off]` | Hide bar on mobs tapped/pulled by players outside your group |
| `/am keepaggro [on\|off]` | Keep red `AGGRO!` indicator active in party/raid while mob targets you |
| `/am debug` / `/am reload` | Print target range diagnostics or refresh spell/item range tables |

---

## License, Inspiration & Third-Party Notices

- **License:** Released under the **MIT License** (`Copyright (c) 2026 Mynou`). See `LICENSE`.
- **Visual Inspiration:** Nameplate bar styling aesthetics and typography choices were visually inspired by **Platynator** (by *plusmouse*) and the World of Warcraft `LibSharedMedia-3.0` community ecosystem.
- **Distance-Range Item Data:** Derived from [LibRangeCheck-3.0](https://github.com/WeakAuras/LibRangeCheck-3.0) by The WoWUIDev Community (MIT License).
- **Fonts, Media & Rights-Holder Notice:** Bundled fonts come from open-source font libraries (`SIL OFL 1.1` / `Apache 2.0`). AggroMeter is free and non-commercial under Blizzard Entertainment's AddOn policy; no ownership is claimed over third-party assets or trademarks. Full notices and the takedown contact procedure are in `THIRD_PARTY_NOTICES.txt` (or via [GitHub Issues](https://github.com/Mynoush/AggroMeter/issues)).
