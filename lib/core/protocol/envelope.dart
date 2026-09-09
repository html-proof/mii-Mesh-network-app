import 'dart:convert';
import 'dart:typed_data';

import 'package:cbor/simple.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
part 'envelope.freezed.dart';
part 'envelope.g.dart';

enum DeliveryState {
  queued,
  encrypting,
  sending,
  relayed,
  delivered,
  read,
  failed,
  expired,
  cancelled,
  saved,
}

/// Phase 1 local laboratory envelope. Not a negotiated network protocol.
@freezed
abstract class Envelope with _$Envelope {
  const Envelope._();
  const factory Envelope({
    @Default(1) int version,
    required String id,
    required String sender,
    required String recipient,
    required int createdAt,
    required int expiresAt,
    required int sequence,
    @Default(0) int hops,
    @Default(3) int maxHops,
    @Default('text') String type,
    required String nonce,
    required String ciphertext,
  }) = _Envelope;
  factory Envelope.fromJson(Map<String, dynamic> json) =>
      _$EnvelopeFromJson(json);
  List<Object> get header => [
    version,
    id,
    sender,
    recipient,
    createdAt,
    expiresAt,
    sequence,
    hops,
    maxHops,
    type,
  ];
  Uint8List get additionalData => Uint8List.fromList(cbor.encode(header));
  Uint8List encode() =>
      Uint8List.fromList(cbor.encode([...header, nonce, ciphertext]));

  void validate(int now) {
    if (version != 1 ||
        !RegExp(r'^[0-9a-f-]{36}$').hasMatch(id) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sender) ||
        recipient != 'laboratory' ||
        type != 'text' ||
        sequence < 1 ||
        sequence > 9007199254740991 ||
        hops < 0 ||
        maxHops < 1 ||
        maxHops > 3 ||
        hops > maxHops ||
        createdAt > now + 300000 ||
        expiresAt <= now ||
        expiresAt <= createdAt ||
        expiresAt - createdAt > 86400000 ||
        base64Decode(nonce).length != 24 ||
        base64Decode(ciphertext).length < 16 ||
        base64Decode(ciphertext).length > 2064) {
      throw const FormatException('Invalid or expired envelope');
    }
  }

  static Envelope decode(Uint8List bytes, int now) {
    if (bytes.length > 4096 || bytes.isEmpty || bytes.first != 0x8c) {
      throw const FormatException('Invalid envelope size or shape');
    }
    // Accept only a flat, definite-length integer/text tuple before decoding.
    var offset = 1;
    for (var field = 0; field < 12; field++) {
      if (offset >= bytes.length) throw const FormatException('Truncated');
      final head = bytes[offset++];
      final major = head >> 5;
      var value = head & 31;
      if (major != 0 && major != 3 || value > 27) {
        throw const FormatException('Invalid field');
      }
      if (value >= 24) {
        final width = 1 << (value - 24);
        if (offset + width > bytes.length) {
          throw const FormatException('Truncated');
        }
        value = 0;
        for (var i = 0; i < width; i++) {
          value = value * 256 + bytes[offset++];
        }
      }
      if (major == 3) {
        if (value < 0 || value > 3000 || offset + value > bytes.length) {
          throw const FormatException('Oversized field');
        }
        offset += value;
      }
    }
    if (offset != bytes.length) throw const FormatException('Trailing bytes');
    try {
      final a = cbor.decode(bytes) as List;
      final envelope = Envelope(
        version: a[0] as int,
        id: a[1] as String,
        sender: a[2] as String,
        recipient: a[3] as String,
        createdAt: a[4] as int,
        expiresAt: a[5] as int,
        sequence: a[6] as int,
        hops: a[7] as int,
        maxHops: a[8] as int,
        type: a[9] as String,
        nonce: a[10] as String,
        ciphertext: a[11] as String,
      );
      envelope.validate(now);
      if (!bytesEqual(bytes, envelope.encode())) {
        throw const FormatException('Noncanonical');
      }
      return envelope;
    } catch (_) {
      throw const FormatException('Invalid envelope');
    }
  }
}

bool bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
