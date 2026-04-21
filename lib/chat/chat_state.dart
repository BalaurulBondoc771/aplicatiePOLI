import 'chat_message_dto.dart';
import 'chat_session_dto.dart';

class ChatState {
  const ChatState({
    required this.loading,
    required this.sending,
    required this.session,
    required this.messages,
    required this.draft,
    required this.connectionState,
    required this.latencyMs,
    required this.sessionState,
    this.lastError,
  });

  final bool loading;
  final bool sending;
  final ChatSessionDto session;
  final List<ChatMessageDto> messages;
  final String draft;
  final String connectionState;
  final int latencyMs;
  final String sessionState;
  final String? lastError;

  factory ChatState.initial() {
    return ChatState(
      loading: true,
      sending: false,
      session: ChatSessionDto.standby(),
      messages: const <ChatMessageDto>[],
      draft: '',
      connectionState: 'disconnected',
      latencyMs: 0,
      sessionState: 'idle',
      lastError: null,
    );
  }

  ChatState copyWith({
    bool? loading,
    bool? sending,
    ChatSessionDto? session,
    List<ChatMessageDto>? messages,
    String? draft,
    String? connectionState,
    int? latencyMs,
    String? sessionState,
    String? lastError,
    bool clearError = false,
  }) {
    return ChatState(
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      session: session ?? this.session,
      messages: messages ?? this.messages,
      draft: draft ?? this.draft,
      connectionState: connectionState ?? this.connectionState,
      latencyMs: latencyMs ?? this.latencyMs,
      sessionState: sessionState ?? this.sessionState,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}
