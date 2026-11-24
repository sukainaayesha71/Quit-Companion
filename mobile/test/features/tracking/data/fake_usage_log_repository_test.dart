import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/tracking/data/fake_usage_log_repository.dart';
import 'package:quit_companion/features/tracking/models/usage_log.dart';

void main() {
  test(
    'getUsageLogs returns an empty list when nothing was ever logged',
    () async {
      final repo = FakeUsageLogRepository();

      expect(await repo.getUsageLogs('user1'), isEmpty);
    },
  );

  test('logUsage persists a log retrievable by userId', () async {
    final repo = FakeUsageLogRepository();
    final log = UsageLog(
      logId: '2026-08-13',
      userId: 'user1',
      date: DateTime(2026, 8, 13),
      actualUsage: 8,
      targetUsage: 10,
    );

    await repo.logUsage(log);

    final logs = await repo.getUsageLogs('user1');
    expect(logs, hasLength(1));
    expect(logs.first.actualUsage, 8);
    expect(logs.first.targetUsage, 10);
  });

  test('getUsageLogs only returns logs for the requested userId', () async {
    final repo = FakeUsageLogRepository();
    await repo.logUsage(
      UsageLog(
        logId: 'a',
        userId: 'user1',
        date: DateTime(2026, 8, 13),
        actualUsage: 8,
        targetUsage: 10,
      ),
    );
    await repo.logUsage(
      UsageLog(
        logId: 'b',
        userId: 'user2',
        date: DateTime(2026, 8, 13),
        actualUsage: 5,
        targetUsage: 5,
      ),
    );

    final logs = await repo.getUsageLogs('user1');
    expect(logs, hasLength(1));
    expect(logs.first.userId, 'user1');
  });

  test('getUsageLogs returns logs sorted by date ascending', () async {
    final repo = FakeUsageLogRepository();
    await repo.logUsage(
      UsageLog(
        logId: 'later',
        userId: 'user1',
        date: DateTime(2026, 8, 15),
        actualUsage: 6,
        targetUsage: 8,
      ),
    );
    await repo.logUsage(
      UsageLog(
        logId: 'earlier',
        userId: 'user1',
        date: DateTime(2026, 8, 13),
        actualUsage: 9,
        targetUsage: 10,
      ),
    );

    final logs = await repo.getUsageLogs('user1');
    expect(logs.map((l) => l.date), [
      DateTime(2026, 8, 13),
      DateTime(2026, 8, 15),
    ]);
  });
}
