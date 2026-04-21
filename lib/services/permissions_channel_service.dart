import 'package:flutter/services.dart';

class PermissionsChannelService {
  PermissionsChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/permissions');

  static Future<Map<String, dynamic>> getPermissionStatus({
    bool includeMicrophone = false,
  }) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getPermissionStatus',
      <String, dynamic>{'includeMicrophone': includeMicrophone},
    );
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> requestPermissions({
    bool includeMicrophone = false,
  }) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'requestPermissions',
      <String, dynamic>{'includeMicrophone': includeMicrophone},
    );
    return _toMap(result);
  }

  static Map<String, dynamic> _toMap(Object? event) {
    final map = (event as Map?)?.cast<Object?, Object?>() ?? const <Object?, Object?>{};
    return map.map((key, value) => MapEntry('$key', value));
  }
}
