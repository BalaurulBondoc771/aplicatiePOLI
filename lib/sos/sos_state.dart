class SosRecipientStatusDto {
  const SosRecipientStatusDto({
    required this.id,
    required this.name,
    required this.status,
    this.error,
  });

  final String id;
  final String name;
  final String status;
  final String? error;

  factory SosRecipientStatusDto.fromMap(Map<String, dynamic> map) {
    return SosRecipientStatusDto(
      id: '${map['recipientId'] ?? map['id'] ?? ''}',
      name: '${map['recipientName'] ?? map['name'] ?? 'UNKNOWN'}',
      status: '${map['status'] ?? 'UNKNOWN'}',
      error: map['error'] != null ? '${map['error']}' : null,
    );
  }
}

class SosSendResultDto {
  const SosSendResultDto({
    required this.ok,
    required this.sosAlertId,
    required this.sentCount,
    required this.deliveredCount,
    required this.failedCount,
    required this.latitude,
    required this.longitude,
    required this.timestampMs,
    required this.recipients,
    required this.isStale,
    required this.isFallback,
    required this.gpsEnabled,
    required this.permissionGranted,
    required this.locationSource,
    this.error,
  });

  final bool ok;
  final String sosAlertId;
  final int sentCount;
  final int deliveredCount;
  final int failedCount;
  final double latitude;
  final double longitude;
  final int timestampMs;
  final List<SosRecipientStatusDto> recipients;
  final bool isStale;
  final bool isFallback;
  final bool gpsEnabled;
  final bool permissionGranted;
  final String locationSource;
  final String? error;

  factory SosSendResultDto.fromMap(Map<String, dynamic> map) {
    final dynamic rawRecipients = map['recipients'];
    final List<SosRecipientStatusDto> recipients = <SosRecipientStatusDto>[];
    if (rawRecipients is List) {
      for (final dynamic item in rawRecipients) {
        if (item is Map) {
          recipients.add(SosRecipientStatusDto.fromMap(item.cast<String, dynamic>()));
        }
      }
    }

    final dynamic location = map['location'];
    final double lat = location is Map ? (location['latitude'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final double lng = location is Map ? (location['longitude'] as num?)?.toDouble() ?? 0.0 : 0.0;

    return SosSendResultDto(
      ok: map['ok'] == true,
      sosAlertId: '${map['sosAlertId'] ?? 'sos_${DateTime.now().millisecondsSinceEpoch}'}',
      sentCount: (map['sentCount'] as num?)?.toInt() ?? 0,
      deliveredCount: (map['deliveredCount'] as num?)?.toInt() ?? 0,
      failedCount: (map['failedCount'] as num?)?.toInt() ?? 0,
      latitude: lat,
      longitude: lng,
      timestampMs: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      recipients: recipients,
      isStale: map['isStale'] == true,
      isFallback: map['isFallback'] == true,
      gpsEnabled: map['gpsEnabled'] != false,
      permissionGranted: map['permissionGranted'] != false,
      locationSource: '${map['source'] ?? 'unknown'}',
      error: map['error'] != null ? '${map['error']}' : null,
    );
  }
}

class SosState {
  const SosState({
    required this.holdProgress,
    required this.isHolding,
    required this.isSending,
    required this.sendResult,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestampMs,
    required this.isLocationStale,
    required this.isFallbackLocation,
    required this.gpsEnabled,
    required this.permissionGranted,
    required this.locationSource,
    required this.errorMessage,
  });

  final double holdProgress;
  final bool isHolding;
  final bool isSending;
  final SosSendResultDto? sendResult;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final int timestampMs;
  final bool isLocationStale;
  final bool isFallbackLocation;
  final bool gpsEnabled;
  final bool permissionGranted;
  final String locationSource;
  final String? errorMessage;

  factory SosState.initial() {
    return SosState(
      holdProgress: 0.0,
      isHolding: false,
      isSending: false,
      sendResult: null,
      latitude: 34.0522,
      longitude: -118.2437,
      accuracyMeters: 0,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      isLocationStale: true,
      isFallbackLocation: true,
      gpsEnabled: true,
      permissionGranted: true,
      locationSource: 'bootstrap',
      errorMessage: null,
    );
  }

  SosState copyWith({
    double? holdProgress,
    bool? isHolding,
    bool? isSending,
    SosSendResultDto? sendResult,
    bool clearSendResult = false,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    int? timestampMs,
    bool? isLocationStale,
    bool? isFallbackLocation,
    bool? gpsEnabled,
    bool? permissionGranted,
    String? locationSource,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SosState(
      holdProgress: holdProgress ?? this.holdProgress,
      isHolding: isHolding ?? this.isHolding,
      isSending: isSending ?? this.isSending,
      sendResult: clearSendResult ? null : (sendResult ?? this.sendResult),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      timestampMs: timestampMs ?? this.timestampMs,
      isLocationStale: isLocationStale ?? this.isLocationStale,
      isFallbackLocation: isFallbackLocation ?? this.isFallbackLocation,
      gpsEnabled: gpsEnabled ?? this.gpsEnabled,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      locationSource: locationSource ?? this.locationSource,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
