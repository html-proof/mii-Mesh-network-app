# Direct laptop–phone Bluetooth

This build includes real foreground BLE messaging between the Android Flutter app and the Windows Python companion. It is a direct one-peer link, not multi-hop mesh or BitChat protocol interoperability.

## Run

1. Install `build/app/outputs/flutter-apk/app-debug.apk` on an ARM64 Android phone. This is a development APK.
2. Turn Bluetooth on for both devices. Open Mii Mesh → Nearby → Start Bluetooth and allow Nearby devices access.
3. On Windows, run `laptop/start.ps1` (Python required). On the phone choose Show pairing secret, then enter that secret in the companion and choose Connect Bluetooth. Hide the secret afterwards.
4. Send text from either device. Keep the phone's Nearby screen open. Leaving the app stops Bluetooth. Start again and enter the new secret to reconnect.

No internet is used for messages. The first companion setup downloads its pinned Python dependencies. USB debugging is only needed to install or automate tests; normal Bluetooth messaging needs no USB cable.

## Delivery and security

Packets use libsodium XChaCha20-Poly1305, a random 32-byte session secret, random nonces and different authentication context for each direction. The phone saves incoming text to its encrypted database before acknowledging it. Outgoing messages become delivered only after an authenticated application acknowledgement; a 20-second timeout exposes manual retry. The laptop transcript is memory-only and its receipt does not imply durable storage.

Anyone who knows the pairing secret can impersonate either endpoint. This is an experimental shared-secret protocol, without forward secrecy, identity negotiation, independent audit, background delivery, multi-hop forwarding or internet relay. BLE connection metadata remains observable. The pairing text exists in application memory and can be captured by screenshots or an observer.

Frames are at most 20 bytes with bounded reassembly up to 4096 bytes. Text is limited to 2048 UTF-8 bytes. Malformed/authentication-failing input is rejected. Phone packet rate is bounded to 120 per minute.

## Physical test, 9 September 2026

Windows MediaTek Bluetooth adapter and Samsung SM-M558B, Android 16, authorized USB debugging:

- Laptop discovered the phone's BLE service and connected through Windows Bluetooth.
- Laptop sent: `Hello phone - sent from this laptop over real Bluetooth`.
- Phone displayed and persisted the message, then returned an authenticated BLE receipt.
- Phone sent: `Hello laptop - received on real Bluetooth`.
- Laptop decrypted and verified the exact reply. Test finished with `PHONE_REPLY_VERIFIED_OVER_BLE` and `ROUND_TRIP_PASS` (exit 0).

USB automation read the temporary pairing secret without logging it and entered the phone reply. Message packets travelled exclusively through BLE GATT writes and notifications. This verifies this device pair; it is not broad device compatibility or a security audit.

Automated validation: 15 Flutter tests covering native crypto, persistence, queue, UI and BLE packets; three Python companion tests. Flutter analyzer reports no issues.

The round trip was repeated successfully after rebuilding and reinstalling the final APK. Existing Bluetooth history survived the update. CONNECT and ADVERTISE runtime permissions were confirmed granted. Final APK SHA-256: `60fd564da26e4be77b3f5dd80dfcd2f9204e231aaf84d2614b0ff405430766f0`.
