import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/craving/controllers/craving_log_controller.dart';
import 'package:quit_companion/features/craving/data/fake_craving_log_repository.dart';
import 'package:quit_companion/features/craving/models/craving_log.dart';
import 'package:quit_companion/features/craving/models/relapse_risk_level.dart';
import 'package:quit_companion/features/craving/models/trigger_category.dart';
import 'package:quit_companion/features/crisis_support/domain/professional_support_check.dart';
import 'package:quit_companion/features/journal/models/mood.dart';
import 'package:quit_companion/features/relapse/data/fake_relapse_prediction_client.dart';

final _now = DateTime(2026, 11, 23, 12);

CravingLog _log(String id, DateTime at, {double? anxious, double? sad}) =>
    CravingLog(
      logId: id,
      userId: 'u1',
      cravingIntensity: 5,
      mood: Mood.sad,
      triggerCategory: TriggerCategory.stress,
      locationContext: 'Home',
      activity: 'Resting',
      timestamp: at,
      relapseRiskScore: RelapseRiskLevel.low,
      moodAnxious: anxious,
      moodSad: sad,
    );

void main() {
  const check = ProfessionalSupportCheck();

  group('ProfessionalSupportCheck (SRDS 4.2)', () {
    test(
      'three recent high anxiety OR sadness ratings trigger the suggestion',
      () {
        final logs = [
          _log('a', _now.subtract(const Duration(days: 1)), anxious: 9),
          _log('b', _now.subtract(const Duration(days: 3)), sad: 8),
          _log(
            'c',
            _now.subtract(const Duration(days: 6)),
            anxious: 10,
            sad: 2,
          ),
        ];
        expect(check.shouldSuggest(logs, now: _now), isTrue);
      },
    );

    test('two high ratings are not enough', () {
      final logs = [
        _log('a', _now.subtract(const Duration(days: 1)), anxious: 9),
        _log('b', _now.subtract(const Duration(days: 2)), sad: 9),
        _log('c', _now.subtract(const Duration(days: 2)), anxious: 7, sad: 7),
      ];
      expect(check.shouldSuggest(logs, now: _now), isFalse);
    });

    test('high ratings older than 14 days are ignored', () {
      final logs = [
        _log('a', _now.subtract(const Duration(days: 1)), anxious: 9),
        _log('b', _now.subtract(const Duration(days: 2)), sad: 9),
        _log('old', _now.subtract(const Duration(days: 15)), anxious: 10),
      ];
      expect(check.shouldSuggest(logs, now: _now), isFalse);
    });

    test('older logs without slider ratings never count', () {
      final logs = [
        for (var i = 0; i < 5; i++)
          _log('n$i', _now.subtract(Duration(days: i))),
      ];
      expect(check.shouldSuggest(logs, now: _now), isFalse);
    });

    test('the threshold is inclusive at 8', () {
      final logs = [
        for (var i = 0; i < 3; i++)
          _log('t$i', _now.subtract(Duration(days: i)), sad: 8),
      ];
      expect(check.shouldSuggest(logs, now: _now), isTrue);
    });
  });

  group('CravingLogController professional-support suggestion', () {
    var clock = _now;

    CravingLogController build(FakeCravingLogRepository repo) =>
        CravingLogController(
          repo,
          FakeRelapsePredictionClient(),
          now: () => clock,
        );

    Future<bool> submit(
      CravingLogController c, {
      double anxious = 5,
      double sad = 5,
    }) => c.submitCraving(
      userId: 'u1',
      intensity: 6,
      mood: Mood.sad,
      triggerCategory: TriggerCategory.stress,
      locationContext: 'Home',
      activity: 'Resting',
      moodAnxious: anxious,
      moodSad: sad,
    );

    setUp(() => clock = _now);

    test(
      'is raised on the third high rating, counting the log just saved',
      () async {
        final c = build(FakeCravingLogRepository());

        await submit(c, anxious: 9);
        expect(c.suggestProfessionalSupport, isFalse);
        clock = clock.add(const Duration(hours: 1));
        await submit(c, sad: 9);
        expect(c.suggestProfessionalSupport, isFalse);
        clock = clock.add(const Duration(hours: 1));
        await submit(c, anxious: 8);

        expect(c.status, CravingLogStatus.success);
        expect(c.suggestProfessionalSupport, isTrue);
      },
    );

    test('normal ratings never raise it', () async {
      final c = build(FakeCravingLogRepository());
      for (var i = 0; i < 4; i++) {
        clock = clock.add(const Duration(hours: 1));
        await submit(c, anxious: 6, sad: 7);
      }
      expect(c.suggestProfessionalSupport, isFalse);
    });

    test('once shown, it is not offered again for 7 days', () async {
      final repo = FakeCravingLogRepository();
      for (var i = 1; i <= 3; i++) {
        await repo.logCraving(
          _log('seed$i', _now.subtract(Duration(days: i)), anxious: 9),
        );
      }
      final c = build(repo);

      await submit(c, anxious: 9);
      expect(c.suggestProfessionalSupport, isTrue);
      c.markProfessionalSupportPromptShown();
      expect(c.suggestProfessionalSupport, isFalse);

      clock = _now.add(const Duration(days: 3));
      await submit(c, anxious: 9);
      expect(c.suggestProfessionalSupport, isFalse);

      clock = _now.add(const Duration(days: 8));
      await submit(c, anxious: 9);
      await submit(c, sad: 9);
      expect(c.suggestProfessionalSupport, isTrue);
    });

    test('a failed history lookup never blocks saving the craving', () async {
      final repo = _ThrowingRecentLogsRepository();
      final c = build(repo);

      final saved = await submit(c, anxious: 10, sad: 10);

      expect(saved, isTrue);
      expect(c.status, CravingLogStatus.success);
      expect(c.suggestProfessionalSupport, isFalse);
    });
  });
}

class _ThrowingRecentLogsRepository extends FakeCravingLogRepository {
  @override
  Future<List<CravingLog>> getRecentLogs(String userId, DateTime since) =>
      Future.error(Exception('offline'));
}
