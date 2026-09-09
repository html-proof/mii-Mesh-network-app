# Validation and manual plan

Automated checks:
```
flutter pub get
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

Tests use the real native libsodium library. RFC 8032 vector 1 checks Ed25519 key generation and signing. AEAD tampering and header substitution must fail; acknowledgements must bind to the original envelope. Parser tests reject nested/oversized input and 1500 randomized malformed packets. Persistence tests use a real encrypted disk database, inspect the file for plaintext/SQLite headers, reopen with correct and incorrect keys, restore drafts and outbox, resume a paused queue, enforce uniqueness and purge expired test messages. Schema initialization and version are checked. Widget tests cover onboarding consent, phone/tablet/large text layouts, and a visually reviewed golden.

Windows: sodium's build hook normally detects Visual Studio automatically. On this host Visual Studio is incomplete and Windows SDK headers are missing. `tools/test_windows.ps1` temporarily copies the pinned sodium package under ignored `.tools`, changes only the Windows build hook to load the official libsodium 1.0.22 native binary, runs the real crypto tests, removes the temporary override and restores normal dependency resolution. It does not change cryptographic code or skip encryption checks. The archive was verified with the upstream libsodium minisign public key and is pinned by SHA-256 in the helper. Android APKs build libsodium from source normally. Git for Windows supplies the required host GCC runtime.

Android cross-compilation on Windows needs Git Bash and GNU Make in the build process PATH. This host's temporary Make came from the official MSYS2 package repository and is excluded from source/distribution. No global PATH or installed library was changed.

## Phase 1 manual acceptance
1. Install the experimental APK on an Android phone; no sensitive permission prompt should appear.
2. Choose a name and deliberately acknowledge experimental status. Check an identity fingerprint appears in Settings.
3. Save notes, type an unsent draft, navigate away, then reopen. Check draft and notes remain.
4. In Settings explicitly enable local test chat. Send text; verify the UI says delivered to the local simulator.
5. Pause the simulator, send two messages and force-stop the app. Reopen; queue should remain. Resume; each message should appear once and become simulator-delivered.
6. Cancel a queued message and verify it is not sent on resume. Delete a note locally. Search for remaining local text.
7. Switch light/dark/system appearance and restart. Check preference persists.
8. Review planned Nearby, Channels and Emergency screens; no control should imply working radios or SOS.
9. Check system backup/restore, low storage, keyboard navigation, TalkBack, largest text size, landscape and screen readers on actual hardware. Native secure storage/process death require device evidence beyond host tests.

## Later-phase multi-device plan (not Phase 1 evidence)
Use two Android phones in airplane mode with Bluetooth enabled: mutually discover, compare identity fingerprints, establish reviewed encrypted sessions, and exchange messages. With three phones, keep A outside direct B reach and use C as a relay; confirm bounded hops, no duplicates and no private plaintext on C. Capture key changes, relay receipt vs endpoint delivery, expiry, permission denial, battery saver, process death, malformed frames and offline→internet transitions. Hardware range is observational, never guaranteed. Do not run these acceptance checks until the transports exist.

