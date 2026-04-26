import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SosChannelService {
  SosChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/sos');
  static const EventChannel _stateChannel = EventChannel('blackout_link/sos/state');

  static Stream<Map<String, dynamic>> get sosStateUpdates =>
      kIsWeb ? const Stream<Map<String, dynamic>>.empty() : _stateChannel.receiveBroadcastStream().map(_toMap);

  static Future<Map<String, dynamic>> triggerSos({
    required double latitude,
    required double longitude,
    List<String> recipients = const <String>[],
  }) async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': false, 'error': 'unsupported_on_web'};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'triggerSos',
        <String, dynamic>{
          'latitude': latitude,
          'longitude': longitude,
          'recipients': recipients,
        },
      );
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': false, 'error': 'missing_plugin'};
    }
  }

  static Future<Map<String, dynamic>> sendSos() async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': false, 'error': 'unsupported_on_web'};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('sendSos');
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': false, 'error': 'missing_plugin'};
    }
  }

  static Future<Map<String, dynamic>> cancelSos() async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': false, 'error': 'unsupported_on_web'};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('cancelSos');
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': false, 'error': 'missing_plugin'};
    }
  }

  static Future<Map<String, dynamic>> getSosHistory({int limit = 50}) async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': true, 'items': <dynamic>[]};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getSosHistory',
        <String, dynamic>{'limit': limit},
      );
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': true, 'items': <dynamic>[]};
    }
  }

  static Map<String, dynamic> _toMap(Object? event) {
    final map = (event as Map?)?.cast<Object?, Object?>() ?? const <Object?, Object?>{};
    return map.map((key, value) => MapEntry('$key', value));
  }
}
