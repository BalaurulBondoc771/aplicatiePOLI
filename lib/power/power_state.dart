class PowerState {
  const PowerState({
    required this.loading,
    required this.batterySaverEnabled,
    required this.lowPowerBluetoothEnabled,
    required this.grayscaleUiEnabled,
    required this.criticalTasksOnlyEnabled,
    required this.sosActive,
    required this.scanIntervalMs,
    required this.runtimeMinutes,
    required this.runtimeSeconds,
    required this.runtimeLabel,
    required this.isSosHolding,
    required this.sosHoldProgress,
    required this.sendingSos,
    required this.lastAction,
    required this.error,
  });

  final bool loading;
  final bool batterySaverEnabled;
  final bool lowPowerBluetoothEnabled;
  final bool grayscaleUiEnabled;
  final bool criticalTasksOnlyEnabled;
  final bool sosActive;
  final int scanIntervalMs;
  final int runtimeMinutes;
  final int runtimeSeconds;
  final String runtimeLabel;
  final bool isSosHolding;
  final double sosHoldProgress;
  final bool sendingSos;
  final String? lastAction;
  final String? error;

  factory PowerState.initial() {
    return const PowerState(
      loading: true,
      batterySaverEnabled: false,
      lowPowerBluetoothEnabled: false,
      grayscaleUiEnabled: false,
      criticalTasksOnlyEnabled: false,
      sosActive: false,
      scanIntervalMs: 1000,
      runtimeMinutes: 2535,
      runtimeSeconds: 2535 * 60,
      runtimeLabel: '42:15:00',
      isSosHolding: false,
      sosHoldProgress: 0,
      sendingSos: false,
      lastAction: null,
      error: null,
    );
  }

  int get runtimeHours => runtimeSeconds ~/ 3600;
  int get runtimeMinsRemainder => (runtimeSeconds % 3600) ~/ 60;
  int get runtimeSecsRemainder => runtimeSeconds % 60;

  PowerState copyWith({
    bool? loading,
    bool? batterySaverEnabled,
    bool? lowPowerBluetoothEnabled,
    bool? grayscaleUiEnabled,
    bool? criticalTasksOnlyEnabled,
    bool? sosActive,
    int? scanIntervalMs,
    int? runtimeMinutes,
    int? runtimeSeconds,
    String? runtimeLabel,
    bool? isSosHolding,
    double? sosHoldProgress,
    bool? sendingSos,
    String? lastAction,
    String? error,
    bool clearError = false,
  }) {
    return PowerState(
      loading: loading ?? this.loading,
      batterySaverEnabled: batterySaverEnabled ?? this.batterySaverEnabled,
      lowPowerBluetoothEnabled: lowPowerBluetoothEnabled ?? this.lowPowerBluetoothEnabled,
      grayscaleUiEnabled: grayscaleUiEnabled ?? this.grayscaleUiEnabled,
      criticalTasksOnlyEnabled: criticalTasksOnlyEnabled ?? this.criticalTasksOnlyEnabled,
      sosActive: sosActive ?? this.sosActive,
      scanIntervalMs: scanIntervalMs ?? this.scanIntervalMs,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      runtimeSeconds: runtimeSeconds ?? this.runtimeSeconds,
      runtimeLabel: runtimeLabel ?? this.runtimeLabel,
      isSosHolding: isSosHolding ?? this.isSosHolding,
      sosHoldProgress: sosHoldProgress ?? this.sosHoldProgress,
      sendingSos: sendingSos ?? this.sendingSos,
      lastAction: lastAction ?? this.lastAction,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
