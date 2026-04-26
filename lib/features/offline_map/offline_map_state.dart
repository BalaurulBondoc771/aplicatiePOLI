enum MapPackStatus {
  notDownloaded,
  downloading,
  downloaded,
  failed,
  unsupported,
}

class OfflineMapState {
  const OfflineMapState({
    required this.status,
    required this.downloadProgress,
    required this.localPath,
    required this.fileSizeBytes,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestampMs,
    required this.locationFallback,
    required this.locationPermissionGranted,
    required this.gpsEnabled,
    required this.locationSource,
    required this.busy,
    required this.error,
  });

  final MapPackStatus status;
  final double downloadProgress;
  final String? localPath;
  final int? fileSizeBytes;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final int? timestampMs;
  final bool locationFallback;
  final bool locationPermissionGranted;
  final bool gpsEnabled;
  final String? locationSource;
  final bool busy;
  final String? error;

  factory OfflineMapState.initial() {
    return const OfflineMapState(
      status: MapPackStatus.notDownloaded,
      downloadProgress: 0,
      localPath: null,
      fileSizeBytes: null,
      latitude: null,
      longitude: null,
      accuracyMeters: null,
      timestampMs: null,
      locationFallback: false,
      locationPermissionGranted: true,
      gpsEnabled: true,
      locationSource: null,
      busy: false,
      error: null,
    );
  }

  OfflineMapState copyWith({
    MapPackStatus? status,
    double? downloadProgress,
    String? localPath,
    int? fileSizeBytes,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    int? timestampMs,
    bool? locationFallback,
    bool? locationPermissionGranted,
    bool? gpsEnabled,
    String? locationSource,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return OfflineMapState(
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localPath: localPath ?? this.localPath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      timestampMs: timestampMs ?? this.timestampMs,
      locationFallback: locationFallback ?? this.locationFallback,
      locationPermissionGranted: locationPermissionGranted ?? this.locationPermissionGranted,
      gpsEnabled: gpsEnabled ?? this.gpsEnabled,
      locationSource: locationSource ?? this.locationSource,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
