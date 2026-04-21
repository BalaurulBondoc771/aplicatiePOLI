import 'package:flutter/services.dart';

class SystemChannelService {
  SystemChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/system');
  static const EventChannel _statusChannel = EventChannel('blackout_link/system/status');

  static Stream<Map<String, dynamic>> get systemStatusUpdates =>
      _statusChannel.receiveBroadcastStream().map(_toMap);

  static Future<Map<String, dynamic>> getStatus() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('getStatus');
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> ping() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('ping');
    return _toMap(result);
  }

  static Map<String, dynamic> _toMap(Object? event) {
    final map = (event as Map?)?.cast<Object?, Object?>() ?? const <Object?, Object?>{};
    return map.map((key, value) => MapEntry('$key', value));
  }
}
