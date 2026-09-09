# Mii Mesh · Flutter and direct Bluetooth

The current source extends this foundation with automatic Android peer discovery, encrypted relay/store-and-forward, three-tab navigation, built-in stickers and reactions. See [mesh upgrade and validation status](docs/MESH_UPGRADE.md) for the implemented scope, tests and remaining features. The original laptop connection is now under Settings → Laptop companion.

An original, Android-first messaging app. **Experimental and unaudited.** The original direct laptop–phone Bluetooth connection was tested on hardware. The new mesh implementation has separate automated and hardware validation requirements documented above. Internet delivery, calls, groups, media and SOS remain unfinished. See [earlier direct Bluetooth test results](docs/BLUETOOTH.md).

## What works

- Material 3 interface, responsive phone/tablet layouts, three navigation sections, light/dark/system appearance.
- Deliberate onboarding, locally generated Ed25519 identity, readable fingerprint, protected key storage.
- Whole-file encrypted Drift/SQLite database with mandatory cipher checks and a tested schema 1 → 2 upgrade.
- Saved notes, local conversation search, persistent drafts and message deletion.
- Explicitly enabled local test chat with XChaCha20-Poly1305 authenticated envelopes and acknowledgements.
- Persistent outbox, pause/resume, bounded retry, manual retry/cancel, deduplication and 24-hour test-message expiry.
- Diagnostics, dependency license screen and clear descriptions of later-phase capabilities.

No sample contacts are seeded. The optional laboratory is clearly a simulator on the same device. Simulator delivery is never described as real remote delivery. Nearby devices access is requested when you start Bluetooth.

## Run

Flutter **3.47.0 stable**, Dart **3.13.0**, Android compile SDK **37**, Android NDK **28.2.13676358**, JDK **21** were used here. All direct packages are pinned and the lockfile is included with the project files.

```sh
flutter pub get
dart run build_runner build
flutter run -d <android-device-id>
```

To build the experimental ARM64 Android APK:

```sh
flutter build apk --debug --target-platform android-arm64
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`. This is a debug-signed development APK, not a store release. A Samsung SM-M558B was used for an actual Bluetooth round-trip test. iOS and Windows hosts are scaffolded; iOS needs macOS/Xcode and platform validation, while Windows desktop needs a complete C++ workload/Windows SDK.

On Windows, the Android crypto build needs Git Bash and GNU Make on the process PATH. See `tools/build_android.ps1` for the workspace helper. `tools/test_windows.ps1` supplies a verified official native libsodium 1.0.22 binary for host tests when Windows SDK headers are missing; no runtime crypto behavior is mocked. It restores the normal dependency graph afterwards. On a fully configured host use `flutter test` normally.

## Architecture and file map

```text
lib/app/                         theme, routing, Riverpod bootstrap, responsive shell
lib/core/crypto/vault.dart        identity seed, fingerprint and platform secrets
lib/core/database/               typed Drift tables, mandatory file encryption
lib/core/protocol/               Freezed envelope, delivery model, bounded CBOR codec
lib/features/onboarding/         consent and local identity setup
lib/features/chats/             persistence/queue service and chat interface
lib/features/settings/          appearance, identity, laboratory and diagnostics
lib/transports/                  transport boundary and explicit in-process simulator
android/app/src/main/            Android host, original vector icon, backup exclusions
assets/fonts/                    bundled Roboto and license; no runtime font downloads
test/                            native crypto, persistence, queue integration, UI/goldens
docs/                            protocol, schema, threat model, tests and licenses
```

Widgets invoke the application service; cryptography, persistence and transport live outside widgets. Riverpod owns the application service; GoRouter controls navigation. The app uses no cloud backend, analytics, registration or copied BitChat source/assets. Full implementation and file-impact plan: [IMPLEMENTATION_PLAN](docs/IMPLEMENTATION_PLAN.md).

## Documentation

- [Database schema and migration policy](docs/DATABASE.md), [schema v1 snapshot](docs/schema/drift_schema_v1.json)
- [Laboratory protocol and required real-network design work](docs/PROTOCOL.md)
- [Threat model, limitations, reporting and release gates](docs/SECURITY.md)
- [Automated checks and manual/multi-device plan](docs/TESTING.md)
- [Pinned dependencies and license review](docs/DEPENDENCIES.md)

## Important limits

The identity has no recovery/export feature yet. Losing keys or clearing app data loses access. There is no app lock, contact verification, authenticated remote handshake or forward secrecy. The laboratory uses a local key and is not a private peer-to-peer session. No BLE scan, relay, background service, internet transport, media transfer or emergency call is active. Expiry maintenance resumes when the app runs. Physical deletion on flash cannot be guaranteed. Android OS backup is disabled; iOS backup and Keychain integration remain a release gate.

A full independent security audit, release-time vulnerability/transitive license review, real device process-death/Keystore testing, and later two/three-phone BLE tests are required before claiming production readiness. The direct BLE extension is documented in [BLUETOOTH.md](docs/BLUETOOTH.md).

## Validation results

See [Phase 1 results](docs/RESULTS.md): 15 Flutter tests and three Python companion tests pass, including crypto, encrypted persistence, queue integration and reviewed UI goldens. The Android ARM64 debug APK builds. Hardware and release security gates remain open.


## Android permission update

The manifest now declares permissions for the planned device features. See [permission scope and runtime requirements](docs/PERMISSIONS.md). The direct BLE feature requests Nearby devices access at runtime; other planned permissions do not implement their associated features.

