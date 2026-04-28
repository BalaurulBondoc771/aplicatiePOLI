import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../location/location_dto.dart';

class LocationChannelService {
  LocationChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/location');
  static const EventChannel _updatesChannel = EventChannel('blackout_link/location/updates');

  static Stream<LocationDto> get locationUpdates {
    if (kIsWeb) {
      return const Stream<LocationDto>.empty();
    }

    return _updatesChannel.receiveBroadcastStream().map(_toMap).asyncExpand((map) {
      if (map['ok'] != true) {
        return Stream<LocationDto>.error(
          PlatformException(
            code: '${map['error'] ?? 'location_update_error'}',
            message: '${map['message'] ?? map['error'] ?? 'Location update failed'}',
          ),
        );
      }

      if (map['latitude'] == null || map['longitude'] == null) {
        return const Stream<LocationDto>.empty();
      }

      return Stream<LocationDto>.value(LocationDto.fromMap(map));
    });
  }

  static Future<LocationDto> getCurrentLocation() async {
    if (kIsWeb) {
      throw MissingPluginException('Location channels are unavailable on web runtime.');
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('getCurrentLocation');
      final map = _toMap(result);
      if (map['ok'] != true) {
        throw PlatformException(
          code: '${map['error'] ?? 'location_error'}',
          message: '${map['message'] ?? map['error'] ?? 'Unable to fetch current location'}',
        );
      }
      return LocationDto.fromMap(map);
    } on MissingPluginException {
      throw MissingPluginException('Location plugin not registered.');
    }
  }

  static Future<LocationDto> getLastKnownLocation() async {
    if (kIsWeb) {
      throw MissingPluginException('Location channels are unavailable on web runtime.');
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('getLastKnownLocation');
      final map = _toMap(result);
      if (map['ok'] != true) {
        throw PlatformException(
          code: '${map['error'] ?? 'location_error'}',
          message: '${map['message'] ?? map['error'] ?? 'Unable to fetch last known location'}',
        );
      }
      return LocationDto.fromMap(map);
    } on MissingPluginException {
      throw MissingPluginException('Location plugin not registered.');
    }
  }

  static Future<Map<String, dynamic>> observeLocationUpdates() async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': false, 'error': 'unsupported_on_web'};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('observeLocationUpdates');
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
