#!/usr/bin/env python3
"""Static release guards; runtime behavior must still be tested in WoW Forever."""
from pathlib import Path

root = Path(__file__).resolve().parent.parent
core = (root / "EmotaSpeak.lua").read_text(encoding="utf-8")
ui = (root / "EmotaSpeak_Settings.lua").read_text(encoding="utf-8")
personality = (root / "EmotaSpeak_Personality.lua").read_text(encoding="utf-8")
manifests = [(root / n).read_text(encoding="utf-8") for n in
             ("EmotaSpeak.toc", "EmotaSpeak_Camelot.toc")]
assert "Copyright (c) 2026 Detok" in (root / "LICENSE").read_text(encoding="utf-8")
assert all("## Version: 0.4.0" in m for m in manifests)
assert all(m.index("EmotaSpeak_Personality.lua") < m.index("EmotaSpeak.lua") <
           m.index("EmotaSpeak_Settings.lua") for m in manifests)
assert all("ChalkBox_" not in x and "ChalkBoxDB" not in x
           for x in (core, ui, personality))
assert all("## SavedVariablesPerCharacter: EmotaSpeakDB" in m for m in manifests)
assert 'SLASH_EMOTASPEAK1="/emota"' in core
assert "function EmotaSpeak_OpenSettings" in ui
assert all(token in ui for token in
           ("MakeEmota", "MakeCatalog", "MakeRacePreferences",
            "RegisterCanvasLayoutSubcategory"))
assert all(token in core for token in
           ("EmotaSpeak_EmotaCatalog", "EmotaSpeak_EmotaSetJokeFrequency",
            "EmotaSpeak_EmotaGetEnabled", "ReadLowHealthFrame", "ReportHealth",
            'HEALME=true', "InCombatLockdown"))
assert "StandaloneEnabled" not in core
assert 'if not manual and (poseTokens[token] or token=="STAND")' in core
assert "function EmotaSpeak_PersonalityContext" in personality
assert "EmotaSpeakDB.raceModes" in personality or "local settings=EmotaSpeakDB" in personality
print("EmotaSpeak standalone release checks passed")
