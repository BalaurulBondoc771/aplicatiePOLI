import 'dart:async';

import '../../location/location_dto.dart';
import '../../services/location_channel_service.dart';
import 'offline_map_service.dart';
import 'offline_map_state.dart';

class OfflineMapController {
  OfflineMapController({OfflineMapService? service}) : _service = service ?? createOfflineMapService();

  final OfflineMapService _service;

  final StreamController<OfflineMapState> _stateController = StreamController<OfflineMapState>.broadcast();
  OfflineMapState _state = OfflineMapState.initial();
  StreamSubscription<LocationDto>? _locationSub;

  Stream<OfflineMapState> get stateStream => _stateController.stream;
  OfflineMapState get state => _state;

  Future<void> init() async {
    _locationSub = LocationChannelService.locationUpdates.listen(
      _applyLocation,
      onError: (Object error) {
        _emit(_state.copyWith(error: '$error'));
      },
    );
    unawaited(
      LocationChannelService.observeLocationUpdates().timeout(
        const Duration(seconds: 2),
        onTimeout: () => <String, dynamic>{'ok': false, 'error': 'observe_location_timeout'},
      ),
    );

    final bool supported = await _service.isSupported();
    if (!supported) {
      _emit(
        _state.copyWith(
          status: MapPackStatus.unsupported,
          error: 'Offline map pack download is available only on Android/iOS builds.',
        ),
      );
    }

    await Future.wait<void>([
      refreshPackState(),
      refreshLocation(),
    ]);
  }

  Future<void> refreshPackState() async {
    try {
      final MapPackInspection inspection = await _service.inspectRomaniaPack();
      if (!inspection.exists) {
        _emit(
          _state.copyWith(
            status: inspection.corrupted ? MapPackStatus.failed : MapPackStatus.notDownloaded,
            localPath: inspection.localPath,
            fileSizeBytes: inspection.fileSizeBytes,
            error: inspection.corrupted ? 'Corrupted map pack. Please redownload.' : null,
          ),
        );
        return;
      }

      _emit(
        _state.copyWith(
          status: MapPackStatus.downloaded,
          localPath: inspection.localPath,
          fileSizeBytes: inspection.fileSizeBytes,
          clearError: true,
        ),
      );
    } catch (e) {
      _emit(_state.copyWith(status: MapPackStatus.failed, error: '$e'));
    }
  }

  Future<void> downloadRomaniaPack() async {
    _emit(
      _state.copyWith(
        busy: true,
        status: MapPackStatus.downloading,
        downloadProgress: 0,
        clearError: true,
      ),
    );

    try {
      final MapPackInspection inspection = await _service.downloadRomaniaPack(
        onProgress: (double p) {
          _emit(_state.copyWith(downloadProgress: p, status: MapPackStatus.downloading));
        },
      );
      _emit(
        _state.copyWith(
          busy: false,
          status: MapPackStatus.downloaded,
          downloadProgress: 1,
          localPath: inspection.localPath,
          fileSizeBytes: inspection.fileSizeBytes,
          clearError: true,
        ),
      );
    } catch (e) {
      _emit(
        _state.copyWith(
          busy: false,
          status: MapPackStatus.failed,
          error: '$e',
        ),
      );
    }
  }

  Future<void> removeRomaniaPack() async {
    try {
      await _service.deleteRomaniaPack();
      _emit(
        _state.copyWith(
          status: MapPackStatus.notDownloaded,
          downloadProgress: 0,
          localPath: null,
          fileSizeBytes: null,
          clearError: true,
        ),
      );
    } catch (e) {
      _emit(_state.copyWith(error: '$e'));
    }
  }

  Future<void> refreshLocation() async {
    try {
      final LocationDto current = await LocationChannelService.getCurrentLocation().timeout(
        const Duration(seconds: 3),
      );
      _applyLocation(current);
      return;
    } catch (_) {}

    try {
      final LocationDto fallback = await LocationChannelService.getLastKnownLocation().timeout(
        const Duration(seconds: 3),
      );
      _applyLocation(fallback);
      _emit(_state.copyWith(error: 'Using last known location.'));
    } catch (e) {
      _emit(_state.copyWith(error: 'Location unavailable: $e'));
    }
  }

  void _applyLocation(LocationDto location) {
    _emit(
      _state.copyWith(
        latitude: location.latitude,
        longitude: location.longitude,
        accuracyMeters: location.accuracyMeters,
        timestampMs: location.timestampMs,
        locationFallback: location.isFallback,
        locationPermissionGranted: location.permissionGranted,
        gpsEnabled: location.gpsEnabled,
        locationSource: location.source,
        clearError: true,
      ),
    );
  }

  void dispose() {
    _locationSub?.cancel();
    _stateController.close();
  }

  void _emit(OfflineMapState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }
}
