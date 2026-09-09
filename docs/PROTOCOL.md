# Mii Mesh laboratory protocol v1

Status: implemented **only for an explicitly enabled in-process simulator**. Not interoperable with BitChat, Nostr, or real peers. Do not connect this protocol to BLE or a public network. No handshake or sender authentication is claimed.

## Implemented encoding
Definite-length canonical CBOR array, exactly 12 flat fields in this order:

| Index | Field | Validation |
|---|---|---|
| 0 | version | 1 only |
| 1 | message ID | UUIDv7 generated locally; UUID-shaped string |
| 2 | sender | 32-byte public key, lowercase hexadecimal |
| 3 | recipient | `laboratory` only |
| 4–5 | created/expires | Unix milliseconds; lifetime ≤24 h; reject expired or >5 min future creation |
| 6 | sender sequence | persisted monotonic positive integer, ≤2^53−1 |
| 7–8 | hops/max hops | 0≤hops≤max≤3; no relay implemented |
| 9 | payload type | `text` only |
| 10 | nonce | base64, 24 random bytes |
| 11 | ciphertext+tag | base64, 16–2064 bytes |

The canonical encoding of fields 0–9 is XChaCha20-Poly1305-IETF additional authenticated data. AEAD uses libsodium, a random 256-bit local laboratory key, and a fresh 192-bit nonce. The library supplies authentication tags. Text is UTF-8 with a 2048-byte maximum. Maximum encoded envelope: 4096 bytes. Before decoding, a bounded flat-field scanner rejects nested containers, indefinite lengths, oversized strings, truncation and trailing bytes. Decoded input must re-encode identically.

The simulator decrypts/authenticates before acknowledging. An acknowledgement is a fresh 24-byte nonce followed by authenticated ciphertext of `ack:<message ID>`, using the same header as additional authenticated data. Acknowledgements are verified before the message can transition from queued to delivered. The UI always calls this **delivery to the local simulator**. Sharing a local laboratory key is not a network session-establishment protocol.

The receive stream suppresses duplicate events with a 1024-ID FIFO cache. Persistent outbox/message primary keys make restart and retransmission idempotent in this local workflow. This is not persistent replay prevention against hostile external senders. The simulator has no socket, radio, sample user or external endpoint.

## Persistence and reliability
One transaction stores the outgoing text, sender sequence, encrypted envelope and cleared draft before sending. Local notes use `saved`; tests use `queued → delivered` after an authenticated simulator acknowledgement. Five failures produce `failed`; retry resets attempts. Cancel removes pending envelope and sets `cancelled`. Retry delay is bounded exponential backoff plus up to 999 ms jitter. Pausing the simulator does not consume retry attempts. Queue and connection preference survive a clean database reopen; timer resumes only while the app runs. Test messages expire after 24 h and are purged on startup and active queue ticks. Notes have no automatic expiry. There is no OS background service in Phase 1.

## Required before a real network phase
* Define and review a maintained Noise handshake with X25519, identity authentication, HKDF-SHA-256, transcript binding and session rotation. The current seed-generated Ed25519 identity alone is not that handshake.
* Separate authenticated immutable headers from mutable relay counters; the current hop fields are authenticated and therefore cannot be rewritten by relays.
* Negotiate capabilities and critical extensions; v1 rejects every extension. No backward compatibility is promised for this internal format.
* Persistent replay windows, authenticated endpoint acknowledgements, clock skew policy, anti-amplification and peer/channel quotas.
* MTU-safe fragmentation and bounded chunk reassembly, rekeying, forward secrecy, key-change warnings and contact verification.
* Group membership authorization and key rotation on every membership change. Removal cannot revoke previously received content.
* Per-attachment random keys, chunk hashes, resumable transfer and storage/MIME limits.

These are release-blocking design tasks, not hidden implementations. No BLE framing, multi-hop forwarding, internet routing, encrypted groups, attachment transfer, or emergency signing ships here.
