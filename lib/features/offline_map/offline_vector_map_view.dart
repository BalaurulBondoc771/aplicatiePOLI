import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'offline_map_service.dart';
import 'offline_vector_tile_pipeline.dart';

class OfflineVectorMapView extends StatefulWidget {
  const OfflineVectorMapView({
    super.key,
    this.latitude,
    this.longitude,
    this.minHeight = 180,
  });

  final double? latitude;
  final double? longitude;
  final double minHeight;

  @override
  State<OfflineVectorMapView> createState() => _OfflineVectorMapViewState();
}

class _OfflineVectorMapViewState extends State<OfflineVectorMapView> {
  final OfflineMapService _service = createOfflineMapService();
  final OfflineVectorTilePipeline _pipeline = createOfflineVectorTilePipeline();
  Future<OfflineVectorMapConfig?>? _configFuture;
  MapLibreMapController? _controller;

  @override
  void initState() {
    super.initState();
    _configFuture = _loadConfig();
  }

  @override
  void didUpdateWidget(covariant OfflineVectorMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude || oldWidget.longitude != widget.longitude) {
      unawaited(_moveCameraToRequestedPoint());
    }
  }

  Future<OfflineVectorMapConfig?> _loadConfig() async {
    final inspection = await _service.inspectRomaniaPack();
    if (!inspection.exists || inspection.localPath == null) {
      return null;
    }
    return _pipeline.ensureStarted(mbtilesPath: inspection.localPath!);
  }

  Future<void> _moveCameraToRequestedPoint() async {
    final controller = _controller;
    if (controller == null || widget.latitude == null || widget.longitude == null) {
      return;
    }
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(widget.latitude!, widget.longitude!),
            zoom: 9,
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_pipeline.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OfflineVectorMapConfig?>(
      future: _configFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            height: widget.minHeight,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final config = snapshot.data;
        if (config == null) {
          return SizedBox(
            height: widget.minHeight,
            child: const Center(
              child: Text(
                'OFFLINE MAP NOT READY',
                style: TextStyle(
                  color: Color(0xFF9CA0AA),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          );
        }

        final target = LatLng(
          widget.latitude ?? config.centerLat,
          widget.longitude ?? config.centerLon,
        );

        return SizedBox(
          height: widget.minHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: MapLibreMap(
                  styleString: config.styleUrl,
                  initialCameraPosition: CameraPosition(
                    target: target,
                    zoom: 7,
                  ),
                  minMaxZoomPreference: MinMaxZoomPreference(config.minZoom, config.maxZoom + 1),
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  onMapCreated: (controller) {
                    _controller = controller;
                    unawaited(_moveCameraToRequestedPoint());
                  },
                ),
              ),
              const IgnorePointer(
                child: Center(
                  child: Icon(
                    Icons.location_on,
                    color: Color(0xFFF7B21A),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
