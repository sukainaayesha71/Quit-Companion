import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/controllers/alternatives_controller.dart';
import 'package:quit_companion/features/craving/data/fake_habit_alternative_attempt_repository.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/goals/data/coaching_client.dart';
import 'package:quit_companion/features/journal/models/mood.dart';

/// The alternatives list must say honestly who ordered it: the server's
/// personalised model, or the app's own rules when the model is unreachable.
class _Coaching extends CoachingClient {
  final List<String>? order;
  _Coaching(this.order)
    : super(baseUrl: 'http://unused.invalid', getToken: () async => 't');

  @override
  Future<List<String>> rank(String trigger, String mood) async {
    if (order == null) throw Exception('503 model unavailable');
    return order!;
  }
}

Future<AlternativesController> _load(CoachingClient? coaching) async {
  final controller = AlternativesController(
    FakeHabitAlternativeAttemptRepository(),
    coachingClient: coaching,
  );
  await controller.loadRecommendations(
    userId: 'u1',
    triggerCategory: TriggerCategory.stress,
    mood: Mood.stressed,
  );
  return controller;
}

void main() {
  test('the model\'s order is used and labelled as the personalised model', () async {
    final local = (await _load(null)).recommendations;
    final reversed = local.reversed.map((a) => a.alternativeId).toList();

    final controller = await _load(_Coaching(reversed));

    expect(
      controller.rankingSource,
      RecommendationRankingSource.personalisedModel,
    );
    expect(
      controller.recommendations.map((a) => a.alternativeId).toList(),
      reversed,
    );
  });

  test('an unreachable model falls back to on-device rules, said so', () async {
    final controller = await _load(_Coaching(null));
    expect(
      controller.rankingSource,
      RecommendationRankingSource.onDeviceRules,
    );
    expect(controller.recommendations, isNotEmpty);
  });

  test('no backend configured also reports on-device rules', () async {
    final controller = await _load(null);
    expect(
      controller.rankingSource,
      RecommendationRankingSource.onDeviceRules,
    );
  });
}
