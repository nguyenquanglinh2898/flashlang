import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import '../database/database_helper.dart';
import '../models/card_model.dart';

const String flashLangNotificationTask = 'flashlang_daily_notification_task';
const String _notificationChannelId = 'flashlang_daily_cards';
const String _notificationChannelName = 'FlashLang Daily Cards';
const String _notificationChannelDescription =
    'Daily flashcard reminders for learning English vocabulary.';
const int _androidAlarmIdOffset = 10000;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (task != flashLangNotificationTask) {
      return true;
    }

    final NotificationService service = NotificationService.instance;
    await service._initializeLocalNotificationsForBackground();
    await service.showRandomCardNotification();
    return true;
  });
}

@pragma('vm:entry-point')
Future<void> flashLangExactAlarmCallback(
  int alarmId,
  Map<String, dynamic> params,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final NotificationService service = NotificationService.instance;
  await service._initializeLocalNotificationsForBackground();
  await service.showRandomCardNotification();

  final String? time = params['time'] as String?;
  if (time == null || time.trim().isEmpty) {
    return;
  }

  await service._scheduleExactAlarmForTime(
    time,
    forceTomorrow: true,
  );
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {
  // The actual navigation is handled when the app returns to foreground and
  // reads launch details or foreground notification responses.
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationPayload> _notificationTapController =
      StreamController<NotificationPayload>.broadcast();

  bool _isInitialized = false;

  Stream<NotificationPayload> get notificationTapStream =>
      _notificationTapController.stream;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    WidgetsFlutterBinding.ensureInitialized();

    await _initializeLocalNotifications();
    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
    }

    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    await initialize();

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    if (Platform.isAndroid) {
      final bool canScheduleExact =
          await androidPlugin?.canScheduleExactNotifications() ?? false;
      if (!canScheduleExact) {
        await androidPlugin?.requestExactAlarmsPermission();
      }
    }

    final IOSFlutterLocalNotificationsPlugin? iosPlugin =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final MacOSFlutterLocalNotificationsPlugin? macOsPlugin =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    await macOsPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> scheduleNotifications(List<String> pushTimes) async {
    await initialize();
    final List<String> normalizedTimes = _normalizeAndSortTimes(pushTimes);
    await Workmanager().cancelAll();

    if (Platform.isAndroid) {
      await _cancelAllAndroidExactAlarms();

      final bool canScheduleExact = await _canScheduleExactAlarms();
      if (canScheduleExact) {
        for (final String time in normalizedTimes) {
          await _scheduleExactAlarmForTime(time);
        }
        return;
      }
    }

    for (final String time in normalizedTimes) {
      await _registerDailyNotificationTask(time);
    }
  }

  Future<void> rescheduleFromSettings() async {
    await initialize();
    final NotificationSettingsModel settings =
        await DatabaseHelper.instance.getNotificationSettings();
    await scheduleNotifications(settings.pushTimes);
  }

  Future<void> cancelAllScheduledNotifications() async {
    await initialize();
    await Workmanager().cancelAll();
    if (Platform.isAndroid) {
      await _cancelAllAndroidExactAlarms();
    }
    await _localNotificationsPlugin.cancelAll();
  }

  Future<bool> canScheduleExactAlarms() async {
    await initialize();
    if (!Platform.isAndroid) {
      return false;
    }

    return _canScheduleExactAlarms();
  }

  Future<bool> requestExactAlarmPermission() async {
    await initialize();
    if (!Platform.isAndroid) {
      return false;
    }

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool canScheduleBefore =
        await androidPlugin?.canScheduleExactNotifications() ?? false;
    if (canScheduleBefore) {
      return true;
    }

    await androidPlugin?.requestExactAlarmsPermission();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  Future<void> showRandomCardNotification() async {
    await _initializeLocalNotificationsForBackground();

    final CardModel? card = await DatabaseHelper.instance.getNextCardForNotification();
    if (card == null || card.id == null) {
      return;
    }

    final NotificationDetails details = _buildNotificationDetails();
    final NotificationPayload payload = NotificationPayload.fromCard(card);

    await _localNotificationsPlugin.show(
      _notificationIdForCard(card.id!),
      card.word,
      card.meaning,
      details,
      payload: payload.toJsonString(),
    );

    await DatabaseHelper.instance.updateCardLastPushedAt(card.id!, DateTime.now());
  }

  Future<NotificationPayload?> getLaunchPayload() async {
    await initialize();
    final NotificationAppLaunchDetails? launchDetails =
        await _localNotificationsPlugin.getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp != true) {
      return null;
    }

    return NotificationPayload.tryParse(
      launchDetails?.notificationResponse?.payload,
    );
  }

  Future<void> handleNotificationResponse(NotificationResponse response) async {
    final NotificationPayload? payload =
        NotificationPayload.tryParse(response.payload);
    if (payload != null) {
      _notificationTapController.add(payload);
    }
  }

  Future<void> dispose() async {
    await _notificationTapController.close();
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );

    await _createNotificationChannel();
  }

  Future<void> _initializeLocalNotificationsForBackground() async {
    if (_isInitialized) {
      return;
    }

    await _initializeLocalNotifications();
    _isInitialized = true;
  }

  Future<void> _createNotificationChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _notificationChannelId,
        _notificationChannelName,
        description: _notificationChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  NotificationDetails _buildNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannelId,
        _notificationChannelName,
        channelDescription: _notificationChannelDescription,
        icon: '@drawable/ic_notification',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  Future<void> _registerDailyNotificationTask(String time) async {
    final String uniqueName = _taskUniqueName(time);
    final Duration initialDelay = _calculateInitialDelay(time);

    await Workmanager().registerPeriodicTask(
      uniqueName,
      flashLangNotificationTask,
      frequency: const Duration(hours: 24),
      initialDelay: initialDelay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      inputData: <String, dynamic>{
        'time': time,
      },
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
    );
  }

  Future<void> _scheduleExactAlarmForTime(
    String time, {
    bool forceTomorrow = false,
  }) async {
    final String normalizedTime = _normalizeTimeString(time);
    if (normalizedTime.isEmpty) {
      return;
    }

    await AndroidAlarmManager.oneShotAt(
      _nextRunForTime(normalizedTime, forceTomorrow: forceTomorrow),
      _alarmIdForTime(normalizedTime),
      flashLangExactAlarmCallback,
      exact: true,
      allowWhileIdle: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: <String, dynamic>{
        'time': normalizedTime,
      },
    );
  }

  DateTime _nextRunForTime(
    String time, {
    bool forceTomorrow = false,
  }) {
    final List<String> parts = time.split(':');
    final int hour = int.tryParse(parts[0]) ?? 0;
    final int minute = int.tryParse(parts[1]) ?? 0;

    final DateTime now = DateTime.now();
    DateTime nextRun = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (forceTomorrow || !nextRun.isAfter(now)) {
      nextRun = nextRun.add(const Duration(days: 1));
    }

    return nextRun;
  }

  Future<void> _cancelAllAndroidExactAlarms() async {
    for (int minutes = 0; minutes < 24 * 60; minutes++) {
      await AndroidAlarmManager.cancel(_androidAlarmIdOffset + minutes);
    }
  }

  Future<bool> _canScheduleExactAlarms() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  Duration _calculateInitialDelay(String time) {
    final List<String> parts = time.split(':');
    final int hour = int.tryParse(parts[0]) ?? 0;
    final int minute = int.tryParse(parts[1]) ?? 0;

    final DateTime now = DateTime.now();
    DateTime nextRun = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!nextRun.isAfter(now)) {
      nextRun = nextRun.add(const Duration(days: 1));
    }

    return nextRun.difference(now);
  }

  List<String> _normalizeAndSortTimes(List<String> pushTimes) {
    final Set<String> uniqueTimes = pushTimes
        .map(_normalizeTimeString)
        .where((String time) => time.isNotEmpty)
        .toSet();

    final List<String> sortedTimes = uniqueTimes.toList()
      ..sort((String a, String b) => _timeToMinutes(a).compareTo(_timeToMinutes(b)));
    return sortedTimes;
  }

  String _normalizeTimeString(String time) {
    final List<String> parts = time.trim().split(':');
    if (parts.length != 2) {
      return '';
    }

    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return '';
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return '';
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  int _timeToMinutes(String time) {
    final List<String> parts = time.split(':');
    final int hour = int.tryParse(parts[0]) ?? 0;
    final int minute = int.tryParse(parts[1]) ?? 0;
    return (hour * 60) + minute;
  }

  String _taskUniqueName(String time) {
    return 'flashlang_notification_${time.replaceAll(':', '_')}';
  }

  int _alarmIdForTime(String time) {
    return _androidAlarmIdOffset + _timeToMinutes(time);
  }

  int _notificationIdForCard(int cardId) {
    return cardId + 1000;
  }
}

class NotificationPayload {
  const NotificationPayload({
    required this.cardId,
    required this.word,
    required this.meaning,
  });

  final int cardId;
  final String word;
  final String meaning;

  factory NotificationPayload.fromCard(CardModel card) {
    return NotificationPayload(
      cardId: card.id ?? 0,
      word: card.word,
      meaning: card.meaning,
    );
  }

  factory NotificationPayload.fromMap(Map<String, dynamic> map) {
    return NotificationPayload(
      cardId: map['cardId'] as int,
      word: map['word'] as String,
      meaning: map['meaning'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cardId': cardId,
      'word': word,
      'meaning': meaning,
    };
  }

  String toJsonString() => jsonEncode(toMap());

  static NotificationPayload? tryParse(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> map =
          jsonDecode(rawPayload) as Map<String, dynamic>;
      return NotificationPayload.fromMap(map);
    } catch (_) {
      return null;
    }
  }
}
