import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceProfileService {
  DeviceProfileService._();

  static final DeviceProfileService instance = DeviceProfileService._();

  static const MethodChannel _channel = MethodChannel('flash_lang_wear_sync');

  Future<bool> isWatchDevice() async {
    if (kIsWeb) {
      return false;
    }

    try {
      final bool? result = await _channel.invokeMethod<bool>('isWatchDevice');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
