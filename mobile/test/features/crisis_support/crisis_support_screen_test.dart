import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quit_companion/features/crisis_support/data/crisis_helplines.dart';
import 'package:quit_companion/features/crisis_support/data/helpline_launcher.dart';
import 'package:quit_companion/features/crisis_support/presentation/screens/crisis_support_screen.dart';

class FakeHelplineLauncher implements HelplineLauncher {
  final bool succeed;
  final List<String> calls = [];
  final List<String> texts = [];
  final List<String> websites = [];

  FakeHelplineLauncher({this.succeed = true});

  @override
  Future<bool> call(String number) async {
    calls.add(number);
    return succeed;
  }

  @override
  Future<bool> text(String number) async {
    texts.add(number);
    return succeed;
  }

  @override
  Future<bool> openWebsite(String url) async {
    websites.add(url);
    return succeed;
  }
}

void main() {
  // Each SelectableText has its own Scrollable, so scrolling must target
  // the screen's ListView explicitly.
  final listScrollable = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;

  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> pump(WidgetTester tester, HelplineLauncher launcher) async {
    await tester.pumpWidget(
      MaterialApp(home: CrisisSupportScreen(launcher: launcher)),
    );
    await tester.pumpAndSettle();
  }

  group('verified helpline data', () {
    test('every entry has a source and either a number or a website', () {
      for (final h in crisisHelplines) {
        expect(h.source, isNotEmpty, reason: h.id);
        expect(h.dialNumber != null || h.website != null, isTrue, reason: h.id);
        if (h.dialNumber != null) {
          expect(h.displayNumber, isNotNull, reason: h.id);
          expect(RegExp(r'^\d+$').hasMatch(h.dialNumber!), isTrue);
        }
      }
    });

    test(
      'covers Pakistan emergency, Pakistan counselling and international',
      () {
        final ids = crisisHelplines.map((h) => h.id).toSet();
        expect(ids, containsAll(['pk_rescue_1122', 'pk_umang', 'pk_rozan']));
        expect(
          crisisHelplines.where(
            (h) => h.region == HelplineRegion.international,
          ),
          isNotEmpty,
        );
      },
    );
  });

  testWidgets('lists every helpline with the emergency notice and disclaimer', (
    tester,
  ) async {
    await pump(tester, FakeHelplineLauncher());

    expect(
      find.byKey(const Key('crisis_support_emergency_notice')),
      findsOneWidget,
    );
    for (final h in crisisHelplines) {
      await tester.scrollUntilVisible(
        find.byKey(Key('crisis_helpline_${h.id}')),
        200,
        scrollable: listScrollable,
      );
      expect(find.byKey(Key('crisis_helpline_${h.id}')), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('crisis_support_footer')),
      200,
      scrollable: listScrollable,
    );
    expect(find.byKey(const Key('crisis_support_footer')), findsOneWidget);
  });

  testWidgets('Call dials the verified number', (tester) async {
    await useTallSurface(tester);
    final launcher = FakeHelplineLauncher();
    await pump(tester, launcher);

    await tester.tap(find.byKey(const Key('crisis_call_pk_rescue_1122')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('crisis_call_pk_umang')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('crisis_call_pk_rozan')));
    await tester.pump();

    expect(launcher.calls, ['1122', '03117786264', '03041111741']);
  });

  testWidgets('Text and Website open the right targets', (tester) async {
    await useTallSurface(tester);
    final launcher = FakeHelplineLauncher();
    await pump(tester, launcher);

    await tester.tap(find.byKey(const Key('crisis_text_intl_988')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('crisis_web_intl_find_a_helpline')));
    await tester.pump();

    expect(launcher.texts, ['988']);
    expect(launcher.websites, ['https://findahelpline.com']);
  });

  testWidgets('if the dialer cannot open, the number is copied instead', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pump(tester, FakeHelplineLauncher(succeed: false));
    await tester.tap(find.byKey(const Key('crisis_call_pk_rescue_1122')));
    await tester.pumpAndSettle();

    expect(copied, '1122');
    expect(find.textContaining('1122 was copied'), findsOneWidget);
  });

  testWidgets('fits a 320x640 screen at 1.5x text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() async {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    });

    await pump(tester, FakeHelplineLauncher());
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
