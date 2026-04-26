import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'features/offline_map/offline_map_service.dart';
import 'permissions/permissions_controller.dart';
import 'permissions/permissions_state.dart';
import 'quick_status_models.dart';
import 'services/chat_channel_service.dart';
import 'sos/sos_controller.dart';
import 'sos/sos_state.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  BroadcastResultDto? _quickStatusResult;
  final SosController _controller = SosController();
  final PermissionsController _permissionsController = PermissionsController();
  final OfflineMapService _offlineMapService = createOfflineMapService();
  bool _offlineMapDownloaded = false;

  static const Color _bg = Color(0xFF080A0E);
  static const Color _panel = Color(0xFF16181D);
  static const Color _panelSoft = Color(0xFF24262C);
  static const Color _amber = Color(0xFFF3C65F);
  static const Color _amberStrong = Color(0xFFF7B20F);

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

        return StreamBuilder<SosState>(
          stream: _controller.stateStream,
          initialData: _controller.state,
          builder: (context, snapshot) {
            final SosState state = snapshot.data ?? _controller.state;

            return Scaffold(
              backgroundColor: _bg,
              body: SafeArea(
                bottom: true,
                child: Column(
                  children: [
                if (!permissionState.canUseSosActions)
                  Container(
                    width: double.infinity,
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
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _permissionsController.requestPermissions,
                          child: const Text(
                            'RETRY',
                            style: TextStyle(
                              color: Color(0xFFF7B21A),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _topBar(state),
                        _coordinatesCard(state),
                        _sosHero(state, permissionState),
                        const SizedBox(height: 14),
                        _section('QUICK STATUS SHARE'),
                        const SizedBox(height: 10),
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
                        const SizedBox(height: 14),
                        _section('LAST KNOWN LOCATION'),
                        const SizedBox(height: 10),
                        _locationCard(state),
                        const SizedBox(height: 10),
                        _offlineMapLink(context),
                        const SizedBox(height: 30),
                      ],
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

  Widget _topBar(SosState state) {
    final String signal = state.isSending
        ? 'SIGNAL: SENDING'
        : (state.sendResult != null ? 'SIGNAL: ${state.sendResult!.ok ? 'DELIVERED' : 'DEGRADED'}' : 'SIGNAL: STANDBY');
    return Container(
      height: 60,
      color: const Color(0xFF171A20),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.cell_tower, color: _amberStrong, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'BLACKOUTLINK',
              style: TextStyle(
                color: Color(0xFFF6B31B),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFCB9524),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            signal,
            style: const TextStyle(
              color: Color(0xFFB2B6BF),
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _coordinatesCard(SosState state) {
    return Container(
      width: double.infinity,
      color: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFF0F1115),
            child: const Text(
              'CURRENT COORDINATES',
              style: TextStyle(
                color: Color(0xFFF5B51F),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.latitude.toStringAsFixed(4)}°N',
                  style: const TextStyle(
                    color: Color(0xFFE9EBEF),
                    fontSize: 42,
                    height: 0.95,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.longitude.abs().toStringAsFixed(4)}°W',
                  style: const TextStyle(
                    color: Color(0xFFE9EBEF),
                    fontSize: 42,
                    height: 0.95,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Color(0xFF8D919A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'UPDATED: ${_formatTimestamp(state.timestampMs)}  +/- ${state.accuracyMeters.toStringAsFixed(0)}M',
                        style: const TextStyle(
                          color: Color(0xFFA2A7B0),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (state.isFallbackLocation || state.isLocationStale || !state.gpsEnabled || !state.permissionGranted) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: const Color(0x22000000),
                    child: Text(
                      _locationHealthText(state),
                      style: const TextStyle(
                        color: Color(0xFFE4E6EB),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sosHero(SosState state, PermissionsState permissions) {
    final double progress = state.holdProgress.clamp(0.0, 1.0);

    return Listener(
      onPointerDown: (_) =>
          permissions.canUseSosActions ? _controller.startHold() : _permissionsController.requestPermissions(),
      onPointerUp: (_) => _controller.endHold(),
      onPointerCancel: (_) => _controller.endHold(),
      child: Container(
        constraints: const BoxConstraints(minHeight: 280),
        width: double.infinity,
        color: _amber,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  transform: Matrix4.rotationZ(0.785398),
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: -0.785398,
                    child: const Text(
                      '!',
                      style: TextStyle(
                        color: Color(0xFFF2C34D),
                        fontSize: 68,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 58,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.isSending
                      ? 'SENDING ALERT...'
                      : (state.isHolding ? 'HOLDING... ${(progress * 100).toInt()}%' : 'HOLD FOR 3 SECONDS'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 8,
                color: const Color(0x33000000),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF707680),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
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

  Future<void> _sendQuickStatus(QuickStatusType status) async {
    final Map<String, dynamic> raw =
        await ChatChannelService.broadcastQuickStatus(status: status.wireValue);
    if (!mounted) return;
    setState(() {
      _quickStatusResult = BroadcastResultDto.fromMap(raw);
    });
  }

  Widget _locationCard(SosState state) {
    return Container(
      height: 185,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1018),
        border: Border.all(color: const Color(0xFF161C28), width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapPainter())),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: Colors.black,
              child: Row(
                children: [
                  Icon(
                    _offlineMapDownloaded ? Icons.map : Icons.map_outlined,
                    color: _offlineMapDownloaded ? _amberStrong : const Color(0xFF8F939D),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _offlineMapDownloaded ? 'OFFLINE MAP READY' : 'OFFLINE MAP MISSING',
                    style: const TextStyle(
                      color: Color(0xFFF0F2F6),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0x66D79A1C),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _amberStrong,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'SATELLITE SYNC: ${_secondsAgo(state.timestampMs)}S AGO',
                style: const TextStyle(
                  color: Color(0xFFF0F2F6),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
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
        margin: const EdgeInsets.symmetric(horizontal: 12),
        height: 46,
        width: double.infinity,
        color: const Color(0xFF12151B),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: const [
            Icon(Icons.map_outlined, color: Color(0xFFF7B20F), size: 18),
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

  Widget _bottomNav(BuildContext context) {
    return Container(
      height: 86,
      color: const Color(0xFF12141A),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_outlined,
              label: 'DASHBOARD',
              active: false,
              onTap: () {
                Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
              },
            ),
          ),
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
          const Expanded(child: _NavItem(icon: Icons.warning_amber_rounded, label: 'SOS', active: true)),
        ],
      ),
    );
  }

  String _formatTimestamp(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  int _secondsAgo(int timestampMs) {
    final diff = DateTime.now().millisecondsSinceEpoch - timestampMs;
    return (diff / 1000).round().clamp(0, 9999);
  }

  String _locationHealthText(SosState state) {
    if (!state.permissionGranted) {
      return 'LOCATION FALLBACK: PERMISSION MISSING';
    }
    if (!state.gpsEnabled) {
      return 'LOCATION FALLBACK: GPS DISABLED (${state.locationSource.toUpperCase()})';
    }
    if (state.isFallbackLocation) {
      return 'LOCATION FALLBACK: LAST KNOWN (${state.locationSource.toUpperCase()})';
    }
    if (state.isLocationStale) {
      return 'LOCATION STALE: LAST UPDATE ${_secondsAgo(state.timestampMs)}S AGO';
    }
    return 'LOCATION: LIVE';
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
        color: _SosPageState._panelSoft,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
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
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF7B21A) : Colors.transparent,
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
                fontSize: 11,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w800,
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

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF293244).withOpacity(0.25)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF5B6577).withOpacity(0.18);

    final path1 = Path()
      ..moveTo(0, size.height * 0.55)
      ..cubicTo(size.width * 0.2, size.height * 0.35, size.width * 0.4, size.height * 0.82, size.width * 0.68, size.height * 0.45)
      ..cubicTo(size.width * 0.8, size.height * 0.3, size.width * 0.9, size.height * 0.5, size.width, size.height * 0.25);
    canvas.drawPath(path1, pathPaint);

    final path2 = Path()
      ..moveTo(size.width * 0.12, 0)
      ..cubicTo(size.width * 0.3, size.height * 0.22, size.width * 0.17, size.height * 0.56, size.width * 0.35, size.height)
      ..moveTo(size.width * 0.73, 0)
      ..cubicTo(size.width * 0.76, size.height * 0.32, size.width * 0.84, size.height * 0.6, size.width * 0.86, size.height);
    canvas.drawPath(path2, pathPaint);

    final fog = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x66090D14), Color(0x22090D14), Color(0x88090D14)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fog);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
