import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_display_settings.dart';
import 'app_routes.dart';
import 'services/app_settings_service.dart';
import 'services/power_channel_service.dart';
import 'widgets/app_bottom_nav.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color _bg = Color(0xFF050608);
  static const Color _panel = Color(0xFF1C1C1F);
  static const Color _line = Color(0xFF2A2D31);
  static const Color _amber = Color(0xFFF7B21A);
  static const Color _muted = Color(0xFF7E838D);
  static const Color _text = Color(0xFFE8EAEE);

  static const List<String> _statusPresets = <String>[
    'SILENT / INCOGNITO',
    'FIELD READY',
    'OPEN BROADCAST',
    'EMERGENCY WATCH',
  ];

  bool _loading = true;
  String _displayName = 'OPERATOR_X';
  String _statusPreset = 'SILENT / INCOGNITO';
  String _encryptionKey = 'BKOT-7F3A-91CD-E256-ROT';
  bool _grayscaleEnabled = false;
  bool _backgroundDiscoverabilityEnabled = true;
  bool _meshActiveInApp = false;
  bool _backgroundBeaconActive = false;
  StreamSubscription<Map<String, dynamic>>? _powerStateSub;

  @override
  void initState() {
    super.initState();
    _load();
    _powerStateSub = PowerChannelService.powerStateUpdates.listen((powerSettings) {
      if (!mounted) return;
      setState(() {
        _grayscaleEnabled = powerSettings['grayscaleUiEnabled'] == true;
        _backgroundDiscoverabilityEnabled = powerSettings['backgroundBeaconEnabled'] == true;
        _meshActiveInApp = powerSettings['meshActiveInApp'] == true;
        _backgroundBeaconActive = powerSettings['backgroundBeaconActive'] == true;
      });
    });
  }

  Future<void> _load() async {
    final AppSettingsData local = await AppSettingsService.load();
    final Map<String, dynamic> powerSettings = await PowerChannelService.getPowerSettings();
    if (!mounted) return;
    setState(() {
      _displayName = local.displayName;
      _statusPreset = local.statusPreset;
      _encryptionKey = local.encryptionKey;
      _grayscaleEnabled = powerSettings['grayscaleUiEnabled'] == true;
      _backgroundDiscoverabilityEnabled = powerSettings['backgroundBeaconEnabled'] is bool
          ? powerSettings['backgroundBeaconEnabled'] == true
          : local.backgroundDiscoverabilityEnabled;
      _meshActiveInApp = powerSettings['meshActiveInApp'] == true;
      _backgroundBeaconActive = powerSettings['backgroundBeaconActive'] == true;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _powerStateSub?.cancel();
    super.dispose();
  }

  Future<void> _editDisplayName() async {
    final TextEditingController controller = TextEditingController(text: _displayName);
    final String? value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _panel,
          title: const Text(
            'DISPLAY NAME',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: _text),
            decoration: const InputDecoration(
              hintText: 'OPERATOR_X',
              hintStyle: TextStyle(color: _muted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL', style: TextStyle(color: _muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('SAVE', style: TextStyle(color: _amber)),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    setState(() {
      _displayName = value.toUpperCase();
    });
    await _persistLocalSettings();
  }

  Future<void> _chooseStatusPreset() async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _panel,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _statusPresets.map((preset) {
              final bool selected = preset == _statusPreset;
              return ListTile(
                title: Text(
                  preset,
                  style: TextStyle(
                    color: selected ? _amber : _text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check, color: _amber)
                    : const Icon(Icons.chevron_right, color: _muted),
                onTap: () => Navigator.of(context).pop(preset),
              );
            }).toList(growable: false),
          ),
        );
      },
    );
    if (selected == null || selected == _statusPreset) return;
    setState(() {
      _statusPreset = selected;
    });
    await _persistLocalSettings();
  }

  Future<void> _persistLocalSettings() async {
    final AppSettingsData next = AppSettingsData(
      displayName: _displayName,
      statusPreset: _statusPreset,
      encryptionKey: _encryptionKey,
      backgroundDiscoverabilityEnabled: _backgroundDiscoverabilityEnabled,
    );
    await AppSettingsService.save(next);
    await AppSettingsService.syncToNative(next);
  }

  Future<void> _toggleBackgroundDiscoverability(bool enabled) async {
    setState(() {
      _backgroundDiscoverabilityEnabled = enabled;
    });
    final AppSettingsData next = AppSettingsData(
      displayName: _displayName,
      statusPreset: _statusPreset,
      encryptionKey: _encryptionKey,
      backgroundDiscoverabilityEnabled: enabled,
    );
    await AppSettingsService.save(next);
    final Map<String, dynamic> response = await PowerChannelService.setBackgroundDiscoverability(enabled);
    if (!mounted) return;
    setState(() {
      _backgroundDiscoverabilityEnabled = response['backgroundBeaconEnabled'] == true;
      _meshActiveInApp = response['meshActiveInApp'] == true;
      _backgroundBeaconActive = response['backgroundBeaconActive'] == true;
    });
  }

  Future<void> _copyEncryptionKey() async {
    await Clipboard.setData(ClipboardData(text: _encryptionKey));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Encryption key copied.')),
    );
  }

  Future<void> _toggleGrayscale(bool enabled) async {
    final Map<String, dynamic> response = await PowerChannelService.setGrayscaleUi(enabled);
    final bool nextValue = response['grayscaleUiEnabled'] == true;
    AppDisplaySettings.setGrayscale(nextValue);
    if (!mounted) return;
    setState(() {
      _grayscaleEnabled = nextValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _amber))
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _deviceStatusCard(),
                          const SizedBox(height: 34),
                          _sectionTitle('SYSTEM'),
                          const SizedBox(height: 14),
                          _systemCard(),
                          const SizedBox(height: 34),
                          _sectionTitle('IDENTITY'),
                          const SizedBox(height: 14),
                          _identityCard(),
                          const SizedBox(height: 34),
                          _sectionTitle('DISPLAY'),
                          const SizedBox(height: 14),
                          _displayCard(),
                          const SizedBox(height: 34),
                          _sectionTitle('PROFILE SUMMARY'),
                          const SizedBox(height: 14),
                          _profileSummaryCard(),
                        ],
                      ),
                    ),
            ),
            const AppBottomNav(currentRoute: AppRoutes.settings),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Container(
      height: 82,
      color: const Color(0xFF171A20),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back, color: _amber, size: 34),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'SETTINGS',
              style: TextStyle(
                color: _amber,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.settings, color: Color(0xFFA8ADB8), size: 30),
        ],
      ),
    );
  }

  Widget _deviceStatusCard() {
    final AppDeviceStatusProfile profile = AppSettingsService.current.value.deviceStatusProfile;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _amber, width: 5)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEVICE STATUS',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.label,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Color(profile.colorValue),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profile.detail,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _amber,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
      ),
    );
  }

  Widget _systemCard() {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'APP VERSION',
                    style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '1.0.0',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _divider(),
          SwitchListTile(
            value: _backgroundDiscoverabilityEnabled,
            onChanged: _toggleBackgroundDiscoverability,
            activeThumbColor: _amber,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            title: const Text(
              'BACKGROUND DISCOVERABILITY',
              style: TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'KEEPS THIS DEVICE DISCOVERABLE AFTER THE APP LEAVES THE SCREEN',
              style: TextStyle(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _runtimeMeshStatusColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _runtimeMeshStatusLabel(),
                  style: TextStyle(
                    color: _runtimeMeshStatusColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityCard() {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _settingsRow(
            title: 'DISPLAY NAME',
            subtitle: _displayName,
            onTap: _editDisplayName,
          ),
          _divider(),
          _settingsRow(
            title: 'STATUS PRESET',
            subtitle: _statusPreset,
            subtitleColor: _amber,
            trailing: const Icon(Icons.keyboard_arrow_down, color: _muted, size: 28),
            onTap: _chooseStatusPreset,
          ),
          _divider(),
          _settingsRow(
            title: 'ENCRYPTION KEY',
            subtitle: 'AES-256 ROTATING',
            trailing: const Icon(Icons.key, color: _muted, size: 28),
            onTap: _copyEncryptionKey,
          ),
        ],
      ),
    );
  }

  Widget _displayCard() {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        value: _grayscaleEnabled,
        onChanged: _toggleGrayscale,
        activeThumbColor: _amber,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        title: const Text(
          'GRAYSCALE UI',
          style: TextStyle(
            color: _text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: const Text(
          'MATCHES THE POWER PAGE DISPLAY MODE',
          style: TextStyle(
            color: _muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }

  Widget _profileSummaryCard() {
    final AppDeviceBehaviorSummary summary = AppSettingsService.current.value.behaviorSummary;
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        children: [
          _summaryLine('SCAN INTERVAL', summary.scanIntervalLabel),
          const SizedBox(height: 12),
          _summaryLine('ADVERTISE MODE', summary.advertiseModeLabel),
          const SizedBox(height: 12),
          _summaryLine('TX POWER', summary.txPowerLabel),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _amber,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _settingsRow({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color subtitleColor = _muted,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing ?? const Icon(Icons.chevron_right, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, thickness: 1, color: _line);
  }

  String _runtimeMeshStatusLabel() {
    if (_meshActiveInApp) {
      return 'MESH ACTIVE IN APP';
    }
    if (_backgroundBeaconActive) {
      return 'BACKGROUND BEACON ACTIVE';
    }
    return 'MESH INACTIVE';
  }

  Color _runtimeMeshStatusColor() {
    if (_meshActiveInApp) {
      return const Color(0xFF41A5FF);
    }
    if (_backgroundBeaconActive) {
      return const Color(0xFF36D26A);
    }
    return _muted;
  }
}