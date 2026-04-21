import 'package:flutter/services.dart';

class ChatChannelService {
  ChatChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/chat');
  static const EventChannel _incomingChannel = EventChannel('blackout_link/chat/incoming');
    static const EventChannel _connectionChannel = EventChannel('blackout_link/chat/connection');

  static Stream<Map<String, dynamic>> get incomingMessages =>
      _incomingChannel.receiveBroadcastStream().map(_toMap);

    static Stream<Map<String, dynamic>> get connectionUpdates =>
      _connectionChannel.receiveBroadcastStream().map(_toMap);

  static Future<Map<String, dynamic>> sendMessage({
    required String content,
    String? receiverId,
    String? sessionId,
  }) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'sendMessage',
      <String, dynamic>{
        'content': content,
        'receiverId': receiverId,
        if (sessionId != null) 'sessionId': sessionId,
      },
    );
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> fetchHistory({String? chatId}) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'fetchHistory',
      <String, dynamic>{'chatId': chatId},
    );
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> getConversationList() async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getConversationList',
    );
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> startOfflineChat({String? peerId}) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'startOfflineChat',
      <String, dynamic>{
        if (peerId != null) 'peerId': peerId,
      },
    );
    return _toMap(result);
  }

  static Future<Map<String, dynamic>> broadcastQuickStatus({
    required String status,
  }) async {
    final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'broadcastQuickStatus',
      <String, dynamic>{
        'status': status,
      },
    );
    return _toMap(result);
  }

  static Map<String, dynamic> _toMap(Object? event) {
    final map = (event as Map?)?.cast<Object?, Object?>() ?? const <Object?, Object?>{};
    return map.map((key, value) => MapEntry('$key', value));
  }
}
