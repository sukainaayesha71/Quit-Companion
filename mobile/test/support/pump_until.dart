import 'package:flutter_test/flutter_test.dart';

/// Pumps in small increments until [condition] is true or [timeout] is
/// reached. Needed for screens with a continuously-running animation or
/// timer (this game's AnimationController keeps cycling for ~2 minutes;
/// Bubble Pop's bubbles float/respawn forever) — `pumpAndSettle()` either
/// never returns or, worse, silently fast-forwards through the entire
/// remaining animation before your test gets to assert anything.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition not met within $timeout');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
