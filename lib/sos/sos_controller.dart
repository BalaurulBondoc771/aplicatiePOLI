import 'dart:async';

import '../location/location_dto.dart';
import '../services/location_channel_service.dart';
import '../services/sos_channel_service.dart';
import 'sos_state.dart';

class SosController {
  SosController();

  static const int _holdDurationMs = 3000;
  static const int _tickMs = 50;

  final StreamController<SosState> _stateController =
      StreamController<SosState>.broadcast();

  SosState _state = SosState.initial();
  SosState get state => _state;
  Stream<SosState> get stateStream => _stateController.stream;

  Timer? _holdTimer;
  int _holdElapsedMs = 0;
  StreamSubscription<Map<String, dynamic>>? _sosSub;
  StreamSubscription<LocationDto>? _locationSub;

  void init() {
    _bootstrapLocation();
    LocationChannelService.observeLocationUpdates();
    _locationSub = LocationChannelService.locationUpdates.listen((location) {
      _applyLocation(location);
    }, onError: (Object error) {
      _emit(_state.copyWith(errorMessage: '$error'));
    });

    _sosSub = SosChannelService.sosStateUpdates.listen((event) {
      if (event['event'] == 'sos_state' && event['state'] == 'idle' && !_state.isHolding) {
        _emit(_state.copyWith(isSending: false));
      }
    }, onError: (Object error) {
      _emit(_state.copyWith(errorMessage: '$error'));
    });
  }

  void startHold() {
    if (_state.isSending || _state.isHolding) return;
    _holdElapsedMs = 0;
    _emit(
      _state.copyWith(
        isHolding: true,
        holdProgress: 0.0,
        clearError: true,
      ),
    );

    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: _tickMs), (timer) {
      _holdElapsedMs += _tickMs;
      final double progress = (_holdElapsedMs / _holdDurationMs).clamp(0.0, 1.0);
      _emit(_state.copyWith(holdProgress: progress));
      if (_holdElapsedMs >= _holdDurationMs) {
        timer.cancel();
        _completeHoldAndSend();
      }
    });
  }

  void endHold() {
    if (!_state.isHolding) return;
    if (_state.holdProgress >= 1.0) return;
    _holdTimer?.cancel();
    _holdElapsedMs = 0;
    _emit(_state.copyWith(isHolding: false, holdProgress: 0.0));
  }

  Future<void> _completeHoldAndSend() async {
    _emit(_state.copyWith(isHolding: false, holdProgress: 1.0));
    await sendSos();
  }

  Future<void> sendSos() async {
    if (_state.isSending) return;

    _emit(
      _state.copyWith(
        isSending: true,
        clearError: true,
      ),
    );

    try {
      final Map<String, dynamic> raw = await SosChannelService.sendSos();
      final SosSendResultDto result = SosSendResultDto.fromMap(raw);

      _emit(
        _state.copyWith(
          isSending: false,
          holdProgress: 0.0,
          sendResult: result,
          latitude: result.latitude,
          longitude: result.longitude,
          timestampMs: result.timestampMs,
          isLocationStale: result.isStale,
          isFallbackLocation: result.isFallback,
          gpsEnabled: result.gpsEnabled,
          permissionGranted: result.permissionGranted,
          locationSource: result.locationSource,
          errorMessage: result.ok ? null : (result.error ?? 'sos_send_failed'),
        ),
      );
    } catch (e) {
      _emit(
        _state.copyWith(
          isSending: false,
          holdProgress: 0.0,
          errorMessage: '$e',
        ),
      );
    }
  }

  void dispose() {
    _holdTimer?.cancel();
    _sosSub?.cancel();
    _locationSub?.cancel();
    _stateController.close();
  }

  Future<void> _bootstrapLocation() async {
    try {
      final current = await LocationChannelService.getCurrentLocation();
      _applyLocation(current);
      return;
    } catch (_) {
      // Fallback is handled below.
    }

    try {
      final fallback = await LocationChannelService.getLastKnownLocation();
      _applyLocation(fallback);
      _emit(
        _state.copyWith(
          errorMessage: 'location_fallback_last_known',
        ),
      );
    } catch (e) {
      _emit(_state.copyWith(errorMessage: '$e'));
    }
  }

  void _applyLocation(LocationDto location) {
    _emit(
      _state.copyWith(
        latitude: location.latitude,
        longitude: location.longitude,
        accuracyMeters: location.accuracyMeters,
        timestampMs: location.timestampMs,
        isLocationStale: location.isStale,
        isFallbackLocation: location.isFallback,
        gpsEnabled: location.gpsEnabled,
        permissionGranted: location.permissionGranted,
        locationSource: location.source,
      ),
    );
  }

  void _emit(SosState value) {
    _state = value;
    if (!_stateController.isClosed) {
      _stateController.add(value);
    }
  }
}
