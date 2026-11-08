# EmotaSpeak

A context-sensitive character immersion addon for **World of Warcraft: Forever**.

**Status: API proof-of-concept, not a finished automatic emote addon.** The first build records live game signals and lets you optionally test whether Forever permits native emotes from those signals. The game can reject event-driven emotes even when the event itself is readable.

## Install

Copy this repository into `World of Warcraft/_forever_/Interface/AddOns/EmotaSpeak/`. The directory must contain `EmotaSpeak_Camelot.toc` and `EmotaSpeak.lua`. Enable it from the in-game AddOns menu and reload.

## In-game commands

- `/emota status` — current diagnostics and auto mode
- `/emota debug on` — print detected event signals locally (does not send chat)
- `/emota debug off` — silence local diagnostics
- `/emota auto on` — **opt in** to trying native emotes from detected events
- `/emota auto off` — disable automatic attempts (default)
- `/emota test` — manually request a `WAVE` emote to prove the API exists
- `/emota health` — report whether health and mana values are accessible or secret

## Currently observed / probed signals

- `UI_ERROR_MESSAGE` / localized `ERR_OUT_OF_MANA`: attempted cast without enough mana, **not** arbitrary mana percentage.
- `UNIT_DIED`: player pet or mapped party/raid member death, subject to GUID secrecy.
- `UNIT_COMBAT`: the player's dodge, block and parry events.
- `UNIT_SPELLCAST_INTERRUPTED`: interrupted player cast.
- `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`: combat start/end (not kill count).
- `PLAYER_LEVEL_UP`: level celebration.
- `UNIT_HEALTH`: low-health percentage **only when it is readable outside combat**.

## Critical limits

Forever inherits the Midnight addon restrictions. Health and primary resource values may be secret during combat; do not perform arithmetic/comparisons on secret values. There is no supported workaround for an exact in-combat low-HP trigger. The old combat-log event is unavailable. `C_ChatInfo.PerformEmote` may fail depending on the combat/action restriction state and execution context. The addon never uses custom /e text or sends /say, whispers or party chat.

See [FEASIBILITY.md](FEASIBILITY.md) for documented API decisions and validation steps. No use of protected actions or restriction bypasses.

## Development

v0.0.1 = instrument first, verify on the actual Forever client, then expand social reactions. This code has not yet been tested in the game.
