import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_chat_session_store.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_client.dart';
import 'package:quit_companion/features/health_bot/data/health_bot_repository.dart';
import 'package:quit_companion/features/health_bot/domain/local_health_bot_fallback.dart';
import 'package:quit_companion/features/health_bot/models/health_bot_conversation.dart';
import 'package:quit_companion/features/health_bot/models/health_bot_message.dart';
import 'package:quit_companion/shared/domain/privacy_redactor.dart';
import 'package:quit_companion/shared/domain/perf_log.dart';

enum HealthBotStatus { idle, sending }

/// FR8 (Module 6): disclaimer-ack state, chat transcript, sendQuery
/// orchestration — appends the user message, calls HealthBotClient,
/// appends the bot/emergency/unmatched response, then fire-and-forget
/// logs the exchange via HealthBotRepository (a logging failure never
/// blocks the visible chat, matching Register's recent-email-suggestion
/// precedent and JournalController's error-isolation style).
class HealthBotController extends ChangeNotifier {
  final HealthBotClient _client;
  final HealthBotRepository _repository;
  final DateTime Function() now;
  final String? Function()? currentDisplayName;
  final LocalHealthBotFallback _fallback;

  /// Loads the user's quit details (product, strategy, days since quitting)
  /// so replies can be personalised. Optional; failures are ignored.
  final Future<HealthBotUserContext?> Function(String userId)? loadUserContext;

  /// Where the start of the current chat (New Chat) is remembered.
  final HealthBotChatSessionStore _chatSessions;

  HealthBotController(
    this._client,
    this._repository, {
    DateTime Function()? now,
    this.currentDisplayName,
    this.loadUserContext,
    HealthBotChatSessionStore? chatSessionStore,
    LocalHealthBotFallback fallback = const LocalHealthBotFallback(),
  }) : now = now ?? DateTime.now,
       _chatSessions = chatSessionStore ?? InMemoryHealthBotChatSessionStore(),
       _fallback = fallback;

  /// Conversation memory: how many earlier messages go with a question,
  /// and how long each may be.
  static const maxHistoryMessages = 10;
  static const maxHistoryMessageChars = 1500;

  /// The profile rarely changes mid-chat; reload it at most this often.
  static const userContextMaxAge = Duration(minutes: 10);
  static const userContextLoadTimeout = Duration(seconds: 2);

  HealthBotUserContext? _userContext;
  String? _userContextUserId;
  DateTime? _userContextLoadedAt;

  /// Replaces a reply that had no real answer (backend unreachable or
  /// failed, or a curated fallback with no matching topic); offered with
  /// "Try again".
  static const noAnswerText = LocalHealthBotFallback.unavailableText;

  /// FR8 response time of the last reply (request start to answer), for
  /// diagnostics/measurement. Includes the local-fallback path.
  Duration? lastResponseTime;

  bool disclaimerAcknowledged = false;
  HealthBotStatus status = HealthBotStatus.idle;
  String? errorMessage;
  final List<HealthBotMessage> transcript = [];
  String? _historyUserId;
  bool isHistoryLoading = false;
  String? historyErrorMessage;
  int _historyRequest = 0;

  void clearSession() {
    _historyRequest++;
    _historyUserId = null;
    newChatStarted = false;
    _userContext = null;
    _userContextUserId = null;
    _userContextLoadedAt = null;
    transcript.clear();
    disclaimerAcknowledged = false;
    errorMessage = null;
    historyErrorMessage = null;
    isHistoryLoading = false;
    status = HealthBotStatus.idle;
    notifyListeners();
  }

