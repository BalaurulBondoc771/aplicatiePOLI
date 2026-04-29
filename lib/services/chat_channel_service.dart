import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ChatChannelService {
  ChatChannelService._();

  static const MethodChannel _methodChannel = MethodChannel('blackout_link/chat');
  static const EventChannel _incomingChannel = EventChannel('blackout_link/chat/incoming');
  static const EventChannel _connectionChannel = EventChannel('blackout_link/chat/connection');

  static Stream<Map<String, dynamic>> get incomingMessages =>
      kIsWeb ? const Stream<Map<String, dynamic>>.empty() : _incomingChannel.receiveBroadcastStream().map(_toMap);

  static Stream<Map<String, dynamic>> get connectionUpdates =>
      kIsWeb ? const Stream<Map<String, dynamic>>.empty() : _connectionChannel.receiveBroadcastStream().map(_toMap);

  static Future<Map<String, dynamic>> sendMessage({
    required String content,
    String? receiverId,
    String? sessionId,
  }) async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': false, 'status': 'FAILED', 'error': 'unsupported_on_web'};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'sendMessage',
        <String, dynamic>{
          'content': content,
          'receiverId': receiverId,
          'sessionId': sessionId,
        },
      );
      return _toMap(result);
    } on PlatformException catch (e) {
      return <String, dynamic>{
        'ok': false,
        'status': 'FAILED',
        'error': e.code.isNotEmpty ? e.code : 'platform_exception',
        'message': e.message,
      };
    } on MissingPluginException {
      return <String, dynamic>{'ok': false, 'status': 'FAILED', 'error': 'missing_plugin'};
    } catch (e) {
      return <String, dynamic>{'ok': false, 'status': 'FAILED', 'error': 'send_exception', 'message': '$e'};
    }
  }

  static Future<Map<String, dynamic>> fetchHistory({String? chatId}) async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': true, 'messages': <dynamic>[]};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'fetchHistory',
        <String, dynamic>{'chatId': chatId},
      );
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': true, 'messages': <dynamic>[]};
    }
  }

  static Future<Map<String, dynamic>> getConversationList() async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': true, 'conversations': <dynamic>[]};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getConversationList',
      );
      return _toMap(result);
    } on MissingPluginException {
      return <String, dynamic>{'ok': true, 'conversations': <dynamic>[]};
    }
  }

  static Future<Map<String, dynamic>> startOfflineChat({String? peerId}) async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': false, 'error': 'unsupported_on_web'};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'startOfflineChat',
        <String, dynamic>{
          'peerId': peerId,
        },
      );
      return _toMap(result);
    } on PlatformException catch (e) {
      return <String, dynamic>{
        'ok': false,
        'error': e.code.isNotEmpty ? e.code : 'platform_exception',
        'message': e.message,
      };
    } on MissingPluginException {
      return <String, dynamic>{'ok': false, 'error': 'missing_plugin'};
    } catch (e) {
      return <String, dynamic>{'ok': false, 'error': 'session_open_exception', 'message': '$e'};
    }
  }

  static Future<Map<String, dynamic>> broadcastQuickStatus({
    required String status,
    String? displayName,
  }) async {
    if (kIsWeb) {
      return <String, dynamic>{'ok': false, 'error': 'unsupported_on_web'};
    }
    try {
      final result = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'broadcastQuickStatus',
        <String, dynamic>{
          'status': status,
          'displayName': displayName,
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
