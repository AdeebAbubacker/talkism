import 'dart:io';

import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

class DefaultDialerService {
  DefaultDialerService._();

  static const MethodChannel _channel = MethodChannel(
    AppConstants.defaultDialerChannel,
  );

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> isDefaultDialer() async {
    if (!isSupported) {
      return false;
    }

    final result = await _channel.invokeMethod<bool>('isDefaultDialer');
    return result ?? false;
  }

  static Future<bool> requestDefaultDialer() async {
    if (!isSupported) {
      return false;
    }

    final result = await _channel.invokeMethod<bool>('requestDefaultDialer');
    return result ?? false;
  }
}
