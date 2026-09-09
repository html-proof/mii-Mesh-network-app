# Security notes and review gates

**Experimental, unaudited. Do not use for sensitive real-world communications or emergency response.** Libraries are used for cryptography; this application and its integration have not received an independent audit.

## Threat model
Protected assets: identity seed, database encryption key, local notes/drafts, pending test payloads. Adversaries considered: someone copying the closed database, malformed laboratory input, accidental cloud backup, app restarts, and local key loss. Trust assumptions: uncompromised OS, functioning platform key storage, genuine native libraries and app binary, and an unlocked authorized user.

Full database encryption uses SQLite3MultipleCiphers through Drift native hooks. A runtime check refuses the ordinary SQLite library in release as well as debug. The 32-byte random database key and Ed25519 seed are protected by flutter_secure_storage (Android Keystore-backed encrypted storage; iOS Keychain with a this-device accessibility class). There is no plaintext fallback, key logging, shared secret constant or automatic identity reset when existing profile keys are missing/mismatched. Application memory and OS secure storage bridges still contain temporary copies; Dart strings cannot be reliably zeroized. Sodium native key buffers are disposed and temporary mutable seed bytes are cleared.

Android backup and device transfer exclusions cover local files, preferences, databases and external app data. The manifest now declares planned Bluetooth, internet, Wi-Fi, notification, location, camera, microphone, media and foreground-service permissions at the user request; see PERMISSIONS.md. Nearby devices access is requested for the direct BLE feature; see BLUETOOTH.md for its separate shared-secret threat model. No contacts permission, analytics or crash-reporting SDK is added. iOS scaffold is not release-validated; review platform backup exclusion and Keychain behavior before distribution.

## What this does not protect
Rooted/jailbroken OS, malware with process access, screenshots, shoulder surfing, clipboard capture, malicious keyboards, memory extraction while unlocked, modified app builds or user exports. There is no app lock, panic wipe, screenshot protection or secure recovery/export yet. Filesystem deletion and SQLite secure_delete cannot guarantee physical erasure on flash storage or remove external copies. Fingerprints are informational; no contact is marked verified.

The simulator uses a local key, not a negotiated remote session. It does not establish sender authenticity, forward secrecy, anonymity, traffic-analysis resistance or real endpoint delivery. BLE tracking, relay amplification, session replay, group key lifecycle and backup exposure must be reassessed when those capabilities are introduced. Display names are neither unique nor trusted. Identity name validation rejects control/bidi formatting characters but does not implement comprehensive Unicode confusable detection.

## Resource limits
2048-byte text; 4096-byte envelope; flat 12-field parser; 10,000 local messages; 500 pending envelopes; 20 sends per pump; 5 retries; 1024 simulator dedup IDs. Test message lifetime 24 h. No compression, media loading or automatic URL opening. The direct BLE extension adds a foreground GATT listener with separate bounds documented in BLUETOOTH.md. Queue pauses when disconnected and does not request OS background exemptions. Physical database file compaction/quotas and process-death fault injection are still required for later reliability hardening.

## Release gates
- [ ] Independent cryptographic and application security audit; resolve all high/critical findings.
- [ ] Dependency vulnerability scan and transitive/native license review at release time.
- [ ] Android Keystore backup/restore and real process-death tests on hardware.
- [ ] iOS build, Keychain entitlement/accessibility, backup policy and platform tests on macOS.
- [ ] Accessible device navigation, screen-reader, large-font and contrast audit.
- [ ] Real two-phone encrypted BLE and ≥3-phone bounded mesh tests in later phases.
- [ ] Production signing identity, reviewed application ID, store disclosures and no debug permissions.
- [ ] Verified session key change warnings, abuse handling, group rotation and attachment safety before enabling those features.

Report security findings privately to the project owner. Do not paste real private keys, message content, database keys, or precise location into issues. No public security-reporting address is configured yet; the owner must provide one before release.