  Future<void> loadHistory(String userId) async {
    if (_historyUserId == userId) return;
    final request = ++_historyRequest;
    transcript.clear();
    newChatStarted = false;
    isHistoryLoading = true;
    historyErrorMessage = null;
    notifyListeners();
    try {
      final startedAtFuture = _safeChatStartedAt(userId);
      final conversations = await _repository.getConversations(userId);
      final chatStartedAt = await startedAtFuture;
      if (request != _historyRequest) return;
      for (final item in conversations) {
        // Only the current chat: anything from before the last New Chat
        // stays saved but is neither shown nor sent as context.
        if (chatStartedAt != null && item.timestamp.isBefore(chatStartedAt)) {
          continue;
        }
        transcript.addAll([
          HealthBotMessage(
            sender: HealthBotSender.user,
            text: item.query,
            timestamp: item.timestamp,
          ),
          HealthBotMessage(
            sender: HealthBotSender.bot,
            text: item.botResponse,
            timestamp: item.timestamp,
            isEmergency: item.isEmergency,
            sources: item.sources,
            note: item.note,
            answerSource: item.answerSource,
          ),
        ]);
      }
      _historyUserId = userId;
    } catch (_) {
      if (request != _historyRequest) return;
      historyErrorMessage =
          'Could not load conversation history. Please try again.';
    } finally {
      if (request == _historyRequest) {
        isHistoryLoading = false;
        notifyListeners();
      }
    }
  }

  void acknowledgeDisclaimer() {
    disclaimerAcknowledged = true;
    notifyListeners();
  }

  /// New Chat is offered once there is something to start over from, and
  /// never while a reply or the history is still loading (so a late reply
  /// can't land in the new chat).
  bool get canStartNewChat =>
      status != HealthBotStatus.sending &&
      !isHistoryLoading &&
      (transcript.isNotEmpty || historyErrorMessage != null);

  /// True from a New Chat until the first message in it, so the empty chat
  /// can say that earlier messages are still saved.
  bool newChatStarted = false;

  /// Starts a completely fresh conversation: clears the visible chat and,
  /// because follow-up context is built from it, the context sent with the
  /// next question. Saved conversations are not deleted or changed; the
  /// start time is remembered so they stay out of this chat after a
  /// restart too.
  Future<void> startNewChat(String userId) async {
    if (status == HealthBotStatus.sending || isHistoryLoading) return;
    final startedAt = now();
    _historyRequest++;
    _historyUserId = userId;
    transcript.clear();
    errorMessage = null;
    historyErrorMessage = null;
    lastResponseTime = null;
    newChatStarted = true;
    notifyListeners();
    try {
      await _chatSessions.saveChatStartedAt(userId, startedAt);
    } catch (e) {
      // The new chat still applies for this app session.
      debugPrint('HealthBotController: could not save new chat start: $e');
    }
  }

  Future<DateTime?> _safeChatStartedAt(String userId) async {
    try {
      return await _chatSessions.chatStartedAt(userId);
    } catch (e) {
      debugPrint('HealthBotController: chat start unavailable: $e');
      return null;
    }
  }

