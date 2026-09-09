# Dependency review

Checked 2026-09-08 against pub.dev release metadata and the licenses in the resolved source packages. Direct dependencies are pinned; pubspec.lock records transitive versions and hashes. Publication activity is evidence of recent maintenance, not a promise of future support or a completed vulnerability audit.

| Package | Pinned version | Published | License family |
|---|---|---|---|
| flutter_riverpod | 3.4.3 | 2026-09-03 | MIT |
| go_router | 18.0.1 | 2026-09-02 | BSD |
| drift | 2.34.4 | 2026-09-02 | MIT |
| sqlite3 | 3.5.2 | 2026-08-19 | MIT |
| flutter_secure_storage | 11.0.0 | 2026-08-06 | BSD |
| sodium | 4.1.0+1 | 2026-09-01 | BSD |
| path_provider | 2.1.6 | 2026-06-15 | BSD |
| path | 1.9.1 | 2024-10-17 | BSD |
| freezed_annotation | 3.1.0 | 2025-07-02 | MIT |
| json_annotation | 4.12.0 | 2026-05-15 | BSD |
| uuid | 4.6.0 | 2026-07-15 | MIT |
| cbor | 6.5.1 | 2026-02-22 | MIT |
| drift_dev | 2.34.6 | 2026-09-02 | MIT |
| build_runner | 2.16.1 | 2026-09-02 | BSD |
| freezed | 4.0.1 | 2026-08-29 | MIT |
| json_serializable | 6.14.1 | 2026-07-30 | BSD |

Full direct license texts are in `dependency-licenses/`. Runtime direct licenses are permissive; preserve notices. Native libsodium is ISC and SQLite3MultipleCiphers has its own notices which require release packaging review. Dev tools are not bundled in the APK. A complete transitive/native license and vulnerability review remains a release gate. GNU Make is a local GPL build tool, excluded from the app. No source or branding from BitChat was copied.

Implementation references: [Drift encryption](https://drift.simonbinder.eu/platforms/encryption/), [sodium](https://pub.dev/packages/sodium), [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage), and package-specific `https://pub.dev/packages/<name>` pages.
