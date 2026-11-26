import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_repository.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_chat_session_store.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';
import 'package:quit_companion/features/health_bot/models/health_bot_conversation.dart';
import 'package:quit_companion/features/health_bot/presentation/screens/health_bot_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _answer = HealthBotAnswer(
  type: HealthBotAnswerType.matched,
  responseText: 'Cravings usually pass within a few minutes.',
  source: HealthBotAnswerSource.ai,
);

/// Holds each reply until the test completes it.
class _PendingClient extends FakeHealthBotClient {
  Completer<HealthBotAnswer> reply = Completer();

  @override
  Future<HealthBotAnswer> ask({
    required String query,
    List<HealthBotTurn> history = const [],
    HealthBotUserContext? userContext,
  }) {
    askedQueries.add(query);
    askedHistories.add(List.unmodifiable(history));
    return reply.future;
  }
}

class _FailingStore implements HealthBotChatSessionStore {
  @override
  Future<String?> activeChatId(String userId) async =>
      throw Exception('storage unavailable');

  @override
  Future<void> saveActiveChatId(String userId, String chatId) async =>
      throw Exception('storage unavailable');

  @override
  Future<DateTime?> chatStartedAt(String userId) async =>
      throw Exception('storage unavailable');

  @override
  Future<void> saveChatStartedAt(String userId, DateTime startedAt) async =>
      throw Exception('storage unavailable');
}

HealthBotConversation _saved(String id, DateTime at, {String user = 'u1'}) =>
    HealthBotConversation(
      conversationId: id,
      userId: user,
      query: 'old question $id',
      botResponse: 'old answer $id',
      timestamp: at,
    );

