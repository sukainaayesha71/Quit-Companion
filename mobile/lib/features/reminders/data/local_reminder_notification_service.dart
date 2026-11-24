import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:quit_companion/core/config/otp_backend_config.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:quit_companion/features/reminders/domain/reminder_schedule_calculator.dart';
import 'package:quit_companion/features/reminders/data/reminder_notification_service.dart';
import 'package:quit_companion/features/reminders/data/fcm_token_repository.dart';
import 'package:quit_companion/features/reminders/data/fcm_token_sync.dart';

/// Real implementation of FR14 reminders: daily reminders are scheduled
/// locally via `flutter_local_notifications`; remote messages are received
/// via FCM. The client does not send or schedule remote messages. Uses
/// `AndroidScheduleMode.inexactAllowWhileIdle` deliberately (not an
/// exact alarm) so this needs only the POST_NOTIFICATIONS permission,
/// not Android 12+'s separate "exact alarm" permission — a small
/// accuracy trade-off (the OS may fire a reminder a few minutes late)
/// that keeps the permission footprint minimal, appropriate for a
/// non-time-critical wellness nudge rather than a real alarm clock.
class LocalReminderNotificationService implements ReminderNotificationService {
  bool _remoteWasEnabled = false;
  final FlutterLocalNotificationsPlugin _plugin;
  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  late final FcmTokenSync _tokenSync;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  bool _initialized = false;

  LocalReminderNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FcmTokenRepository? tokenRepository,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _messaging = messaging ?? FirebaseMessaging.instance,
       _auth = auth ?? FirebaseAuth.instance {
    _tokenSync = FcmTokenSync(
      repository:
          tokenRepository ??
          FirestoreFcmTokenRepository(firestore: firestore, auth: _auth),
      cache: SharedPreferencesFcmTokenCache(),
      currentUserId: () => _auth.currentUser?.uid,
      getToken: _messaging.getToken,
      tokenRefreshes: _messaging.onTokenRefresh,
    );
  }

