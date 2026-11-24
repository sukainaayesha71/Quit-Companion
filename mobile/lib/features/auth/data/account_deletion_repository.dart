import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;

abstract interface class AccountDeletionRepository {
  Future<void> deleteAccount();
}

class HttpAccountDeletionRepository implements AccountDeletionRepository {
  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function() _getIdToken;

  HttpAccountDeletionRepository({
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
  Future<void> deleteAccount() async {
    final token = await _getIdToken();
    if (token == null || token.isEmpty) {
      throw const AccountDeletionException('You must be signed in.');
    }

    final http.Response response;
    try {
      response = await _httpClient
          .delete(
            Uri.parse('$baseUrl/account'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(minutes: 2));
    } catch (_) {
      throw const AccountDeletionException(
        'Could not reach the account service. Please try again.',
      );
    }

    if (response.statusCode != 204) {
      String? detail;
      try {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        detail = payload['detail'] as String?;
      } catch (_) {
        detail = null;
      }
      throw AccountDeletionException(
        detail ?? 'Could not delete the account. Please try again.',
      );
    }
  }
}

class UnconfiguredAccountDeletionRepository
    implements AccountDeletionRepository {
  const UnconfiguredAccountDeletionRepository();

  @override
  Future<void> deleteAccount() async {
    throw const AccountDeletionException(
      'Account deletion is not configured. Please contact support.',
    );
  }
}

class AccountDeletionException implements Exception {
  final String message;

  const AccountDeletionException(this.message);

  @override
  String toString() => message;
}