void main() {
  // A clock that moves forward a minute per call, so every message and the
  // New Chat boundary get distinct, ordered times.
  late DateTime clock;
  DateTime tick() => clock = clock.add(const Duration(minutes: 1));

  setUp(() => clock = DateTime(2026, 11, 26, 12));

  group('HealthBotController.startNewChat', () {
    test('clears the chat and its context, keeping saved history', () async {
      final repository = FakeHealthBotRepository();
      final client = FakeHealthBotClient(nextAnswer: _answer);
      final controller = HealthBotController(client, repository, now: tick);

      await controller.sendQuery(userId: 'u1', text: 'Why do I crave?');
      await controller.sendQuery(userId: 'u1', text: 'and at night?');
      await Future<void>.delayed(Duration.zero); // fire-and-forget logging
      expect(controller.transcript, hasLength(4));
      expect(repository.logged, hasLength(2));

      await controller.startNewChat('u1');
      expect(controller.transcript, isEmpty);

      await controller.sendQuery(userId: 'u1', text: 'Fresh question');
      // No earlier messages are sent as context for the new chat.
      expect(client.askedHistories.last, isEmpty);
      expect(controller.transcript, hasLength(2));
      await Future<void>.delayed(Duration.zero);
      // Nothing deleted or overwritten: the new exchange is added.
      expect(repository.logged.map((c) => c.query), [
        'Why do I crave?',
        'and at night?',
        'Fresh question',
      ]);
    });

    test('after a restart only the current chat is shown', () async {
      final repository = FakeHealthBotRepository()
        ..logged.addAll([
          _saved('a', DateTime(2026, 11, 25, 9)),
          _saved('b', DateTime(2026, 11, 25, 10)),
        ]);
      final store = InMemoryHealthBotChatSessionStore();
      final first = HealthBotController(
        FakeHealthBotClient(nextAnswer: _answer),
        repository,
        now: tick,
        chatSessionStore: store,
      );
      await first.loadHistory('u1');
      expect(first.transcript, hasLength(4));

      await first.startNewChat('u1');
      await first.sendQuery(userId: 'u1', text: 'New chat question');
      await Future<void>.delayed(Duration.zero);

      // A new controller with the same saved data = the app reopened.
      final reopened = HealthBotController(
        FakeHealthBotClient(nextAnswer: _answer),
        repository,
        now: tick,
        chatSessionStore: store,
      );
      await reopened.loadHistory('u1');
      expect(reopened.transcript.map((m) => m.text), [
        'New chat question',
        _answer.responseText,
      ]);
      expect(repository.logged, hasLength(3)); // all still saved
    });

    test('without a New Chat the full saved history loads as before', () async {
      final repository = FakeHealthBotRepository()
        ..logged.addAll([
          _saved('a', DateTime(2026, 11, 25, 9)),
          _saved('b', DateTime(2026, 11, 25, 10)),
        ]);
      final controller = HealthBotController(
        FakeHealthBotClient(),
        repository,
        chatSessionStore: InMemoryHealthBotChatSessionStore(),
      );
      await controller.loadHistory('u1');
      expect(controller.transcript, hasLength(4));
    });

    test('a New Chat for one account does not hide another account\'s chat',
        () async {
      final repository = FakeHealthBotRepository()
        ..logged.addAll([
          _saved('a', DateTime(2026, 11, 25, 9)),
          _saved('x', DateTime(2026, 11, 25, 9), user: 'u2'),
        ]);
      final store = InMemoryHealthBotChatSessionStore();
      final controller = HealthBotController(
        FakeHealthBotClient(),
        repository,
        now: tick,
        chatSessionStore: store,
      );
      await controller.loadHistory('u1');
      await controller.startNewChat('u1');
      controller.clearSession();
      await controller.loadHistory('u2');
      expect(controller.transcript, hasLength(2));
    });

    test('is only offered when there is something to start over from', () async {
      final client = _PendingClient();
      final controller = HealthBotController(
        client,
        FakeHealthBotRepository(),
        now: tick,
      );
      expect(controller.canStartNewChat, isFalse); // empty chat

      final sending = controller.sendQuery(userId: 'u1', text: 'Hi');
      expect(controller.status, HealthBotStatus.sending);
      expect(controller.canStartNewChat, isFalse); // reply pending
      await controller.startNewChat('u1'); // ignored while sending
      expect(controller.transcript, hasLength(1));

      client.reply.complete(_answer);
      await sending;
      expect(controller.canStartNewChat, isTrue);
    });

    test('works for this session even if device storage fails', () async {
      final repository = FakeHealthBotRepository()
        ..logged.add(_saved('a', DateTime(2026, 11, 25, 9)));
      final controller = HealthBotController(
        FakeHealthBotClient(nextAnswer: _answer),
        repository,
        now: tick,
        chatSessionStore: _FailingStore(),
      );
      await controller.loadHistory('u1');
      expect(controller.transcript, hasLength(2)); // read failure: as before
      await controller.startNewChat('u1');
      expect(controller.transcript, isEmpty);
      await controller.loadHistory('u1'); // already current for this session
      expect(controller.transcript, isEmpty);
    });
  });

  test('the device store keeps a separate start time per account', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesHealthBotChatSessionStore();
    expect(await store.chatStartedAt('u1'), isNull);
    final at = DateTime(2026, 11, 26, 18, 30);
    await store.saveChatStartedAt('u1', at);
    expect(await store.chatStartedAt('u1'), at);
    expect(await store.chatStartedAt('u2'), isNull);
    expect(
      await SharedPreferencesHealthBotChatSessionStore().chatStartedAt('u1'),
      at,
    );
  });

  group('New Chat button', () {
    Future<HealthBotController> pumpScreen(
      WidgetTester tester, {
      required FakeHealthBotClient client,
      FakeHealthBotRepository? repository,
    }) async {
      final controller = HealthBotController(
        client,
        repository ?? FakeHealthBotRepository(),
        now: tick,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HealthBotScreen(userId: 'u1', controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('healthbot_disclaimer_acknowledge_button')),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    Future<void> ask(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const Key('healthbot_input_field')), text);
      await tester.tap(find.byKey(const Key('healthbot_send_button')));
      await tester.pumpAndSettle();
    }

    IconButton newChatButton(WidgetTester tester) => tester.widget<IconButton>(
      find.byKey(const Key('healthbot_new_chat_button')),
    );

    testWidgets(
      'starts a fresh chat: clears the screen and context, keeps saved messages',
      (tester) async {
        final client = FakeHealthBotClient(nextAnswer: _answer);
        final repository = FakeHealthBotRepository();
        await pumpScreen(tester, client: client, repository: repository);

        // Visible next to Crisis support; nothing to clear yet.
        expect(
          find.byKey(const Key('healthbot_new_chat_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('healthbot_crisis_support_button')),
          findsOneWidget,
        );
        expect(find.byTooltip('New chat'), findsOneWidget);
        expect(newChatButton(tester).onPressed, isNull);

        await ask(tester, 'Why do I crave after meals?');
        expect(find.text('Why do I crave after meals?'), findsOneWidget);
        expect(newChatButton(tester).onPressed, isNotNull);

        await tester.enterText(
          find.byKey(const Key('healthbot_input_field')),
          'half-typed draft',
        );
        await tester.tap(find.byKey(const Key('healthbot_new_chat_button')));
        await tester.pumpAndSettle();

        expect(find.text('Why do I crave after meals?'), findsNothing);
        expect(find.text(_answer.responseText), findsNothing);
        expect(find.byKey(const Key('healthbot_empty_state')), findsOneWidget);
        expect(find.text('half-typed draft'), findsNothing);
        expect(
          find.byKey(const Key('healthbot_new_chat_notice')),
          findsOneWidget,
        );
        expect(newChatButton(tester).onPressed, isNull);

        await ask(tester, 'Fresh start question');
        expect(find.byKey(const Key('healthbot_new_chat_notice')), findsNothing);
        expect(client.askedHistories.last, isEmpty);
        expect(find.text('Fresh start question'), findsOneWidget);
        expect(find.text('Why do I crave after meals?'), findsNothing);
        await tester.pump();
        expect(repository.logged.map((c) => c.query), [
          'Why do I crave after meals?',
          'Fresh start question',
        ]);
      },
    );

    testWidgets('is disabled while a reply is on its way', (tester) async {
      final client = _PendingClient();
      final controller = await pumpScreen(tester, client: client);

      await tester.enterText(
        find.byKey(const Key('healthbot_input_field')),
        'Are cravings normal?',
      );
      await tester.tap(find.byKey(const Key('healthbot_send_button')));
      await tester.pump();
      expect(find.byKey(const Key('healthbot_typing_indicator')), findsOneWidget);
      expect(newChatButton(tester).onPressed, isNull);

      client.reply.complete(_answer);
      await tester.pumpAndSettle();
      expect(controller.transcript, hasLength(2));
      expect(newChatButton(tester).onPressed, isNotNull);
    });
  });
}
