import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'offline_vector_tile_pipeline.dart';
import 'poi_categories.dart';

class _OfflineVectorTilePipelineIo implements OfflineVectorTilePipeline {
  HttpServer? _server;
  Database? _db;
  String? _activePath;
  OfflineVectorMapConfig? _activeConfig;
  late Map<String, String> _metadata;
  late List<String> _vectorLayers;

  @override
  Future<OfflineVectorMapConfig?> ensureStarted({required String mbtilesPath}) async {
    final file = File(mbtilesPath);
    if (!file.existsSync()) {
      return null;
    }

    if (_activePath == mbtilesPath && _server != null && _activeConfig != null) {
      return _activeConfig;
    }

    await dispose();

    _db = sqlite3.open(mbtilesPath, mode: OpenMode.readOnly);
    _metadata = _readMetadata(_db!);
    _vectorLayers = _extractVectorLayerIds(_metadata['json']);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _activePath = mbtilesPath;

    server.listen((HttpRequest request) {
      _handleRequest(request);
    });

    final bounds = _parseBounds(_metadata['bounds']);
    final centerLat = (bounds?.$2 ?? 45.8);
    final centerLon = (bounds?.$1 ?? 24.9);
    final minZoom = _parseDouble(_metadata['minzoom'], fallback: 3);
    final maxZoom = _parseDouble(_metadata['maxzoom'], fallback: 12);
    final styleJson = _buildStyleJson();

    _activeConfig = OfflineVectorMapConfig(
      styleUrl: styleJson,
      centerLat: centerLat,
      centerLon: centerLon,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );

    return _activeConfig;
  }

