import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum NotificationEventType { badgeEarned, restartPlan }

abstract interface class NotificationEventClient {
  Future<void> send(NotificationEventType event);
}

class NoopNotificationEventClient implements NotificationEventClient {
  const NoopNotificationEventClient();

  @override
  Future<void> send(NotificationEventType event) async {}
}

class HttpNotificationEventClient implements NotificationEventClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function() _getIdToken;

  HttpNotificationEventClient({
    required this.baseUrl,
    http.Client? httpClient,
    Future<String?> Function()? getIdToken,
  }) : _httpClient = httpClient ?? http.Client(),
       _getIdToken = getIdToken ?? _defaultGetIdToken;

  static Future<String?> _defaultGetIdToken() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  @override
  Future<void> send(NotificationEventType event) async {
    final token = await _getIdToken();
    if (token == null || token.isEmpty) {
      throw const NotificationEventException('You must be signed in.');
    }

    final eventName = switch (event) {
      NotificationEventType.badgeEarned => 'badge_earned',
      NotificationEventType.restartPlan => 'restart_plan',
    };
    final http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse('$baseUrl/notifications/events/$eventName'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (error, stackTrace) {
      debugPrint('Notification event request failed: $error\n$stackTrace');
      throw const NotificationEventException(
        'Could not reach the notification service.',
      );
    }

    if (response.statusCode != 200) {
      String? detail;
      try {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        detail = payload['detail'] as String?;
      } catch (_) {
        detail = null;
      }
      throw NotificationEventException(
        detail ?? 'Could not send this notification.',
      );
    }
  }
}

class NotificationEventException implements Exception {
  final String message;

  const NotificationEventException(this.message);

  @override
  String toString() => message;
}
