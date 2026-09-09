import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';

import '../../core/protocol/envelope.dart';
import '../transport.dart';

/// Explicit local simulation. No sockets, radio, or sample remote identities.
class FakeTransport implements Transport {
  FakeTransport(this.sodium, this.key);
  final Sodium sodium;
  final SecureKey key;
  bool available = false;
  final _receive = StreamController<Uint8List>.broadcast();
  final _health = StreamController<TransportHealth>.broadcast();
  final Set<String> _seen = {};
  @override
  Future<List<String>> discoverPeers() async => available ? ['laboratory'] : [];
  @override
  Future<void> connect() async {
    available = true;
    _health.add(const TransportHealth(true, TransportRoute.localTest));
  }

  @override
  Future<void> disconnect() async {
    available = false;
    _health.add(const TransportHealth(false, TransportRoute.pending));
  }

  @override
  Stream<Uint8List> get receiveEnvelopes => _receive.stream;
  @override
  Stream<TransportHealth> get healthStream => _health.stream;
  @override
  Future<Uint8List> sendEnvelope(Uint8List bytes) async {
    if (!available) throw StateError('Test transport is paused');
    final envelope = Envelope.decode(
      bytes,
      DateTime.now().millisecondsSinceEpoch,
    );
    sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
      cipherText: base64Decode(envelope.ciphertext),
      nonce: base64Decode(envelope.nonce),
      key: key,
      additionalData: envelope.additionalData,
    );
    if (_seen.add(envelope.id)) {
      if (_seen.length > 1024) _seen.remove(_seen.first);
      _receive.add(Uint8List.fromList(bytes));
    }
    final nonce = sodium.randombytes.buf(24);
    final ack = sodium.crypto.aeadXChaCha20Poly1305IETF.encrypt(
      message: Uint8List.fromList(utf8.encode('ack:${envelope.id}')),
      nonce: nonce,
      key: key,
      additionalData: envelope.additionalData,
    );
    return Uint8List.fromList([...nonce, ...ack]);
  }

  bool verifyAck(Envelope envelope, Uint8List ack) {
    if (ack.length < 40 || ack.length > 128) return false;
    try {
      final plain = sodium.crypto.aeadXChaCha20Poly1305IETF.decrypt(
        cipherText: Uint8List.sublistView(ack, 24),
        nonce: Uint8List.sublistView(ack, 0, 24),
        key: key,
        additionalData: envelope.additionalData,
      );
      return utf8.decode(plain) == 'ack:${envelope.id}';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    await _receive.close();
    await _health.close();
    key.dispose();
  }
}