  Future<void> sendQuery({required String userId, required String text}) async {
    final trimmed = text.trim();
    final sanitized = redactContactDetails(
      trimmed,
      displayName: currentDisplayName?.call(),
    );
    if (trimmed.isEmpty ||
        status == HealthBotStatus.sending ||
        isHistoryLoading) {
      return;
    }
    final request = _historyRequest;
    // Built before this question joins the transcript.
    final history = _recentHistory();

    final timestamp = now();
    errorMessage = null;
    newChatStarted = false;
    transcript.add(
      HealthBotMessage(
        sender: HealthBotSender.user,
        text: trimmed,
        timestamp: timestamp,
      ),
    );
    status = HealthBotStatus.sending;
    notifyListeners();

    final stopwatch = Stopwatch()..start();
    HealthBotAnswer answer;
    String? fallbackNote;
    try {
      final userContext = await _userContextFor(userId);
      if (request != _historyRequest) return;
      answer = await _client.ask(
        query: sanitized,
        history: history,
        userContext: userContext,
      );
    } catch (e) {
      if (request != _historyRequest) return;
      debugPrint('HealthBotController.sendQuery failed: $e');
      // FR8: a slow or unreachable backend still gets a curated reply —
      // with the same crisis detection — instead of a bare error.
      errorMessage = e is HealthBotClientException
          ? e.message
          : 'Could not reach the Health-Bot. Please try again.';
      answer = _fallback.answer(sanitized);
      // Only a reason the user can act on (signing in again) is shown under
      // the reply. Server status details (e.g. a 503 explanation) are not
      // user-facing; the reply itself offers "Try again".
      fallbackNote = e is HealthBotAuthException ? e.message : null;
    }
    stopwatch.stop();
    lastResponseTime = stopwatch.elapsed;
    logPerf(
      answer.isLocalFallback
          ? 'healthbot_response_local_fallback'
          : 'healthbot_response',
      stopwatch.elapsed,
    );
    final isEmergency = answer.type == HealthBotAnswerType.emergency;
    final sources = isEmergency ? const <HealthBotSource>[] : answer.sources;
    var botResponseText = answer.responseText;
    String? note;
    String? retryQuery;
    if (isEmergency) {
      // Emergency replies stay exactly as they are: no note, no retry.
    } else if (answer.isLocalFallback) {
      botResponseText = noAnswerText;
      note = fallbackNote;
      // Retrying can't help until the user signs in again.
      if (fallbackNote == null) retryQuery = trimmed;
    } else if (answer.source == HealthBotAnswerSource.curated &&
        answer.fallbackReason != null &&
        answer.type == HealthBotAnswerType.unmatched) {
      botResponseText = noAnswerText;
      retryQuery = trimmed;
    }
    // Curated answers show no visible note (owner decision, 2026-11-23);
    // their origin is still recorded below as answerSource, in the
    // transcript and in saved history, so they are never treated as AI.
    final answerSource = answer.source;

    if (request != _historyRequest) return;
    transcript.add(
      HealthBotMessage(
        sender: HealthBotSender.bot,
        text: botResponseText,
        isEmergency: isEmergency,
        timestamp: now(),
        sources: sources,
        note: note,
        retryQuery: retryQuery,
        answerSource: answerSource,
      ),
    );
    status = HealthBotStatus.idle;
    notifyListeners();

    // Fire-and-forget: a logging failure must never block or error the chat.
    unawaited(
      _logConversation(
        userId: userId,
        query: sanitized,
        botResponse: botResponseText,
        timestamp: timestamp,
        isEmergency: isEmergency,
        sources: sources,
        note: note,
        answerSource: answerSource,
      ),
    );
  }

  /// The last [maxHistoryMessages] chat messages, oldest first, for
  /// follow-up questions. User messages are redacted exactly like the
  /// question itself; "no answer" placeholders are left out.
  List<HealthBotTurn> _recentHistory() {
    final displayName = currentDisplayName?.call();
    final turns = <HealthBotTurn>[];
    for (final message in transcript) {
      final fromUser = message.sender == HealthBotSender.user;
      if (!fromUser && message.text == noAnswerText) continue;
      var text = fromUser
          ? redactContactDetails(message.text, displayName: displayName)
          : message.text;
      text = text.trim();
      if (text.isEmpty) continue;
      if (text.length > maxHistoryMessageChars) {
        text = text.substring(0, maxHistoryMessageChars);
      }
      turns.add(HealthBotTurn(fromUser: fromUser, text: text));
    }
    return turns.length <= maxHistoryMessages
        ? turns
        : turns.sublist(turns.length - maxHistoryMessages);
  }

  Future<HealthBotUserContext?> _userContextFor(String userId) async {
    final loader = loadUserContext;
    if (loader == null) return null;
    final loadedAt = _userContextLoadedAt;
    if (_userContextUserId == userId &&
        loadedAt != null &&
        now().difference(loadedAt) < userContextMaxAge) {
      return _userContext;
    }
    try {
      _userContext = await loader(userId).timeout(userContextLoadTimeout);
    } catch (e) {
      // Personalisation is optional: answer without it.
      debugPrint('HealthBotController: user context unavailable: $e');
      _userContext = null;
    }
    _userContextUserId = userId;
    _userContextLoadedAt = now();
    return _userContext;
  }

  Future<void> _logConversation({
    required String userId,
    required String query,
    required String botResponse,
    required DateTime timestamp,
    required bool isEmergency,
    required List<HealthBotSource> sources,
    String? note,
    HealthBotAnswerSource? answerSource,
  }) async {
    try {
      await _repository.logConversation(
        HealthBotConversation(
          conversationId: timestamp.microsecondsSinceEpoch.toString(),
          userId: userId,
          query: query,
          botResponse: botResponse,
          timestamp: timestamp,
          isEmergency: isEmergency,
          sources: sources,
          note: note,
          answerSource: answerSource,
        ),
      );
    } catch (e) {
      debugPrint(
        'HealthBotController: failed to log conversation (non-fatal): $e',
      );
    }
  }
}
