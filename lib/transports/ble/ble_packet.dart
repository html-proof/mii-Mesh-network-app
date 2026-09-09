import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';

/// Versioned direct-link payload. All fields, including direction, are encrypted.
class BlePacket {
  const BlePacket(this.id, this.type, this.body, this.createdAt);
  final String id, type, body;
  final int createdAt;
  static const maxBytes = 4096;
  Uint8List encrypt(Sodium sodium, SecureKey key, {required bool fromPhone}) {
    final plain = utf8.encode(jsonEncode([1, id, type, body, createdAt]));
    final nonce = sodium.randombytes.buf(24);
    final cipher = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: Uint8List.fromList(plain),
      nonce: nonce,
      key: key,
      additionalData: Uint8List.fromList(
        utf8.encode(fromPhone ? 'mii-ble-v1:phone' : 'mii-ble-v1:laptop'),
      ),
    );
    final packet = Uint8List.fromList([1, ...nonce, ...cipher]);
    if (packet.length > maxBytes) {
      throw const FormatException('Message too large');
    }
    return packet;
  }

  static BlePacket decrypt(
    Sodium sodium,
    SecureKey key,
    Uint8List bytes, {
    required bool fromPhone,
    int? now,
  }) {
    if (bytes.length < 41 || bytes.length > maxBytes || bytes[0] != 1) {
      throw const FormatException('Invalid packet');
    }
    final plain = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: Uint8List.sublistView(bytes, 25),
      nonce: Uint8List.sublistView(bytes, 1, 25),
      key: key,
      additionalData: Uint8List.fromList(
        utf8.encode(fromPhone ? 'mii-ble-v1:phone' : 'mii-ble-v1:laptop'),
      ),
    );
    // Encrypted peer input is still untrusted; bound nesting before JSON parsing.
    final text = utf8.decode(plain);
    var quoted = false, escaped = false;
    var depth = 0;
    for (final c in text.codeUnits) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (quoted && c == 92) {
        escaped = true;
        continue;
      }
      if (c == 34) {
        quoted = !quoted;
        continue;
      }
      if (!quoted && (c == 91 || c == 123)) {
        if (++depth > 1) throw const FormatException('Nested payload');
      }
      if (!quoted && (c == 93 || c == 125)) depth--;
    }
    final a = jsonDecode(text);
    if (a is! List ||
        a.length != 5 ||
        a[0] != 1 ||
        a[1] is! String ||
        a[2] is! String ||
        a[3] is! String ||
        a[4] is! int) {
      throw const FormatException('Invalid payload');
    }
    final time = now ?? DateTime.now().millisecondsSinceEpoch;
    if (!RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(a[1]) ||
        !['text', 'ack'].contains(a[2]) ||
        utf8.encode(a[3]).length > 2048 ||
        (a[2] == 'text' && (a[3] as String).trim().isEmpty) ||
        (a[2] == 'ack' && a[3] != '') ||
        a[4] > time + 300000 ||
        a[4] < time - 86400000) {
      throw const FormatException('Expired or invalid payload');
    }
    return BlePacket(a[1], a[2], a[3], a[4]);
  }
}
