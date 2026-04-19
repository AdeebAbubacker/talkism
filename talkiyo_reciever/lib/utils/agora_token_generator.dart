import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';

/// Generates Agora AccessToken2 (prefix "007") for RTC channel joining.
/// Algorithm mirrors the official Agora open-source token builders.
class AgoraTokenGenerator {
  static const String _version = '007';
  static const int _rtcServiceType = 1;
  static const int _privilegeJoinChannel = 1;
  static const int _privilegePublishAudioStream = 2;
  static const int _privilegePublishVideoStream = 3;
  static const int _privilegePublishDataStream = 4;

  /// Generate a token valid for [expireSeconds] (default 1 hour).
  /// Pass uid=0 to allow any user ID to join with this token.
  static String generateRtcToken({
    required String appId,
    required String appCertificate,
    required String channelName,
    int uid = 0,
    int expireSeconds = 3600,
  }) {
    final issueTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final salt = Random.secure().nextInt(99999998) + 1;
    final uidStr = uid > 0 ? uid.toString() : '';
    final privilegeExpire = expireSeconds;

    final signingKey = Hmac(
      sha256,
      _u32(salt),
    )
        .convert(Hmac(sha256, _u32(issueTs))
            .convert(utf8.encode(appCertificate))
            .bytes)
        .bytes;

    final services = BytesBuilder()
      ..add(_u16(1))
      ..add(_buildRtcService(channelName, uidStr, privilegeExpire));

    final sigContent = BytesBuilder()
      ..add(_packStr(utf8.encode(appId)))
      ..add(_u32(issueTs))
      ..add(_u32(expireSeconds))
      ..add(_u32(salt))
      ..add(services.toBytes());
    final signature =
        Hmac(sha256, signingKey).convert(sigContent.toBytes()).bytes;

    final tokenBytes = BytesBuilder()
      ..add(_packStr(signature))
      ..add(_packStr(utf8.encode(appId)))
      ..add(_u32(issueTs))
      ..add(_u32(expireSeconds))
      ..add(_u32(salt))
      ..add(services.toBytes());

    final compressed = const ZLibEncoder().encode(tokenBytes.toBytes());
    return _version + base64.encode(compressed);
  }

  static Uint8List _buildRtcService(
      String channelName, String uid, int privilegeExpireTs) {
    return (BytesBuilder()
          ..add(_u16(_rtcServiceType))
          ..add(_packPrivileges({
            _privilegeJoinChannel: privilegeExpireTs,
            _privilegePublishAudioStream: privilegeExpireTs,
            _privilegePublishVideoStream: privilegeExpireTs,
            _privilegePublishDataStream: privilegeExpireTs,
          }))
          ..add(_packStr(utf8.encode(channelName)))
          ..add(_packStr(utf8.encode(uid))))
        .toBytes();
  }

  static Uint8List _packPrivileges(Map<int, int> privileges) {
    final sortedKeys = privileges.keys.toList()..sort();
    final builder = BytesBuilder()..add(_u16(sortedKeys.length));
    for (final key in sortedKeys) {
      builder
        ..add(_u16(key))
        ..add(_u32(privileges[key]!));
    }
    return builder.toBytes();
  }

  static Uint8List _u16(int v) =>
      (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List();

  static Uint8List _u32(int v) =>
      (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();

  static Uint8List _packStr(List<int> bytes) {
    return (BytesBuilder()
          ..add(_u16(bytes.length))
          ..add(bytes))
        .toBytes();
  }
}
