import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PowerChannelService {
  PowerChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/power');
  static const EventChannel _stateChannel = EventChannel('blackout_link/power/state');

  static Stream<Map<String, dynamic>> get powerStateUpdates =>
      kIsWeb ? const Stream<Map<String, dynamic>>.empty() : _stateChannel.receiveBroadcastStream().map(_toMap);

    static Map<String, dynamic> _defaultSettings() => <String, dynamic>{
      'batterySaverEnabled': false,
      'lowPowerBluetoothEnabled': false,
      'grayscaleUiEnabled': false,
      'criticalTasksOnlyEnabled': false,
      'sosActive': false,
      'scanIntervalMs': 1000,
      'meshActiveInApp': false,
      'displayName': 'OPERATOR_X',
      'statusPreset': 'SILENT / INCOGNITO',
      'backgroundBeaconEnabled': true,
      'backgroundBeaconActive': false,
      };

  static Future<Map<String, dynamic>> setBatterySaver(bool enabled) async {
    if (kIsWeb) {
      return _defaultSettings();
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setBatterySaver',
        <String, dynamic>{'enabled': enabled},
      );
      return _toMap(result);
    } on MissingPluginException {
      return _defaultSettings();
    }
  }

  static Future<Map<String, dynamic>> setLowPowerBluetooth(bool enabled) async {
    if (kIsWeb) {
      return _defaultSettings();
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setLowPowerBluetooth',
        <String, dynamic>{'enabled': enabled},
      );
      return _toMap(result);
    } on MissingPluginException {
      return _defaultSettings();
    }
  }

  static Future<Map<String, dynamic>> setGrayscaleUi(bool enabled) async {
    if (kIsWeb) {
      final data = _defaultSettings();
      data['grayscaleUiEnabled'] = enabled;
      return data;
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setGrayscaleUi',
        <String, dynamic>{'enabled': enabled},
      );
      return _toMap(result);
    } on MissingPluginException {
      final data = _defaultSettings();
      data['grayscaleUiEnabled'] = enabled;
      return data;
    }
  }

  static Future<Map<String, dynamic>> killBackgroundApps() async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': false, 'openedSettingsDeepLink': false};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('killBackgroundApps');
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': false, 'openedSettingsDeepLink': false};
    }
  }

  static Future<Map<String, dynamic>> setCriticalTasksOnly(bool enabled) async {
    if (kIsWeb) {
      final data = _defaultSettings();
      data['criticalTasksOnlyEnabled'] = enabled;
      return data;
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setCriticalTasksOnly',
        <String, dynamic>{'enabled': enabled},
      );
      return _toMap(result);
    } on MissingPluginException {
      final data = _defaultSettings();
      data['criticalTasksOnlyEnabled'] = enabled;
      return data;
    }
  }

  static Future<Map<String, dynamic>> setScanIntervalMs(int value) async {
    if (kIsWeb) {
      final data = _defaultSettings();
      data['scanIntervalMs'] = value;
      return data;
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setScanIntervalMs',
        <String, dynamic>{'value': value},
      );
      return _toMap(result);
    } on MissingPluginException {
      final data = _defaultSettings();
      data['scanIntervalMs'] = value;
      return data;
    }
  }

  static Future<Map<String, dynamic>> setIdentityProfile({
    required String displayName,
    required String statusPreset,
    bool? backgroundDiscoverabilityEnabled,
  }) async {
    if (kIsWeb) {
      final data = _defaultSettings();
      data['displayName'] = displayName;
      data['statusPreset'] = statusPreset;
      if (backgroundDiscoverabilityEnabled != null) {
        data['backgroundBeaconEnabled'] = backgroundDiscoverabilityEnabled;
      }
      return data;
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setIdentityProfile',
        <String, dynamic>{
          'displayName': displayName,
          'statusPreset': statusPreset,
          'backgroundDiscoverabilityEnabled': backgroundDiscoverabilityEnabled,
        },
      );
      return _toMap(result);
    } on MissingPluginException {
      final data = _defaultSettings();
      data['displayName'] = displayName;
      data['statusPreset'] = statusPreset;
      if (backgroundDiscoverabilityEnabled != null) {
        data['backgroundBeaconEnabled'] = backgroundDiscoverabilityEnabled;
      }
      return data;
    }
  }

  static Future<Map<String, dynamic>> setBackgroundDiscoverability(bool enabled) async {
    if (kIsWeb) {
      final data = _defaultSettings();
      data['backgroundBeaconEnabled'] = enabled;
      return data;
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setBackgroundDiscoverability',
        <String, dynamic>{'enabled': enabled},
      );
      return _toMap(result);
    } on MissingPluginException {
      final data = _defaultSettings();
      data['backgroundBeaconEnabled'] = enabled;
      return data;
    }
  }

  static Future<Map<String, dynamic>> getSettings() async {
    if (kIsWeb) {
      return _defaultSettings();
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('getSettings');
      return _toMap(result);
    } on MissingPluginException {
      return _defaultSettings();
    }
  }

  static Future<Map<String, dynamic>> getPowerSettings() async {
    if (kIsWeb) {
      return _defaultSettings();
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('getPowerSettings');
      return _toMap(result);
    } on MissingPluginException {
      return _defaultSettings();
    }
  }

  static Future<Map<String, dynamic>> getRuntimeEstimate() async {
    if (kIsWeb) {
      return <String, dynamic>{
        'minutes': 2535,
        'seconds': 2535 * 60,
        'runtimeLabel': '42:15:00',
        'runtimeSource': 'battery_percent',
      };
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('getRuntimeEstimate');
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{
        'minutes': 2535,
        'seconds': 2535 * 60,
        'runtimeLabel': '42:15:00',
        'runtimeSource': 'battery_percent',
      };
    }
  }

  static Map<String, dynamic> _toMap(Object? event) {
    final map = (event as Map?)?.cast<Object?, Object?>() ?? const <Object?, Object?>{};
    return map.map((key, value) => MapEntry('$key', value));
  }
}
