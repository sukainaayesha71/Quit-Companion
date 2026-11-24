import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/onboarding/domain/quit_date_calculator.dart';
import 'package:quit_companion/features/onboarding/models/quit_strategy.dart';

void main() {
  final fixedToday = DateTime(2026, 8, 11);
  QuitDateCalculator calculator() => QuitDateCalculator(now: () => fixedToday);

  test('COLD_TURKEY sets quitDate to today and no reduction schedule', () {
    final result = calculator().determineQuitDate(
      quitStrategy: QuitStrategy.coldTurkey,
      baselineDailyUsage: 10,
    );

    expect(result.quitDate, fixedToday);
    expect(result.reductionSchedule, isNull);
  });

  test('DATE_BASED requires selectedTargetDate', () {
    expect(
      () => calculator().determineQuitDate(
        quitStrategy: QuitStrategy.dateBased,
        baselineDailyUsage: 10,
      ),
      throwsArgumentError,
    );
  });

  test('DATE_BASED rejects a target date that is not in the future', () {
    expect(
      () => calculator().determineQuitDate(
        quitStrategy: QuitStrategy.dateBased,
        baselineDailyUsage: 10,
        selectedTargetDate: fixedToday,
      ),
      throwsArgumentError,
    );
  });

  test('DATE_BASED uses the selected date with no reduction schedule', () {
    final target = DateTime(2026, 9, 1);
    final result = calculator().determineQuitDate(
      quitStrategy: QuitStrategy.dateBased,
      baselineDailyUsage: 10,
      selectedTargetDate: target,
    );

    expect(result.quitDate, target);
    expect(result.reductionSchedule, isNull);
  });

  test('GRADUAL requires selectedTargetDate', () {
    expect(
      () => calculator().determineQuitDate(
        quitStrategy: QuitStrategy.gradual,
        baselineDailyUsage: 10,
      ),
      throwsArgumentError,
    );
  });

  test('GRADUAL builds a linear taper from baseline to 0 by quitDate', () {
    final target = fixedToday.add(const Duration(days: 5));
    final result = calculator().determineQuitDate(
      quitStrategy: QuitStrategy.gradual,
      baselineDailyUsage: 10,
      selectedTargetDate: target,
    );

    expect(result.quitDate, target);
    final schedule = result.reductionSchedule!;
    expect(
      schedule.length,
      6,
    ); // day 0 (today) through day 5 (quitDate), inclusive
    expect(schedule[fixedToday], 10.0);
    expect(schedule[fixedToday.add(const Duration(days: 1))], 8.0);
    expect(schedule[target], 0.0);
  });
}
