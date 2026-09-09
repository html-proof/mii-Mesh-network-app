import 'dart:typed_data';

enum TransportRoute {
  directBluetooth,
  meshRelay,
  internetRelay,
  pending,
  localTest,
}

class TransportHealth {
  const TransportHealth(this.available, this.route);
  final bool available;
  final TransportRoute route;
}

abstract interface class Transport {
  Future<List<String>> discoverPeers();
  Future<void> connect();
  Future<void> disconnect();
  Future<Uint8List> sendEnvelope(Uint8List bytes);
  Stream<Uint8List> get receiveEnvelopes;
  Stream<TransportHealth> get healthStream;
  Future<void> dispose();
}