  @override
  Future<void> dispose() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
    _db?.dispose();
    _db = null;
    _activePath = null;
    _activeConfig = null;
  }

  void _handleRequest(HttpRequest request) {
    final response = request.response;
    try {
      final path = request.uri.path;
      if (path == '/style.json') {
        response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
        response.write(_buildStyleJson());
        response.close();
        return;
      }

      final match = RegExp(r'^/tiles/(\d+)/(\d+)/(\d+)\.pbf$').firstMatch(path);
      if (match == null) {
        response.statusCode = HttpStatus.notFound;
        response.close();
        return;
      }

      final z = int.parse(match.group(1)!);
      final x = int.parse(match.group(2)!);
      final yXyz = int.parse(match.group(3)!);
      final db = _db;
      if (db == null) {
        response.statusCode = HttpStatus.serviceUnavailable;
        response.close();
        return;
      }

      final tileData = _lookupTileData(db, z, x, yXyz);
      if (tileData == null) {
        response.statusCode = HttpStatus.notFound;
        response.close();
        return;
      }

      response.headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.mapbox-vector-tile');
      if (_isGzip(tileData)) {
        response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      }
      response.add(tileData);
      response.close();
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
      response.close();
    }
  }

  bool _isGzip(List<int> data) {
    return data.length >= 2 && data[0] == 0x1f && data[1] == 0x8b;
  }

  List<int>? _lookupTileData(Database db, int z, int x, int yXyz) {
    final declaredScheme = (_metadata['scheme'] ?? '').toLowerCase();
    final yTms = ((1 << z) - 1) - yXyz;

    List<int>? queryByRow(int row) {
      final stmt = db.prepare(
        'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ? LIMIT 1',
      );
      final result = stmt.select([z, x, row]);
      stmt.dispose();
      if (result.isEmpty) return null;
      final data = result.first.columnAt(0);
      return data is List<int> ? data : null;
    }

    if (declaredScheme == 'xyz') {
      return queryByRow(yXyz) ?? queryByRow(yTms);
    }

    // Default to TMS (common in MBTiles), but keep XYZ fallback for portability.
    return queryByRow(yTms) ?? queryByRow(yXyz);
  }

  Map<String, String> _readMetadata(Database db) {
    final map = <String, String>{};
    final result = db.select('SELECT name, value FROM metadata');
    for (final row in result) {
      final name = row['name']?.toString() ?? '';
      final value = row['value']?.toString() ?? '';
      if (name.isNotEmpty) {
        map[name] = value;
      }
    }
    return map;
  }

  List<String> _extractVectorLayerIds(String? jsonValue) {
    if (jsonValue == null || jsonValue.isEmpty) {
      return const <String>[];
    }
    try {
      final decoded = json.decode(jsonValue);
      if (decoded is! Map<String, dynamic>) {
        return const <String>[];
      }
      final layers = decoded['vector_layers'];
      if (layers is! List) {
        return const <String>[];
      }
      return layers
          .whereType<Map>()
          .map((e) => '${e['id'] ?? ''}')
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  (double, double)? _parseBounds(String? bounds) {
    if (bounds == null || bounds.isEmpty) return null;
    final parts = bounds.split(',');
    if (parts.length != 4) return null;
    final minLon = double.tryParse(parts[0]);
    final minLat = double.tryParse(parts[1]);
    final maxLon = double.tryParse(parts[2]);
    final maxLat = double.tryParse(parts[3]);
    if (minLon == null || minLat == null || maxLon == null || maxLat == null) {
      return null;
    }
    return ((minLon + maxLon) / 2.0, (minLat + maxLat) / 2.0);
  }

  double _parseDouble(String? value, {required double fallback}) {
    return double.tryParse(value ?? '') ?? fallback;
  }

  String _buildStyleJson() {
    final minZoom = _parseDouble(_metadata['minzoom'], fallback: 3);
    final maxZoom = _parseDouble(_metadata['maxzoom'], fallback: 12);
    final tileUrl = 'http://127.0.0.1:${_server?.port ?? 0}/tiles/{z}/{x}/{y}.pbf';

    final effectiveLayers = _vectorLayers.isEmpty
        ? const <String>[
            'points',
            'lines',
            'multilinestrings',
            'multipolygons',
            'other_relations',
          ]
        : _vectorLayers;

    // Detect format: MapTiler standard OSM export uses 'multipolygons'/'lines' layer ids.
    // OpenMapTiles format uses 'water'/'landcover'/'building' etc.
    final isMapTilerOsm = effectiveLayers.contains('multipolygons') ||
      effectiveLayers.contains('lines');

    final layers = <Map<String, dynamic>>[
      {
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': '#ede9e0'},
      },
    ];

    if (isMapTilerOsm) {
      // ── MapTiler standard OSM format ─────────────────────────────────────
      // Layer IDs: points, lines, multilinestrings, multipolygons, other_relations

      // Keep this intentionally simple: no complex filters, just guaranteed base layers.
      if (effectiveLayers.contains('multipolygons')) {
        layers.add({
          'id': 'poly-base',
          'type': 'fill',
          'source': 'offline',
          'source-layer': 'multipolygons',
          'paint': {
            'fill-color': '#d6d2c8',
            'fill-outline-color': '#a29a89',
            'fill-opacity': 0.96,
          },
        });
      }

      // other_relations (typically admin boundaries as polygons)
      if (effectiveLayers.contains('other_relations')) {
        layers.add({
          'id': 'other-relations',
          'type': 'line',
          'source': 'offline',
          'source-layer': 'other_relations',
          'paint': {'line-color': '#836f5a', 'line-width': 1.0, 'line-opacity': 0.72},
        });
      }

      // multilinestrings: typically admin boundaries
      if (effectiveLayers.contains('multilinestrings')) {
        layers.add({
          'id': 'multilinestrings',
          'type': 'line',
          'source': 'offline',
          'source-layer': 'multilinestrings',
          'paint': {
            'line-color': '#a15f38',
            'line-width': 1.3,
            'line-opacity': 0.85,
            'line-dasharray': [4.0, 2.0],
          },
        });
      }

      if (effectiveLayers.contains('lines')) {
        layers.add({
          'id': 'lines-base',
          'type': 'line',
          'source': 'offline',
          'source-layer': 'lines',
          'paint': {
            'line-color': '#5b5f67',
            'line-width': [
              'interpolate',
              ['linear'],
              ['zoom'],
              4,
              0.6,
              9,
              1.3,
              13,
              2.4,
            ],
            'line-opacity': 0.92,
          },
        });
      }

      // points: POI-uri per categorie (un strat per categorie pentru filtrare independentă)
      if (effectiveLayers.contains('points')) {
        for (final cat in kPoiCategories) {
          final otherTagsFilter = cat.tagSnippets.isEmpty
              ? const <dynamic>['literal', false]
              : <dynamic>[
                  'any',
                  ...cat.tagSnippets.map(
                    (snippet) => <dynamic>[
                      'in',
                      snippet,
                      ['coalesce', ['get', 'other_tags'], ''],
                    ],
                  ),
                ];
          layers.add({
            'id': cat.layerId,
            'type': 'circle',
            'source': 'offline',
            'source-layer': 'points',
            'minzoom': cat.minZoom,
            'filter': otherTagsFilter,
            'layout': {'visibility': 'visible'},
            'paint': {
              'circle-radius': [
                'interpolate', ['linear'], ['zoom'],
                10.0, 2.5,
                14.0, 5.0,
              ],
              'circle-color': cat.hexColor,
              'circle-stroke-color': '#0A0A0A',
              'circle-stroke-width': 0.8,
              'circle-opacity': 0.88,
            },
          });
        }
      }
    } else {
      // ── OpenMapTiles format fallback ─────────────────────────────────────
      const omtFills = {
        'landcover': '#cad6bb', 'landuse': '#d8cfbf', 'park': '#bad6b1',
        'water': '#7baed6', 'aeroway': '#d5d0c7', 'building': '#c9c0b4',
      };
      const omtLines = {
        'waterway': '#5f96bf', 'boundary': '#9f5b35', 'transportation': '#575c65',
      };
      const omtDrawOrder = [
        'landcover', 'landuse', 'park', 'water', 'aeroway',
        'waterway', 'boundary', 'building', 'transportation',
      ];
      for (final name in omtDrawOrder) {
        if (!effectiveLayers.contains(name)) continue;
        if (omtFills.containsKey(name)) {
          layers.add({
            'id': 'fill_$name', 'type': 'fill', 'source': 'offline',
            'source-layer': name,
            'paint': {'fill-color': omtFills[name], 'fill-opacity': 0.96},
          });
        } else if (omtLines.containsKey(name)) {
          layers.add({
            'id': 'line_$name', 'type': 'line', 'source': 'offline',
            'source-layer': name,
            'paint': {
              'line-color': omtLines[name],
              'line-width': [
                'interpolate',
                ['linear'],
                ['zoom'],
                4,
                0.7,
                9,
                1.4,
                13,
                2.2,
              ],
              'line-opacity': 0.9,
            },
          });
        }
      }
    }

    final style = {
      'version': 8,
      'name': 'Blackout Offline',
      'sources': {
        'offline': {
          'type': 'vector',
          'scheme': 'xyz',
          'minzoom': minZoom.toInt(),
          'maxzoom': maxZoom.toInt(),
          'tiles': [tileUrl],
        }
      },
      'layers': layers,
    };

    return json.encode(style);
  }
}

OfflineVectorTilePipeline createOfflineVectorTilePipelineImpl() =>
    _OfflineVectorTilePipelineIo();
