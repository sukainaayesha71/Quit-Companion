import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class CoachingPlan {
  final List<String> steps;
  final String source;
  const CoachingPlan(this.steps, this.source);
}

class CoachingClient {
  final String baseUrl;
  final http.Client client;
  final Future<String?> Function() getToken;
  CoachingClient({
    required this.baseUrl,
    http.Client? client,
    Future<String?> Function()? getToken,
  }) : client = client ?? http.Client(),
       getToken =
           getToken ??
           (() async => FirebaseAuth.instance.currentUser?.getIdToken());

  Future<Map<String, dynamic>> _post(
    String path,
    String trigger,
    String mood,
  ) async {
    final token = await getToken();
    if (token == null) {
      throw StateError('Sign in to use personalized coaching.');
    }
    final response = await client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'trigger_category': trigger, 'mood': mood}),
        )
        .timeout(Duration(seconds: path.startsWith('/plans/') ? 30 : 5));
    if (response.statusCode != 200) {
      throw StateError('Coaching service is unavailable.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<CoachingPlan> plan(
    String kind, {
    String trigger = 'other',
    String mood = 'happy',
  }) async {
    final data = await _post('/plans/$kind', trigger, mood);
    final steps = (data['steps'] as List).cast<String>();
    if (steps.isEmpty) throw StateError('The plan was empty.');
    return CoachingPlan(steps, data['source'] as String);
  }

  Future<List<String>> rank(String trigger, String mood) async {
    final data = await _post('/recommend/alternative', trigger, mood);
    return (data['recommendations'] as List)
        .map((item) => (item as Map)['alternative_id'] as String)
        .toList();
  }
}
