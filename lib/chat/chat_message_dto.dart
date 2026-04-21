class ChatMessageDto {
  const ChatMessageDto({
    required this.id,
    required this.content,
    required this.createdAtMs,
    required this.status,
    required this.outgoing,
    this.conversationId,
    this.senderId,
    this.type,
    this.peerId,
  });

  final String id;
  final String content;
  final int createdAtMs;
  final String status;
  final bool outgoing;
  final String? conversationId;
  final String? senderId;
  final String? type;
  final String? peerId;

  ChatMessageDto copyWith({
    String? id,
    String? content,
    int? createdAtMs,
    String? status,
    bool? outgoing,
    String? conversationId,
    String? senderId,
    String? type,
    String? peerId,
  }) {
    return ChatMessageDto(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      status: status ?? this.status,
      outgoing: outgoing ?? this.outgoing,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      peerId: peerId ?? this.peerId,
    );
  }

  factory ChatMessageDto.outgoingDraft({
    required String id,
    required String content,
    required int createdAtMs,
  }) {
    return ChatMessageDto(
      id: id,
      content: content,
      createdAtMs: createdAtMs,
      status: 'QUEUED',
      outgoing: true,
      conversationId: null,
      senderId: 'LOCAL_USER',
      type: 'TEXT',
    );
  }

  factory ChatMessageDto.fromIncoming(Map<String, dynamic> map) {
    final int ts = (map['createdAt'] as num?)?.toInt() ??
        (map['timestamp'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final String delivery = '${map['deliveryStatus'] ?? map['status'] ?? 'SENT'}'.toUpperCase();
    return ChatMessageDto(
      id: '${map['id'] ?? 'incoming_$ts'}',
      content: '${map['content'] ?? ''}',
      createdAtMs: ts,
      status: delivery,
      outgoing: '${map['senderId'] ?? ''}' == 'LOCAL_USER',
      conversationId: map['conversationId'] != null ? '${map['conversationId']}' : null,
      senderId: map['senderId'] != null ? '${map['senderId']}' : null,
      type: map['type'] != null ? '${map['type']}' : 'TEXT',
      peerId: map['senderId'] != null ? '${map['senderId']}' : (map['from'] != null ? '${map['from']}' : null),
    );
  }
}
