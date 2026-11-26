import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quit_companion/features/health_bot/controllers/health_bot_controller.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/fake_health_bot_repository.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_chat_session_store.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';
import 'package:quit_companion/features/health_bot/domain/health_bot_chats.dart';
import 'package:quit_companion/features/health_bot/models/health_bot_conversation.dart';
import 'package:quit_companion/features/health_bot/presentation/screens/health_bot_history_screen.dart';
import 'package:quit_companion/features/health_bot/presentation/screens/health_bot_screen.dart';

const _answer = HealthBotAnswer(
  type: HealthBotAnswerType.matched,
  responseText: 'Here is a helpful answer.',
  source: HealthBotAnswerSource.ai,
);

HealthBotConversation _exchange(
  String id,
  DateTime at, {
  String user = 'u1',
  String? sessionId,
  String? query,
}) => HealthBotConversation(
  conversationId: id,
  userId: user,
  query: query ?? 'question $id',
  botResponse: 'answer $id',
  timestamp: at,
  sessionId: sessionId,
);

/// Holds getConversations until [gate] completes (loading-state tests).
class _SlowRepository extends FakeHealthBotRepository {
  Completer<void>? gate;

  @override
  Future<List<HealthBotConversation>> getConversations(String userId) async {
    final pending = gate;
    if (pending != null) await pending.future;
    return super.getConversations(userId);
  }
}

/// Returns another account's exchange too, to prove the app filters it out.
class _LeakyRepository extends FakeHealthBotRepository {
  @override
  Future<List<HealthBotConversation>> getConversations(String userId) async =>
      logged.toList();
}

