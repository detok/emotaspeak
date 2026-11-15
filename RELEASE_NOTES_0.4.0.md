# EmotaSpeak 0.4.0 — Standalone personality update

- Updated standalone EmotaSpeak to the behavior and settings available in ChalkBox Emota.
- Added a weighted idle-emote pool, optional extra variety, race/class/rest flavor, supported per-race intensity and Hunter pet context.
- Introduced Race Behavior and Emote Catalog settings pages, a frequency slider and manual preview controls.
- Preserved per-character EmotaSpeakDB, the /emota commands and experimental health diagnostics (still disabled by default).
- Preserved the automatic-emotes-off default. No automatic native emotes during combat, and no automatic pose-changing emotes.
- No dependency on ChalkBox. When both are loaded, ChalkBox's existing standalone-precedence guard prevents duplicate dispatch.
- Updated both manifests, package script, CI syntax and archive verification checks.

Live Forever-client testing is still required before marking this release stable.
