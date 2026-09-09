# Mii Mesh upgrade — implementation and validation record

This extends the existing Flutter project. The original v1 laptop BLE service and existing Ed25519 identity, encrypted database, notes, drafts and laboratory remain available. It is not wire-compatible with BitChat.

## Implemented in source

- Chats, Nearby and Calls navigation; Settings in the top corner.
- Automatic discovery after the user enables Nearby devices access once. Enablement is remembered across app launches.
- Android central and peripheral roles, four simultaneous links, session-random connection tie breaking, low-power scanning, bounded buffers and exponential retry delay.
- A visible connected-device foreground service while mesh is enabled. Minimizing does not deliberately stop mesh. Explicit pause and activity destruction stop it. Force-stop/process eviction still interrupts communication; the encrypted outbox resumes on reopening.
- Signed announcements, pinned peer encryption keys, last-seen state, direct versus relayed availability and a diagnostics page.
- Recipient-encrypted and sender-signed private text, six built-in sticker IDs and small reactions. Relays do not decrypt private payloads.
- A seven-hop limit, duplicate suppression, bounded persistent courier packets, automatic retry and recipient acknowledgement after database insertion.
- Schema 1 → 2 migration adds peer and courier tables while retaining the original tables and keys.

## Run

Install the latest development APK on Android 8 or later. Open Nearby and choose Enable Bluetooth. After permission is granted, other phones running this build appear automatically. Tap a person to message; long-press a message to react, or use the smile button for stickers. Messages remain queued while the recipient is unreachable.

The original laptop companion is under Settings → Laptop companion (original connection). It retains the v1 pairing-secret workflow and separate service UUID. The new `laptop/mesh_probe.py` is a hardware test tool with a temporary identity; it is not a persistent everyday laptop client.

## Protocol and limits

Mii v2 uses a flat signed JSON envelope with message ID, Ed25519 sender public key, recipient ID, timestamp, kind, payload, initial TTL and mutable hop count. Ed25519 signs the immutable fields. A private body is a libsodium sealed box addressed to the recipient's additional Curve25519 key. That key is bound by a signed announcement and pinned on first sight. The original signing identity is retained.

This provides sender-key authentication, not verification of a person's display name. Users can compare fingerprints in person. It does not establish forward-secret Noise sessions. Public announcements and routing metadata expose identities and names; passive observation remains possible. An intermediary can drop traffic, and hop counts are operational controls rather than a defence against a malicious relay resetting them.

Limits: 256 known peers; 500 retained packets; 10,000 local messages; 2,048 UTF-8 text bytes; 8,192-byte wire packets; 120 complete packets/minute/link; 128 pending event callbacks; 24-hour retention and 60-second presence freshness. BLE frames are 20 bytes or less with bounded reassembly. Built-in stickers are transmitted by ID only; external sticker packs and chunked media are not implemented.

## Validation status

Automated checks cover native crypto, encrypted persistence, schema upgrade, four-node relay topology, alternate paths, returning recipients, duplicate handling, rejected packet corruption/key changes, and a 100-message burst. These topology tests use an in-memory transport with the real protocol and cryptography. They do not prove physical multi-phone BLE reliability.

Hardware results and final test counts will be recorded after running the new APK. The earlier v1 laptop round trip is documented in BLUETOOTH.md and must not be treated as evidence for v2.

## Remaining brief requirements

The Calls tab currently states that calls are unavailable. Full-duplex direct audio, incoming/locked-screen calls, push-to-talk, photo/file/location transfer, external sticker-pack transfer, Nearby group chat, read/unread counts, adaptive ACTIVE/BALANCED/IDLE scheduling, and advanced transfer priority/resume are not yet implemented. No screen should claim that those features work.

Physical three-/four-phone relay, out-of-range, low-battery and long-duration background tests require the additional phones. iOS and Windows Flutter hosts remain unvalidated.

References: [Android BLE background guidance](https://developer.android.com/develop/connectivity/bluetooth/ble/background), [libsodium sealed boxes](https://libsodium.gitbook.io/doc/public-key_cryptography/sealed_boxes), [BitChat whitepaper (reference, separate protocol)](https://github.com/permissionlesstech/bitchat/blob/main/WHITEPAPER.md).
