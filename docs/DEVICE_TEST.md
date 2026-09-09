# Physical Android smoke test

Device: Samsung SM-M558B, Android 16. USB debugging authorized.

Passed on the physical phone:
- Installed updated ARM64 debug APK with `adb install -r` (no data clear).
- Launched the actual Flutter app; existing identity/local vault opened.
- Saved the distinct note `Mii-device-test-20260908` through the real UI.
- Force-stopped and relaunched; the note remained visible in Saved notes.
- Entered `Mii-draft-restart-test` without sending; force-stopped and relaunched; draft restored in the editor.
- Cleared only the test draft afterwards. The labeled saved test note remains for inspection.
- Checked recent Android logs after launch/restart: no FATAL EXCEPTION or E/flutter matches observed.

Scope: this is a real-device local-storage/UI smoke test, not complete acceptance testing. Bluetooth discovery, remote encrypted messaging, mesh routing, media and SOS do not exist yet. Manifest declarations do not implement them. Runtime permission grants/denials, multi-device radio operation and security audit remain untested. Existing app data was preserved.
