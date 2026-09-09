# Android permission declarations

Updated at the user's request to declare permissions for planned real-device features. These declarations do not implement features or grant runtime access. No permission-request flow or native mesh service exists yet. Existing Phase 1 test results predate this manifest expansion.

| Capability | Declared permissions |
|---|---|
| Bluetooth | BLUETOOTH/BLUETOOTH_ADMIN through API 30; SCAN, CONNECT, ADVERTISE on newer Android |
| Optional internet/Wi-Fi | INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_STATE, NEARBY_WIFI_DEVICES |
| User-shared location / legacy discovery | ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION |
| Alerts | POST_NOTIFICATIONS, VIBRATE |
| Camera / voice | CAMERA, RECORD_AUDIO |
| App lock | USE_BIOMETRIC |
| Media | READ_EXTERNAL_STORAGE through API 32; READ_MEDIA_IMAGES, VIDEO, AUDIO, VISUAL_USER_SELECTED |
| Future foreground work | FOREGROUND_SERVICE and CONNECTED_DEVICE, MICROPHONE, LOCATION, DATA_SYNC type permissions; WAKE_LOCK |

Bluetooth and nearby Wi-Fi results must not derive physical location (`neverForLocation`). BLE filtering implications must be tested on hardware. Explicit location sharing uses separate location permission, so location declarations are not capped at API 30. Hardware features are optional to preserve access to local notes.

No contacts, SMS, call, background location, all-files access, battery-optimization bypass or automatic startup permission was added. Photo/document pickers should be preferred over broad library access. No obsolete write-storage permission is needed for app-private files or scoped storage.

Before using each feature: explain the purpose, request only its runtime permissions, handle denied/permanently denied/partial access, and keep local features usable. Before starting a foreground service, implement its actual class, matching type, visible notification, and platform-compliant startup. Permission declarations alone cannot enable a radio or background execution.

References: [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions), [foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types), [partial media access](https://developer.android.com/about/versions/14/changes/partial-photo-video-access).
