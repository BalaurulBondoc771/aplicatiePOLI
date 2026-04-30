import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'offline_map_service.dart';
import 'offline_vector_tile_debug.dart';
import 'offline_vector_tile_pipeline.dart';
import 'poi_categories.dart';

class OfflineVectorMapView extends StatefulWidget {
  const OfflineVectorMapView({
    super.key,
    this.mapPackPath,
    this.latitude,
    this.longitude,
    this.minHeight = 180,
    this.showMyLocation = true,
    this.interactive = true,
    this.onPreviewTap,
  });

  final String? mapPackPath;
  final double? latitude;
  final double? longitude;
  final double minHeight;

  /// Activează dot-ul GPS nativ pe hartă și butoanele de navigație.
  final bool showMyLocation;
  final bool interactive;
  final VoidCallback? onPreviewTap;

  @override
  State<OfflineVectorMapView> createState() => _OfflineVectorMapViewState();
}

class _OfflineVectorMapViewState extends State<OfflineVectorMapView> {
  final OfflineMapService _service = createOfflineMapService();
  final OfflineVectorTilePipeline _pipeline = createOfflineVectorTilePipeline();
  Future<OfflineVectorMapConfig?>? _configFuture;
  MapLibreMapController? _mapController;
  double _resolvedFocusZoom = 9;
  double _resolvedMaxZoom = 9;

  MyLocationTrackingMode _trackingMode = MyLocationTrackingMode.none;
  LatLng? _userLocation;

  Set<String> _enabledCategories = Set<String>.from(kPoiCategories.map((c) => c.id));
  bool _filterOpen = false;
  bool _styleLoaded = false;

  @override
  void initState() {
    super.initState();
    _configFuture = _loadConfig();
  }

