# Changelog

## 0.3.0 — Professional preview (2026-11-07)
- Added original branded in-game icon for the AddOns list and Addon Compartment.
- Added native WoW Settings panel with master reactions, idle jokes, and diagnostic toggles.
- Added a one-click *Test a voiced joke* button, while preserving `/emota` commands.
- Redesigned idle-joke scheduling: 60 seconds first, then expanding randomized delays up to 5–10 minutes per session.
- Idle session pacing survives walking around and combat, but resets on login or `/reload`.
- Added `/emota idle reset` for testing.
- Added release packaging, documentation, and prepared CurseForge listing.

## 0.2.0 — Ambient personality
- Added occasional voiced racial `JOKE` reactions after a stationary interval.
- Added movement and activity guards to prevent interruptions.
- Quieted misleading `false` API return diagnostics.

## 0.1.1 — Native low-health experiment
- Added read-only `LowHealthFrame` diagnostics, with low-health automation off by default.

## 0.1.0 — Expanded reactions
- Added OOM and other resource error reactions.
- Added social wave-backs, trade bows, quest celebrations, and resurrection reactions.
- Added cooldowns, consent-based automation, and diagnostics.

## 0.0.1 — Initial proof of concept
- Introduced native emote dispatcher and readable game-event probes.
