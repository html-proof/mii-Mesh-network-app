# Mii Mesh — Phase 1

Repository audit: empty workspace; no existing code, native modules, or user changes.
Toolchain: Flutter stable 3.47.0, Dart 3.13.0, Android SDK 36/37, Java 21.
Windows desktop tooling is incomplete; iOS compilation needs macOS.

## Scope and file impact
1. Scaffold Flutter Android/iOS hosts and a development desktop host.
2. `lib/core/crypto`, `features/identity`: libsodium Ed25519 identity and platform secure storage. Never fall back to plaintext storage.
3. `lib/core/database`: Drift schema v1 with full-file SQLite3MultipleCiphers encryption, fail-closed cipher verification, persistent messages/drafts/outbox/preferences.
4. `lib/core/protocol`, `transports`: immutable envelope, bounded deterministic CBOR codec, explicit in-process fake transport. No BLE or internet permissions in Phase 1.
5. `lib/features/chats`, `lib/app`: Riverpod services, GoRouter, original Material 3 responsive UI, onboarding, local notes, opt-in test conversation, retry/cancel, appearance and diagnostics.
6. `test`, `integration_test`, `docs`: real crypto known-answer checks, encrypted persistence/restart, malformed packets, widget and fake transport tests; protocol, threat model, manual plan and release gates.

## Security decisions
Unaudited experimental build. The fake transport is exclusively an explicitly labeled local laboratory, never proof of remote delivery. No real-world handshake or group encryption ships in this phase. SQLite encryption is mandatory even in release mode. Private keys live in platform secure storage; no automatic backup or analytics. Only local content is searchable. No location, Bluetooth, camera, microphone, contacts, or notification requests yet.

Stop after Phase 1 checks and report remaining gates. Do not implement later phases implicitly.
