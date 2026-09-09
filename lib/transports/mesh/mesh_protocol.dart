import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';
import 'package:uuid/uuid.dart';

import '../../core/crypto/vault.dart';

/// Mii v2 is a separate protocol. The original laptop v1 service is preserved.
const meshLifetime = 86400000;
const meshKinds = {'text', 'sticker', 'reaction', 'ack'};
const meshStickers = {
  'wave': '👋',
  'heart': '💚',
  'party': '🎉',
  'coffee': '☕',
  'yes': '👍',
  'smile': '😊',
};
const meshReactions = {'❤️', '😂', '👍', '😮', '😢', '🔥'};

Uint8List meshBytes(Object value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

/// Bound nesting before JSON decoding to reject recursive parser exhaustion.
List<dynamic> meshList(Uint8List bytes, int fields, {int limit = 8192}) {
  if (bytes.length > limit) throw const FormatException('Packet too large');
  final text = utf8.decode(bytes);
  var depth = 0, quoted = false, escaped = false;
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
    if (!quoted && (c == 91 || c == 123) && ++depth > 1) {
      throw const FormatException('Nested packet');
    }
    if (!quoted && (c == 93 || c == 125)) depth--;
  }
  final value = jsonDecode(text);
  if (value is! List || value.length != fields) {
    throw const FormatException('Invalid fields');
  }
  return value;
}

class MeshIdentity {
  MeshIdentity(this.sodium, this.signing, this.box);
  final Sodium sodium;
  final KeyPair signing, box;
  String get id => base64UrlEncode(signing.publicKey);
  static Future<MeshIdentity> open(Vault vault) async {
    final encoded = await vault.store.read('identity');
    if (encoded == null) throw StateError('Create your identity first');
    Future<KeyPair> pair(String value, bool sign) async {
      final bytes = base64Decode(value);
      final seed = vault.sodium.secureCopy(bytes);
      bytes.fillRange(0, bytes.length, 0);
      try {
        return sign
            ? vault.sodium.crypto.sign.seedKeyPair(seed)
            : vault.sodium.crypto.box.seedKeyPair(seed);
      } finally {
        seed.dispose();
      }
    }

    var boxSeed = await vault.store.read('mesh.box.seed');
    if (boxSeed == null) {
      final bytes = vault.sodium.randombytes.buf(32);
      try {
        boxSeed = base64Encode(bytes);
        await vault.store.write('mesh.box.seed', boxSeed);
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    }
    final signing = await pair(encoded, true);
    try {
      return MeshIdentity(vault.sodium, signing, await pair(boxSeed, false));
    } catch (_) {
      signing.secretKey.dispose();
      rethrow;
    }
  }

  MeshPacket create(
    String destination,
    String kind,
    Uint8List body, {
    String? id,
    int? now,
  }) {
    final fields = [
      2,
      id ?? const Uuid().v4(),
      this.id,
      destination,
      now ?? DateTime.now().millisecondsSinceEpoch,
      kind,
      base64UrlEncode(body),
      7,
    ];
    final signature = sodium.crypto.sign.detached(
      message: meshBytes(fields),
      secretKey: signing.secretKey,
    );
    return MeshPacket(fields, base64UrlEncode(signature), 0);
  }

  MeshPacket privatePacket(
    MeshPeer peer,
    String kind,
    String body, {
    String reference = '',
    String? id,
  }) {
    MeshContent(kind, body, reference).validate();
    final plain = meshBytes([kind, body, reference]);
    if (plain.length > 4000) {
      throw const FormatException('Encoded message too large');
    }
    final ciphertext = sodium.crypto.box.seal(
      message: plain,
      publicKey: peer.boxKey,
    );
    return create(peer.id, 'sealed', ciphertext, id: id);
  }

  MeshContent decrypt(MeshPacket packet) {
    if (packet.destination != id || packet.kind != 'sealed') {
      throw const FormatException('Wrong recipient');
    }
    final plain = sodium.crypto.box.sealOpen(
      cipherText: packet.payload,
      publicKey: box.publicKey,
      secretKey: box.secretKey,
    );
    final a = meshList(plain, 3, limit: 4096);
    final content = MeshContent(a[0] as String, a[1] as String, a[2] as String);
    content.validate();
    return content;
  }

  void dispose() {
    signing.secretKey.dispose();
    box.secretKey.dispose();
  }
}

class MeshContent {
  const MeshContent(this.kind, this.body, this.reference);
  final String kind, body, reference;
  void validate() {
    if (!meshKinds.contains(kind) ||
        utf8.encode(body).length > 2048 ||
        reference.length > 40) {
      throw const FormatException('Invalid message');
    }
    if (kind == 'text' && (body.trim().isEmpty || reference.isNotEmpty)) {
      throw const FormatException('Empty text');
    }
    if (kind == 'sticker' &&
        (!meshStickers.containsKey(body) || reference.isNotEmpty)) {
      throw const FormatException('Unknown sticker');
    }
    if (kind == 'reaction' &&
        (!meshReactions.contains(body) ||
            !Uuid.isValidUUID(fromString: reference))) {
      throw const FormatException('Invalid reaction');
    }
    if (kind == 'ack' &&
        (body.isNotEmpty || !Uuid.isValidUUID(fromString: reference))) {
      throw const FormatException('Invalid receipt');
    }
  }

