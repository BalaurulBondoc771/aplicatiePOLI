import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PermissionsChannelService {
  PermissionsChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/permissions');

  static Map<String, dynamic> _defaultPermissions({required bool includeMicrophone}) {
    return <String, dynamic>{
      'permissions': <String, String>{
        'android.permission.BLUETOOTH_SCAN': 'granted',
        'android.permission.BLUETOOTH_CONNECT': 'granted',
        'android.permission.BLUETOOTH_ADVERTISE': 'granted',
        'android.permission.ACCESS_FINE_LOCATION': 'granted',
        'android.permission.RECORD_AUDIO': includeMicrophone ? 'granted' : 'not_required',
      },
      'bluetoothEnabled': true,
      'locationServiceEnabled': true,
    };
  }

  static Future<Map<String, dynamic>> getPermissionStatus({
    bool includeMicrophone = false,
  }) async {
    if (kIsWeb) {
      return _defaultPermissions(includeMicrophone: includeMicrophone);
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getPermissionStatus',
        <String, dynamic>{'includeMicrophone': includeMicrophone},
      );
      return _toMap(result);
    } on MissingPluginException {
      return _defaultPermissions(includeMicrophone: includeMicrophone);
    }
  }

  static Future<Map<String, dynamic>> requestPermissions({
    bool includeMicrophone = false,
  }) async {
    if (kIsWeb) {
      return _defaultPermissions(includeMicrophone: includeMicrophone);
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'requestPermissions',
        <String, dynamic>{'includeMicrophone': includeMicrophone},
      );
      return _toMap(result);
    } on MissingPluginException {
      return _defaultPermissions(includeMicrophone: includeMicrophone);
    }
  }

  static Map<String, dynamic> _toMap(Object? event) {
    final map = (event as Map?)?.cast<Object?, Object?>() ?? const <Object?, Object?>{};
    return map.map((key, value) => MapEntry('$key', value));
  }
}
