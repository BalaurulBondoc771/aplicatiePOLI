import 'dart:async';

import '../services/permissions_channel_service.dart';
import 'permissions_state.dart';

class PermissionsController {
  PermissionsController({
    this.includeMicrophone = false,
    this.autoRequestOnInit = true,
  });

  final bool includeMicrophone;
  final bool autoRequestOnInit;
  bool _autoRequestTriggered = false;

  final StreamController<PermissionsState> _stateController =
      StreamController<PermissionsState>.broadcast();

  PermissionsState _state = PermissionsState.initial();
  PermissionsState get state => _state;
  Stream<PermissionsState> get stateStream => _stateController.stream;

  Future<void> init() async {
    await refresh();
    if (
      autoRequestOnInit &&
      !_autoRequestTriggered &&
      _shouldAutoRequestPermissions()
    ) {
      _autoRequestTriggered = true;
      await requestPermissions();
    }
  }

  Future<void> refresh() async {
    try {
      final map = await PermissionsChannelService.getPermissionStatus(
        includeMicrophone: includeMicrophone,
      );
      _emit(_mapToState(map, requestInProgress: false));
    } catch (e) {
      _emit(_state.copyWith(lastError: '$e'));
    }
  }

  Future<void> requestPermissions() async {
    _emit(_state.copyWith(requestInProgress: true, clearError: true));
    try {
      final map = await PermissionsChannelService.requestPermissions(
        includeMicrophone: includeMicrophone,
      );
      _emit(_mapToState(map, requestInProgress: false));
    } catch (e) {
      _emit(_state.copyWith(requestInProgress: false, lastError: '$e'));
    }
  }

  PermissionsState _mapToState(
    Map<String, dynamic> map, {
    required bool requestInProgress,
  }) {
    final permissionsRaw = map['permissions'];
    final permissions = permissionsRaw is Map
        ? permissionsRaw.map((key, value) => MapEntry('$key', '$value'))
        : const <String, String>{};

    return _state.copyWith(
      bluetoothScan: permissions['android.permission.BLUETOOTH_SCAN'] ?? _state.bluetoothScan,
      bluetoothConnect:
          permissions['android.permission.BLUETOOTH_CONNECT'] ?? _state.bluetoothConnect,
      fineLocation:
          permissions['android.permission.ACCESS_FINE_LOCATION'] ?? _state.fineLocation,
      microphone:
          permissions['android.permission.RECORD_AUDIO'] ??
              (includeMicrophone ? _state.microphone : 'not_required'),
      bluetoothEnabled: map['bluetoothEnabled'] == true,
      locationServiceEnabled: map['locationServiceEnabled'] == true,
      requestInProgress: requestInProgress,
      clearError: true,
    );
  }

  bool _shouldAutoRequestPermissions() {
    if (_state.permanentlyDeniedAny) {
      return false;
    }

    final bool missingCore =
        _state.bluetoothScan == 'denied' ||
        _state.bluetoothConnect == 'denied' ||
        _state.fineLocation == 'denied';

    if (missingCore) {
      return true;
    }

    return includeMicrophone && _state.microphone == 'denied';
  }

  void dispose() {
    _stateController.close();
  }

  void _emit(PermissionsState value) {
    _state = value;
    if (!_stateController.isClosed) {
      _stateController.add(value);
    }
  }
}
