import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';

typedef SettingsChangedCallback = Future<void> Function(List<String> pushTimes);

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    DatabaseHelper? databaseHelper,
    SettingsChangedCallback? onSettingsChanged,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _onSettingsChanged = onSettingsChanged;

  final DatabaseHelper _databaseHelper;
  final SettingsChangedCallback? _onSettingsChanged;

  List<String> _pushTimes = <String>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<String> get pushTimes => List<String>.unmodifiable(_pushTimes);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get pushCount => _pushTimes.length;
  bool get hasPushTimes => _pushTimes.isNotEmpty;

  Future<void> loadSettings() async {
    _setLoading(true);
    _clearError();

    try {
      final NotificationSettingsModel settings =
          await _databaseHelper.getNotificationSettings();
      _pushTimes = _sortTimes(settings.pushTimes);
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
      final List<String> updatedTimes = _sortTimes(
        <String>[..._pushTimes, normalizedTime],
      );
      await _persistPushTimes(updatedTimes);
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
      await _persistPushTimes(updatedTimes);
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
      await _persistPushTimes(normalizedTimes);
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

  Future<void> _persistPushTimes(List<String> times) async {
    final List<String> sortedTimes = _sortTimes(times);
    await _databaseHelper.upsertNotificationSettings(sortedTimes);
    _pushTimes = sortedTimes;
    notifyListeners();

    final SettingsChangedCallback? onSettingsChanged = _onSettingsChanged;
    if (onSettingsChanged != null) {
      await onSettingsChanged(sortedTimes);
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
