import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';

/// Test double — returns a caller-configured canned answer, or an
/// exception if [failWith] is set. Records every asked query for
/// assertions.
class FakeHealthBotClient implements HealthBotClient {
  HealthBotAnswer nextAnswer;
  Object? failWith;
  final List<String> askedQueries = [];

  FakeHealthBotClient({
    this.nextAnswer = const HealthBotAnswer(
      type: HealthBotAnswerType.unmatched,
      responseText:
          'I cannot answer this confidently. Please consult a doctor.',
    ),
  });

  @override
  Future<HealthBotAnswer> ask({required String query}) async {
    askedQueries.add(query);
    if (failWith != null) throw failWith!;
    return nextAnswer;
  }
}
