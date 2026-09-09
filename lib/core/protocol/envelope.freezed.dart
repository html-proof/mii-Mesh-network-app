// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'envelope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Envelope {

 int get version; String get id; String get sender; String get recipient; int get createdAt; int get expiresAt; int get sequence; int get hops; int get maxHops; String get type; String get nonce; String get ciphertext;
/// Create a copy of Envelope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EnvelopeCopyWith<Envelope> get copyWith => _$EnvelopeCopyWithImpl<Envelope>(this as Envelope, _$identity);

  /// Serializes this Envelope to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Envelope;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Envelope&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sender, _this.sender) || other.sender == _this.sender)&&(identical(other.recipient, _this.recipient) || other.recipient == _this.recipient)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.sequence, _this.sequence) || other.sequence == _this.sequence)&&(identical(other.hops, _this.hops) || other.hops == _this.hops)&&(identical(other.maxHops, _this.maxHops) || other.maxHops == _this.maxHops)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.nonce, _this.nonce) || other.nonce == _this.nonce)&&(identical(other.ciphertext, _this.ciphertext) || other.ciphertext == _this.ciphertext));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Envelope;
  return Object.hash(runtimeType,_this.version,_this.id,_this.sender,_this.recipient,_this.createdAt,_this.expiresAt,_this.sequence,_this.hops,_this.maxHops,_this.type,_this.nonce,_this.ciphertext);
}

@override
String toString() {
  final _this = this as Envelope;
  return 'Envelope(version: ${_this.version}, id: ${_this.id}, sender: ${_this.sender}, recipient: ${_this.recipient}, createdAt: ${_this.createdAt}, expiresAt: ${_this.expiresAt}, sequence: ${_this.sequence}, hops: ${_this.hops}, maxHops: ${_this.maxHops}, type: ${_this.type}, nonce: ${_this.nonce}, ciphertext: ${_this.ciphertext})';
}


}

