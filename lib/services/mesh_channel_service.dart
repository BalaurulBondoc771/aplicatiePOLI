import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MeshChannelService {
  MeshChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/mesh');
  static const EventChannel _peersChannel = EventChannel('blackout_link/mesh/peers');

  static Stream<Map<String, dynamic>> get peersUpdates =>
      kIsWeb ? const Stream<Map<String, dynamic>>.empty() : _peersChannel.receiveBroadcastStream().map(_toMap);

  static Future<Map<String, dynamic>> startScan() async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': false, 'error': 'unsupported_on_web'};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('startScan');
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': false, 'error': 'missing_plugin'};
    }
  }

  static Future<Map<String, dynamic>> stopScan() async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': false, 'error': 'unsupported_on_web'};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('stopScan');
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': false, 'error': 'missing_plugin'};
    }
  }

  static Future<Map<String, dynamic>> refreshPeers() async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': true, 'peers': <dynamic>[]};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('refreshPeers');
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': true, 'peers': <dynamic>[]};
    }
  }

  static Future<Map<String, dynamic>> getRecentPeers({int limit = 20}) async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': true, 'peers': <dynamic>[]};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getRecentPeers',
        <String, dynamic>{'limit': limit},
      );
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': true, 'peers': <dynamic>[]};
    }
  }

  static Future<Map<String, dynamic>> markTrustedPeer({
    required String peerId,
    required bool trusted,
  }) async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': false, 'error': 'unsupported_on_web'};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'markTrustedPeer',
        <String, dynamic>{
          'peerId': peerId,
          'trusted': trusted,
        },
      );
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
