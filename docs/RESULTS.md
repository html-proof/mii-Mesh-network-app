# Phase 1 validation results

Checked 2026-09-08 on Windows with Flutter 3.47.0 / Dart 3.13.0.

- 13 automated tests passed, including the final run without regenerating goldens.
- Real Ed25519 RFC 8032 known-answer test passed.
- AEAD tampering/header substitution and invalid acknowledgement rejection passed.
- Encrypted database creation/reopening, wrong-key rejection, persistent identity/drafts/outbox, resume, expiry and deduplication passed.
- Queue integration: persistence-before-send, five-attempt failure limit, retry, cancel and input rollback passed.
- 1500 randomized malformed packet inputs plus targeted parser cases passed.
- Phone/tablet/large-text layout checks passed; onboarding, tablet conversations and phone dark-mode goldens were visually reviewed.
- Android ARM64 debug APK compiled. No Android device was connected; installation, platform Keystore and actual force-stop testing remain manual checks.
- iOS build and backup/Keychain validation were not run (requires macOS).
- Host tests used the official signature-verified libsodium 1.0.22 binary because Windows SDK headers are missing. Android uses the normal source build. Temporary dependency overrides were removed after tests.
- Independent security audit and complete transitive/native vulnerability/license review remain release gates.

The supplied brief requires stopping after Phase 1 and reporting before beginning BLE. Real peer messaging, multi-hop relay, secure groups, media, internet relay and emergency broadcasts remain unimplemented later phases.

Final static analysis: no issues found. Formatter: 20 files checked, no changes needed.


Subsequent physical-phone validation: Samsung SM-M558B / Android 16 passed installation, launch, saved-note recovery and draft recovery after force-stop. See DEVICE_TEST.md. Earlier no-device statements describe the original build session.

