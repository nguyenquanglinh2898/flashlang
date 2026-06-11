import 'package:flutter/material.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/tts_service.dart';
import 'services/wear_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final NotificationService notificationService = NotificationService.instance;

  try {
    await notificationService.initialize();
    await notificationService.requestPermissions();
    await notificationService.rescheduleFromSettings();
  } catch (error) {
    debugPrint('Notification bootstrap failed: $error');
  }

  try {
    await TtsService.instance.initialize();
  } catch (error) {
    debugPrint('TTS bootstrap failed: $error');
  }

  try {
    await WearSyncService.instance.syncFromDatabase();
  } catch (error) {
    debugPrint('Wear sync bootstrap failed: $error');
  }

  runApp(FlashLangApp(notificationService: notificationService));
}
