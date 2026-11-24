import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:quit_companion/core/config/otp_backend_config.dart';

/// Authenticated deletion for content requiring recursive or atomic cleanup.
class ContentDeletionClient {
  final String baseUrl;
  final http.Client client;
  final Future<String?> Function() getToken;
  ContentDeletionClient({
    this.baseUrl = OtpBackendConfig.baseUrl,
    http.Client? client,
    Future<String?> Function()? getToken,
  }) : client = client ?? http.Client(),
       getToken =
           getToken ??
           (() async => FirebaseAuth.instance.currentUser?.getIdToken());

  Future<void> delete(String path) async {
    final token = await getToken();
    if (token == null) throw StateError('Please sign in again.');
    final response = await client
        .delete(
          Uri.parse('$baseUrl$path'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 204) return;
    String message = 'Could not delete this item. Please try again.';
    try {
      final detail = (jsonDecode(response.body) as Map)['detail'];
      if (detail is String) message = detail;
    } catch (_) {
      /* Keep a safe error for non-JSON service responses. */
    }
    throw StateError(message);
  }
}
