import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';

class WearSyncService {
  WearSyncService._();

  static final WearSyncService instance = WearSyncService._();

  static const MethodChannel _channel = MethodChannel('flash_lang_wear_sync');

  Future<void> syncFromDatabase() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final Map<String, Object?> snapshot =
        await DatabaseHelper.instance.getWearSyncSnapshot();
    await syncSnapshot(snapshot);
  }

  Future<void> syncSnapshot(Map<String, Object?> snapshot) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(
        'syncSnapshot',
        <String, dynamic>{
          'snapshotJson': jsonEncode(snapshot),
        },
      );
    } catch (_) {
      // Wear sync is best-effort so the phone app can keep working offline.
    }
  }

  Future<void> pushCardNotification({
    required int cardId,
    required String title,
    required String meaning,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(
        'pushCardNotification',
        <String, dynamic>{
          'cardId': cardId,
          'title': title,
          'meaning': meaning,
        },
      );
    } catch (_) {
      // Watch notification is best-effort.
    }
  }
}