void main() {
  late DateTime clock;
  DateTime tick() => clock = clock.add(const Duration(minutes: 1));
  setUp(() => clock = DateTime(2026, 11, 26, 12));

  HealthBotController controllerFor(
    FakeHealthBotRepository repository, {
    FakeHealthBotClient? client,
    HealthBotChatSessionStore? store,
  }) => HealthBotController(
    client ?? FakeHealthBotClient(nextAnswer: _answer),
    repository,
    now: tick,
    chatSessionStore: store ?? InMemoryHealthBotChatSessionStore(),
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('grouping saved exchanges into chats', () {
    test('by sessionId, most recently active first', () {
      final chats = groupIntoChats([
        _exchange('1', DateTime(2026, 11, 20, 9), sessionId: 'a'),
        _exchange('2', DateTime(2026, 11, 21, 9), sessionId: 'b'),
        _exchange('3', DateTime(2026, 11, 22, 9), sessionId: 'a'),
      ]);
      expect(chats.map((c) => c.id), ['a', 'b']);
      expect(chats.first.exchanges.map((e) => e.conversationId), ['1', '3']);
      expect(chats.first.title, 'question 1');
      expect(chats.first.questionCount, 2);
    });

    test('older exchanges without a sessionId are split by pauses', () {
      final chats = groupIntoChats([
        _exchange('1', DateTime(2026, 11, 20, 9)),
        _exchange('2', DateTime(2026, 11, 20, 9, 20)),
        _exchange('3', DateTime(2026, 11, 20, 14)), // > 1 h later
      ]);
      expect(chats, hasLength(2));
      expect(chats.last.id, 'legacy_1');
      expect(chats.last.questionCount, 2);
      expect(chats.first.id, 'legacy_3');
    });

    test('an earlier New Chat start also splits older exchanges', () {
      final chats = groupIntoChats([
        _exchange('1', DateTime(2026, 11, 26, 9)),
        _exchange('2', DateTime(2026, 11, 26, 9, 10)),
      ], legacyBoundary: DateTime(2026, 11, 26, 9, 5));
      expect(chats, hasLength(2));
    });

    test('continuing an older chat keeps the new messages in it', () {
      final chats = groupIntoChats([
        _exchange('1', DateTime(2026, 11, 20, 9)),
        _exchange('2', DateTime(2026, 11, 26, 9), sessionId: 'legacy_1'),
      ]);
      expect(chats.single.id, 'legacy_1');
      expect(chats.single.questionCount, 2);
    });

    test('titles come from the first question, shortened', () {
      expect(chatTitleFor('  How long   does\nwithdrawal last? '),
          'How long does withdrawal last?');
      final long = chatTitleFor(
        'Can you make a seven day recovery plan for me because I keep '
        'relapsing on the third day every single time',
      );
      expect(long.length, lessThanOrEqualTo(61));
      expect(long, endsWith('…'));
      expect(long, startsWith('Can you make a seven day recovery plan'));
      expect(chatTitleFor('   '), 'Conversation');
    });

    test('dates and times are readable', () {
      expect(formatChatDateTime(DateTime(2026, 11, 26, 21, 5)),
          '26 Nov 2026, 9:05 PM');
      expect(formatChatDateTime(DateTime(2026, 1, 2, 0, 0)),
          '2 Jan 2026, 12:00 AM');
      expect(formatChatDateTime(DateTime(2026, 6, 9, 12, 30)),
          '9 Jun 2026, 12:30 PM');
    });
  });

  group('chats in the controller', () {
    test('messages are saved with their chat and time', () async {
      final repository = FakeHealthBotRepository();
      final controller = controllerFor(repository);
      await controller.loadHistory('u1');

      await controller.sendQuery(userId: 'u1', text: 'Why do I crave at night?');
      await controller.sendQuery(userId: 'u1', text: 'What helps?');
      await settle();

      final chatId = controller.currentChatId;
      expect(chatId, isNotNull);
      expect(repository.logged.map((e) => e.sessionId).toSet(), {chatId});
      expect(repository.logged.map((e) => e.timestamp).toSet(), hasLength(2));
      expect(controller.chats.single.title, 'Why do I crave at night?');
      expect(controller.chats.single.questionCount, 2);
    });

    test('New Chat keeps the old chat and starts with clean context', () async {
      final repository = FakeHealthBotRepository();
      final client = FakeHealthBotClient(nextAnswer: _answer);
      final controller = controllerFor(repository, client: client);
      await controller.loadHistory('u1');
      await controller.sendQuery(userId: 'u1', text: 'First chat question');
      final firstChat = controller.currentChatId;

      await controller.startNewChat('u1');
      expect(controller.currentChatId, isNot(firstChat));
      await controller.sendQuery(userId: 'u1', text: 'Second chat question');
      await settle();

      expect(client.askedHistories.last, isEmpty);
      expect(controller.chats.map((c) => c.title), [
        'Second chat question',
        'First chat question',
      ]);
      expect(repository.logged, hasLength(2));
    });

    test('an old chat opens with only its messages and continues there', () async {
      final repository = FakeHealthBotRepository();
      final client = FakeHealthBotClient(nextAnswer: _answer);
      final controller = controllerFor(repository, client: client);
      await controller.loadHistory('u1');
      await controller.sendQuery(userId: 'u1', text: 'About sleep');
      final sleepChat = controller.currentChatId!;
      await controller.startNewChat('u1');
      await controller.sendQuery(userId: 'u1', text: 'About coffee');

      await controller.openChat('u1', sleepChat);
      expect(controller.transcript.map((m) => m.text), [
        'About sleep',
        _answer.responseText,
      ]);

      await controller.sendQuery(userId: 'u1', text: 'And naps?');
      await settle();
      // Context is this chat only — nothing from the coffee chat.
      expect(client.askedHistories.last, const [
        HealthBotTurn(fromUser: true, text: 'About sleep'),
        HealthBotTurn(fromUser: false, text: 'Here is a helpful answer.'),
      ]);
      expect(repository.logged.last.sessionId, sleepChat);
      expect(controller.chats.first.id, sleepChat); // most recent now
      expect(controller.chats.first.questionCount, 2);
    });

    test('older history without chats can be opened and continued, unchanged',
        () async {
      final repository = FakeHealthBotRepository()
        ..logged.addAll([
          _exchange('1', DateTime(2026, 11, 20, 9), query: 'Old headache question'),
          _exchange('2', DateTime(2026, 11, 24, 9), query: 'Old sleep question'),
        ]);
      final controller = controllerFor(repository);
      await controller.loadHistory('u1');
      expect(controller.chats.map((c) => c.title), [
        'Old sleep question',
        'Old headache question',
      ]);
      // Opens on the most recent conversation, as before.
      expect(controller.transcript.first.text, 'Old sleep question');

      await controller.openChat('u1', 'legacy_1');
      await controller.sendQuery(userId: 'u1', text: 'Still getting headaches');
      await settle();
      expect(repository.logged.last.sessionId, 'legacy_1');
      // The saved older exchanges were not rewritten.
      expect(repository.logged.take(2).map((e) => e.sessionId), [null, null]);
      expect(
        controller.chats.firstWhere((c) => c.id == 'legacy_1').questionCount,
        2,
      );
    });

    test('the open chat is remembered after a restart', () async {
      final repository = FakeHealthBotRepository();
      final store = InMemoryHealthBotChatSessionStore();
      final first = controllerFor(repository, store: store);
      await first.loadHistory('u1');
      await first.sendQuery(userId: 'u1', text: 'Chat A');
      final chatA = first.currentChatId!;
      await first.startNewChat('u1');
      await first.sendQuery(userId: 'u1', text: 'Chat B');
      await first.openChat('u1', chatA);
      await settle();

      final reopened = controllerFor(repository, store: store);
      await reopened.loadHistory('u1');
      expect(reopened.currentChatId, chatA);
      expect(reopened.transcript.first.text, 'Chat A');
      expect(reopened.chats, hasLength(2));
    });

    test('switching accounts shows only that account\'s chats', () async {
      final repository = FakeHealthBotRepository()
        ..logged.addAll([
          _exchange('a1', DateTime(2026, 11, 25, 9), query: 'Ayesha question'),
          _exchange('b1', DateTime(2026, 11, 25, 10), user: 'u2', query: 'Other user question'),
        ]);
      final store = InMemoryHealthBotChatSessionStore();
      final controller = controllerFor(repository, store: store);

      await controller.loadHistory('u1');
      expect(controller.chats.map((c) => c.title), ['Ayesha question']);
      await controller.startNewChat('u1');
      await controller.sendQuery(userId: 'u1', text: 'u1 new chat');

      controller.clearSession(); // sign out
      expect(controller.chats, isEmpty);
      expect(controller.transcript, isEmpty);

      await controller.loadHistory('u2');
      expect(controller.chats.map((c) => c.title), ['Other user question']);
      expect(controller.transcript.first.text, 'Other user question');

      controller.clearSession();
      await controller.loadHistory('u1');
      expect(controller.chats.map((c) => c.title), [
        'u1 new chat',
        'Ayesha question',
      ]);
      expect(controller.transcript.first.text, 'u1 new chat');
    });

    test('another account\'s exchanges are never shown', () async {
      final repository = _LeakyRepository()
        ..logged.addAll([
          _exchange('a1', DateTime(2026, 11, 25, 9)),
          _exchange('b1', DateTime(2026, 11, 25, 10), user: 'u2'),
        ]);
      final controller = controllerFor(repository);
      await controller.loadHistory('u1');
      expect(controller.chats.single.exchanges.single.userId, 'u1');
    });

    test('refresh adds chats saved elsewhere without changing the open chat',
        () async {
      final repository = FakeHealthBotRepository();
      final controller = controllerFor(repository);
      await controller.loadHistory('u1');
      await controller.sendQuery(userId: 'u1', text: 'Here');
      final open = controller.currentChatId;
      await settle();
      repository.logged.add(_exchange(
        'other-device',
        DateTime(2026, 11, 26, 13),
        sessionId: 'chat_other',
        query: 'From my other phone',
      ));

      await controller.refreshChats('u1');
      expect(controller.chats.map((c) => c.title), contains('From my other phone'));
      expect(controller.currentChatId, open);
      expect(controller.transcript.first.text, 'Here');

      repository.failWith = Exception('offline');
      await controller.refreshChats('u1');
      expect(controller.chatListErrorMessage, isNotNull);
      expect(controller.chats, hasLength(2)); // still listed
    });
  });

  group('Chat History screen', () {
    Future<HealthBotController> pumpHealthBot(
      WidgetTester tester,
      FakeHealthBotRepository repository, {
      FakeHealthBotClient? client,
    }) async {
      final controller = controllerFor(repository, client: client);
      await tester.pumpWidget(
        MaterialApp(home: HealthBotScreen(userId: 'u1', controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('healthbot_disclaimer_acknowledge_button')),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    Future<void> openHistory(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('healthbot_history_button')));
      await tester.pumpAndSettle();
      expect(find.byType(HealthBotHistoryScreen), findsOneWidget);
    }

    Future<void> ask(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const Key('healthbot_input_field')), text);
      await tester.tap(find.byKey(const Key('healthbot_send_button')));
      await tester.pumpAndSettle();
    }

    testWidgets('empty history says so', (tester) async {
      await pumpHealthBot(tester, FakeHealthBotRepository());
      expect(find.byTooltip('Chat history'), findsOneWidget);
      expect(find.byTooltip('New chat'), findsOneWidget);
      await openHistory(tester);
      expect(find.byKey(const Key('healthbot_history_empty')), findsOneWidget);
      expect(find.text('No conversations yet'), findsOneWidget);
    });

    testWidgets('shows a loading state, then the chats', (tester) async {
      final repository = _SlowRepository()
        ..logged.add(_exchange('1', DateTime(2026, 11, 25, 21, 5), query: 'Saved chat'));
      final controller = controllerFor(repository);
      repository.gate = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: HealthBotHistoryScreen(userId: 'u1', controller: controller),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('healthbot_history_loading')), findsOneWidget);

      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('healthbot_history_loading')), findsNothing);
      expect(find.text('Saved chat'), findsOneWidget);
      expect(find.text('25 Nov 2026, 9:05 PM · 1 question'), findsOneWidget);
    });

    testWidgets('a load failure offers Try again, which recovers', (tester) async {
      final repository = FakeHealthBotRepository()
        ..logged.add(_exchange('1', DateTime(2026, 11, 25, 9), query: 'Recovered chat'))
        ..failWith = Exception('offline');
      final controller = controllerFor(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: HealthBotHistoryScreen(userId: 'u1', controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('healthbot_history_error')), findsOneWidget);

      repository.failWith = null;
      await tester.tap(find.byKey(const Key('healthbot_history_retry')));
      await tester.pumpAndSettle();
      expect(find.text('Recovered chat'), findsOneWidget);
    });

    testWidgets(
      'create, save, switch, reopen and continue chats from the screen',
      (tester) async {
        final repository = FakeHealthBotRepository();
        final client = FakeHealthBotClient(nextAnswer: _answer);
        final controller = await pumpHealthBot(tester, repository, client: client);

        await ask(tester, 'How long do cravings last?');
        expect(find.byKey(const Key('healthbot_chat_started_at')), findsOneWidget);
        await tester.tap(find.byKey(const Key('healthbot_new_chat_button')));
        await tester.pumpAndSettle();
        await ask(tester, 'Can I drink coffee?');
        await tester.pump();
        expect(repository.logged, hasLength(2));

        await openHistory(tester);
        expect(find.text('Can I drink coffee?'), findsOneWidget);
        expect(find.text('How long do cravings last?'), findsOneWidget);
        // The open chat is marked.
        expect(find.byKey(const Key('healthbot_history_open_badge')), findsOneWidget);

        final cravingsChat = controller.chats.last;
        await tester.tap(
          find.byKey(Key('healthbot_history_chat_${cravingsChat.id}')),
        );
        await tester.pumpAndSettle();

        // Back on the Health-Bot screen, in the old conversation.
        expect(find.byType(HealthBotHistoryScreen), findsNothing);
        expect(find.text('How long do cravings last?'), findsOneWidget);
        expect(find.text('Can I drink coffee?'), findsNothing);

        await ask(tester, 'And after a month?');
        expect(client.askedHistories.last.first.text, 'How long do cravings last?');
        expect(
          client.askedHistories.last.any((t) => t.text == 'Can I drink coffee?'),
          isFalse,
        );
        await tester.pump();
        expect(repository.logged.last.sessionId, cravingsChat.id);
        expect(controller.chats.first.id, cravingsChat.id);
      },
    );

    testWidgets('Chat History is unavailable while a reply is on its way', (
      tester,
    ) async {
      final client = _PendingClient();
      await pumpHealthBot(tester, FakeHealthBotRepository(), client: client);
      await tester.enterText(find.byKey(const Key('healthbot_input_field')), 'Hi');
      await tester.tap(find.byKey(const Key('healthbot_send_button')));
      await tester.pump();
      final button = tester.widget<IconButton>(
        find.byKey(const Key('healthbot_history_button')),
      );
      expect(button.onPressed, isNull);
      client.reply.complete(_answer);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('healthbot_history_button')))
            .onPressed,
        isNotNull,
      );
    });
  });
}

class _PendingClient extends FakeHealthBotClient {
  final Completer<HealthBotAnswer> reply = Completer();

  @override
  Future<HealthBotAnswer> ask({
    required String query,
    List<HealthBotTurn> history = const [],
    HealthBotUserContext? userContext,
  }) => reply.future;
}
