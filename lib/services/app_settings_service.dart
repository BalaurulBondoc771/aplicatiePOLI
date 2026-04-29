import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'power_channel_service.dart';

class AppDeviceStatusProfile {
  const AppDeviceStatusProfile({
    required this.label,
    required this.detail,
    required this.colorValue,
  });

  final String label;
  final String detail;
  final int colorValue;
}

class AppDeviceBehaviorSummary {
  const AppDeviceBehaviorSummary({
    required this.scanIntervalLabel,
    required this.advertiseModeLabel,
    required this.txPowerLabel,
  });

  final String scanIntervalLabel;
  final String advertiseModeLabel;
  final String txPowerLabel;
}

class AppSettingsData {
  const AppSettingsData({
    required this.displayName,
    required this.statusPreset,
    required this.encryptionKey,
    required this.backgroundDiscoverabilityEnabled,
  });

  final String displayName;
  final String statusPreset;
  final String encryptionKey;
  final bool backgroundDiscoverabilityEnabled;

  factory AppSettingsData.defaults() {
    return const AppSettingsData(
      displayName: 'OPERATOR_X',
      statusPreset: 'SILENT / INCOGNITO',
      encryptionKey: 'BKOT-7F3A-91CD-E256-ROT',
      backgroundDiscoverabilityEnabled: true,
    );
  }

  factory AppSettingsData.fromJson(Map<String, dynamic> json) {
    final defaults = AppSettingsData.defaults();
    return AppSettingsData(
      displayName: (json['displayName'] as String?)?.trim().isNotEmpty == true
          ? (json['displayName'] as String).trim()
          : defaults.displayName,
      statusPreset: (json['statusPreset'] as String?)?.trim().isNotEmpty == true
          ? (json['statusPreset'] as String).trim()
          : defaults.statusPreset,
      encryptionKey: (json['encryptionKey'] as String?)?.trim().isNotEmpty == true
          ? (json['encryptionKey'] as String).trim()
          : defaults.encryptionKey,
        backgroundDiscoverabilityEnabled: json['backgroundDiscoverabilityEnabled'] is bool
          ? json['backgroundDiscoverabilityEnabled'] as bool
          : defaults.backgroundDiscoverabilityEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'displayName': displayName,
      'statusPreset': statusPreset,
      'encryptionKey': encryptionKey,
      'backgroundDiscoverabilityEnabled': backgroundDiscoverabilityEnabled,
    };
  }

  AppSettingsData copyWith({
    String? displayName,
    String? statusPreset,
    String? encryptionKey,
    bool? backgroundDiscoverabilityEnabled,
  }) {
    return AppSettingsData(
      displayName: displayName ?? this.displayName,
      statusPreset: statusPreset ?? this.statusPreset,
      encryptionKey: encryptionKey ?? this.encryptionKey,
      backgroundDiscoverabilityEnabled:
          backgroundDiscoverabilityEnabled ?? this.backgroundDiscoverabilityEnabled,
    );
  }
}

class AppSettingsService {
  AppSettingsService._();

  static AppSettingsData? _cache;
  static final ValueNotifier<AppSettingsData> current =
      ValueNotifier<AppSettingsData>(AppSettingsData.defaults());

  static Future<AppSettingsData> load() async {
    if (_cache != null) {
      return _cache!;
    }
    try {
      final File file = await _settingsFile();
      if (!file.existsSync()) {
        _cache = AppSettingsData.defaults();
        current.value = _cache!;
        await save(_cache!);
        return _cache!;
      }
      final String raw = await file.readAsString();
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _cache = AppSettingsData.fromJson(decoded);
      } else {
        _cache = AppSettingsData.defaults();
      }
    } catch (_) {
      _cache = AppSettingsData.defaults();
    }
    current.value = _cache!;
    return _cache!;
  }

  static Future<AppSettingsData> save(AppSettingsData data) async {
    _cache = data;
    current.value = data;
    try {
      final File file = await _settingsFile();
      await file.writeAsString(jsonEncode(data.toJson()));
    } catch (_) {
      // Keep in-memory settings when local persistence is unavailable.
    }
    return data;
  }

  static Future<void> syncToNative([AppSettingsData? data]) async {
    final AppSettingsData effective = data ?? _cache ?? current.value;
    try {
      await PowerChannelService.setIdentityProfile(
        displayName: effective.displayName,
        statusPreset: effective.statusPreset,
        backgroundDiscoverabilityEnabled: effective.backgroundDiscoverabilityEnabled,
      );
    } catch (_) {
      // Keep Flutter-side settings even if native sync is unavailable.
    }
  }

  static Future<File> _settingsFile() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}${Platform.pathSeparator}app_settings.json');
  }
}

extension AppSettingsDeviceProfile on AppSettingsData {
  AppDeviceStatusProfile get deviceStatusProfile {
    switch (statusPreset.toUpperCase()) {
      case 'FIELD READY':
        return const AppDeviceStatusProfile(
          label: 'READY',
          detail: 'FULL MESH PRESENCE ENABLED',
          colorValue: 0xFF36D26A,
        );
      case 'OPEN BROADCAST':
        return const AppDeviceStatusProfile(
          label: 'BROADCASTING',
          detail: 'HIGH VISIBILITY PROFILE',
          colorValue: 0xFF41A5FF,
        );
      case 'EMERGENCY WATCH':
        return const AppDeviceStatusProfile(
          label: 'ALERT WATCH',
          detail: 'PRIORITY RESPONSE MONITORING',
          colorValue: 0xFFE43A3A,
        );
      case 'SILENT / INCOGNITO':
      default:
        return const AppDeviceStatusProfile(
          label: 'SECURED',
          detail: 'LOW-SIGNATURE MESH MODE',
          colorValue: 0xFFB68118,
        );
    }
  }

  AppDeviceBehaviorSummary get behaviorSummary {
    switch (statusPreset.toUpperCase()) {
      case 'FIELD READY':
        return const AppDeviceBehaviorSummary(
          scanIntervalLabel: '15s',
          advertiseModeLabel: 'BALANCED',
          txPowerLabel: 'MEDIUM',
        );
      case 'OPEN BROADCAST':
        return const AppDeviceBehaviorSummary(
          scanIntervalLabel: '1s',
          advertiseModeLabel: 'LOW LATENCY',
          txPowerLabel: 'HIGH',
        );
      case 'EMERGENCY WATCH':
        return const AppDeviceBehaviorSummary(
          scanIntervalLabel: '3s',
          advertiseModeLabel: 'LOW LATENCY',
          txPowerLabel: 'HIGH',
        );
      case 'SILENT / INCOGNITO':
      default:
        return const AppDeviceBehaviorSummary(
          scanIntervalLabel: '120s',
          advertiseModeLabel: 'LOW POWER',
          txPowerLabel: 'LOW',
        );
    }
  }
}