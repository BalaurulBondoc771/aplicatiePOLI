import 'package:flutter/material.dart';

import '../../permissions/permissions_controller.dart';
import '../../permissions/permissions_state.dart';
import '../../widgets/app_bottom_nav.dart';
import 'offline_map_controller.dart';
import 'offline_map_dialog.dart';
import 'offline_map_state.dart';
import 'offline_vector_map_view.dart';

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final OfflineMapController _controller = OfflineMapController();
  final PermissionsController _permissionsController = PermissionsController();

  static const Color _bg = Color(0xFF07090D);
  static const Color _panel = Color(0xFF171A20);
  static const Color _amber = Color(0xFFF7B21A);
  static const Color _danger = Color(0x33EF242B);

  @override
  void initState() {
    super.initState();
    _permissionsController.init();
    _controller.init();
  }

  @override
  void dispose() {
    _permissionsController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PermissionsState>(
      stream: _permissionsController.stateStream,
      initialData: _permissionsController.state,
      builder: (context, permissionSnapshot) {
        final PermissionsState permissions = permissionSnapshot.data ?? _permissionsController.state;
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
                            if (!permissions.canUseLocationActions) ...[
                              _permissionBanner(permissions),
                              const SizedBox(height: 12),
                            ],
                            _packCard(state, permissions),
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
      },
    );
  }

  Widget _permissionBanner(PermissionsState permissions) {
    return Container(
      width: double.infinity,
      color: const Color(0x33EF242B),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              permissions.toBannerMessage(),
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
                color: Color(0xFFF7B21A),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
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

  Widget _packCard(OfflineMapState state, PermissionsState permissions) {
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
                  onTap: state.busy
                      ? null
                      : () async {
                          await _controller.downloadRomaniaPack();
                        },
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
      height: 340,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1018),
        border: Border.all(color: const Color(0xFF161C28), width: 1),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: OfflineVectorMapView(
              mapPackPath: state.localPath,
              latitude: state.latitude,
              longitude: state.longitude,
              minHeight: 340,
              showMyLocation: true,
              interactive: false,
              onPreviewTap: () => showOfflineMapDialog(
                context: context,
                mapPackPath: state.localPath,
                latitude: state.latitude,
                longitude: state.longitude,
                showMyLocation: true,
                title: 'OFFLINE ROMANIA MAP',
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
      color: const Color(0xFF12151B),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CURRENT POSITION',
            style: TextStyle(
              color: Color(0xFF9CA0AA),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
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
            'SOURCE: ${(state.locationSource ?? 'unknown').toUpperCase()} | ACC: +/- ${(state.accuracyMeters ?? 0).toStringAsFixed(0)}M',
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
    return const AppBottomNav(currentRoute: null);
  }
}
