import 'dart:async';

import '../app_display_settings.dart';
import '../services/power_channel_service.dart';
import '../services/sos_channel_service.dart';
import 'power_state.dart';

class PowerController {
  PowerController();

  static const int _sosHoldDurationMs = 3000;
  static const int _tickMs = 50;

  final StreamController<PowerState> _stateController =
      StreamController<PowerState>.broadcast();

  PowerState _state = PowerState.initial();
  PowerState get state => _state;
  Stream<PowerState> get stateStream => _stateController.stream;

  StreamSubscription<Map<String, dynamic>>? _powerSub;
  Timer? _sosHoldTimer;
  Timer? _runtimeRefreshTimer;
  Timer? _runtimeCountdownTimer;
  int _sosHoldElapsedMs = 0;

  Future<void> init() async {
    _powerSub = PowerChannelService.powerStateUpdates.listen((event) {
      if (event['event'] != 'power_settings') return;
      _applyPowerSettings(event);
    }, onError: (Object error) {
      _emit(_state.copyWith(error: '$error'));
    });

    _emit(_state.copyWith(loading: true, clearError: true));
    await refresh();
    _emit(_state.copyWith(loading: false));

    // Refresh runtime estimate every 30 seconds and animate countdown every second.
    _runtimeRefreshTimer?.cancel();
    _runtimeRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshRuntimeOnly(),
    );

    _runtimeCountdownTimer?.cancel();
    _runtimeCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickRuntimeCountdown(),
    );
  }

  Future<void> refresh() async {
    try {
      final settings = await PowerChannelService.getPowerSettings();
      _applyPowerSettings(settings);

      final runtime = await PowerChannelService.getRuntimeEstimate();
      _applyRuntimeEstimate(runtime);
    } catch (e) {
      _emit(_state.copyWith(error: '$e'));
    }
  }

  Future<void> setBatterySaver(bool enabled) async {
    final response = await PowerChannelService.setBatterySaver(enabled);
    _applyPowerSettings(response);
    await _refreshRuntimeOnly();
  }

  Future<void> setLowPowerBluetooth(bool enabled) async {
    final response = await PowerChannelService.setLowPowerBluetooth(enabled);
    _applyPowerSettings(response);
    await _refreshRuntimeOnly();
  }

  Future<void> setGrayscaleUi(bool enabled) async {
    final response = await PowerChannelService.setGrayscaleUi(enabled);
    _applyPowerSettings(response);
    await _refreshRuntimeOnly();
  }

  Future<void> killBackgroundApps() async {
    final response = await PowerChannelService.killBackgroundApps();
    _applyPowerSettings(response);
    final opened = response['openedSettingsDeepLink'] == true;
    _emit(
      _state.copyWith(
        lastAction: opened
            ? 'Internal optimization applied. Opened battery optimization settings.'
            : 'Internal optimization applied. Battery optimization settings unavailable.',
      ),
    );
    await _refreshRuntimeOnly();
  }

  void startSosHold() {
    if (_state.sendingSos || _state.isSosHolding) return;
    _sosHoldElapsedMs = 0;
    _emit(_state.copyWith(isSosHolding: true, sosHoldProgress: 0.0, clearError: true));

    _sosHoldTimer?.cancel();
    _sosHoldTimer = Timer.periodic(const Duration(milliseconds: _tickMs), (timer) {
      _sosHoldElapsedMs += _tickMs;
      final progress = (_sosHoldElapsedMs / _sosHoldDurationMs).clamp(0.0, 1.0);
      _emit(_state.copyWith(sosHoldProgress: progress));
      if (_sosHoldElapsedMs >= _sosHoldDurationMs) {
        timer.cancel();
        _triggerEmergencySos();
      }
    });
  }

  void endSosHold() {
    if (!_state.isSosHolding) return;
    if (_state.sosHoldProgress >= 1.0) return;
    _sosHoldTimer?.cancel();
    _sosHoldElapsedMs = 0;
    _emit(_state.copyWith(isSosHolding: false, sosHoldProgress: 0.0));
  }

  Future<void> _triggerEmergencySos() async {
    _emit(_state.copyWith(isSosHolding: false, sendingSos: true));
    try {
      final response = await SosChannelService.sendSos();
      final ok = response['ok'] == true;
      _emit(
        _state.copyWith(
          sendingSos: false,
          sosHoldProgress: 0.0,
          sosActive: ok || _state.sosActive,
          lastAction: ok ? 'Emergency SOS sent.' : 'Emergency SOS failed: ${response['error'] ?? 'unknown'}',
          error: ok ? null : '${response['error'] ?? 'sos_send_failed'}',
        ),
      );
      await refresh();
    } catch (e) {
      _emit(_state.copyWith(sendingSos: false, sosHoldProgress: 0.0, error: '$e'));
    }
  }

  Future<void> _refreshRuntimeOnly() async {
    try {
      final runtime = await PowerChannelService.getRuntimeEstimate();
      _applyRuntimeEstimate(runtime);
    } catch (e) {
      _emit(_state.copyWith(error: '$e'));
    }
  }

  void _applyRuntimeEstimate(Map<String, dynamic> runtime) {
    final int secondsFromNative = (runtime['seconds'] as num?)?.toInt() ?? -1;
    final int minutesFromNative = (runtime['minutes'] as num?)?.toInt() ?? _state.runtimeMinutes;
    final int resolvedSeconds =
        secondsFromNative >= 0 ? secondsFromNative : (minutesFromNative * 60);
    final String label = _formatRuntimeSeconds(resolvedSeconds);
    _emit(
      _state.copyWith(
        runtimeMinutes: resolvedSeconds ~/ 60,
        runtimeSeconds: resolvedSeconds,
        runtimeLabel: label,
        clearError: true,
      ),
    );
  }

  void _tickRuntimeCountdown() {
    if (_state.runtimeSeconds <= 0) {
      return;
    }
    final int nextSeconds = _state.runtimeSeconds - 1;
    _emit(
      _state.copyWith(
        runtimeSeconds: nextSeconds,
        runtimeMinutes: nextSeconds ~/ 60,
        runtimeLabel: _formatRuntimeSeconds(nextSeconds),
      ),
    );
  }

  void _applyPowerSettings(Map<String, dynamic> map) {
    final bool grayscaleEnabled = map['grayscaleUiEnabled'] == true;
    AppDisplaySettings.setGrayscale(grayscaleEnabled);
    _emit(
      _state.copyWith(
        batterySaverEnabled: map['batterySaverEnabled'] == true,
        lowPowerBluetoothEnabled: map['lowPowerBluetoothEnabled'] == true,
        grayscaleUiEnabled: grayscaleEnabled,
        criticalTasksOnlyEnabled: map['criticalTasksOnlyEnabled'] == true,
        sosActive: map['sosActive'] == true,
        scanIntervalMs: (map['scanIntervalMs'] as num?)?.toInt() ?? _state.scanIntervalMs,
        clearError: true,
      ),
    );
  }

  String _formatRuntimeSeconds(int seconds) {
    final int safeSeconds = seconds < 0 ? 0 : seconds;
    final h = (safeSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((safeSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (safeSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void dispose() {
    _sosHoldTimer?.cancel();
    _runtimeRefreshTimer?.cancel();
    _runtimeCountdownTimer?.cancel();
    _powerSub?.cancel();
    _stateController.close();
  }

  void _emit(PowerState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }
}
