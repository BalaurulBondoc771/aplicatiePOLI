class PermissionsState {
  const PermissionsState({
    required this.bluetoothScan,
    required this.bluetoothConnect,
    required this.bluetoothAdvertise,
    required this.fineLocation,
    required this.microphone,
    required this.bluetoothEnabled,
    required this.locationServiceEnabled,
    required this.requestInProgress,
    required this.lastError,
  });

  final String bluetoothScan;
  final String bluetoothConnect;
  final String bluetoothAdvertise;
  final String fineLocation;
  final String microphone;
  final bool bluetoothEnabled;
  final bool locationServiceEnabled;
  final bool requestInProgress;
  final String? lastError;

  factory PermissionsState.initial() {
    return const PermissionsState(
      bluetoothScan: 'denied',
      bluetoothConnect: 'denied',
      bluetoothAdvertise: 'denied',
      fineLocation: 'denied',
      microphone: 'not_required',
      bluetoothEnabled: false,
      locationServiceEnabled: false,
      requestInProgress: false,
      lastError: null,
    );
  }

  bool get bluetoothScanGranted => bluetoothScan == 'granted' || bluetoothScan == 'not_required';
  bool get bluetoothConnectGranted => bluetoothConnect == 'granted' || bluetoothConnect == 'not_required';
  bool get bluetoothAdvertiseGranted => bluetoothAdvertise == 'granted' || bluetoothAdvertise == 'not_required';
  bool get fineLocationGranted => fineLocation == 'granted';
  bool get microphoneGranted => microphone == 'granted' || microphone == 'not_required';

  bool get meshPermissionsGranted =>
      bluetoothScanGranted && bluetoothConnectGranted && bluetoothAdvertiseGranted && fineLocationGranted;
  bool get canUseMeshActions => meshPermissionsGranted && bluetoothEnabled;
  bool get canUseLocationActions => fineLocationGranted && locationServiceEnabled;
  bool get canUseSosActions => canUseMeshActions && canUseLocationActions;

  bool get permanentlyDeniedAny =>
      bluetoothScan == 'permanently_denied' ||
      bluetoothConnect == 'permanently_denied' ||
      bluetoothAdvertise == 'permanently_denied' ||
      fineLocation == 'permanently_denied' ||
      microphone == 'permanently_denied';

  String toBannerMessage({bool includeMicrophone = false}) {
    if (!meshPermissionsGranted) {
      if (permanentlyDeniedAny) {
        return 'Permissions permanently denied. Open app settings and retry.';
      }
      return 'Permissions missing for mesh/location. Tap retry to request.';
    }
    if (!bluetoothEnabled) {
      return 'Bluetooth is disabled. Enable Bluetooth to continue.';
    }
    if (!locationServiceEnabled) {
      return 'Location service is off. Enable GPS/location services.';
    }
    if (includeMicrophone && !microphoneGranted) {
      return 'Microphone permission missing for voice burst.';
    }
    return '';
  }

  PermissionsState copyWith({
    String? bluetoothScan,
    String? bluetoothConnect,
    String? bluetoothAdvertise,
    String? fineLocation,
    String? microphone,
    bool? bluetoothEnabled,
    bool? locationServiceEnabled,
    bool? requestInProgress,
    String? lastError,
    bool clearError = false,
  }) {
    return PermissionsState(
      bluetoothScan: bluetoothScan ?? this.bluetoothScan,
      bluetoothConnect: bluetoothConnect ?? this.bluetoothConnect,
      bluetoothAdvertise: bluetoothAdvertise ?? this.bluetoothAdvertise,
      fineLocation: fineLocation ?? this.fineLocation,
      microphone: microphone ?? this.microphone,
      bluetoothEnabled: bluetoothEnabled ?? this.bluetoothEnabled,
      locationServiceEnabled: locationServiceEnabled ?? this.locationServiceEnabled,
      requestInProgress: requestInProgress ?? this.requestInProgress,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}
