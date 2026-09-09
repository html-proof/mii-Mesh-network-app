import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mii_mesh/transports/ble/ble_packet.dart';
import 'package:sodium/sodium.dart';

void main() {
  late Sodium sodium;
  setUpAll(() async {
    sodium = await SodiumInit.init();
  });
  test('Direct BLE messages authenticate body, direction, key and expiry', () {
    final key = sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
    final other = sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
    final now = DateTime.now().millisecondsSinceEpoch;
    final packet = BlePacket(
      '019932ab-7b10-7000-8000-000000000001',
      'text',
      'Real Bluetooth hello 👋',
      now,
    );
    try {
      final bytes = packet.encrypt(sodium, key, fromPhone: true);
      expect(
        BlePacket.decrypt(sodium, key, bytes, fromPhone: true).body,
        packet.body,
      );
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains(packet.body)),
      );
      expect(
        () => BlePacket.decrypt(sodium, other, bytes, fromPhone: true),
        throwsA(anything),
      );
      expect(
        () => BlePacket.decrypt(sodium, key, bytes, fromPhone: false),
        throwsA(anything),
      );
      expect(
        () => BlePacket.decrypt(
          sodium,
          key,
          bytes,
          fromPhone: true,
          now: now + 86400001,
        ),
        throwsFormatException,
      );
      bytes[bytes.length - 1] ^= 1;
      expect(
        () => BlePacket.decrypt(sodium, key, bytes, fromPhone: true),
        throwsA(anything),
      );
      expect(
        () => BlePacket.decrypt(sodium, key, Uint8List(4097), fromPhone: true),
        throwsFormatException,
      );
    } finally {
      key.dispose();
      other.dispose();
    }
  });
  test('Direct BLE rejects authenticated invalid payload and nested JSON', () {
    final key = sodium.crypto.aeadXChaCha20Poly1305IETF.keygen();
    try {
      for (final plain in ['[[[[[[]]]]]]', '[1,"bad-id","text","hello",0]']) {
        final nonce = sodium.randombytes.buf(24);
        final cipher = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
          message: Uint8List.fromList(utf8.encode(plain)),
          nonce: nonce,
          key: key,
          additionalData: Uint8List.fromList(utf8.encode('mii-ble-v1:laptop')),
        );
        expect(
          () => BlePacket.decrypt(
            sodium,
            key,
            Uint8List.fromList([1, ...nonce, ...cipher]),
            fromPhone: false,
          ),
          throwsFormatException,
        );
      }
    } finally {
      key.dispose();
    }
  });
}
