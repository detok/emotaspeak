# EmotaSpeak — CurseForge publishing draft

## Project name
EmotaSpeak

## Short summary
Give your WoW character a personality with subtle reactions and occasional voiced jokes.

## Long description

**A little personality for every adventure.**

EmotaSpeak makes your character feel more alive in **World of Warcraft: Forever** by responding to everyday moments with Blizzard's existing character emotes and voiced lines.

Your hunter's pet dies? They might mourn. You finish a long fight? Your character may celebrate. Someone waves directly at you? Your character can wave back. When you're standing around for a while, your character can tell one of their own racial jokes—without you typing /silly.

**Features**
- **Natural reactions:** wave-backs, trade bows, pet/party death reactions, level-up cheers, interrupted-spell sighs, and other contextual moments.
- **Voiced idle jokes:** an early joke after roughly a minute of stillness, then increasingly spaced-out intervals of 1–3, 1½–4, 2½–6, 4–8 and eventually 5–10 minutes as your session continues.
- **Low noise:** cooldowns, combat and activity checks, and subtle probabilities.
- **Built-in settings:** toggle reactions, idle jokes, and diagnostics through the WoW AddOns settings panel or the Addon Compartment beside the minimap.
- **Slash commands:** every setting can still be managed with `/emota`.
- **Simple installation:** no dependencies, no external program, no AI-generated chat or account access.

**Controls**

Type `/emota` or use Options → AddOns → EmotaSpeak. Use `/emota idle test` to hear your character's racial joke.

**Compatibility**

Designed for **WoW Forever 1.60.1**. Requires no other addons.

**Important notes**

EmotaSpeak uses standard Blizzard emotes and does not cast spells, move your character, or automate gameplay. Individual event reactions depend on which signals the client exposes. This early release remains experimental: some combat reactions need live testing. It does not promise automatic healing requests at an exact low-health percentage, because Forever protects combat health data.

**Made by Detok Whitemaine.**

---

## Submission checklist (not part of public description)

- [ ] Test both clicking the Addon Compartment and opening Settings → AddOns → EmotaSpeak in the live Forever client.
- [ ] Verify the custom icon appears after a full WoW restart.
- [ ] Confirm a joke after ~60 stationary seconds, then a second joke within 60–180 seconds of further eligible idle time, with session count preserved after movement.
- [ ] Confirm `/emota auto off` disables reactions immediately, and the checkboxes match.
- [ ] Confirm `/emota idle off` disables ambient jokes without disabling pet, trade, or quest reactions.
- [ ] Inspect the package with `python scripts/package.py`—ZIP contains a top-level EmotaSpeak folder.
- [ ] Select **World of Warcraft: Forever**, interface 16001, on the file upload page.
- [ ] Add a 256px or larger PNG project image (use the companion EmotaSpeak CurseForge icon).
- [ ] Choose and add the project's license; no license has been selected on behalf of the author.
- [ ] Choose a release channel (Alpha until user testing confirms v0.3.0).
- [ ] Add `CHANGELOG.md` notes to the release description.

### Suggested metadata

- Category: Roleplay / Miscellaneous
- Authors: Detok Whitemaine
- Dependencies: None
- Supported flavor: World of Warcraft: Forever
- Suggested file: `publish/EmotaSpeak-0.3.0.zip` (generated, not tracked)
- Project page / source: https://github.com/detok/emotaspeak
- Issue reporting: GitHub Issues

### Suggested initial changelog

Initial feature-rich Forever preview with native Settings UI and Addon Compartment access, custom icon, session-paced voiced idle jokes, social reactions, and protected-data-safe diagnostic tools.

**Note:** This draft is publication preparation, not a claim of CurseForge approval.
