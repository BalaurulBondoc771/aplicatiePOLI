import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'features/offline_map/offline_map_dialog.dart';
import 'features/offline_map/offline_map_service.dart';
import 'features/offline_map/offline_vector_map_view.dart';
import 'permissions/permissions_controller.dart';
import 'permissions/permissions_state.dart';
import 'sos/sos_controller.dart';
import 'sos/sos_state.dart';
import 'widgets/app_bottom_nav.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  final SosController _controller = SosController();
  final PermissionsController _permissionsController = PermissionsController();
  final OfflineMapService _offlineMapService = createOfflineMapService();
  bool _offlineMapDownloaded = false;

  static const Color _bg = Color(0xFF080A0E);
  static const Color _panel = Color(0xFF16181D);
  static const Color _amber = Color(0xFFF3C65F);
  static const Color _amberStrong = Color(0xFFF7B20F);
  static const Color _red = Color(0xFFB50014);

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
                        _topBar(),
                        _coordinatesCard(state),
                        _sosHero(state, permissionState),
                        const SizedBox(height: 10),
                        const Center(
                          child: Text(
                            'TAP SURVIVAL GUIDE TO OPEN THE CHECKLIST',
                            style: TextStyle(
                              color: Color(0xFF767B86),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _emergencySosAction(state, permissionState),
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

  Widget _topBar() {
    return Container(
      height: 82,
      color: const Color(0xFF171A20),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: _amberStrong, size: 21),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'BLACKOUT LINK',
              style: TextStyle(
                color: Color(0xFFF6B31B),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
            child: const Icon(Icons.settings, color: Color(0xFFA8ADB8), size: 34),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${state.latitude.toStringAsFixed(4)} deg N',
                    style: const TextStyle(
                      color: Color(0xFFE9EBEF),
                      fontSize: 42,
                      height: 0.95,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${state.longitude.abs().toStringAsFixed(4)} deg W',
                    style: const TextStyle(
                      color: Color(0xFFE9EBEF),
                      fontSize: 42,
                      height: 0.95,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
    return GestureDetector(
      onTap: _showSurvivalGuideDialog,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        constraints: const BoxConstraints(minHeight: 280),
        width: double.infinity,
        decoration: BoxDecoration(
          color: _amber,
          border: Border.all(color: const Color(0xFF1A1D24), width: 1),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SurvivalGuideBadge(),
                const SizedBox(height: 14),
                const SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'SURVIVAL GUIDE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        height: 1,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'TAP TO OPEN CHECKLIST',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSurvivalGuideDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF12141A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 32),
                      child: Text(
                        'SURVIVAL GUIDE',
                        style: TextStyle(
                          color: Color(0xFFF7B21A),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Urmeaza pasii de mai jos in ordine:',
                      style: TextStyle(
                        color: Color(0xFFE7EAF0),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _guideStep('1. Muta-te intr-o zona sigura, ferita de trafic si structuri instabile.'),
                    _guideStep('2. Verifica rapid daca tu sau cei din jur aveti rani grave.'),
                    _guideStep('3. Economiseste bateria: redu luminozitatea si inchide aplicatiile inutile.'),
                    _guideStep('4. Activeaza localizarea si Bluetooth pentru coordonare in mesh.'),
                    _guideStep('5. Trimite status scurt (SAFE / NEED HELP) catre echipa sau familie.'),
                    _guideStep('6. Pastreaza apa, trusa medicala si documentele esentiale la indemana.'),
                    _guideStep('7. Urmeaza doar informatiile verificate si planul de evacuare local.'),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFFAAB0BB), size: 22),
                  tooltip: 'Inchide',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _guideStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_circle, color: Color(0xFFF7B21A), size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFDDE1E8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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

  Widget _emergencySosAction(SosState state, PermissionsState permissions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Listener(
            onPointerDown: (_) {
              if (!permissions.canUseSosActions) {
                _permissionsController.requestPermissions();
                return;
              }
              _controller.startHold();
            },
            onPointerUp: (_) => _controller.endHold(),
            onPointerCancel: (_) => _controller.endHold(),
            child: SizedBox(
              height: 96,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.emergency_outlined, size: 28),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          state.isSending
                              ? 'SENDING EMERGENCY\nSOS'
                              : 'ACTIVATE EMERGENCY\nSOS',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 7,
                      color: const Color(0x33000000),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: state.holdProgress.clamp(0.0, 1.0),
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              state.isSending
                  ? 'BROADCASTING LOCATION...'
                  : 'HOLD 3 SECONDS TO BROADCAST LOCATION',
              style: const TextStyle(
                color: Color(0xFF767B86),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationCard(SosState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 185,
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1018),
        border: Border.all(color: const Color(0xFF161C28), width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: OfflineVectorMapView(
              latitude: state.latitude,
              longitude: state.longitude,
              minHeight: 185,
              interactive: false,
              onPreviewTap: () => showOfflineMapDialog(
                context: context,
                latitude: state.latitude,
                longitude: state.longitude,
                title: 'SOS MAP',
                showMyLocation: true,
              ),
            ),
          ),
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
    return const AppBottomNav(currentRoute: AppRoutes.sos);
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

class _SurvivalGuideBadge extends StatelessWidget {
  const _SurvivalGuideBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 124,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 4),
                SizedBox(
                  width: 8,
                  height: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFFF2C34D), borderRadius: BorderRadius.all(Radius.circular(4))),
                  ),
                ),
                SizedBox(height: 7),
                SizedBox(
                  width: 10,
                  height: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFFF2C34D), shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

