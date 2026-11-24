import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/shared/domain/relative_time_formatter.dart';

void main() {
  final now = DateTime(2026, 8, 19, 12, 0);

  group('formatRelativeTime', () {
    test('less than a minute ago', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        'Just now',
      );
    });

    test('minutes ago', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
    });

    test('hours ago (matches the approved reference: "2h ago")', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 2)), now: now),
        '2h ago',
      );
    });

    test('days ago', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 3)), now: now),
        '3d ago',
      );
    });

    test('weeks ago falls back to a short date', () {
      expect(formatRelativeTime(DateTime(2026, 7, 1), now: now), 'Jul 1');
    });
  });
}
