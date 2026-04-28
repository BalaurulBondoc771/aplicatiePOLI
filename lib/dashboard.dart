import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'dashboard/dashboard_controller.dart';
import 'dashboard/dashboard_models.dart';
import 'features/offline_map/offline_map_dialog.dart';
import 'features/offline_map/offline_map_service.dart';
import 'features/offline_map/offline_vector_map_view.dart';
import 'permissions/permissions_controller.dart';
import 'permissions/permissions_state.dart';
import 'quick_status_models.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  static const Color amber = Color(0xFFF7B21A);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardController _controller = DashboardController();
  final PermissionsController _permissionsController = PermissionsController();
  final OfflineMapService _offlineMapService = createOfflineMapService();
  BroadcastResultDto? _quickStatusResult;
  bool _offlineMapDownloaded = false;

  static const Color _bg = Color(0xFF050608);
  static const Color _panel = Color(0xFF17191D);
  static const Color _panelSoft = Color(0xFF22242A);
  static const Color _green = Color(0xFF00DF86);
  static const Color _red = Color(0xFFEF242B);
  static const Color _text = Color(0xFFF5F6F8);
  static const Color _muted = Color(0xFF8F939D);

  @override
  void initState() {
    super.initState();
    _controller.init();
    _permissionsController.init();
    _refreshOfflineMapStatus();
  }

  @override
  void dispose() {
    _permissionsController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshOfflineMapStatus() async {
    try {
      final inspection = await _offlineMapService.inspectRomaniaPack();
      if (!mounted) return;
      setState(() {
        _offlineMapDownloaded = inspection.exists && !inspection.corrupted;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _offlineMapDownloaded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PermissionsState>(
      stream: _permissionsController.stateStream,
      initialData: _permissionsController.state,
      builder: (context, permissionSnapshot) {
        final PermissionsState permissionState =
            permissionSnapshot.data ?? _permissionsController.state;

        return StreamBuilder<DashboardState>(
          stream: _controller.stateStream,
          initialData: _controller.state,
          builder: (context, snapshot) {
            final DashboardState state = snapshot.data ?? DashboardState.initial();

            return Scaffold(
              backgroundColor: _bg,
              body: SafeArea(
                child: Column(
                  children: [
                if (state.loading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: DashboardPage.amber,
                    backgroundColor: Color(0xFF2A2E36),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!permissionState.canUseMeshActions ||
                              !permissionState.canUseLocationActions)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              color: const Color(0x33EF242B),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      permissionState.toBannerMessage(),
                                      style: const TextStyle(
                                        color: Color(0xFFF5F6F8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: _permissionsController.requestPermissions,
                                    child: const Text(
                                      'RETRY',
                                      style: TextStyle(
                                        color: DashboardPage.amber,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _header(state),
                          if (state.permissionsMissing ||
                              state.bluetoothDisabled ||
                              state.staleData ||
                              !state.batteryAvailable ||
                              !state.locationAvailable ||
                              state.signalState == 'standby')
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                _statusHint(state),
                                style: const TextStyle(
                                  color: Color(0xFFFFC266),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          _systemHealthCard(state),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _batteryCard(state)),
                              const SizedBox(width: 12),
                              Expanded(child: _rangeCard(state)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _sectionLabel('MISSION CRITICAL ACTIONS'),
                          const SizedBox(height: 14),
                          _offlineButton(context, enabled: permissionState.canUseMeshActions),
                          const SizedBox(height: 24),
                          _batterySaverRow(state),
                          const SizedBox(height: 24),
                          _meshRadiusCard(state),
                          const SizedBox(height: 10),
                          _offlineMapLink(context),
                          const SizedBox(height: 26),
                          _sectionLabel('NETWORK PEERS'),
                          const SizedBox(height: 14),
                          ..._peerList(state),
                          const SizedBox(height: 24),
                          _sectionLabel('QUICK STATUS SHARE'),
                          const SizedBox(height: 14),
                          if (_quickStatusResult != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              color: _quickStatusResult!.ok
                                  ? const Color(0x2200DF86)
                                  : const Color(0x33EF242B),
                              child: Text(
                                _quickStatusResult!.toBannerText(),
                                style: const TextStyle(
                                  color: Color(0xFFF5F6F8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          _quickGrid(permissionState),
                        ],
                      ),
                    ),
                  ),
                ),
                _bottomNav(context),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendQuickStatus(QuickStatusType status) async {
    final BroadcastResultDto result = await _controller.broadcastQuickStatus(status);
    if (!mounted) return;
    setState(() {
      _quickStatusResult = result;
    });
  }

  String _statusHint(DashboardState state) {
    if (state.permissionsMissing) {
      return 'Permissions missing - limited telemetry';
    }
    if (state.bluetoothDisabled) {
      return 'Bluetooth disabled - mesh offline';
    }
    if (!state.batteryAvailable) {
      return 'Battery reading unavailable - estimate degraded';
    }
    if (!state.locationAvailable) {
      return 'Location unavailable - routing confidence reduced';
    }
    if (state.signalState == 'standby') {
      return 'Signal standby - awaiting optimal peer coverage';
    }
    if (state.staleData) {
      return 'Telemetry stale - awaiting updates';
    }
    return '';
  }

  Widget _header(DashboardState state) {
    return Row(
      children: [
        Icon(Icons.signal_cellular_alt, color: DashboardPage.amber, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'MISSION_STATUS',
              style: TextStyle(
                color: DashboardPage.amber,
                fontSize: 31,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                height: 1,
              ),
            ),
          ),
        ),
          Text(
            '${state.batteryPercent}% BAT',
            style: TextStyle(
              color: DashboardPage.amber,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _systemHealthCard(DashboardState state) {
    final String healthLabel;
    final Color healthColor;

    switch (state.systemHealth) {
      case SystemHealthDto.operational:
        healthLabel = 'OPERATIONAL';
        healthColor = _green;
        break;
      case SystemHealthDto.degraded:
        healthLabel = 'DEGRADED';
        healthColor = DashboardPage.amber;
        break;
      case SystemHealthDto.offline:
        healthLabel = 'OFFLINE';
        healthColor = _red;
        break;
    }

    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: _panel,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SYSTEM HEALTH',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        healthLabel,
                        style: TextStyle(
                          color: _text,
                          fontSize: 42,
                          letterSpacing: -0.4,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: healthColor.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              state.systemHealth == SystemHealthDto.offline ? Icons.error : Icons.check_circle,
              color: healthColor,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _batteryCard(DashboardState state) {
    final int battery = state.batteryPercent.clamp(0, 100);

    return Container(
      height: 138,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      color: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BATTERY',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              letterSpacing: 3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$battery',
                        style: TextStyle(
                          color: _text,
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: '%',
                        style: TextStyle(
                          color: DashboardPage.amber,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 4,
            child: Row(
              children: [
                Expanded(flex: battery, child: Container(color: DashboardPage.amber)),
                Expanded(flex: 100 - battery, child: Container(color: const Color(0xFF2A2E36))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeCard(DashboardState state) {
    return Container(
      height: 138,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      color: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BT RANGE',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              letterSpacing: 3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: state.meshStats.btRangeKm.toStringAsFixed(1),
                        style: TextStyle(
                          color: _text,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: ' KM',
                        style: TextStyle(
                          color: const Color(0xFFC8CBD1),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(13, DashboardPage.amber),
              const SizedBox(width: 4),
              _bar(22, DashboardPage.amber),
              const SizedBox(width: 4),
              _bar(31, DashboardPage.amber),
              const SizedBox(width: 4),
              _bar(18, const Color(0xFF5D6068)),
              const SizedBox(width: 4),
              _bar(22, const Color(0xFF5D6068)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(double h, Color c) {
    return Container(width: 7, height: h, color: c);
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 3.2,
      ),
    );
  }

  Widget _offlineButton(BuildContext context, {required bool enabled}) {
    return SizedBox(
      height: 66,
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEFC45F),
          foregroundColor: Colors.black,
          shape: const RoundedRectangleBorder(),
          elevation: 0,
        ),
        onPressed: !enabled
            ? null
            : () async {
          final chatArgs = await _controller.startOfflineChat();
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.chat,
            arguments: chatArgs,
          );
        },
        icon: const Icon(Icons.bluetooth, size: 22),
        label: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'START OFFLINE CHAT',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _batterySaverRow(DashboardState state) {
    return GestureDetector(
      onTap: _controller.toggleBatterySaver,
      child: Container(
        height: 84,
        color: _panelSoft,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Icon(Icons.battery_charging_full, color: DashboardPage.amber, size: 25),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'BATTERY SAVER',
                    style: TextStyle(
                      color: Color(0xFFE8EAEE),
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      letterSpacing: 0.4,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'EXTEND MESH UPTIME',
                    style: TextStyle(
                      color: Color(0xFF9EA3AD),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 1,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 56,
              height: 30,
              color: state.batterySaverEnabled
                  ? DashboardPage.amber
                  : const Color(0xFF4A4D53),
              padding: const EdgeInsets.all(4),
              child: Align(
                alignment: state.batterySaverEnabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(width: 18, height: 18, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meshRadiusCard(DashboardState state) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _panel,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: OfflineVectorMapView(
              minHeight: 250,
              interactive: false,
              onPreviewTap: () => showOfflineMapDialog(
                context: context,
                title: 'NETWORK MAP',
                showMyLocation: true,
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.black,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: DashboardPage.amber,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${state.meshStats.nodesActive} NODES ACTIVE',
                    style: const TextStyle(
                      color: Color(0xFFF0F2F6),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: Colors.black,
              child: Row(
                children: [
                  Icon(
                    _offlineMapDownloaded ? Icons.map : Icons.map_outlined,
                    color: _offlineMapDownloaded ? DashboardPage.amber : const Color(0xFF8F939D),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _offlineMapDownloaded ? 'MAP PACK READY' : 'MAP PACK MISSING',
                    style: const TextStyle(
                      color: Color(0xFFF0F2F6),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT MESH RADIUS',
                  style: TextStyle(
                    color: Color(0xFFA3A8B1),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${state.meshStats.meshRadiusKm.toStringAsFixed(1)} KM',
                    style: const TextStyle(
                      color: Color(0xFFF5F6F8),
                      fontWeight: FontWeight.w800,
                      fontSize: 44,
                      height: 1,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _offlineMapLink(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).pushNamed(AppRoutes.offlineMap);
        if (!mounted) return;
        await _refreshOfflineMapStatus();
      },
      child: Container(
        height: 46,
        width: double.infinity,
        color: const Color(0xFF12151B),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: const [
            Icon(Icons.map_outlined, color: DashboardPage.amber, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'OPEN OFFLINE ROMANIA MAP',
                style: TextStyle(
                  color: Color(0xFFEFF1F5),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Icon(Icons.arrow_forward, color: Color(0xFF8F939D), size: 16),
          ],
        ),
      ),
    );
  }

  List<Widget> _peerList(DashboardState state) {
    if (state.emptyPeers) {
      return [
        _peerTile(
          badge: '-',
          name: 'NO PEERS DETECTED',
          status: 'SCANNING...',
          color: DashboardPage.amber,
        ),
      ];
    }

    final peers = state.peers.take(4).toList();
    final widgets = <Widget>[];

    for (var i = 0; i < peers.length; i++) {
      final peer = peers[i];
      widgets.add(
        _peerTile(
          badge: String.fromCharCode(65 + i),
          name: peer.name.toUpperCase(),
          status: '${peer.status.toUpperCase()} - ${peer.distanceMeters.toStringAsFixed(0)}M',
          color: peer.status.toLowerCase() == 'connected' ? _green : DashboardPage.amber,
        ),
      );
      if (i < peers.length - 1) {
        widgets.add(const SizedBox(height: 8));
      }
    }

    return widgets;
  }

  Widget _peerTile({
    required String badge,
    required String name,
    required String status,
    required Color color,
  }) {
    return Container(
      height: 86,
      width: double.infinity,
      color: _panel,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            color: const Color(0xFF2B2E34),
            alignment: Alignment.center,
            child: Text(
              badge,
              style: const TextStyle(
                color: Color(0xFFF5F6F8),
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFFF3F5F8),
                    fontSize: 18,
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.more_vert, color: Color(0xFF747882), size: 22),
        ],
      ),
    );
  }

  Widget _quickGrid(PermissionsState permissions) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 1.25,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _QuickCard(
          icon: Icons.check,
          label: 'I AM SAFE',
          iconBg: const Color(0xFFF4B51B),
          iconColor: Colors.black,
          onTap: permissions.canUseMeshActions
              ? () => _sendQuickStatus(QuickStatusType.iAmSafe)
              : _permissionsController.requestPermissions,
        ),
        _QuickCard(
          icon: Icons.medical_services,
          label: 'NEED HELP',
          iconBg: const Color(0xFFFFB9B9),
          iconColor: const Color(0xFF4E1C1C),
          onTap: permissions.canUseMeshActions
              ? () => _sendQuickStatus(QuickStatusType.needHelp)
              : _permissionsController.requestPermissions,
        ),
        _QuickCard(
          icon: Icons.explore,
          label: 'EN ROUTE',
          iconBg: const Color(0xFFB3B8C1),
          iconColor: const Color(0xFF1F242B),
          onTap: permissions.canUseMeshActions
              ? () => _sendQuickStatus(QuickStatusType.onMyWay)
              : _permissionsController.requestPermissions,
        ),
        _QuickCard(
          icon: Icons.battery_3_bar,
          label: 'LOW BATTERY',
          iconBg: const Color(0xFFC8CCD3),
          iconColor: const Color(0xFF30343C),
          onTap: permissions.canUseMeshActions
              ? () => _sendQuickStatus(QuickStatusType.lowBattery)
              : _permissionsController.requestPermissions,
        ),
      ],
    );
  }

  Widget _bottomNav(BuildContext context) {
    return Container(
      height: 86,
      color: const Color(0xFF12141A),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(child: _NavItem(icon: Icons.dashboard_outlined, label: 'DASHBOARD', active: true)),
          Expanded(
            child: _NavItem(
              icon: Icons.chat_outlined,
              label: 'CHAT',
              active: false,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.chat);
              },
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.flash_on_outlined,
              label: 'POWER',
              active: false,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.power);
              },
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.warning_amber_rounded,
              label: 'SOS',
              active: false,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.sos);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 70,
        decoration: BoxDecoration(
          color: active ? DashboardPage.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? Colors.black : const Color(0xFF737885),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : const Color(0xFF737885),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: _DashboardPageState._panelSoft,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE9EBEF),
                fontSize: 13,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
