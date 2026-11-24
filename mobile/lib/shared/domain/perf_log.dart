import 'package:flutter/foundation.dart';

/// Step 13 performance instrumentation. Prints one `[perf] <metric> <ms>ms`
/// line in debug/profile builds so on-device timings can be collected with
/// `adb logcat | grep "\[perf\]"`. Silent in release builds. Never logs user
/// content — metric names and durations only.
void logPerf(String metric, Duration elapsed) {
  if (kReleaseMode) return;
  debugPrint('[perf] $metric ${elapsed.inMilliseconds}ms');
}
