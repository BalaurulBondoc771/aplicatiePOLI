import 'dart:async';

import '../app_routes.dart';
import '../services/chat_channel_service.dart';
import 'chat_message_dto.dart';
import 'chat_state.dart';
import 'chat_session_dto.dart';

class ChatController {
  ChatController();

  static const String _sendFailedMessageText = 'Mesajul nu a putut fi trimis.';

  final StreamController<ChatState> _stateController = StreamController<ChatState>.broadcast();

  ChatState _state = ChatState.initial();
  ChatState get state => _state;
  Stream<ChatState> get stateStream => _stateController.stream;

  StreamSubscription<Map<String, dynamic>>? _incomingSub;
  StreamSubscription<Map<String, dynamic>>? _connectionSub;

  Future<void> init(ChatRouteArgs? args) async {
    _emit(_state.copyWith(loading: true, clearError: true));

    if (args?.session != null) {
      _emit(_state.copyWith(loading: false, session: args!.session!));
    } else {
      await openOfflineSession(
        peerId: args?.peerId,
        peerName: args?.peerName,
        forceStandby: args?.forceStandby ?? false,
      );
    }

    _incomingSub = ChatChannelService.incomingMessages.listen((event) {
      if (event['event'] == 'incoming_message') {
        final incoming = ChatMessageDto.fromIncoming(event);
        if (_containsMessage(incoming.id)) {
          return;
        }
        _emit(
          _state.copyWith(
            messages: <ChatMessageDto>[..._state.messages, incoming],
            clearError: true,
          ),
        );
      }
    }, onError: (Object error) {
      _emit(_state.copyWith(lastError: '$error'));
    });

    _connectionSub = ChatChannelService.connectionUpdates.listen((event) {
      if (event['event'] != 'connection_state') return;
      final String incomingState = '${event['state'] ?? _state.connectionState}';
      final String? peerId = event['peerId'] != null ? '${event['peerId']}' : null;
      final String? peerName = event['peerName'] != null ? '${event['peerName']}' : null;
      final String? sessionId = event['sessionId'] != null ? '${event['sessionId']}' : null;
      final bool connected = incomingState.toLowerCase() == 'connected';
      final ChatSessionDto nextSession = _state.session.copyWith(
        sessionId: sessionId,
        peerId: peerId,
        peerName: peerName,
        connected: connected,
        standby: !connected,
        status: '${event['sessionState'] ?? _state.sessionState}',
        clearError: true,
      );
      _emit(
        _state.copyWith(
          connectionState: incomingState,
          latencyMs: (event['latencyMs'] as num?)?.toInt() ?? _state.latencyMs,
          sessionState: '${event['sessionState'] ?? _state.sessionState}',
          session: nextSession,
          clearError: true,
        ),
      );
    }, onError: (Object error) {
      _emit(_state.copyWith(connectionState: 'error', lastError: '$error'));
    });

    await _loadHistory();
  }

  void updateDraft(String value) {
    _emit(_state.copyWith(draft: value));
  }

  Future<void> sendDraft() async {
    return sendText(_state.draft);
  }

