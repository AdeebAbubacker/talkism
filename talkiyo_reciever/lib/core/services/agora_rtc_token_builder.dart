import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class AgoraRtcTokenBuilder {
  const AgoraRtcTokenBuilder._();

  static const String _version = '006';
  static const int _joinChannelPrivilege = 1;
  static const int _publishAudioPrivilege = 2;
  static const int _publishVideoPrivilege = 3;
  static const int _publishDataPrivilege = 4;

  static String buildTokenWithUid({
    required String appId,
    required String appCertificate,
    required String channelName,
    required int uid,
    required int privilegeExpiredTs,
  }) {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final normalizedUid = uid == 0 ? '' : '$uid';
    final message = _packMessage(
      salt: _randomSalt(),
      timestamp: nowSeconds + 24 * 3600,
      privileges: <int, int>{
        _joinChannelPrivilege: privilegeExpiredTs,
        _publishAudioPrivilege: privilegeExpiredTs,
        _publishVideoPrivilege: privilegeExpiredTs,
        _publishDataPrivilege: privilegeExpiredTs,
      },
    );

    final toSign = BytesBuilder(copy: false)
      ..add(utf8.encode(appId))
      ..add(utf8.encode(channelName))
      ..add(utf8.encode(normalizedUid))
      ..add(message);

    final signature = Hmac(
      sha256,
      utf8.encode(appCertificate),
    ).convert(toSign.toBytes()).bytes;

    final content = _ByteWriter()
      ..putBytes(signature)
      ..putUint32(_crc32(channelName))
      ..putUint32(_crc32(normalizedUid))
      ..putBytes(message);

    return _version + appId + base64.encode(content.toBytes());
  }

  static Uint8List _packMessage({
    required int salt,
    required int timestamp,
    required Map<int, int> privileges,
  }) {
    final writer = _ByteWriter()
      ..putUint32(salt)
      ..putUint32(timestamp)
      ..putUint16(privileges.length);

    final sortedKeys = privileges.keys.toList()..sort();
    for (final key in sortedKeys) {
      writer
        ..putUint16(key)
        ..putUint32(privileges[key] ?? 0);
    }

    return writer.toBytes();
  }

  static int _randomSalt() {
    final random = Random.secure();
    return random.nextInt(0x100000000);
  }

  static int _crc32(String value) {
    var crc = 0xffffffff;
    for (final byte in utf8.encode(value)) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        final mask = -(crc & 1);
        crc = (crc >>> 1) ^ (0xedb88320 & mask);
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}

class _ByteWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  void putUint16(int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    _builder.add(data.buffer.asUint8List());
  }

  void putUint32(int value) {
    final data = ByteData(4)..setUint32(0, value & 0xffffffff, Endian.little);
    _builder.add(data.buffer.asUint8List());
  }

  void putBytes(List<int> value) {
    putUint16(value.length);
    _builder.add(value);
  }

  Uint8List toBytes() => _builder.toBytes();
}
