# Happy Tree Friends

[English](README.md) | [简体中文](README.zh-CN.md)

Happy Tree Friends is a lightweight quality-of-life addon for **World of Warcraft Retail 12.1**. It brings secure raid-debuff enhancements, merchant automation, a customizable character HUD, and friendly-player name controls together in one clean settings window.

## Features

- **Automatic repair** — Repair with personal gold or guild funds.
- **Automatic junk selling** — Sell grey-quality items when visiting a merchant.
- **Protected junk items** — Keep selected grey items by item link or ID.
- **Session ledger** — Review repair spending, junk-sale income, and protected items skipped during the current session.
- **Adventure HUD** — Display character stats, durability, free bag slots, money, and latency in a movable, resizable, lockable transparent overlay.
- **Flexible HUD styling** — Show or hide each value and customize its font size and color.
- **Friendly names** — Show friendly players as names only, with an optional custom font size.
- **Raid debuff enhancement** — Add up to two bleeds, crowd-control effects, raid-important debuffs, and short otherwise-unclassified effects per category to Blizzard party and raid frames while keeping Blizzard's own dispellable-only setting unchanged.
- **Compact aura controls** — Choose which debuff categories appear, select one of four frame corners, and fine-tune icon offsets.
- **Standalone settings** — Open a clean, movable HTF settings window directly with `/htf`.
- **Diagnostics** — English and Simplified Chinese localization, optional debug logging, and a copyable diagnostic report.

## Commands

- `/htf` — Open settings.
- `/htf stats` — Open HUD settings.
- `/htf merchant` — Open merchant settings.
- `/htf nameplates` — Open friendly-name settings.
- `/htf debuffs` — Open raid-debuff enhancement settings.
- `/htf protect <item link or ID>` — Protect a grey item from automatic selling.
- `/htf unprotect <item link or ID>` — Remove an item from the protection list.
- `/htf protected` — List protected items.
- `/htf debug` — Toggle debug mode.
- `/htf dump` — Generate a copyable diagnostic report.
- `/htf clearlog` — Clear saved debug logs.

## Compatibility

- World of Warcraft Retail 12.1
- Interface version 120100
- English and Simplified Chinese

## Raid Debuff Limitation

WoW 12.1 does not reliably permit spell-ID filtering for harmful auras on friendly units. The addon therefore uses Blizzard's secure bleed, crowd-control, and raid-in-combat categories, plus a disjoint fallback for otherwise-unclassified debuffs lasting up to 60 seconds that the active character's dispellable-only filter omits. This fallback covers Ula'tek's Hobbled (spell 1300938), but can also include short effects that are not movement slows.

## Development Note

This addon was developed with assistance from AI tools. Bug reports, feature requests, and suggestions are welcome.
