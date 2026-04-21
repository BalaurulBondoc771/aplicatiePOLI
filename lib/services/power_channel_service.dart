import 'package:flutter/services.dart';

class PowerChannelService {
  PowerChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/power');
  static const EventChannel _stateChannel = EventChannel('blackout_link/power/state');

  static Stream<Map<String, dynamic>> get powerStateUpdates =>
      _stateChannel.receiveBroadcastStream().map(_toMap);

  static Future<Map<String, dynamic>> setBatterySaver(bool enabled) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'setBatterySaver',
      <String, dynamic>{'enabled': enabled},
    );
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> setLowPowerBluetooth(bool enabled) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'setLowPowerBluetooth',
      <String, dynamic>{'enabled': enabled},
    );
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> setGrayscaleUi(bool enabled) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'setGrayscaleUi',
      <String, dynamic>{'enabled': enabled},
    );
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> killBackgroundApps() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('killBackgroundApps');
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> setScanIntervalMs(int value) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'setScanIntervalMs',
      <String, dynamic>{'value': value},
    );
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('getSettings');
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> getPowerSettings() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('getPowerSettings');
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> getRuntimeEstimate() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('getRuntimeEstimate');
    return _toMap(result);
  }

  static Map<String, dynamic> _toMap(Object? event) {
    final map = (event as Map?)?.cast<Object?, Object?>() ?? const <Object?, Object?>{};
    return map.map((key, value) => MapEntry('$key', value));
  }
}
