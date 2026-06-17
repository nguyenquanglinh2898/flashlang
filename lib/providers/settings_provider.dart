import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/card_model.dart';

typedef SettingsChangedCallback =
    Future<void> Function(NotificationSettingsModel settings);

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    DatabaseHelper? databaseHelper,
    SettingsChangedCallback? onSettingsChanged,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       _onSettingsChanged = onSettingsChanged;

  final DatabaseHelper _databaseHelper;
  final SettingsChangedCallback? _onSettingsChanged;

  List<String> _pushTimes = <String>[];
  NotificationScheduleMode _scheduleMode = NotificationScheduleMode.fixedTimes;
  int? _intervalMinutes;
  bool _quietHoursEnabled = false;
  String? _quietHoursStart;
  String? _quietHoursEnd;
  CardModel? _lastPushedCard;
  CardModel? _nextCardInQueue;
  bool _isLoading = false;
  String? _errorMessage;

  List<String> get pushTimes => List<String>.unmodifiable(_pushTimes);
  NotificationScheduleMode get scheduleMode => _scheduleMode;
  int? get intervalMinutes => _intervalMinutes;
  bool get quietHoursEnabled => _quietHoursEnabled;
  String? get quietHoursStart => _quietHoursStart;
  String? get quietHoursEnd => _quietHoursEnd;
  CardModel? get lastPushedCard => _lastPushedCard;
  CardModel? get nextCardInQueue => _nextCardInQueue;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get pushCount => _scheduleMode == NotificationScheduleMode.interval
      ? 0
      : _pushTimes.length;
  bool get hasPushTimes => _pushTimes.isNotEmpty;
  bool get isIntervalMode => _scheduleMode == NotificationScheduleMode.interval;
  bool get isFixedTimesMode =>
      _scheduleMode == NotificationScheduleMode.fixedTimes;
  DateTime? get nextScheduledNotificationAt {
    final DateTime now = DateTime.now();

    if (_scheduleMode == NotificationScheduleMode.interval) {
      final int minutes = _intervalMinutes ?? 60;
      DateTime candidate = now.add(Duration(minutes: minutes));
      if (_quietHoursEnabled) {
        candidate = _adjustForQuietHours(candidate);
      }
      return candidate;
    }

    if (_pushTimes.isEmpty) {
      return null;
    }

    DateTime? nextRun;
    for (final String time in _pushTimes) {
      final List<String> parts = time.split(':');
      if (parts.length != 2) {
        continue;
      }

      final int hour = int.tryParse(parts[0]) ?? 0;
      final int minute = int.tryParse(parts[1]) ?? 0;
      DateTime candidate = DateTime(now.year, now.month, now.day, hour, minute);

      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }

      if (nextRun == null || candidate.isBefore(nextRun)) {
        nextRun = candidate;
      }
    }

    return nextRun;
  }

  String get nextScheduledNotificationLabel {
    final DateTime? nextRun = nextScheduledNotificationAt;
    if (nextRun == null) {
      return 'Not scheduled';
    }

    final DateTime now = DateTime.now();
    final bool isToday =
        nextRun.year == now.year &&
        nextRun.month == now.month &&
        nextRun.day == now.day;
    final DateTime tomorrow = now.add(const Duration(days: 1));
    final bool isTomorrow =
        nextRun.year == tomorrow.year &&
        nextRun.month == tomorrow.month &&
        nextRun.day == tomorrow.day;

    final String hh = nextRun.hour.toString().padLeft(2, '0');
    final String mm = nextRun.minute.toString().padLeft(2, '0');
    final String time = '$hh:$mm';

    if (isToday) {
      return 'Today at $time';
    }

    if (isTomorrow) {
      return 'Tomorrow at $time';
    }

    final String dd = nextRun.day.toString().padLeft(2, '0');
    final String mo = nextRun.month.toString().padLeft(2, '0');
    return '$dd/$mo at $time';
  }

  Future<void> loadSettings() async {
    _setLoading(true);
    _clearError();

    try {
      final NotificationSettingsModel settings = await _databaseHelper
          .getNotificationSettings();
      final CardModel? lastPushedCard = await _databaseHelper
          .getMostRecentlyPushedCard();
      final CardModel? nextCardInQueue = await _databaseHelper
          .getNextCardForNotification();
      _pushTimes = _sortTimes(settings.pushTimes);
      _scheduleMode = settings.scheduleMode;
      _intervalMinutes = settings.intervalMinutes;
      _quietHoursEnabled = settings.quietHoursEnabled;
      _quietHoursStart = settings.quietHoursStart;
      _quietHoursEnd = settings.quietHoursEnd;
      _lastPushedCard = lastPushedCard;
      _nextCardInQueue = nextCardInQueue;
      notifyListeners();
    } catch (error) {
      _setError('Failed to load notification settings: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addPushTime(String time) async {
    final String normalizedTime = _normalizeTimeString(time);
    if (normalizedTime.isEmpty) {
      _setError('Push time is invalid.');
      return false;
    }

    if (_pushTimes.contains(normalizedTime)) {
      _setError('Push time already exists.');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final List<String> updatedTimes = _sortTimes(<String>[
        ..._pushTimes,
        normalizedTime,
      ]);
      await _persistSettings(
        pushTimes: updatedTimes,
        scheduleMode: _scheduleMode,
        intervalMinutes: _intervalMinutes,
        quietHoursEnabled: _quietHoursEnabled,
        quietHoursStart: _quietHoursStart,
        quietHoursEnd: _quietHoursEnd,
      );
      return true;
    } catch (error) {
      _setError('Failed to add push time: $error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> removePushTime(String time) async {
    final String normalizedTime = _normalizeTimeString(time);
    if (!_pushTimes.contains(normalizedTime)) {
      _setError('Push time not found.');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final List<String> updatedTimes = List<String>.from(_pushTimes)
        ..remove(normalizedTime);
      await _persistSettings(
        pushTimes: updatedTimes,
        scheduleMode: _scheduleMode,
        intervalMinutes: _intervalMinutes,
        quietHoursEnabled: _quietHoursEnabled,
        quietHoursStart: _quietHoursStart,
        quietHoursEnd: _quietHoursEnd,
      );
      return true;
    } catch (error) {
      _setError('Failed to remove push time: $error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> replacePushTimes(List<String> times) async {
    final List<String> normalizedTimes = _sortTimes(
      times
          .map(_normalizeTimeString)
          .where((String value) => value.isNotEmpty)
          .toSet()
          .toList(),
    );

    _setLoading(true);
    _clearError();

    try {
      await _persistSettings(
        pushTimes: normalizedTimes,
        scheduleMode: _scheduleMode,
        intervalMinutes: _intervalMinutes,
        quietHoursEnabled: _quietHoursEnabled,
        quietHoursStart: _quietHoursStart,
        quietHoursEnd: _quietHoursEnd,
      );
      return true;
    } catch (error) {
      _setError('Failed to update push times: $error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  bool containsTime(String time) {
    return _pushTimes.contains(_normalizeTimeString(time));
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadSettings();
  }

  Future<bool> updateScheduleMode(NotificationScheduleMode mode) async {
    _setLoading(true);
    _clearError();

    try {
      await _persistSettings(
        pushTimes: _pushTimes,
        scheduleMode: mode,
        intervalMinutes: mode == NotificationScheduleMode.interval
            ? (_intervalMinutes ?? 60)
            : null,
        quietHoursEnabled: _quietHoursEnabled,
        quietHoursStart: _quietHoursStart,
        quietHoursEnd: _quietHoursEnd,
      );
      return true;
    } catch (error) {
      _setError('Failed to update notification mode: $error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateIntervalMinutes(int minutes) async {
    if (minutes <= 0) {
      _setError('Interval must be greater than 0 minutes.');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      await _persistSettings(
        pushTimes: _pushTimes,
        scheduleMode: NotificationScheduleMode.interval,
        intervalMinutes: minutes,
        quietHoursEnabled: _quietHoursEnabled,
        quietHoursStart: _quietHoursStart,
        quietHoursEnd: _quietHoursEnd,
      );
      return true;
    } catch (error) {
      _setError('Failed to update interval: $error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _persistSettings({
    required List<String> pushTimes,
    required NotificationScheduleMode scheduleMode,
    required int? intervalMinutes,
    required bool quietHoursEnabled,
    required String? quietHoursStart,
    required String? quietHoursEnd,
  }) async {
    final List<String> sortedTimes = _sortTimes(pushTimes);
    await _databaseHelper.upsertNotificationSettings(
      pushTimes: sortedTimes,
      scheduleMode: scheduleMode,
      intervalMinutes: intervalMinutes,
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
    );
    _pushTimes = sortedTimes;
    _scheduleMode = scheduleMode;
    _intervalMinutes = scheduleMode == NotificationScheduleMode.interval
        ? intervalMinutes
        : null;
    _quietHoursEnabled = quietHoursEnabled;
    _quietHoursStart = quietHoursStart;
    _quietHoursEnd = quietHoursEnd;
    notifyListeners();

    final SettingsChangedCallback? onSettingsChanged = _onSettingsChanged;
    if (onSettingsChanged != null) {
      await onSettingsChanged(
        NotificationSettingsModel(
          id: 1,
          pushTimes: _pushTimes,
          pushCount: _pushTimes.length,
          scheduleMode: _scheduleMode,
          intervalMinutes: _intervalMinutes,
          quietHoursEnabled: _quietHoursEnabled,
          quietHoursStart: _quietHoursStart,
          quietHoursEnd: _quietHoursEnd,
        ),
      );
    }
  }

  Future<bool> updateQuietHours({
    required bool enabled,
    String? start,
    String? end,
  }) async {
    if (enabled) {
      final String normalizedStart = _normalizeTimeString(start ?? '');
      final String normalizedEnd = _normalizeTimeString(end ?? '');
      if (normalizedStart.isEmpty || normalizedEnd.isEmpty) {
        _setError('Quiet hours start and end times are required.');
        return false;
      }

      _setLoading(true);
      _clearError();
      try {
        await _persistSettings(
          pushTimes: _pushTimes,
          scheduleMode: _scheduleMode,
          intervalMinutes: _intervalMinutes,
          quietHoursEnabled: true,
          quietHoursStart: normalizedStart,
          quietHoursEnd: normalizedEnd,
        );
        return true;
      } catch (error) {
        _setError('Failed to update quiet hours: $error');
        return false;
      } finally {
        _setLoading(false);
      }
    }

    _setLoading(true);
    _clearError();
    try {
      await _persistSettings(
        pushTimes: _pushTimes,
        scheduleMode: _scheduleMode,
        intervalMinutes: _intervalMinutes,
        quietHoursEnabled: false,
        quietHoursStart: null,
        quietHoursEnd: null,
      );
      return true;
    } catch (error) {
      _setError('Failed to update quiet hours: $error');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  List<String> _sortTimes(List<String> times) {
    final List<String> sorted = List<String>.from(times);
    sorted.sort(_compareTimeStrings);
    return sorted;
  }

  int _compareTimeStrings(String a, String b) {
    final int aMinutes = _timeToMinutes(a);
    final int bMinutes = _timeToMinutes(b);
    return aMinutes.compareTo(bMinutes);
  }

  int _timeToMinutes(String time) {
    final List<String> parts = time.split(':');
    if (parts.length != 2) {
      return 0;
    }

    final int hour = int.tryParse(parts[0]) ?? 0;
    final int minute = int.tryParse(parts[1]) ?? 0;
    return (hour * 60) + minute;
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

    final String normalizedHour = hour.toString().padLeft(2, '0');
    final String normalizedMinute = minute.toString().padLeft(2, '0');
    return '$normalizedHour:$normalizedMinute';
  }

  DateTime _adjustForQuietHours(DateTime candidate) {
    if (!_quietHoursEnabled ||
        (_quietHoursStart ?? '').isEmpty ||
        (_quietHoursEnd ?? '').isEmpty) {
      return candidate;
    }

    final int? startMinutes = _tryTimeToMinutes(_quietHoursStart!);
    final int? endMinutes = _tryTimeToMinutes(_quietHoursEnd!);
    if (startMinutes == null || endMinutes == null) {
      return candidate;
    }

    final int candidateMinutes = (candidate.hour * 60) + candidate.minute;
    final bool crossesMidnight = startMinutes > endMinutes;
    final bool isInsideQuietHours = crossesMidnight
        ? candidateMinutes >= startMinutes || candidateMinutes < endMinutes
        : candidateMinutes >= startMinutes && candidateMinutes < endMinutes;

    if (!isInsideQuietHours) {
      return candidate;
    }

    DateTime adjusted = DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
      endMinutes ~/ 60,
      endMinutes % 60,
    );

    if (crossesMidnight && candidateMinutes >= startMinutes) {
      adjusted = adjusted.add(const Duration(days: 1));
    }

    if (!adjusted.isAfter(candidate)) {
      adjusted = adjusted.add(const Duration(days: 1));
    }

    return adjusted;
  }

  int? _tryTimeToMinutes(String time) {
    final List<String> parts = time.split(':');
    if (parts.length != 2) {
      return null;
    }

    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    return (hour * 60) + minute;
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
