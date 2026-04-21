class ConversationListItemDto {
  const ConversationListItemDto({
    required this.id,
    required this.peerId,
    required this.title,
    required this.lastMessagePreview,
    required this.updatedAt,
    required this.unreadCount,
  });

  final String id;
  final String? peerId;
  final String title;
  final String lastMessagePreview;
  final int updatedAt;
  final int unreadCount;

  factory ConversationListItemDto.fromMap(Map<String, dynamic> map) {
    return ConversationListItemDto(
      id: '${map['id'] ?? ''}',
      peerId: map['peerId'] != null ? '${map['peerId']}' : null,
      title: '${map['title'] ?? ''}',
      lastMessagePreview: '${map['lastMessagePreview'] ?? ''}',
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}
