import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SystemChannelService {
  SystemChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/system');
  static const EventChannel _statusChannel = EventChannel('blackout_link/system/status');

  static Stream<Map<String, dynamic>> get systemStatusUpdates =>
      kIsWeb ? const Stream<Map<String, dynamic>>.empty() : _statusChannel.receiveBroadcastStream().map(_toMap);

  static Future<Map<String, dynamic>> getStatus() async {
    if (kIsWeb) {
      return <String, dynamic>{
        'state': 'offline',
        'bluetoothEnabled': false,
        'permissionsMissing': true,
        'batteryAvailable': true,
        'locationAvailable': false,
        'staleScanResults': true,
        'batteryPercent': 100,
        'nodesActive': 0,
        'meshRadiusKm': 0.0,
        'btRangeKm': 0.0,
        'signalState': 'standby',
        'peersAvailable': false,
      };
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('getStatus');
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'state': 'offline', 'signalState': 'standby', 'peersAvailable': false};
    }
  }

  static Future<Map<String, dynamic>> ping() async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': true};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('ping');
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': false, 'error': 'missing_plugin'};
    }
  }

  static Map<String, dynamic> _toMap(Object? event) {
    final map = (event as Map?)?.cast<Object?, Object?>() ?? const <Object?, Object?>{};
    return map.map((key, value) => MapEntry('$key', value));
  }
}
