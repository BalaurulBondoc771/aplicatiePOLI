import 'package:flutter/material.dart';

import '../../app_routes.dart';
import 'offline_map_controller.dart';
import 'offline_map_state.dart';

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final OfflineMapController _controller = OfflineMapController();

  static const Color _bg = Color(0xFF07090D);
  static const Color _panel = Color(0xFF171A20);
  static const Color _amber = Color(0xFFF7B21A);
  static const Color _danger = Color(0x33EF242B);

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OfflineMapState>(
      stream: _controller.stateStream,
      initialData: _controller.state,
      builder: (context, snapshot) {
        final OfflineMapState state = snapshot.data ?? _controller.state;

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _packCard(state),
                        const SizedBox(height: 14),
                        _mapPreview(state),
                        const SizedBox(height: 12),
                        _locationCard(state),
                        if (state.error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            color: _danger,
                            child: Text(
                              state.error!,
                              style: const TextStyle(
                                color: Color(0xFFF5F6F8),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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
  }

  Widget _header(BuildContext context) {
    return Container(
      height: 72,
      color: const Color(0xFF0F1218),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back, color: Color(0xFFA8ADB8), size: 22),
          ),
          const SizedBox(width: 10),
          const Text(
            'OFFLINE ROMANIA MAP',
            style: TextStyle(
              color: Color(0xFFF7B21A),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _packCard(OfflineMapState state) {
    final String statusLabel;
    switch (state.status) {
      case MapPackStatus.notDownloaded:
        statusLabel = 'NOT DOWNLOADED';
        break;
      case MapPackStatus.downloading:
        statusLabel = 'DOWNLOADING ${(state.downloadProgress * 100).toStringAsFixed(0)}%';
        break;
      case MapPackStatus.downloaded:
        statusLabel = 'DOWNLOADED';
        break;
      case MapPackStatus.failed:
        statusLabel = 'FAILED';
        break;
      case MapPackStatus.unsupported:
        statusLabel = 'UNSUPPORTED ON WEB';
        break;
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(left: BorderSide(color: _amber, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OFFLINE ROMANIA MAP PACK',
            style: TextStyle(
              color: Color(0xFFEFF1F5),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'STATUS: $statusLabel',
            style: const TextStyle(
              color: Color(0xFF9CA0AA),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          if (state.fileSizeBytes != null) ...[
            const SizedBox(height: 4),
            Text(
              'SIZE: ${_formatBytes(state.fileSizeBytes!)}',
              style: const TextStyle(
                color: Color(0xFF9CA0AA),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (state.localPath != null) ...[
            const SizedBox(height: 4),
            Text(
              'PATH: ${state.localPath}',
              style: const TextStyle(
                color: Color(0xFF6B707B),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (state.status != MapPackStatus.unsupported)
                _actionButton(
                  label: state.status == MapPackStatus.downloaded ? 'REDOWNLOAD' : 'DOWNLOAD',
                  onTap: state.busy ? null : _controller.downloadRomaniaPack,
                ),
              _actionButton(
                label: 'REFRESH',
                onTap: state.busy
                    ? null
                    : () async {
                        await _controller.refreshPackState();
                        await _controller.refreshLocation();
                      },
              ),
              if (state.status == MapPackStatus.downloaded)
                _actionButton(
                  label: 'REMOVE',
                  onTap: state.busy ? null : _controller.removeRomaniaPack,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required String label, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: onTap == null ? const Color(0xFF5B5F68) : _amber,
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? const Color(0xFFCCD0D8) : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _mapPreview(OfflineMapState state) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1018),
        border: Border.all(color: const Color(0xFF161C28), width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _TacticalMapPainter()),
          ),
          if (state.latitude != null && state.longitude != null)
            Align(
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0x44F7B21A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _amber,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: const Color(0xCC000000),
              child: Text(
                state.status == MapPackStatus.downloaded ? 'OFFLINE MAP ACTIVE' : 'PREVIEW MODE',
                style: const TextStyle(
                  color: Color(0xFFF0F2F6),
                  fontWeight: FontWeight.w800,
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

  Widget _locationCard(OfflineMapState state) {
    final String coords = state.latitude != null && state.longitude != null
        ? '${state.latitude!.toStringAsFixed(5)}, ${state.longitude!.toStringAsFixed(5)}'
        : 'NO LOCATION';

    return Container(
      width: double.infinity,
      color: _panel,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'POSITION',
            style: TextStyle(
              color: Color(0xFF9CA0AA),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            coords,
            style: const TextStyle(
              color: Color(0xFFEFF1F5),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ACCURACY +/- ${state.accuracyMeters?.toStringAsFixed(0) ?? '-'}m | SOURCE ${state.locationSource ?? '-'}',
            style: const TextStyle(
              color: Color(0xFF9CA0AA),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'GPS ${state.gpsEnabled ? 'ON' : 'OFF'} | PERMISSION ${state.locationPermissionGranted ? 'OK' : 'DENIED'} | FALLBACK ${state.locationFallback ? 'YES' : 'NO'}',
            style: const TextStyle(
              color: Color(0xFF9CA0AA),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _bottomNav(BuildContext context) {
    return Container(
      height: 86,
      color: const Color(0xFF090B10),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.grid_view,
              label: 'DASHBOARD',
              active: false,
              onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.chat,
              label: 'CHAT',
              active: false,
              onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.chat),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.flash_on,
              label: 'POWER',
              active: false,
              onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.power),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.warning,
              label: 'SOS',
              active: false,
              onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.sos),
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
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF7B21A) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? Colors.black : const Color(0xFF737885), size: 21),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : const Color(0xFF737885),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
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

class _TacticalMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = const Color(0xFF293244).withValues(alpha: 0.25)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final Paint pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF5B6577).withValues(alpha: 0.18);

    final Path path1 = Path()
      ..moveTo(0, size.height * 0.55)
      ..cubicTo(size.width * 0.2, size.height * 0.35, size.width * 0.4, size.height * 0.82, size.width * 0.68, size.height * 0.45)
      ..cubicTo(size.width * 0.8, size.height * 0.3, size.width * 0.9, size.height * 0.5, size.width, size.height * 0.25);
    canvas.drawPath(path1, pathPaint);

    final Paint fog = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x66090D14), Color(0x22090D14), Color(0x88090D14)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fog);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
