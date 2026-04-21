class SosHistoryRecipientDto {
  const SosHistoryRecipientDto({
    required this.id,
    required this.name,
    required this.channelType,
    required this.trusted,
    required this.isPrimary,
    required this.lastUsedAt,
  });

  final String id;
  final String name;
  final String channelType;
  final bool trusted;
  final bool isPrimary;
  final int? lastUsedAt;

  factory SosHistoryRecipientDto.fromMap(Map<String, dynamic> map) {
    return SosHistoryRecipientDto(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? 'UNKNOWN'}',
      channelType: '${map['channelType'] ?? 'mesh'}',
      trusted: map['trusted'] == true,
      isPrimary: map['isPrimary'] == true,
      lastUsedAt: (map['lastUsedAt'] as num?)?.toInt(),
    );
  }
}

class SosHistoryItemDto {
  const SosHistoryItemDto({
    required this.id,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.sentCount,
    required this.deliveredCount,
    required this.failedCount,
    required this.status,
    required this.error,
    required this.recipients,
  });

  final String id;
  final int createdAt;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final int sentCount;
  final int deliveredCount;
  final int failedCount;
  final String status;
  final String? error;
  final List<SosHistoryRecipientDto> recipients;

  factory SosHistoryItemDto.fromMap(Map<String, dynamic> map) {
    final rawRecipients = map['recipients'];
    final recipients = <SosHistoryRecipientDto>[];
    if (rawRecipients is List) {
      for (final item in rawRecipients) {
        if (item is Map) {
          recipients.add(SosHistoryRecipientDto.fromMap(item.cast<String, dynamic>()));
        }
      }
    }

    return SosHistoryItemDto(
      id: '${map['id'] ?? ''}',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble() ?? 0.0,
      sentCount: (map['sentCount'] as num?)?.toInt() ?? 0,
      deliveredCount: (map['deliveredCount'] as num?)?.toInt() ?? 0,
      failedCount: (map['failedCount'] as num?)?.toInt() ?? 0,
      status: '${map['status'] ?? 'UNKNOWN'}',
      error: map['error'] != null ? '${map['error']}' : null,
      recipients: recipients,
    );
  }
}
