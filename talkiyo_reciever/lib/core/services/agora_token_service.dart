import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'agora_rtc_token_builder.dart';
import '../constants/app_constants.dart';

class AgoraTokenService {
  const AgoraTokenService({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  Future<String> fetchRtcToken({
    required String callId,
    required String channelName,
    required String appUserId,
    required String participantDeviceId,
    required int agoraUid,
  }) async {
    final baseUrl = _resolveBaseUrl();
    if (baseUrl.isEmpty) {
      return _buildLocalRtcToken(channelName: channelName, agoraUid: agoraUid);
    }

    final client = _httpClient ?? http.Client();
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/agora/fetchAgoraRtcToken',
    );

    try {
      final response = await client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'callId': callId,
          'channelName': channelName,
          'appUserId': appUserId,
          'participantDeviceId': participantDeviceId,
          'agoraUid': agoraUid,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Token server returned ${response.statusCode}.');
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('Token server returned an invalid response.');
      }

      final token = body['rtcToken']?.toString().trim() ?? '';
      if (token.isEmpty) {
        throw Exception('Token server response did not include rtcToken.');
      }

      return token;
    } catch (_) {
      return _buildLocalRtcToken(channelName: channelName, agoraUid: agoraUid);
    }
  }

  String _resolveBaseUrl() {
    final configuredBaseUrl = AppConstants.callApiBaseUrl.trim();
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    if (kIsWeb) {
      return '';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8080';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'http://127.0.0.1:8080';
      case TargetPlatform.fuchsia:
        return '';
    }
  }

  String _buildLocalRtcToken({
    required String channelName,
    required int agoraUid,
  }) {
    final certificate = AppConstants.agoraAppCertificate;
    if (certificate.isEmpty) {
      return '';
    }

    final privilegeExpiresAt =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        AppConstants.agoraTokenTtlSeconds;

    return AgoraRtcTokenBuilder.buildTokenWithUid(
      appId: AppConstants.agoraAppId,
      appCertificate: certificate,
      channelName: channelName,
      uid: agoraUid,
      privilegeExpiredTs: privilegeExpiresAt,
    );
  }
}