  static const _channelId = 'craving_checkin_reminders';
  static const _channelName = 'Craving Check-In Reminders';
  static const _pushChannelId = 'quit_companion_updates';
  static const _pushChannelName = 'Progress updates';
  static const _title = 'How are you feeling?';
  static const _body =
      "Take a moment to log your craving, mood, or context in Quit Companion.";
  static const _habitTitle = 'Try a healthy alternative';
  static const _habitBody =
      'Take a short walk, try a breathing exercise, or use a quick distraction.';
  static const _recoveryTitle = 'Your recovery is worth celebrating';
  static const _recoveryBody =
      'Every nicotine-free day is progress. Take a moment to notice how far you have come.';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final deviceTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));

    const androidSettings = AndroidInitializationSettings(
      'ic_stat_quit_companion',
    );
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _pushChannelId,
            _pushChannelName,
            description: 'Milestone and recovery updates.',
            importance: Importance.defaultImportance,
          ),
        );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
      (message) => unawaited(_showForegroundMessage(message)),
      onError: (Object error) =>
          debugPrint('Foreground FCM message failed: $error'),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    bool localGranted;
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      localGranted = granted ?? false;
    } else {
      final iosImpl = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImpl != null) {
        final granted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        localGranted = granted ?? false;
      } else {
        // Platform with no notification-permission concept (e.g. desktop/web
        // test targets) — nothing to request, treat as granted.
        localGranted = true;
      }
    }
    if (!localGranted) return false;

    return localGranted;
  }

  @override
  Future<bool> hasPermission() async {
    await _ensureInitialized();
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      return await androidImpl.areNotificationsEnabled() ?? false;
    }
    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosImpl != null) {
      final options = await iosImpl.checkPermissions();
      return options?.isEnabled ?? false;
    }
    return true;
  }

  @override
  Future<void> scheduleOneOffNotification({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Daily reminders to check in on your cravings and progress.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Same inexact mode as the daily reminders: no exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelNotification(int id) async {
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> setPushNotificationsEnabled(bool enabled) async {
    await _ensureInitialized();
    if (!enabled) {
      await _tokenSync.disable();
      final wasEnabled = _remoteWasEnabled;
      _remoteWasEnabled = false;
      if (wasEnabled) {
        try {
          await _saveRemoteSchedule(false, const [], false, false);
        } catch (error) {
          // No token remains for this device; a legacy remote schedule cannot
          // deliver to it. Disabling local reminders never enters this path.
          debugPrint('Could not clear the legacy push schedule: $error');
        }
      }
      return;
    }
    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError('Notification permission was not granted.');
    }
    // Step 12: no longer clears the server schedule here — daily check-ins
    // are delivered by push by default (scheduleRemoteDailyReminders).
    await _tokenSync.enable(requireRegistration: true);
    _remoteWasEnabled = true;
  }

  @override
  Future<void> scheduleRemoteDailyReminders(
    List<ReminderTime> times, {
    bool habitRemindersEnabled = false,
    bool recoveryMotivationEnabled = false,
  }) async {
    await _ensureInitialized();
    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      throw const PushUnavailableException(
        'Notification permission was not granted.',
      );
    }
    try {
      await _tokenSync.enable(
        habitRemindersEnabled: habitRemindersEnabled,
        recoveryMotivationEnabled: recoveryMotivationEnabled,
        requireRegistration: true,
      );
    } catch (error) {
      throw PushUnavailableException('Push registration failed: $error');
    }
    _remoteWasEnabled = true;
    try {
      await _saveRemoteSchedule(
        true,
        times,
        habitRemindersEnabled,
        recoveryMotivationEnabled,
      );
    } catch (error) {
      throw RemoteScheduleException('Could not save the push schedule: $error');
    }
  }

  @override
  Future<void> disableRemoteDailyReminders() async {
    await _saveRemoteSchedule(false, const [], false, false);
  }

  @override
  Future<void> scheduleDailyReminders(
    List<ReminderTime> times, {
    bool habitRemindersEnabled = false,
    bool recoveryMotivationEnabled = false,
    bool remoteDelivery = false,
  }) async {
    await _ensureInitialized();
    await cancelLocalReminders();
    for (var i = 0; i < times.length; i++) {
      await _schedule(id: i, time: times[i], title: _title, body: _body);
    }
    if (habitRemindersEnabled) {
      await _schedule(
        id: 100,
        time: const ReminderTime(hour: 11, minute: 0),
        title: _habitTitle,
        body: _habitBody,
      );
    }
    if (recoveryMotivationEnabled) {
      await _schedule(
        id: 101,
        time: const ReminderTime(hour: 18, minute: 0),
        title: _recoveryTitle,
        body: _recoveryBody,
      );
    }
  }

  Future<void> _saveRemoteSchedule(
    bool enabled,
    List<ReminderTime> times,
    bool habit,
    bool recovery,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (enabled) throw StateError('Sign in to enable push reminders.');
      return;
    }
    final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final response = await http
        .put(
          Uri.parse('${OtpBackendConfig.baseUrl}/notifications/schedule'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'enabled': enabled,
            'timezone': zone,
            'dailyTimes': times.map((t) => t.toString()).toList(),
            'habitEnabled': habit,
            'recoveryEnabled': recovery,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('Could not save push reminder settings.');
    }
  }

  Future<void> _schedule({
    required int id,
    required ReminderTime time,
    required String title,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOf(time),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Daily reminders to check in on your cravings and progress.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancelLocalReminders() async {
    await _ensureInitialized();
    for (final id in [0, 1, 2, 3, 4, 100, 101]) {
      await _plugin.cancel(id: id);
    }
  }

  @override
  Future<void> cancelAllReminders() async {
    await cancelLocalReminders();
    // Logout/account deletion: also drop a pending FR11 check-in (id 200).
    await cancelNotification(200);
    await setPushNotificationsEnabled(false);
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    if (!_remoteWasEnabled) return;
    final notification = message.notification;
    if (notification == null) return;
    final title = _boundedText(notification.title, 80);
    final body = _boundedText(notification.body, 240);
    if (title == null && body == null) return;
    await _plugin.show(
      id: message.hashCode & 0x7fffffff,
      title: title ?? 'Quit Companion',
      body: body ?? 'You have a new reminder.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _pushChannelId,
          _pushChannelName,
          channelDescription: 'Milestone and recovery updates.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  String? _boundedText(String? value, int maxLength) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }

  tz.TZDateTime _nextInstanceOf(ReminderTime time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Notification payloads are displayed by the OS in the background.
  // Data-only payloads are intentionally ignored by the client.
}
