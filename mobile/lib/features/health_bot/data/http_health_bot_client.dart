import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';

/// Real implementation — calls the FastAPI backend's POST /healthbot/query,
/// which requires a Firebase ID token (backend/app/firebase_auth_dependency.py),
/// mirroring HttpRelapsePredictionClient's auth-attachment pattern exactly.
class HttpHealthBotClient implements HealthBotClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function() _getIdToken;

  /// Hard ceiling for one request. The backend gives Gemini a fixed budget
  /// (HEALTHBOT_GEMINI_TIMEOUT_SECONDS, 10 s in production) and then answers
  /// from the curated knowledge, so a healthy backend replies inside this.
  /// The extra margin is for slow mobile networks (a new HTTPS connection to
  /// the server can take ~2-3 s on its own); past it, the controller offers
  /// "Try again" rather than leave the user waiting.
  final Duration requestTimeout;
  static const defaultRequestTimeout = Duration(seconds: 16);

  HttpHealthBotClient({
    required this.baseUrl,
    http.Client? httpClient,
    Future<String?> Function()? getIdToken,
    this.requestTimeout = defaultRequestTimeout,
  }) : _httpClient = httpClient ?? http.Client(),
       _getIdToken = getIdToken ?? _defaultGetIdToken;

  static Future<String?> _defaultGetIdToken() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  static const _defaultError =
      'Could not reach the Health-Bot. Please try again.';

  @override
  Future<HealthBotAnswer> ask({
    required String query,
    List<HealthBotTurn> history = const [],
    HealthBotUserContext? userContext,
  }) async {
    final String? idToken;
    try {
      idToken = await _getIdToken();
    } catch (_) {
      throw HealthBotAuthException(
        'Could not verify your sign-in. Please sign in again.',
      );
    }
    if (idToken == null || idToken.isEmpty) {
      throw HealthBotAuthException('Please sign in to use the Health-Bot.');
    }

    final http.Response response;
    try {
      debugPrint('HttpHealthBotClient calling URL: $baseUrl/healthbot/query');
      response = await _httpClient
          .post(
            Uri.parse('$baseUrl/healthbot/query'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'query': query,
              if (history.isNotEmpty)
                'history': [for (final turn in history) turn.toJson()],
              if (userContext != null && !userContext.isEmpty)
                'user_context': userContext.toJson(),
            }),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw HealthBotTimeoutException(
        'The Health-Bot is taking too long to respond.',
      );
    } catch (e, st) {
      debugPrint('HttpHealthBotClient failed: $e\n$st');
      throw HealthBotUnreachableException(
        'Could not reach the Health-Bot service. Check your connection.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw HealthBotAuthException(
        'Your sign-in has expired. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      throw HealthBotClientException(_extractDetail(response) ?? _defaultError);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final type = _parseAnswerType(data['answer_type'] as String?);
    final responseText = data['response_text'] as String?;
    if (type == null || responseText == null) {
      throw HealthBotClientException(_defaultError);
    }
    return HealthBotAnswer(
      type: type,
      responseText: responseText,
      sources: _parseSources(data),
      // Missing on older backends: unknown source, no fallback reason.
      source: parseHealthBotAnswerSource(data['answer_source']),
      fallbackReason: parseHealthBotFallbackReason(data['fallback_reason']),
    );
  }

  /// Prefers `sources` (title + url); falls back to the older `source_urls`
  /// list from backends that predate titles. Non-https entries are dropped.
  List<HealthBotSource> _parseSources(Map<String, dynamic> data) {
    final rich = data['sources'];
    if (rich is List && rich.isNotEmpty) {
      return [for (final item in rich) ?HealthBotSource.fromMap(item)];
    }
    final urls = data['source_urls'];
    if (urls is List) {
      return [
        for (final url in urls)
          if (url is String && url.startsWith('https://'))
            HealthBotSource(title: Uri.parse(url).host, url: url),
      ];
    }
    return const [];
  }

  HealthBotAnswerType? _parseAnswerType(String? value) {
    for (final type in HealthBotAnswerType.values) {
      if (type.name == value) return type;
    }
    return null;
  }

  String? _extractDetail(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = data['detail'];
      return detail is String ? detail : null;
    } catch (_) {
      return null;
    }
  }
}