/// @nodoc
abstract mixin class $EnvelopeCopyWith<$Res>  {
  factory $EnvelopeCopyWith(Envelope value, $Res Function(Envelope) _then) = _$EnvelopeCopyWithImpl;
@useResult
$Res call({
 int version, String id, String sender, String recipient, int createdAt, int expiresAt, int sequence, int hops, int maxHops, String type, String nonce, String ciphertext
});




}
/// @nodoc
class _$EnvelopeCopyWithImpl<$Res>
    implements $EnvelopeCopyWith<$Res> {
  _$EnvelopeCopyWithImpl(this._self, this._then);

  final Envelope _self;
  final $Res Function(Envelope) _then;

/// Create a copy of Envelope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? id = null,Object? sender = null,Object? recipient = null,Object? createdAt = null,Object? expiresAt = null,Object? sequence = null,Object? hops = null,Object? maxHops = null,Object? type = null,Object? nonce = null,Object? ciphertext = null,}) {
  return _then(Envelope(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as String,recipient: null == recipient ? _self.recipient : recipient // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,hops: null == hops ? _self.hops : hops // ignore: cast_nullable_to_non_nullable
as int,maxHops: null == maxHops ? _self.maxHops : maxHops // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,nonce: null == nonce ? _self.nonce : nonce // ignore: cast_nullable_to_non_nullable
as String,ciphertext: null == ciphertext ? _self.ciphertext : ciphertext // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Envelope].
extension EnvelopePatterns on Envelope {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Envelope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Envelope() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Envelope value)  $default,){
final _that = this;
switch (_that) {
case _Envelope():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Envelope value)?  $default,){
final _that = this;
switch (_that) {
case _Envelope() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  String id,  String sender,  String recipient,  int createdAt,  int expiresAt,  int sequence,  int hops,  int maxHops,  String type,  String nonce,  String ciphertext)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Envelope() when $default != null:
return $default(_that.version,_that.id,_that.sender,_that.recipient,_that.createdAt,_that.expiresAt,_that.sequence,_that.hops,_that.maxHops,_that.type,_that.nonce,_that.ciphertext);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  String id,  String sender,  String recipient,  int createdAt,  int expiresAt,  int sequence,  int hops,  int maxHops,  String type,  String nonce,  String ciphertext)  $default,) {final _that = this;
switch (_that) {
case _Envelope():
return $default(_that.version,_that.id,_that.sender,_that.recipient,_that.createdAt,_that.expiresAt,_that.sequence,_that.hops,_that.maxHops,_that.type,_that.nonce,_that.ciphertext);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  String id,  String sender,  String recipient,  int createdAt,  int expiresAt,  int sequence,  int hops,  int maxHops,  String type,  String nonce,  String ciphertext)?  $default,) {final _that = this;
switch (_that) {
case _Envelope() when $default != null:
return $default(_that.version,_that.id,_that.sender,_that.recipient,_that.createdAt,_that.expiresAt,_that.sequence,_that.hops,_that.maxHops,_that.type,_that.nonce,_that.ciphertext);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Envelope extends Envelope {
  const _Envelope({this.version = 1, required this.id, required this.sender, required this.recipient, required this.createdAt, required this.expiresAt, required this.sequence, this.hops = 0, this.maxHops = 3, this.type = 'text', required this.nonce, required this.ciphertext}): super._();
  factory _Envelope.fromJson(Map<String, dynamic> json) => _$EnvelopeFromJson(json);

@override@JsonKey() final  int version;
@override final  String id;
@override final  String sender;
@override final  String recipient;
@override final  int createdAt;
@override final  int expiresAt;
@override final  int sequence;
@override@JsonKey() final  int hops;
@override@JsonKey() final  int maxHops;
@override@JsonKey() final  String type;
@override final  String nonce;
@override final  String ciphertext;

/// Create a copy of Envelope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EnvelopeCopyWith<_Envelope> get copyWith => __$EnvelopeCopyWithImpl<_Envelope>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EnvelopeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Envelope&&(identical(other.version, version) || other.version == version)&&(identical(other.id, id) || other.id == id)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.recipient, recipient) || other.recipient == recipient)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.hops, hops) || other.hops == hops)&&(identical(other.maxHops, maxHops) || other.maxHops == maxHops)&&(identical(other.type, type) || other.type == type)&&(identical(other.nonce, nonce) || other.nonce == nonce)&&(identical(other.ciphertext, ciphertext) || other.ciphertext == ciphertext));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,version,id,sender,recipient,createdAt,expiresAt,sequence,hops,maxHops,type,nonce,ciphertext);
}

@override
String toString() {
    return 'Envelope(version: $version, id: $id, sender: $sender, recipient: $recipient, createdAt: $createdAt, expiresAt: $expiresAt, sequence: $sequence, hops: $hops, maxHops: $maxHops, type: $type, nonce: $nonce, ciphertext: $ciphertext)';
}


}

/// @nodoc
abstract mixin class _$EnvelopeCopyWith<$Res> implements $EnvelopeCopyWith<$Res> {
  factory _$EnvelopeCopyWith(_Envelope value, $Res Function(_Envelope) _then) = __$EnvelopeCopyWithImpl;
@override @useResult
$Res call({
 int version, String id, String sender, String recipient, int createdAt, int expiresAt, int sequence, int hops, int maxHops, String type, String nonce, String ciphertext
});




}
/// @nodoc
class __$EnvelopeCopyWithImpl<$Res>
    implements _$EnvelopeCopyWith<$Res> {
  __$EnvelopeCopyWithImpl(this._self, this._then);

  final _Envelope _self;
  final $Res Function(_Envelope) _then;

/// Create a copy of Envelope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? id = null,Object? sender = null,Object? recipient = null,Object? createdAt = null,Object? expiresAt = null,Object? sequence = null,Object? hops = null,Object? maxHops = null,Object? type = null,Object? nonce = null,Object? ciphertext = null,}) {
  return _then(_Envelope(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as String,recipient: null == recipient ? _self.recipient : recipient // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,hops: null == hops ? _self.hops : hops // ignore: cast_nullable_to_non_nullable
as int,maxHops: null == maxHops ? _self.maxHops : maxHops // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,nonce: null == nonce ? _self.nonce : nonce // ignore: cast_nullable_to_non_nullable
as String,ciphertext: null == ciphertext ? _self.ciphertext : ciphertext // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
