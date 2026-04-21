class PeerLastSeenDto {
  const PeerLastSeenDto({
    required this.id,
    required this.name,
    required this.status,
    required this.rssi,
    required this.distanceMeters,
    required this.lastSeenMs,
    required this.trusted,
    required this.relayCapable,
  });

  final String id;
  final String name;
  final String status;
  final int rssi;
  final double distanceMeters;
  final int lastSeenMs;
  final bool trusted;
  final bool relayCapable;

  factory PeerLastSeenDto.fromMap(Map<String, dynamic> map) {
    return PeerLastSeenDto(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? 'UNKNOWN_NODE'}',
      status: '${map['status'] ?? 'unknown'}',
      rssi: (map['rssi'] as num?)?.toInt() ?? -70,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      lastSeenMs: (map['lastSeenMs'] as num?)?.toInt() ?? 0,
      trusted: map['trusted'] == true,
      relayCapable: map['relayCapable'] != false,
    );
  }
}
