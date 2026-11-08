# WoW Forever API feasibility — EmotaSpeak

Research date: 2026-11-07. Target client: Forever 1.60.1, interface `16001`. Status: experimental v0.1.0.

## Critical distinction

**Receiving an event is not the same as being allowed to perform an emote in response.** `C_ChatInfo.PerformEmote("WAVE")` exists in Forever but is marked `HasRestrictions`. Automatic native emotes can return false or trigger `ADDON_ACTION_BLOCKED` in certain contexts. Custom `/e` messages outdoors require a real hardware action. Do not attempt to bypass either restriction.

`/emota debug on` logs event detections without emitting any chat. `/emota auto on` (off by default) permits rate-limited native-emote attempts for validation. `/emota test` tests a player-initiated native emote. **In-game report:** user confirmed manual WAVE visually plays despite API return `false`, and an automatic TRAIN after a long fight visually plays. This establishes at least one working automatic native-emote path in their client, not that every event or target will work. The new logger prints `API returned false (check animation)` when debug is enabled. Test remaining event-driven calls and watch for blocked-action notifications.

## Hooks and results

| Wanted behavior | Source | What is available | Decision |
|---|---|---|---|
| Out of mana | `UI_ERROR_MESSAGE`, localized `ERR_OUT_OF_MANA` | Identifies a *failed cast because mana is insufficient*, not being at an exact mana percentage | Implemented; `OOM` attempt; not yet confirmed in game |
| Low HP during combat | `UNIT_HEALTH`, `UnitHealth` / `UnitHealthPercent` | Value is secret in combat: Lua cannot compare/arithmetic on it | **Do not build in-combat percentage trigger** |
| Low HP after combat | `UNIT_HEALTH` + guarded `UnitHealth/UnitHealthMax` | Numeric comparison only when values are not secret | Supported fallback, out of combat only |
| Pet dying | `UNIT_DIED` + pet GUID cached from `UnitGUID("pet")` | Death event exists; GUID can be restricted, so always guard | Attempt `CRY`; test in client |
| Friend dying | `UNIT_DIED` + cached party/raid GUIDs | Detects members of *your group*, not every WoW friend anywhere in the world | Attempt `MOURN`; test in client |
| Dodge, parry, block | `UNIT_COMBAT("player", eventType, ...)` | Event-type notifications can be received without interpreting secret health | Low-chance `LAUGH` / `FLEX` |
| Spell interrupted | `UNIT_SPELLCAST_INTERRUPTED` for `player` | Player spellcast event exists | Low-chance `SIGH` |
| Enter/leave combat | `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` | Reliable combat-lockdown transitions | Post-fight `TRAIN` after a long fight, **not** a verified multi-kill |
| Level up | `PLAYER_LEVEL_UP` | Direct progression event | `CHEER` |
| Insufficient focus or energy | `UI_ERROR_MESSAGE` + localized `ERR_OUT_OF_FOCUS` / `ERR_OUT_OF_ENERGY` | Resource-related failed spell, without inspecting protected power values | Rare `SIGH` attempt; untested |
| Turn in quest | `QUEST_TURNED_IN` | Direct quest completion event | Rare `CHEER`; untested |
| Return from ghost form | `PLAYER_UNGHOST` | Resurrection/ghost-return signal | Occasional `SIGH`; untested |
| Wave back | `CHAT_MSG_TEXT_EMOTE` | Requires English `waves at you` and the player's name in target field, ignores own emotes and has a five-minute reply lock | Implemented, pending live tests; not for other locales |
| Successful trade | `UI_INFO_MESSAGE` + localized `ERR_TRADE_COMPLETE` | True completed trade rather than merely closing a trade window | Implemented, `BOW` attempt; pending live test |
| Defeated 3+ mobs | Enemy death details / combat log | Enemy GUID can be secret; old combat log event is unavailable | **Not reliably possible as an exact count** |

## Restriction-safe principles

1. Use `issecretvalue(x)` before arithmetic, comparisons, indexing or string operations on guarded values. Never use `pcall` as a bypass; it only catches errors.
2. Never reconstruct protected in-combat health or power values using damage events.
3. Never use `COMBAT_LOG_EVENT_UNFILTERED` on Forever.
4. Never automate a spellcast, movement, target selection, /say or /yell.
5. Treat `false` from `PerformEmote` as *diagnostic only*; an animation was observed despite `false`. Never retry rapidly or loop trying to get around blocked calls.
6. Keep global/per-event cooldowns and opt-in diagnostics.
7. Always label combat end as combat end, not a verified victory.
8. Distinguish **event detected**, **native call accepted**, and **emote visibly played** when testing.

## Live validation matrix

Test with local diagnostics enabled, then with auto enabled:

- In town: `/emota test` — native manually initiated WAVE accepted?
- Get into a fight and cast with insufficient mana — did `UI_ERROR_MESSAGE` carry the localized message? Did the character actually play `OOM`? A `false` result alone is inconclusive.
- Have a friend wave directly at you in an English client — check the target field, and confirm the wave-back happens at most once per five minutes.
- Complete a trade and cancel another trade — bow only on real completion.
- Finish a quest or return from ghost form — confirm the corresponding rare events.
- Let a hunter pet die — was its cached GUID matched by `UNIT_DIED`?
- Have a party member die — was its GUID matched?
- Dodge/parry/block several attacks — does `UNIT_COMBAT` report those subtypes?
- Finish a fight longer than 20 seconds — does `PLAYER_REGEN_ENABLED` arrive, and was automatic `TRAIN` accepted?
- Try `/emota health` in and out of combat — does it say SECRET for combat HP/mana? Do not print or operate on secret numeric values.
- Check `ADDON_ACTION_BLOCKED` and `ADDON_ACTION_FORBIDDEN` errors.

Automatic TRAIN after a long fight has been observed working on a Forever client, but other triggers have not been validated. If any other automatic native emote is consistently blocked, preserve its event-detection idea with *optional local visual cues* or player-initiated keypresses, not a protected-action workaround.

## Sources

- https://warcraft.wiki.gg/wiki/API_C_ChatInfo.PerformEmote
- https://warcraft.wiki.gg/wiki/Event:UNIT_DIED
- https://warcraft.wiki.gg/wiki/Event:UNIT_COMBAT
- https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes/notes
- https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes
- https://www.curseforge.com/wow/addons/flourishforever/files/9485576
- https://github.com/Thunderz96/forever-addon-kit

This is a **probe**, not a claim that every Forever event/response pair has been tested live.
