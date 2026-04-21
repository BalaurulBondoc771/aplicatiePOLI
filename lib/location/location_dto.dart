class LocationDto {
  const LocationDto({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestampMs,
    required this.isStale,
    required this.isFallback,
    required this.gpsEnabled,
    required this.permissionGranted,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final int timestampMs;
  final bool isStale;
  final bool isFallback;
  final bool gpsEnabled;
  final bool permissionGranted;
  final String source;

  factory LocationDto.fromMap(Map<String, dynamic> map) {
    return LocationDto(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble() ?? 0.0,
      timestampMs: (map['timestamp'] as num?)?.toInt() ?? 0,
      isStale: map['isStale'] == true,
      isFallback: map['isFallback'] == true,
      gpsEnabled: map['gpsEnabled'] != false,
      permissionGranted: map['permissionGranted'] != false,
      source: '${map['source'] ?? 'unknown'}',
    );
  }

  String toInlineLabel() {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)} '
        '(+/- ${accuracyMeters.toStringAsFixed(0)}m)';
  }
}