  @override
  void didUpdateWidget(covariant OfflineVectorMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapPackPath != widget.mapPackPath) {
      setState(() {
        _configFuture = _loadConfig();
      });
    }
    // Mută camera doar dacă nu suntem în modul follow (care face asta automat)
    if ((oldWidget.latitude != widget.latitude || oldWidget.longitude != widget.longitude) &&
        _trackingMode == MyLocationTrackingMode.none) {
      unawaited(_moveCameraToRequestedPoint());
    }
  }

  Future<OfflineVectorMapConfig?> _loadConfig() async {
    final directPath = widget.mapPackPath;
    if (directPath != null && directPath.isNotEmpty) {
      final config = await _pipeline.ensureStarted(mbtilesPath: directPath);
      if (config != null) {
        _resolvedFocusZoom = config.maxZoom;
        _resolvedMaxZoom = (config.maxZoom + 5).clamp(config.maxZoom, 20).toDouble();
      }
      return config;
    }

    final inspection = await _service.inspectRomaniaPack();
    if (!inspection.exists || inspection.localPath == null || inspection.localPath!.isEmpty) {
      return null;
    }
    final config = await _pipeline.ensureStarted(mbtilesPath: inspection.localPath!);
    if (config != null) {
      _resolvedFocusZoom = config.maxZoom;
      _resolvedMaxZoom = (config.maxZoom + 5).clamp(config.maxZoom, 20).toDouble();
    }
    return config;
  }

  Future<void> _moveCameraToRequestedPoint() async {
    final controller = _mapController;
    if (controller == null || widget.latitude == null || widget.longitude == null) {
      return;
    }
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(widget.latitude!, widget.longitude!),
            zoom: _resolvedFocusZoom,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _locateMe() async {
    final controller = _mapController;
    if (controller == null) return;
    final target = _userLocation ??
        (widget.latitude != null && widget.longitude != null
            ? LatLng(widget.latitude!, widget.longitude!)
            : null);
    if (target == null) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: _resolvedFocusZoom),
        ),
      );
    } catch (_) {}
  }

  void _toggleFollow() {
    setState(() {
      _trackingMode = _trackingMode == MyLocationTrackingMode.none
          ? MyLocationTrackingMode.tracking
          : MyLocationTrackingMode.none;
    });
  }

  // Dacă utilizatorul mișcă manual harta, dezactivăm modul follow
  void _onMapClick(Point<double> point, LatLng coordinates) {
    if (_trackingMode != MyLocationTrackingMode.none) {
      setState(() {
        _trackingMode = MyLocationTrackingMode.none;
      });
    }
  }

  void _onStyleLoaded() {
    if (!mounted) return;
    setState(() => _styleLoaded = true);
    _applyPoiVisibility();
  }

  void _applyPoiVisibility() {
    final ctrl = _mapController;
    if (ctrl == null || !_styleLoaded) return;
    for (final cat in kPoiCategories) {
      unawaited(_setLayerVisible(ctrl, cat.layerId, _enabledCategories.contains(cat.id)));
    }
  }

  Future<void> _setLayerVisible(
      MapLibreMapController ctrl, String layerId, bool visible) async {
    try {
      await ctrl.setLayerVisibility(layerId, visible);
    } catch (_) {}
  }

  void _toggleCategory(String id) {
    setState(() {
      if (_enabledCategories.contains(id)) {
        _enabledCategories.remove(id);
      } else {
        _enabledCategories.add(id);
      }
    });
    _applyPoiVisibility();
  }

  void _enableAllCategories() {
    setState(() {
      _enabledCategories = Set<String>.from(kPoiCategories.map((c) => c.id));
    });
    _applyPoiVisibility();
  }

  Widget _buildFilterPanel() {
    return Container(
      height: 48,
      color: const Color(0xEE07090D),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: kPoiCategories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            final allEnabled = _enabledCategories.length == kPoiCategories.length;
            return GestureDetector(
              onTap: allEnabled ? null : _enableAllCategories,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allEnabled
                      ? const Color(0x33F7B21A)
                      : const Color(0xFF1A1D24),
                  border: Border.all(
                    color: allEnabled
                        ? const Color(0xFFF7B21A)
                        : const Color(0xFF3A3D44),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'ALL',
                  style: TextStyle(
                    color: allEnabled
                        ? const Color(0xFFF7B21A)
                        : const Color(0xFF666A74),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            );
          }
          final cat = kPoiCategories[index - 1];
          final enabled = _enabledCategories.contains(cat.id);
          return GestureDetector(
            onTap: () => _toggleCategory(cat.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: enabled ? cat.color.withAlpha(40) : const Color(0xFF0E1015),
                border: Border.all(
                  color: enabled ? cat.color : const Color(0xFF2E3140),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat.iconData,
                    size: 11,
                    color: enabled ? cat.color : const Color(0xFF4A4E5A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cat.label,
                    style: TextStyle(
                      color: enabled ? cat.color : const Color(0xFF4A4E5A),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_pipeline.dispose());
    super.dispose();
  }

  String? _renderWarningForStats(OfflineTileDebugStats stats) {
    if (!_styleLoaded) {
      return null;
    }
    if (stats.lastStatus.startsWith('file-source-')) {
      return null;
    }
    if (stats.requests == 0) {
      return 'NO TILE REQUESTS. MAP SDK IS NOT REACHING THE LOCAL TILE SERVER.';
    }
    if (stats.requests > 0 && stats.hits == 0) {
      return 'TILES REQUESTED BUT NONE MATCHED IN MBTILES. CHECK TILE COORDINATE MAPPING.';
    }
    if (stats.hits > 0) {
      return 'TILES ARE LOADING. IF MAP STILL LOOKS EMPTY, THE ISSUE IS IN VECTOR RENDERING.';
    }
    return null;
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

        final bool followActive = _trackingMode != MyLocationTrackingMode.none;

        return SizedBox(
          height: widget.minHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: MapLibreMap(
                  key: ValueKey<String>(config.styleUrl),
                  styleString: config.styleUrl,
                  initialCameraPosition: CameraPosition(
                    target: target,
                    zoom: _resolvedFocusZoom,
                  ),
                  minMaxZoomPreference: MinMaxZoomPreference(config.minZoom, _resolvedMaxZoom),
                  scrollGesturesEnabled: widget.interactive,
                  zoomGesturesEnabled: widget.interactive,
                  doubleClickZoomEnabled: widget.interactive,
                  compassEnabled: widget.showMyLocation && widget.interactive,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  myLocationEnabled: widget.showMyLocation,
                  myLocationTrackingMode: _trackingMode,
                  myLocationRenderMode: MyLocationRenderMode.normal,
                  onUserLocationUpdated: (UserLocation location) {
                    _userLocation = location.position;
                  },
                  onMapClick: _onMapClick,
                  onStyleLoadedCallback: _onStyleLoaded,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    unawaited(_moveCameraToRequestedPoint());
                  },
                ),
              ),

              // Panoul de filtrare POI (apare deasupra butoanelor când e deschis)
              if (widget.showMyLocation && widget.interactive && _filterOpen)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 54,
                  child: _buildFilterPanel(),
                ),

              // Butoane GPS (locate me + follow) - dreapta-jos
              if (widget.showMyLocation && widget.interactive)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapButton(
                        icon: followActive ? Icons.navigation : Icons.navigation_outlined,
                        active: followActive,
                        tooltip: followActive ? 'Oprește urmărirea' : 'Urmărire automată',
                        onTap: _toggleFollow,
                      ),
                      const SizedBox(height: 6),
                      _MapButton(
                        icon: Icons.my_location,
                        active: false,
                        tooltip: 'Localizează-mă',
                        onTap: _locateMe,
                      ),
                    ],
                  ),
                ),

              // Buton filtrare POI - stânga-jos
              if (widget.showMyLocation && widget.interactive)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: _MapButton(
                    icon: Icons.layers,
                    active: _filterOpen || _enabledCategories.length < kPoiCategories.length,
                    tooltip: 'Filtrează POI-uri',
                    onTap: () => setState(() => _filterOpen = !_filterOpen),
                  ),
                ),

              // Crosshair static - vizibil DOAR când showMyLocation = false (mod preview)
              if (!widget.showMyLocation)
                const IgnorePointer(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xCC1A1F2A),
                              border: Border.fromBorderSide(
                                BorderSide(color: Color(0xFFF6C24A), width: 1.2),
                              ),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.location_on,
                          color: Color(0xFFF7B21A),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

              // Border overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0x661A1F2B), width: 1),
                    ),
                  ),
                ),
              ),
              if (!widget.interactive)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onPreviewTap,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          color: const Color(0xCC000000),
                          child: const Text(
                            'TAP FOR FULLSCREEN',
                            style: TextStyle(
                              color: Color(0xFFF7B21A),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.interactive)
                Positioned(
                  left: 10,
                  right: 10,
                  top: 10,
                  child: ValueListenableBuilder<OfflineTileDebugStats>(
                    valueListenable: offlineTileDebugStats,
                    builder: (context, stats, _) {
                      final warning = _renderWarningForStats(stats);
                      return IgnorePointer(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (warning != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                color: const Color(0xDD2C0C10),
                                child: Text(
                                  warning,
                                  style: const TextStyle(
                                    color: Color(0xFFFFB8B8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              color: const Color(0xB0000000),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (stats.exportedTiles > 0)
                                    Text(
                                      'LOCAL TILES EXPORTED: ${stats.exportedTiles}',
                                      style: const TextStyle(
                                        color: Color(0xFF9DF0C2),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  Text(
                                    'REQ ${stats.requests} | HIT ${stats.hits} | MISS ${stats.misses} | ${stats.lastStatus}',
                                    style: const TextStyle(
                                      color: Color(0xFFE4E8EE),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active ? const Color(0xEEF7B21A) : const Color(0xDD05070B),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? const Color(0xFFF7B21A) : const Color(0x55F7B21A),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Icon(
            icon,
            color: active ? Colors.black : const Color(0xFFF7B21A),
            size: 20,
          ),
        ),
      ),
    );
  }
}
