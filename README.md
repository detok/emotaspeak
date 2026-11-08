# EmotaSpeak

A context-sensitive character immersion addon for **World of Warcraft: Forever**.

**Status: experimental v0.1.1.** A user has confirmed that a manually initiated wave and an automatic post-combat TRAIN emote play in Forever. Other event handlers still need live testing. Native calls may return `false` even when the animation visibly plays; that return value is logged as diagnostics rather than definitive failure.

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
- `/emota lowhealth` — inspect the native red health-warning frame's state (shown/hidden/secret/ambiguous)
- `/emota lowhealth on` — **optionally** test a `HEALME` reaction when the public native low-health border transitions from hidden to shown; also requires `/emota auto on`
- `/emota lowhealth off` — disable the experimental warning reaction (default)

## Implemented reactions (not all tested in game)

- `UI_ERROR_MESSAGE` / localized `ERR_OUT_OF_MANA`: a failed cast due to insufficient mana attempts `OOM`. This is not a mana percentage check.
- `ERR_OUT_OF_FOCUS` and `ERR_OUT_OF_ENERGY`: rare `SIGH` after a resource-related failed cast.
- `UNIT_DIED`: player pet or mapped party/raid member death, subject to GUID secrecy.
- `UNIT_COMBAT`: the player's dodge, block and parry events.
- `UNIT_SPELLCAST_INTERRUPTED`: interrupted player cast.
- `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`: combat start/end (not kill count).
- `PLAYER_LEVEL_UP`: `CHEER` on leveling.
- `UI_INFO_MESSAGE` / `ERR_TRADE_COMPLETE`: likely `BOW` after an actually successful trade, not just a closed trade window.
- `CHAT_MSG_TEXT_EMOTE`: English-only targeted "/wave" reply with a five-minute anti-loop lock; requires target name and the phrase "waves at you".
- `QUEST_TURNED_IN`: rare `CHEER`.
- `PLAYER_UNGHOST`: occasional `SIGH`.
- `UNIT_HEALTH`: low-health percentage **only when it is readable outside combat**.

## Native red-screen experiment (v0.1.1)

Blizzard includes a built-in `LowHealthFrame` visual, and ZSBT publicly documents using its visibility for a warning sound. Hearth UI's description documents a different, visual-only approach using a secret-safe curve. Our implementation was independently written and does not copy either addon.

The frame can also show for certain **fullscreen** edge flashes. EmotaSpeak excludes fullscreen-panel cases when possible, refuses secret states, and treats unverifiable/fullscreen signals as **ambiguous**, never a reason to emote. It does not call Blizzard's health evaluator or read/compare secret health numbers. It samples once after Blizzard's `UNIT_HEALTH` or combat-state events. `/emota lowhealth` is a local diagnostic; no automatic low-health emote is attempted unless you explicitly enable both `/emota auto on` and `/emota lowhealth on`.

**Important:** Retail source and other addon behavior cannot establish whether `LowHealthFrame:IsShown()` returns a public boolean in the live Forever client. Test by typing `/emota lowhealth` at normal HP and again after the screen flashes red, optionally with `/emota debug on`. A `secret`, `missing`, or `ambiguous` result means the automatic path isn't validated.

## Critical limits

Forever inherits the Midnight addon restrictions. Health and primary resource values may be secret during combat; do not perform arithmetic/comparisons on secret values. There is no supported workaround for an exact in-combat low-HP trigger. The old combat-log event is unavailable. `C_ChatInfo.PerformEmote` may fail depending on the combat/action restriction state and execution context. The addon never uses custom /e text or sends /say, whispers or party chat.

See [FEASIBILITY.md](FEASIBILITY.md) for documented API decisions and validation steps. No use of protected actions or restriction bypasses.

## Development

v0.1.1 = native LowHealthFrame diagnostic, optionally activated HEALME on confirmed non-secret visual transitions; no health math or restricted-state workaround.

v0.1.0 = observed working manual wave and automatic post-fight train from v0.0.1, expanded event recognition, optional social responses, rare quest/rez reactions, corrected diagnostics. Still experimental. Keep `/emota debug on` for testing; with `/emota auto on`, emotes are rate-limited to at most one native attempt every 45 seconds, with at least two minutes between the same reason. Targeted wave replies additionally require five minutes between replies. These are intentional anti-spam defaults.

**How to test:** after updating, `/reload`; use `/emota status` to check whether auto is enabled. Attempt a spell you cannot afford, complete a trade, and have a friend wave directly at your character. Check both the in-game action and debug text. No chat replies are generated and no combat percentage measurements are attempted.