  Future<void> sendText(String rawText) async {
    final String text = rawText.trim();
    if (text.isEmpty) {
      _emit(_state.copyWith(lastError: 'empty_draft'));
      return;
    }

    final String? targetPeerId = _state.session.peerId?.trim().isNotEmpty == true
        ? _state.session.peerId
        : null;
    if (targetPeerId == null) {
      _emit(
        _state.copyWith(
          lastError: 'missing_peer',
          messages: _appendSendErrorMessage(_state.messages),
        ),
      );
      return;
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    final String localId = 'local_$now';
    final ChatMessageDto pending = ChatMessageDto.outgoingDraft(
      id: localId,
      content: text,
      createdAtMs: now,
    ).copyWith(peerId: targetPeerId);

    _emit(
      _state.copyWith(
        sending: true,
        draft: '',
        messages: <ChatMessageDto>[..._state.messages, pending],
        clearError: true,
      ),
    );

    try {
      final String? sessionId = _effectiveSessionId(_state.session);
      final response = await ChatChannelService.sendMessage(
        content: text,
        receiverId: targetPeerId,
        sessionId: sessionId,
      );

      final String status = '${response['status'] ?? 'FAILED'}'.toUpperCase();
      final String remoteId = response['messageId'] != null ? '${response['messageId']}' : localId;
      final int createdAt = (response['createdAt'] as num?)?.toInt() ?? now;
      final String? error = response['error'] != null ? '${response['error']}' : null;

      final updated = _state.messages.map((message) {
        if (message.id != localId) return message;
        return message.copyWith(
          id: remoteId,
          status: status,
          createdAtMs: createdAt,
          conversationId: _state.session.sessionId,
          peerId: targetPeerId,
        );
      }).toList(growable: false);

      final bool failed = status == 'FAILED' || (response['ok'] == false);
      _emit(
        _state.copyWith(
          sending: false,
          messages: failed ? _appendSendErrorMessage(updated) : updated,
          lastError: failed ? (error ?? 'send_failed') : error,
        ),
      );
    } catch (e) {
      final updated = _state.messages.map((message) {
        if (message.id != localId) return message;
        return message.copyWith(status: 'FAILED');
      }).toList(growable: false);

      _emit(
        _state.copyWith(
          sending: false,
          messages: _appendSendErrorMessage(updated),
          lastError: 'send_failed:$e',
        ),
      );
    }
  }

  Future<void> retryFailed(String messageId) async {
    final ChatMessageDto? failed = _state.messages
        .where((m) => m.id == messageId && m.outgoing && m.status.toUpperCase() == 'FAILED')
        .cast<ChatMessageDto?>()
        .firstWhere((m) => m != null, orElse: () => null);
    if (failed == null) return;

    final List<ChatMessageDto> queued = _state.messages.map((m) {
      if (m.id != messageId) return m;
      return m.copyWith(status: 'QUEUED');
    }).toList(growable: false);

    _emit(_state.copyWith(messages: queued, sending: true, clearError: true));

    try {
      final String? targetPeerId = failed.peerId?.trim().isNotEmpty == true
          ? failed.peerId
          : (_state.session.peerId?.trim().isNotEmpty == true ? _state.session.peerId : null);
      if (targetPeerId == null) {
        throw StateError('missing_peer');
      }

      final String? sessionId = _effectiveSessionId(_state.session);
      final response = await ChatChannelService.sendMessage(
        content: failed.content,
        receiverId: targetPeerId,
        sessionId: sessionId,
      );
      final String status = '${response['status'] ?? 'FAILED'}'.toUpperCase();
      final String remoteId = response['messageId'] != null ? '${response['messageId']}' : messageId;
      final int createdAt = (response['createdAt'] as num?)?.toInt() ?? failed.createdAtMs;
      final String? error = response['error'] != null ? '${response['error']}' : null;

      final List<ChatMessageDto> updated = _state.messages.map((m) {
        if (m.id != messageId) return m;
        return m.copyWith(
          id: remoteId,
          status: status,
          createdAtMs: createdAt,
          conversationId: _state.session.sessionId,
          peerId: targetPeerId,
        );
      }).toList(growable: false);

      _emit(_state.copyWith(messages: updated, sending: false, lastError: error));
    } catch (e) {
      final List<ChatMessageDto> failedAgain = _state.messages.map((m) {
        if (m.id != messageId) return m;
        return m.copyWith(status: 'FAILED');
      }).toList(growable: false);
      _emit(_state.copyWith(messages: failedAgain, sending: false, lastError: 'retry_failed:$e'));
    }
  }

  Future<void> openOfflineSession({
    String? peerId,
    String? peerName,
    bool forceStandby = false,
  }) async {
    if (forceStandby) {
      _emit(
        _state.copyWith(
          loading: false,
          session: ChatSessionDto.standby(
            peerId: peerId,
            peerName: peerName,
          ),
        ),
      );
      return;
    }

    try {
      final Map<String, dynamic> response =
          await ChatChannelService.startOfflineChat(peerId: peerId);

      if (response['ok'] == true) {
        final ChatSessionDto session = ChatSessionDto.fromMap(response);
        _emit(_state.copyWith(loading: false, session: session, clearError: true));
      } else {
        final String errorCode = response['error'] != null ? '${response['error']}' : 'session_open_failed';
        _emit(
          _state.copyWith(
            loading: false,
            session: ChatSessionDto.standby(
              peerId: peerId,
              peerName: peerName,
              errorCode: errorCode,
            ),
            lastError: errorCode,
          ),
        );
      }
    } catch (e) {
      _emit(
        _state.copyWith(
          loading: false,
          session: ChatSessionDto.standby(
            peerId: peerId,
            peerName: peerName,
            errorCode: 'session_open_failed',
          ),
          lastError: '$e',
        ),
      );
    }
  }

  void dispose() {
    _incomingSub?.cancel();
    _connectionSub?.cancel();
    _stateController.close();
  }

  Future<void> _loadHistory() async {
    try {
      final String? chatId = _state.session.peerId;
      final response = await ChatChannelService.fetchHistory(chatId: chatId);
      final rawMessages = response['messages'];
      if (rawMessages is! List) {
        return;
      }

      final List<ChatMessageDto> restored = <ChatMessageDto>[];
      for (final item in rawMessages) {
        if (item is Map) {
          restored.add(ChatMessageDto.fromIncoming(item.cast<String, dynamic>()));
        }
      }
      restored.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
      _emit(_state.copyWith(messages: restored, loading: false, clearError: true));
    } catch (_) {
      _emit(_state.copyWith(loading: false));
    }
  }

  bool _containsMessage(String id) {
    for (final message in _state.messages) {
      if (message.id == id) return true;
    }
    return false;
  }

  List<ChatMessageDto> _appendSendErrorMessage(List<ChatMessageDto> base) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final ChatMessageDto errorMessage = ChatMessageDto(
      id: 'send_error_$now',
      content: _sendFailedMessageText,
      createdAtMs: now,
      status: 'INFO',
      outgoing: false,
      senderId: 'SYSTEM',
      type: 'ERROR',
      peerId: _state.session.peerId,
      conversationId: _state.session.sessionId,
    );
    return <ChatMessageDto>[...base, errorMessage];
  }

  void appendSendFailureNotice() {
    _emit(
      _state.copyWith(
        messages: _appendSendErrorMessage(_state.messages),
        lastError: 'send_failed',
      ),
    );
  }

  String? _effectiveSessionId(ChatSessionDto session) {
    final String id = session.sessionId.trim();
    if (id.isEmpty) return null;
    if (session.standby || !session.connected) return null;
    if (id.startsWith('standby_')) return null;
    return id;
  }

  void _emit(ChatState value) {
    _state = value;
    if (!_stateController.isClosed) {
      _stateController.add(value);
    }
  }
}
