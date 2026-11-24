import 'dart:async';

import 'package:flutter/foundation.dart';
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

  HealthBotController(
    this._client,
    this._repository, {
    DateTime Function()? now,
    this.currentDisplayName,
    LocalHealthBotFallback fallback = const LocalHealthBotFallback(),
  }) : now = now ?? DateTime.now,
       _fallback = fallback;

  /// Shown under on-device guidance when the backend couldn't be reached.
  static const offlineNote =
      "Offline guidance — Health-Bot couldn't be reached.";

  /// Replaces a reply that had no real answer (curated fallback with no
  /// matching topic); offered with "Try again".
  static const noAnswerText =
      "Sorry, I couldn't get an answer to that just now.";

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
    isHistoryLoading = true;
    historyErrorMessage = null;
    notifyListeners();
    try {
      final conversations = await _repository.getConversations(userId);
      if (request != _historyRequest) return;
      for (final item in conversations) {
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

    final timestamp = now();
    errorMessage = null;
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
      answer = await _client.ask(query: sanitized);
    } catch (e) {
      if (request != _historyRequest) return;
      debugPrint('HealthBotController.sendQuery failed: $e');
      // FR8: a slow or unreachable backend still gets a curated reply —
      // with the same crisis detection — instead of a bare error.
      errorMessage = e is HealthBotClientException
          ? e.message
          : 'Could not reach the Health-Bot. Please try again.';
      answer = _fallback.answer(sanitized);
      // Network trouble gets a plain offline note; an actionable reason
      // (e.g. "Please sign in to use the Health-Bot.") is shown as is.
      final isNetwork =
          e is HealthBotTimeoutException ||
          e is HealthBotUnreachableException ||
          e is! HealthBotClientException;
      fallbackNote = isNetwork ? offlineNote : errorMessage;
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
      note = fallbackNote ?? offlineNote;
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
