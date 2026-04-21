import 'chat/chat_session_dto.dart';

class AppRoutes {
  static const String dashboard = '/dashboard';
  static const String chat = '/chat';
  static const String power = '/power';
  static const String sos = '/sos';

  static ChatRouteArgs? chatArgsOf(Object? args) {
    if (args is ChatRouteArgs) {
      return args;
    }
    return null;
  }
}

class ChatRouteArgs {
  const ChatRouteArgs({
    this.peerId,
    this.peerName,
    this.session,
    this.forceStandby = false,
  });

  final String? peerId;
  final String? peerName;
  final ChatSessionDto? session;
  final bool forceStandby;
}