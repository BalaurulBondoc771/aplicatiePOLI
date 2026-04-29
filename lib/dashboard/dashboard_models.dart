import 'dart:math' as math;

enum SystemHealthDto {
  operational,
  degraded,
  offline,
}

class PeerDto {
  const PeerDto({
    required this.id,
    required this.name,
    required this.status,
    required this.rssi,
    required this.distanceMeters,
    required this.lastSeenMs,
    this.statusPreset,
    this.batterySaverEnabled,
    this.meshRole,
  });

  final String id;
  final String name;
  final String status;
  final int rssi;
  final double distanceMeters;
  final int lastSeenMs;
  final String? statusPreset;
  final bool? batterySaverEnabled;
  final String? meshRole;

  factory PeerDto.fromMap(Map<String, dynamic> map) {
    final dynamic rawDistance = map['distanceMeters'];
    final dynamic rawRssi = map['rssi'];
    final int rssi = rawRssi is int ? rawRssi : int.tryParse('${rawRssi ?? -70}') ?? -70;
    final double distanceMeters = rawDistance is num
        ? rawDistance.toDouble()
        : _rssiToDistance(rssi);

    return PeerDto(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? 'UNKNOWN_NODE'}',
      status: '${map['status'] ?? 'unknown'}',
      rssi: rssi,
      distanceMeters: distanceMeters,
      lastSeenMs: map['lastSeenMs'] is int ? map['lastSeenMs'] as int : DateTime.now().millisecondsSinceEpoch,
      statusPreset: map['statusPreset'] != null ? '${map['statusPreset']}' : null,
      batterySaverEnabled: map['batterySaverEnabled'] is bool
          ? map['batterySaverEnabled'] as bool
          : null,
      meshRole: map['meshRole'] != null ? '${map['meshRole']}' : null,
    );
  }

  static double _rssiToDistance(int rssi, {int txPower = -59}) {
    return math.pow(10.0, (txPower - rssi) / 20.0).toDouble();
  }
}

class MeshStatsDto {
  const MeshStatsDto({
    required this.nodesActive,
    required this.meshRadiusKm,
    required this.btRangeKm,
  });

  final int nodesActive;
  final double meshRadiusKm;
  final double btRangeKm;

  factory MeshStatsDto.fromPeers(List<PeerDto> peers) {
    if (peers.isEmpty) {
      return const MeshStatsDto(nodesActive: 0, meshRadiusKm: 0.0, btRangeKm: 0.0);
    }

    final double maxMeters = peers
        .map((peer) => peer.distanceMeters)
        .fold<double>(0.0, (prev, element) => element > prev ? element : prev);

    final double km = maxMeters / 1000.0;
    return MeshStatsDto(
      nodesActive: peers.where((peer) => peer.status.toLowerCase() == 'connected').length,
      meshRadiusKm: km,
      btRangeKm: km,
    );
  }
}

class DashboardState {
  const DashboardState({
    required this.loading,
    required this.permissionsMissing,
    required this.bluetoothDisabled,
    required this.emptyPeers,
    required this.staleData,
    required this.systemHealth,
    required this.batteryPercent,
    required this.batteryAvailable,
    required this.locationAvailable,
    required this.signalState,
    required this.meshStats,
    required this.peers,
    required this.batterySaverEnabled,
    required this.lastError,
    required this.lastUpdatedMs,
  });

  final bool loading;
  final bool permissionsMissing;
  final bool bluetoothDisabled;
  final bool emptyPeers;
  final bool staleData;
  final SystemHealthDto systemHealth;
  final int batteryPercent;
  final bool batteryAvailable;
  final bool locationAvailable;
  final String signalState;
  final MeshStatsDto meshStats;
  final List<PeerDto> peers;
  final bool batterySaverEnabled;
  final String? lastError;
  final int lastUpdatedMs;

  factory DashboardState.initial() {
    return const DashboardState(
      loading: true,
      permissionsMissing: false,
      bluetoothDisabled: false,
      emptyPeers: true,
      staleData: false,
      systemHealth: SystemHealthDto.offline,
      batteryPercent: 0,
      batteryAvailable: false,
      locationAvailable: false,
      signalState: 'standby',
      meshStats: MeshStatsDto(nodesActive: 0, meshRadiusKm: 0.0, btRangeKm: 0.0),
      peers: <PeerDto>[],
      batterySaverEnabled: false,
      lastError: null,
      lastUpdatedMs: 0,
    );
  }

  DashboardState copyWith({
    bool? loading,
    bool? permissionsMissing,
    bool? bluetoothDisabled,
    bool? emptyPeers,
    bool? staleData,
    SystemHealthDto? systemHealth,
    int? batteryPercent,
    bool? batteryAvailable,
    bool? locationAvailable,
    String? signalState,
    MeshStatsDto? meshStats,
    List<PeerDto>? peers,
    bool? batterySaverEnabled,
    String? lastError,
    bool clearError = false,
    int? lastUpdatedMs,
  }) {
    return DashboardState(
      loading: loading ?? this.loading,
      permissionsMissing: permissionsMissing ?? this.permissionsMissing,
      bluetoothDisabled: bluetoothDisabled ?? this.bluetoothDisabled,
      emptyPeers: emptyPeers ?? this.emptyPeers,
      staleData: staleData ?? this.staleData,
      systemHealth: systemHealth ?? this.systemHealth,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      batteryAvailable: batteryAvailable ?? this.batteryAvailable,
      locationAvailable: locationAvailable ?? this.locationAvailable,
      signalState: signalState ?? this.signalState,
      meshStats: meshStats ?? this.meshStats,
      peers: peers ?? this.peers,
      batterySaverEnabled: batterySaverEnabled ?? this.batterySaverEnabled,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastUpdatedMs: lastUpdatedMs ?? this.lastUpdatedMs,
    );
  }
}
