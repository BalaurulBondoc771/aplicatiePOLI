import 'package:flutter/services.dart';

class MeshChannelService {
  MeshChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/mesh');
  static const EventChannel _peersChannel = EventChannel('blackout_link/mesh/peers');

  static Stream<Map<String, dynamic>> get peersUpdates =>
      _peersChannel.receiveBroadcastStream().map(_toMap);

  static Future<Map<String, dynamic>> startScan() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('startScan');
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> stopScan() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('stopScan');
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> refreshPeers() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>('refreshPeers');
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> getRecentPeers({int limit = 20}) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getRecentPeers',
      <String, dynamic>{'limit': limit},
    );
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> markTrustedPeer({
    required String peerId,
    required bool trusted,
  }) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'markTrustedPeer',
      <String, dynamic>{
        'peerId': peerId,
        'trusted': trusted,
      },
    );
    return _toMap(result);
  }

  static Map<String, dynamic> _toMap(Object? event) {
    final map = (event as Map?)?.cast<Object?, Object?>() ?? const <Object?, Object?>{};
    return map.map((key, value) => MapEntry('$key', value));
  }
}
