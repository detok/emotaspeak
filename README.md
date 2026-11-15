# EmotaSpeak

**Your character, a little more alive.**

EmotaSpeak is a standalone personality addon for **World of Warcraft: Forever**. It reacts to everyday adventuring through native character emotes and varied, occasional idle behavior. It requires no other addons.

## Version 0.4.0 — testing candidate

This update brings standalone EmotaSpeak's feature set in line with ChalkBox's Emota module while preserving existing per-character settings and familiar commands. Automatic reactions default **off**, and some client event responses still need live verification.

### What it does

- **Natural reactions:** optional directed wave-backs, trade bows, pet/party mourning when readable, level-up cheers, interrupted-cast reactions and occasional post-combat celebrations.
- **Idle personality:** randomized weighted choices such as voiced jokes, dancing, yawning, pondering and other native emotes, with expanding, variable pacing.
- **Race and class flavor:** supported racial profiles, profession-agnostic class weighting, resting area influence and Hunter-pet context.
- **Race Behavior page:** inspect race profiles and set Off, Subtle, Default or Expressive. Profiles with no unique behavior are labeled planned.
- **Emote Catalog page:** toggle individual supported reactions and try emotes manually without waiting for idle.
- **Frequency slider:** tune how often eligible idle events occur, with configurable variety and context.
- **Activity safeguards:** automatic emotes avoid combat and do not fire while moving, dead, AFK, mounted, on a taxi, casting or using supported interaction frames. Pose-changing emotes (sit/sleep/lay down) are **manual previews only**.

### Settings

Use **Options → AddOns → EmotaSpeak** and its Race Behavior and Emote Catalog subpages, click the AddOn Compartment shortcut, or enter `/emota`.

All preferences are stored per character in `EmotaSpeakDB` and do not read or overwrite ChalkBox settings.

| Command | Purpose |
|---|---|
| `/emota` | Open settings |
| `/emota auto on` / `off` | Toggle all automatic reactions |
| `/emota idle on` / `off` | Toggle idle behavior |
| `/emota idle test` / `preview` | Preview a joke / random enabled idle emote |
| `/emota idle reset` | Restart this session's idle pacing |
| `/emota variety on` / `off` | Enable extra catalog emotes for idle |
| `/emota context on` / `off` | Toggle race/class/rest/pet context |
| `/emota debug on` / `off` | Toggle local diagnostics |
| `/emota test` / `status` | Wave test / show settings |
| `/emota health` / `lowhealth` | Existing experimental diagnostics |
| `/emota help` | List commands |

The experimental low-health border reaction is disabled by default. Forever protects some health and resource data in combat; this is not a reliable in-combat warning feature.

### Installation and packaging

Extract `EmotaSpeak/` directly into your client's `Interface/AddOns` folder. The packaged addon includes both TOC files, `EmotaSpeak_Personality.lua`, `EmotaSpeak.lua`, `EmotaSpeak_Settings.lua` and the original `assets/Icon.tga`. Restart the game when changing manifest or icon files.

To build the CurseForge archive, run `python scripts/package.py`. This creates `publish/EmotaSpeak-0.4.0.zip` with the correct top-level folder. GitHub Actions also builds a ready-to-test ZIP on pull requests.

### Coexistence with ChalkBox

Both addons can be installed. ChalkBox detects standalone EmotaSpeak and yields emote dispatch to it, avoiding two copies reacting at once. ChalkBox's other modules continue to work. EmotaSpeak itself does not depend on ChalkBox.

This addon never casts spells, moves your character, generates custom chat text or transmits personal information. Reactions are attempted through client-native emotes and may vary depending on client restrictions.

**Made by Detok Whitemaine.** Please report issues with your client build and steps to reproduce.
