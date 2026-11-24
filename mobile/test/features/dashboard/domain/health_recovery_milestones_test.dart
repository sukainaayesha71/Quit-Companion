import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/dashboard/domain/health_recovery_milestones.dart';
import 'package:quit_companion/features/onboarding/models/product_type.dart';

void main() {
  test(
    'nicotine pouches show the research-limits source, not smoking dates',
    () {
      final timeline = healthRecoveryMilestonesFor(ProductType.pouches);

      expect(timeline, hasLength(5));
      expect(timeline.last.sourceTitle, 'CDC: Nicotine Pouches');
      expect(timeline.last.description, contains('has not been established'));
      expect(
        timeline.any((milestone) => milestone.timeframe == 'Minutes'),
        isFalse,
      );
    },
  );

  test('hookah shows hookah-specific evidence limits, not smoking dates', () {
    final timeline = healthRecoveryMilestonesFor(ProductType.hookah);

    expect(timeline, hasLength(5));
    expect(timeline.last.sourceTitle, 'CDC: Hookahs');
    expect(
      timeline.any((milestone) => milestone.timeframe == 'Minutes'),
      isFalse,
    );
  });
}
