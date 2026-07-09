# Changelog

## 1.0 (build 6) — unreleased

Pre-release hardening pass (QA audit 2026-07-09):

- Mac sync now works on device: local-network permission keys were missing,
  and an unreachable Mac hung pushes forever instead of timing out.
- A phone call mid-recording no longer silently ends capture; recording
  resumes after the interruption and the UI says so.
- Microphone-permission denial is handled instead of crashing.
- A corrupt session library is quarantined instead of being silently
  overwritten; save failures are surfaced.
- The Mac-sync pairing token and vocabulary auth headers moved to the
  Keychain; library files get stronger data protection.
- Long recordings no longer hold the whole session in memory.
- Re-transcribe works; duplicate model downloads prevented; CLI --vocab is
  honored; vocabulary sync is https-only; sync listener caps frame sizes.
- Widget extension version now matches the app (App Store upload fix).
- README/App Store copy now disclose the opt-in sync features; added
  privacy policy, sync guide, SECURITY.md.

## 1.0 (builds 1–5)

Initial development: on-device diarized transcription, speaker enrollment,
summaries, live captions, vocabulary, Siri/App Intents, widgets, MCP
server, Bonjour/LAN Mac sync.
