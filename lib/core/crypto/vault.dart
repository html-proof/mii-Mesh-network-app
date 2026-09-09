import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sodium/sodium.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PlatformSecretStore implements SecretStore {
  final FlutterSecureStorage storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  @override
  Future<String?> read(String key) => storage.read(key: 'mii.v1.$key');
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: 'mii.v1.$key', value: value);
}

class Vault {
  Vault(this.sodium, this.store);
  final Sodium sodium;
  final SecretStore store;

  Future<String> databaseKey({required bool databaseExists}) async {
    final existing = await store.read('database');
    if (existing != null) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(existing)) {
        throw StateError('Invalid database key');
      }
      return existing;
    }
    if (databaseExists) throw StateError('Database key unavailable');
    final key = sodium.randombytes
        .buf(32)
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();
    await store.write('database', key);
    return key;
  }

  Future<Uint8List> identityPublicKey() async {
    var encoded = await store.read('identity');
    if (encoded == null) {
      final seed = sodium.randombytes.buf(sodium.crypto.sign.seedBytes);
      try {
        encoded = base64Encode(seed);
        await store.write('identity', encoded);
      } finally {
        seed.fillRange(0, seed.length, 0);
      }
    }
    final bytes = base64Decode(encoded);
    try {
      final seed = sodium.secureCopy(bytes);
      try {
        final pair = sodium.crypto.sign.seedKeyPair(seed);
        try {
          return pair.publicKey;
        } finally {
          pair.secretKey.dispose();
        }
      } finally {
        seed.dispose();
      }
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  String fingerprint(Uint8List publicKey) {
    final hash = sodium.crypto.genericHash(message: publicKey, outLen: 16);
    final hex = hash
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return List.generate(8, (i) => hex.substring(i * 4, i * 4 + 4)).join(' ');
  }

  Future<SecureKey> laboratoryKey() async {
    final existing = await store.read('laboratory');
    if (existing != null) {
      final bytes = base64Decode(existing);
      try {
        return sodium.secureCopy(bytes);
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    }
    final key = sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
    final bytes = key.extractBytes();
    try {
      await store.write('laboratory', base64Encode(bytes));
    } catch (_) {
      key.dispose();
      rethrow;
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
    return key;
  }
}
