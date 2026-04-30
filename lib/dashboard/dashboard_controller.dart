import 'dart:async';

import '../app_routes.dart';
import '../chat/chat_session_dto.dart';
import '../quick_status_models.dart';
import '../services/app_settings_service.dart';
import '../services/chat_channel_service.dart';
import '../services/mesh_channel_service.dart';
import '../services/power_channel_service.dart';
import '../services/sos_channel_service.dart';
import '../services/system_channel_service.dart';
import 'dashboard_models.dart';

class DashboardController {
  DashboardController();

  static String? _appliedQuickPresetThisRun;

  final StreamController<DashboardState> _stateController =
      StreamController<DashboardState>.broadcast();

  DashboardState _state = DashboardState.initial();
  DashboardState get state => _state;
  Stream<DashboardState> get stateStream => _stateController.stream;

  StreamSubscription<Map<String, dynamic>>? _systemSub;
  StreamSubscription<Map<String, dynamic>>? _meshSub;
  StreamSubscription<Map<String, dynamic>>? _powerSub;
  Timer? _staleTimer;

  Future<void> init() async {
    _emit(_state.copyWith(loading: true, clearError: true));

    _systemSub = SystemChannelService.systemStatusUpdates.listen(_onSystemUpdate, onError: _onError);
    _meshSub = MeshChannelService.peersUpdates.listen(_onMeshUpdate, onError: _onError);
    _powerSub = PowerChannelService.powerStateUpdates.listen(_onPowerUpdate, onError: _onError);

    await _bootstrap();
    await _applyQuickStatusPresetOnEntry();

    _staleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final bool stale = _state.lastUpdatedMs == 0 ||
          DateTime.now().millisecondsSinceEpoch - _state.lastUpdatedMs > 15000;
      if (stale && !_state.staleData) {
        _emit(_state.copyWith(staleData: true));
      }
    });
  }

  void dispose() {
    _systemSub?.cancel();
    _meshSub?.cancel();
    _powerSub?.cancel();
    _staleTimer?.cancel();
    _stateController.close();
  }

  Future<ChatRouteArgs> startOfflineChat() async {
    final PeerDto? preferredPeer = _firstActivePeer();

    if (_state.bluetoothDisabled) {
      return ChatRouteArgs(
        peerId: preferredPeer?.id,
        peerName: preferredPeer?.name,
        forceStandby: true,
        session: ChatSessionDto.standby(
          peerId: preferredPeer?.id,
          peerName: preferredPeer?.name,
          errorCode: 'bluetooth_disabled',
        ),
      );
    }

    if (_state.permissionsMissing) {
      return ChatRouteArgs(
        peerId: preferredPeer?.id,
        peerName: preferredPeer?.name,
        forceStandby: true,
        session: ChatSessionDto.standby(
          peerId: preferredPeer?.id,
          peerName: preferredPeer?.name,
          errorCode: 'permissions_missing',
        ),
      );
    }

    if (preferredPeer == null) {
      return const ChatRouteArgs(forceStandby: true);
    }

    final Map<String, dynamic> result = await ChatChannelService.startOfflineChat(peerId: preferredPeer.id);
    if (result['ok'] == true) {
      return ChatRouteArgs(
        peerId: preferredPeer.id,
        peerName: preferredPeer.name,
        forceStandby: false,
        session: ChatSessionDto.fromMap(result),
      );
    }

    final String errorCode = result['error'] != null ? '${result['error']}' : 'session_open_failed';
    return ChatRouteArgs(
      peerId: preferredPeer.id,
      peerName: preferredPeer.name,
      forceStandby: true,
      session: ChatSessionDto.standby(
        peerId: preferredPeer.id,
        peerName: preferredPeer.name,
        errorCode: errorCode,
      ),
    );
  }

  Future<void> activateSos() async {
    await SosChannelService.triggerSos(
      latitude: 34.0522,
      longitude: -118.2437,
    );
  }

  Future<void> toggleBatterySaver() async {
    await PowerChannelService.setBatterySaver(!_state.batterySaverEnabled);
  }

  Future<BroadcastResultDto> broadcastQuickStatus(QuickStatusType status) async {
    final AppSettingsData appSettings = await AppSettingsService.load();
    final Map<String, dynamic> result =
        await ChatChannelService.broadcastQuickStatus(
          status: status.wireValue,
          displayName: appSettings.displayName,
        );
    if (status == QuickStatusType.needHelp) {
      await SosChannelService.triggerSos(
        latitude: 34.0522,
        longitude: -118.2437,
      );
    }
    return BroadcastResultDto.fromMap(result);
  }

  Future<void> _applyQuickStatusPresetOnEntry() async {
    try {
      final AppSettingsData appSettings = await AppSettingsService.load();
      final String presetWire = appSettings.quickStatusPreset.trim().toUpperCase();
      if (presetWire.isEmpty || presetWire == 'NONE') {
        return;
      }
      if (_appliedQuickPresetThisRun == presetWire) {
        return;
      }
      final QuickStatusType? status = QuickStatusTypeParse.fromWireValue(presetWire);
      if (status == null) {
        return;
      }

      await ChatChannelService.broadcastQuickStatus(
        status: status.wireValue,
        displayName: appSettings.displayName,
      );
      _appliedQuickPresetThisRun = presetWire;
    } catch (_) {
      // Preset auto-share should not block dashboard startup.
    }
  }

  Future<void> refreshMesh() async {
    await MeshChannelService.refreshPeers();
  }

  Future<void> _bootstrap() async {
    try {
      final status = await SystemChannelService.getStatus().timeout(
        const Duration(seconds: 2),
      );
      _onSystemUpdate(status);
    } catch (e) {
      _onError('system_bootstrap:$e');
    }

    try {
      final settings = await PowerChannelService.getSettings().timeout(
        const Duration(seconds: 2),
      );
      _onPowerUpdate(settings);
    } catch (e) {
      _onError('power_bootstrap:$e');
    }

    _emit(_state.copyWith(loading: false));
  }

  void _onSystemUpdate(Map<String, dynamic> data) {
    final String rawState = '${data['state'] ?? 'offline'}'.toLowerCase();
    final bool bluetoothEnabled = data['bluetoothEnabled'] == true;
    final bool permissionsMissing = data['permissionsMissing'] == true;
    final bool batteryAvailable = data['batteryAvailable'] == true;
    final bool locationAvailable = data['locationAvailable'] == true;
    final bool staleScanResults = data['staleScanResults'] == true;
    final int batteryPercent = (data['batteryPercent'] as num?)?.toInt() ?? (batteryAvailable ? _state.batteryPercent : 0);
    final int nodesActive = (data['nodesActive'] as num?)?.toInt() ?? _state.meshStats.nodesActive;
    final double meshRadiusKm = (data['meshRadiusKm'] as num?)?.toDouble() ?? _state.meshStats.meshRadiusKm;
    final double btRangeKm = (data['btRangeKm'] as num?)?.toDouble() ?? _state.meshStats.btRangeKm;
    final String signalState = '${data['signalState'] ?? _state.signalState}'.toLowerCase();

    final SystemHealthDto health;
    switch (rawState) {
      case 'operational':
        health = SystemHealthDto.operational;
        break;
      case 'degraded':
        health = SystemHealthDto.degraded;
        break;
      default:
        health = SystemHealthDto.offline;
    }

    _emit(
      _state.copyWith(
        systemHealth: health,
        bluetoothDisabled: !bluetoothEnabled,
        permissionsMissing: permissionsMissing,
        batteryPercent: batteryPercent,
        batteryAvailable: batteryAvailable,
        locationAvailable: locationAvailable,
        signalState: signalState,
        meshStats: MeshStatsDto(
          nodesActive: nodesActive,
          meshRadiusKm: meshRadiusKm,
          btRangeKm: btRangeKm,
        ),
        staleData: staleScanResults,
        emptyPeers: data['peersAvailable'] == false ? true : _state.emptyPeers,
        lastError: data['lastError'] != null ? '${data['lastError']}' : _state.lastError,
        lastUpdatedMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _onMeshUpdate(Map<String, dynamic> data) {
    final dynamic rawPeers = data['peers'];
    final List<PeerDto> peers = <PeerDto>[];

    if (rawPeers is List) {
      for (final dynamic item in rawPeers) {
        if (item is Map) {
          peers.add(PeerDto.fromMap(item.cast<String, dynamic>()));
        }
      }
    }

    final meshStats = MeshStatsDto.fromPeers(peers);

    _emit(
      _state.copyWith(
        peers: peers,
        meshStats: meshStats,
        emptyPeers: peers.isEmpty,
        lastUpdatedMs: DateTime.now().millisecondsSinceEpoch,
        staleData: false,
      ),
    );
  }

  void _onPowerUpdate(Map<String, dynamic> data) {
    _emit(
      _state.copyWith(
        batterySaverEnabled: data['batterySaverEnabled'] == true,
        lastUpdatedMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _onError(Object error) {
    _emit(_state.copyWith(lastError: '$error'));
  }

  void _emit(DashboardState value) {
    _state = value;
    if (!_stateController.isClosed) {
      _stateController.add(value);
    }
  }

  PeerDto? _firstActivePeer() {
    for (final peer in _state.peers) {
      final status = peer.status.toLowerCase();
      if (status == 'connected' || status == 'scanning') {
        return peer;
      }
    }
    return null;
  }
}
