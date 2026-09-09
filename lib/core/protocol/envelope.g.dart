// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Envelope _$EnvelopeFromJson(Map<String, dynamic> json) => _Envelope(
  version: (json['version'] as num?)?.toInt() ?? 1,
  id: json['id'] as String,
  sender: json['sender'] as String,
  recipient: json['recipient'] as String,
  createdAt: (json['createdAt'] as num).toInt(),
  expiresAt: (json['expiresAt'] as num).toInt(),
  sequence: (json['sequence'] as num).toInt(),
  hops: (json['hops'] as num?)?.toInt() ?? 0,
  maxHops: (json['maxHops'] as num?)?.toInt() ?? 3,
  type: json['type'] as String? ?? 'text',
  nonce: json['nonce'] as String,
  ciphertext: json['ciphertext'] as String,
);

Map<String, dynamic> _$EnvelopeToJson(_Envelope instance) => <String, dynamic>{
  'version': instance.version,
  'id': instance.id,
  'sender': instance.sender,
  'recipient': instance.recipient,
  'createdAt': instance.createdAt,
  'expiresAt': instance.expiresAt,
  'sequence': instance.sequence,
  'hops': instance.hops,
  'maxHops': instance.maxHops,
  'type': instance.type,
  'nonce': instance.nonce,
  'ciphertext': instance.ciphertext,
};
