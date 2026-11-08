# EmotaSpeak

**Your character, a little more alive.**  
An event-driven character immersion addon for **World of Warcraft: Forever**.

EmotaSpeak gives your character subtle, occasional reactions to the things that happen in Azeroth: a pet dying, a companion falling, a successful trade, an interrupted cast, or simply standing around long enough to tell a voiced joke. It uses Blizzard's built-in emotes—**no AI chat, no spammy dialogue generator, no gameplay automation**.

> **Version 0.3.0 — experimental Forever release.** A manual wave and automatic TRAIN reaction have been observed working on the Forever client. The new settings panel, variable idle scheduling, and other event combinations still need in-game validation before a public CurseForge release.

## At a glance

| | |
|---|---|
| Game | World of Warcraft: Forever 1.60.1 |
| Interface number | `16001` |
| Dependencies | None |
| Author | Detok Whitemaine |
| Controls | Game Settings → AddOns → EmotaSpeak, the Addon Compartment beside the minimap, or `/emota` |
| Saves | Per-character settings; session joke pacing resets on login/reload |
| Privacy | No outgoing custom chat text, network requests, collection, or telemetry |

## What it does

- **Social manners:** can return a targeted wave and bow after a successful trade.
- **Companionship:** can mourn your pet or a party/raid member when a readable death event identifies them.
- **Adventuring:** occasional post-combat `TRAIN`, level-up cheers, quest-completion celebrations, and interrupted-cast sighs.
- **Resource frustration:** reacts to a *cast that fails for insufficient mana* with `OOM`; no need to read protected in-combat mana values.
- **Ambient personality:** a voiced racial `JOKE` (the familiar `/silly`) after your character has stood still for a while.
- **Quiet by design:** per-reaction cooldowns, a global cooldown, and activity checks prevent constant chatter.

### Idle jokes: a growing interval, not a repeating spam timer

Idle jokes use your character's own voiced lines; Blizzard picks which joke is heard. Jokes are scheduled after **continuous standing still**, and each one pushes the next scheduled interval farther into the session.

| Joke in this session | Stationary time before next joke |
|---|---|
| First | 60 seconds |
| Second | Randomly 60–180 seconds |
| Third | Randomly 90–240 seconds |
| Fourth | Randomly 150–360 seconds |
| Fifth | Randomly 240–480 seconds |
| Sixth and later | Randomly 300–600 seconds |

Moving, mounting, entering combat, and certain interactions postpone idle jokes; the session's count **does not restart when you move**. Combat and other important reactions take priority. The master switch still controls all automation. The timing resets on login or `/reload` (not merely on movement).

### Settings in the game

Open the standard **Game Menu → Options → AddOns → EmotaSpeak** panel, click EmotaSpeak in the **Addon Compartment** next to the minimap, or type `/emota`.

The small settings screen provides:

- **Enable character reactions:** master toggle.
- **Occasional voiced jokes:** enable/disable ambient jokes independently.
- **Diagnostic messages:** show the technical events only when troubleshooting.
- **Test a voiced joke:** a user-initiated, audible demo.

Settings are saved per character. The menu and existing slash commands update the same saved settings.

## Installation

1. Copy or extract the addon to `World of Warcraft/_forever_/Interface/AddOns/EmotaSpeak/`.
2. Ensure the folder contains both `EmotaSpeak.lua` and `EmotaSpeak_Settings.lua`, the `EmotaSpeak_Camelot.toc` manifest, and `assets/Icon.tga`.
3. **Fully restart WoW** after adding or changing the manifest or texture. For Lua-only changes, `/reload` is usually sufficient.
4. Enable **EmotaSpeak** in the character-select AddOns list.

A release ZIP may be built with `python scripts/package.py`. It produces `publish/EmotaSpeak-0.3.0.zip` with the correctly named `EmotaSpeak/` folder. Do not install GitHub's source ZIP without renaming its directory.

## Slash commands

| Command | Purpose |
|---|---|
| `/emota` or `/emota settings` | Open the settings panel |
| `/emota auto on` / `off` | Enable or disable all automatic reactions |
| `/emota idle on` / `off` | Enable or disable ambient voiced jokes |
| `/emota idle` | See current idle interval and session joke count |
| `/emota idle reset` | Reset the progressively growing session interval (for testing) |
| `/emota idle test` | Manually play a voiced `JOKE` emote |
| `/emota debug on` / `off` | Toggle local diagnostics |
| `/emota status` | See active settings |
| `/emota test` | Manually wave |
| `/emota health` | Show whether health/power values are readable |
| `/emota lowhealth` | Inspect Blizzard's red low-health border (experimental, diagnostic only by default) |
| `/emota lowhealth on` / `off` | Explicitly opt in/out of unverified native low-health reaction |

New installs default to automatic reactions **off**. Once enabled, idle jokes default to on. Low-health automation remains **off** by default.

## Compatibility and limitations

WoW Forever protects health and resource data in combat. EmotaSpeak does **not** calculate secret health percentages, reconstruct hidden combat data, cast spells, move your character, or generate chat messages.

The experimental `LowHealthFrame` probe only inspects the native red edge when a non-secret, unambiguous frame state can be read. This remains an **unverified experiment**, not a supported low-HP warning feature. Some emotes may return `false` even when the animation plays; EmotaSpeak no longer prints that misleading value as a gameplay failure.

The addon detects some reactions based on localized UI messages, and targeted wave matching currently assumes English client text. Group member death detection depends on readable GUIDs. The long-fight celebration is based on **time in combat**, not an exact enemy kill count.

Please report issues with the game build, reproduction steps, and any messages from `/emota debug on`. See [FEASIBILITY.md](FEASIBILITY.md) for API test notes and known restrictions.

## Publishing / branding

- `assets/Icon.tga`: original, custom in-game icon shown in the AddOns list and Addon Compartment.
- `scripts/package.py`: reproducible CurseForge ZIP packager using Python's standard library only.
- `CURSEFORGE.md`: prepared listing copy, category guidance, and first release checklist.
- `CHANGELOG.md`: release notes.

This project is independent and not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft is a trademark of Blizzard Entertainment.
