# Happy Tree Friends

Happy Tree Friends is a lightweight quality-of-life toolkit for **World of Warcraft Retail 12.1**.

## Features

- Automatic repair with personal gold or guild funds
- Automatic selling of grey-quality junk, with a protected-item list
- Session tracking for repair costs and junk-sale income
- Friendly-player name-only mode with a custom font-size option
- Secure raid-debuff categories for bleeds, crowd control, raid-important effects, and short otherwise-unclassified debuffs such as Ula'tek's Hobbled (1300938)
- Adjustable raid-debuff icon size from 8 to 24 pixels
- A clean standalone settings window
- English and Simplified Chinese localization, debug logs, and copyable diagnostics

## Aura Position and Appearance

- Open `/htf buffs` to enable a separate icon for your own Beacon of Virtue (spell 200025). This is currently the only tracked buff.
- The buff defaults to the top-left corner at 18 pixels, with a steady gold border and countdown. Choose any corner, adjust horizontal/vertical offsets, or set its size from 8 to 24 pixels.
- Extra debuffs in `/htf debuffs` have independent position and size controls, plus optional orange-red borders and outlined countdowns. Scroll down for the appearance controls.
- Key buffs start disabled. Debuff borders and countdowns also start disabled to preserve existing preferences. Borders do not flash.
- These controls affect HTF's additional icons. Blizzard's original buff/debuff icons stay in place, so Beacon of Virtue may appear in both displays.
- Changes made during combat are saved and applied when combat ends.

## Commands

- `/htf` — Settings
- `/htf merchant` — Merchant settings
- `/htf nameplates` — Friendly-name settings
- `/htf debuffs` — Raid-debuff enhancement settings
- `/htf protect <item link or ID>` — Protect a grey item
- `/htf unprotect <item link or ID>` — Remove protection
- `/htf protected` — List protected items
- `/htf debug` — Toggle debug mode
- `/htf dump` — Generate a diagnostic report
- `/htf clearlog` — Clear debug logs

Developed with assistance from AI tools. Feedback and bug reports are welcome.
