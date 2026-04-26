import 'package:flutter/foundation.dart';

import 'services/power_channel_service.dart';

class AppDisplaySettings {
  AppDisplaySettings._();

  static final ValueNotifier<bool> grayscaleEnabled = ValueNotifier<bool>(false);

  static Future<void> syncFromPowerSettings() async {
    try {
      final Map<String, dynamic> settings = await PowerChannelService.getPowerSettings();
      setGrayscale(settings['grayscaleUiEnabled'] == true);
    } catch (_) {
      // Keep current value if platform channel is unavailable.
    }
  }

  static void setGrayscale(bool enabled) {
    if (grayscaleEnabled.value == enabled) return;
    grayscaleEnabled.value = enabled;
  }
}
