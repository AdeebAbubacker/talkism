import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class RingtoneService {
  static const String _assetPath = 'assets/iphone.mp3';
  static const MethodChannel _channel = MethodChannel('com.talkiyo/ringtone');
  static final AudioPlayer _player = AudioPlayer();
  static bool _isPrepared = false;
  static bool _isRinging = false;

  static Future<void> startRinging() async {
    if (_isRinging) return;

    try {
      _isRinging = true;

      // Stop native Android ringtone service before starting just_audio
      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod('stopRingtone');
        } catch (_) {}
      }

      if (!_isPrepared) {
        await _player.setLoopMode(LoopMode.one);
        await _player.setAsset(_assetPath);
        await _player.setVolume(1);
        _isPrepared = true;
      }

      await _player.seek(Duration.zero);
      await _player.play();
    } catch (error, stackTrace) {
      _isRinging = false;
      debugPrint('Failed to start ringtone: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> stopRinging() async {
    if (!_isRinging && !_player.playing) return;

    try {
      _isRinging = false;
      await _player.stop();
      if (_isPrepared) {
        await _player.seek(Duration.zero);
      }

      // Also stop native Android ringtone service
      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod('stopRingtone');
        } catch (_) {}
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to stop ringtone: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
