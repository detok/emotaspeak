# EmotaSpeak — CurseForge listing copy

## Project name
EmotaSpeak

## Short summary
Give your WoW Forever character a personality with natural reactions, racial flavor and customizable idle emotes.

## Public description

**A little personality for every adventure.**

EmotaSpeak makes your character feel a bit more alive in **World of Warcraft: Forever**. It uses the game's own emotes and voiced jokes to respond to everyday moments—without custom chat bots, spam or gameplay automation.

A wave directed at you might earn a wave in return. Your pet or party companion might be mourned. A difficult fight may end with a celebration. When you stand still long enough, your character can use a random, thoughtfully paced idle emote.

### Features

- **Social and adventure reactions:** targeted wave-backs, trade bows, companion reactions, level-up cheers and occasional post-combat emotes.
- **Idle personality:** native jokes, dance, yawn, ponder and more, chosen from a weighted pool.
- **Race and class flavor:** the selected character's race and class, resting state and Hunter pet can influence idle choices.
- **Race Behavior:** Off, Subtle, Default and Expressive weighting for supported races; planned profiles are labeled clearly.
- **Emote Catalog:** individual switches and instant manual previews; pose-changing emotes are manual-only.
- **Frequency control:** tune idle pacing, extra variety, contextual behavior and optional diagnostics.
- **Safe and quiet:** opt-in automation, cooldowns, no automatic emotes in combat, and checks for activity and relevant open windows.
- **Standalone:** no dependencies. Works alongside ChalkBox without doubling up on automatic reactions.

### How to use

Enter `/emota`, use **Options → AddOns → EmotaSpeak**, or click its AddOn Compartment shortcut. Auto reactions are **off by default**; enable them when you want your character to react. Use the settings **Test Joke**, **Surprise Me** and catalog **Try** buttons to preview emotes while out of combat.

For WoW Forever interface **16001**. Specific reactions depend on client events and emote restrictions. Low-health experiments are not guaranteed combat alerts.

**Created by Detok Whitemaine.**

---

## Publishing checklist — not for public description

- [ ] Validate GitHub Actions Lua syntax and ZIP packaging.
- [ ] Test toggles, slider, race settings, catalog pagination, preview buttons and /emota commands in-game.
- [ ] Check combat suppression and coexistence with ChalkBox.
- [ ] Upload the generated `publish/EmotaSpeak-0.4.0.zip` (not a source ZIP).
- [ ] Upload a **512×512 PNG** image (EmotaSpeak-CurseForge-Icon.png) as the CurseForge project icon.
- [ ] Use the existing `assets/Icon.tga` for the game's AddOns icon.
- [ ] Confirm supported game version in CurseForge and pick an appropriate license and Alpha/Beta channel until tested.

Suggested category: Roleplay / Miscellaneous. Source: https://github.com/detok/emotaspeak