  String get stored => jsonEncode([kind, body, reference]);
  static MeshContent fromStored(String value) {
    final a = meshList(Uint8List.fromList(utf8.encode(value)), 3, limit: 4096);
    return MeshContent(a[0] as String, a[1] as String, a[2] as String)
      ..validate();
  }
}

class MeshPacket {
  const MeshPacket(this.fields, this.signature, this.hops);
  final List<dynamic> fields;
  final String signature;
  final int hops;
  String get id => fields[1] as String;
  String get sender => fields[2] as String;
  String get destination => fields[3] as String;
  int get timestamp => fields[4] as int;
  String get kind => fields[5] as String;
  Uint8List get payload => base64Url.decode(fields[6] as String);
  int get expires => timestamp + (kind == 'presence' ? 60000 : meshLifetime);
  Uint8List encode() => meshBytes([...fields, signature, hops]);
  MeshPacket relayed() {
    if (hops >= 7) throw StateError('Hop limit reached');
    return MeshPacket(fields, signature, hops + 1);
  }

  static MeshPacket decode(Sodium sodium, Uint8List bytes, {int? now}) {
    final a = meshList(bytes, 10);
    final clock = now ?? DateTime.now().millisecondsSinceEpoch;
    if (a[0] != 2 ||
        a[1] is! String ||
        !Uuid.isValidUUID(fromString: a[1] as String) ||
        a[2] is! String ||
        a[3] is! String ||
        a[4] is! int ||
        a[5] is! String ||
        a[6] is! String ||
        a[7] != 7 ||
        a[8] is! String ||
        a[9] is! int ||
        (a[9] as int) < 0 ||
        (a[9] as int) > 7) {
      throw const FormatException('Invalid header');
    }
    final p = MeshPacket(a.sublist(0, 8), a[8] as String, a[9] as int);
    if (!{'presence', 'sealed'}.contains(p.kind) ||
        p.timestamp > clock + 30000 ||
        p.expires <= clock ||
        (p.kind == 'presence') != (p.destination == '*') ||
        (p.destination != '*' &&
            base64Url.decode(p.destination).length != 32) ||
        p.payload.length > 4096) {
      throw const FormatException('Invalid packet');
    }
    if (!sodium.crypto.sign.verifyDetached(
      message: meshBytes(p.fields),
      signature: base64Url.decode(p.signature),
      publicKey: base64Url.decode(p.sender),
    )) {
      throw const FormatException('Invalid signature');
    }
    return p;
  }
}

class MeshPeer {
  MeshPeer(this.id, this.name, this.boxKey, this.lastSeen, this.hops, this.via);
  final String id, name;
  final Uint8List boxKey;
  int lastSeen, hops;
  String via;
  bool get reachable =>
      DateTime.now().millisecondsSinceEpoch - lastSeen < 60000;
  String get availability => !reachable
      ? 'Recently seen'
      : hops == 0
      ? 'Nearby'
      : 'Via mesh';
}
