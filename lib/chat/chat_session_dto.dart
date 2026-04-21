class ChatSessionDto {
  const ChatSessionDto({
    required this.sessionId,
    required this.connected,
    required this.standby,
    required this.startedAtMs,
    this.peerId,
    this.peerName,
    this.status,
    this.errorCode,
  });

  final String sessionId;
  final String? peerId;
  final String? peerName;
  final bool connected;
  final bool standby;
  final int startedAtMs;
  final String? status;
  final String? errorCode;

  factory ChatSessionDto.standby({
    String? peerId,
    String? peerName,
    String? errorCode,
  }) {
    return ChatSessionDto(
      sessionId: 'standby_${DateTime.now().millisecondsSinceEpoch}',
      peerId: peerId,
      peerName: peerName,
      connected: false,
      standby: true,
      startedAtMs: DateTime.now().millisecondsSinceEpoch,
      status: 'disconnected',
      errorCode: errorCode,
    );
  }

  factory ChatSessionDto.fromMap(Map<String, dynamic> raw) {
    final dynamic sessionRaw = raw['session'];
    final Map<String, dynamic> map = sessionRaw is Map
        ? sessionRaw.cast<String, dynamic>()
        : raw;

    final bool connected = map['connected'] == true;
    final bool standby = map['standby'] == true || !connected;

    return ChatSessionDto(
      sessionId: '${map['sessionId'] ?? map['id'] ?? 'session_${DateTime.now().millisecondsSinceEpoch}'}',
      peerId: map['peerId'] != null ? '${map['peerId']}' : null,
      peerName: map['peerName'] != null ? '${map['peerName']}' : null,
      connected: connected,
      standby: standby,
      startedAtMs: (map['startedAtMs'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      status: map['status'] != null ? '${map['status']}' : null,
      errorCode: raw['error'] != null ? '${raw['error']}' : (map['error'] != null ? '${map['error']}' : null),
    );
  }
}
