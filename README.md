# Happy Tree Friends

Happy Tree Friends is a lightweight, event-driven quality-of-life addon for **World of Warcraft Retail 12.1**. It combines practical merchant tools, a clear at-a-glance HUD, and optional friendly-player name controls without constant background polling.

## Features

- **Safe merchant automation** — Automatically repair with personal gold or guild funds when enabled, and sell grey-quality junk items.
- **Protected junk items** — Protect specific grey items by item link or ID so they are never sold automatically.
- **Session ledger** — Track repair costs, guild and personal repair spending, junk-sale earnings, and protected items skipped during the current session.
- **Friendly-player name-only mode** — Keep friendly player names visible while hiding health bars and other nameplate clutter. Optional class colors and a custom font size make names easier to identify; previous game settings are restored when the feature is disabled.
- **Standalone settings window** — `/htf` opens Happy Tree Friends directly, without nesting its controls inside the Blizzard settings screen.
- **Customizable adventure HUD** — Move, resize, and lock a transparent HUD for character stats, durability, free bag slots, money, and latency. Each item can be shown or hidden independently, with custom colors and font size.
- **Smart visual warnings** — Durability and free-bag-slot values change color when they need attention.
- **Localization and diagnostics** — Includes English and Simplified Chinese, optional debug logging, and a copyable diagnostic report.

## Lightweight by Design

Happy Tree Friends reacts only to relevant game events. It does not use an `OnUpdate` loop, permanently scan bags, or listen to combat logs. Merchant automation and friendly-name-only mode are opt-in and disabled by default.

## Commands

- `/htf` — Open the standalone HTF settings window
- `/htf stats` — Open HUD settings
- `/htf merchant` — Open merchant settings
- `/htf nameplates` — Open friendly-name settings
- `/htf protect <item link or ID>` — Protect a grey item from auto-selling
- `/htf unprotect <item link or ID>` — Remove protection
- `/htf protected` — List protected items
- `/htf debug` — Toggle debug mode
- `/htf dump` — Generate a diagnostic report

## AI Disclosure

This addon was developed with assistance from AI tools. Please report any issue you encounter so the addon can continue to improve.

## Feedback

Bug reports, feature requests, and better ideas are always welcome. If you have a suggestion for Happy Tree Friends, please share it!
