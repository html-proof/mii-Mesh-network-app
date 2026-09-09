# Encrypted database, schema v2

The mesh upgrade adds `mesh_peers(id, name, box_key)` and `mesh_packets(id, packet, expires)` through an explicit 1 → 2 migration. These supplementary SQL tables are inside the same encrypted database. Original profile, history, draft and outbox tables remain unchanged. The existing v1 JSON snapshot describes that preserved baseline; the mesh-table definitions are in `MeshDatabase.createMeshTables`. Upgrade/restart tests verify original identity and notes, durable encrypted mesh packets, duplicate delivery and conflicting IDs.

Fresh encrypted database created by Drift's `createAll` migration; versioned snapshot: `schema/drift_schema_v1.json`. No earlier app database existed to migrate. Future upgrades must add explicit migration steps and retain snapshots. Sensitive columns and indexes are protected by whole-file SQLite3MultipleCiphers encryption. A 256-bit random key is kept in platform secure storage, never in this schema.

| Table | Key | Stored fields |
|---|---|---|
| profiles | local singleton id | display name, Ed25519 public key |
| conversations | id | title, kind (notes/laboratory), draft |
| messages | UUIDv7 id | conversation FK, text, created/expires timestamps, delivery status, sequence |
| outbox | message FK | authenticated encrypted envelope, attempts, next attempt |
| preferences | key | appearance, lab connection setting, persistent sender sequence |

Foreign keys are enabled; deleting a message cascades its pending outbox row. Sending and outbox insertion are atomic with sequence allocation and draft clearing. Messages are ordered by local timestamp then sequence. Only locally authored messages exist in Phase 1; untrusted remote clock ordering remains later work.

Retention: notes persist until local deletion. Test messages expire after 24 hours; startup and a two-second foreground maintenance tick delete expired rows and dependent envelopes. App termination delays cleanup until reopening. No media exists. Outbox ≤500 and messages ≤10,000; no attachment/storage compaction worker yet. Drafts are persisted on edit, bounded at 2048 characters. File pages use secure_delete, in-memory temporary storage and full-file encryption. These do not guarantee physical flash erasure.

The remaining tables in the full brief—contacts, trusted identities, channels, membership, revisions, reactions, attachments, receipts, replay windows, peer observations, transport events, blocked identities and emergencies—belong to later phases. Empty tables pretending to support those features are intentionally not created.
