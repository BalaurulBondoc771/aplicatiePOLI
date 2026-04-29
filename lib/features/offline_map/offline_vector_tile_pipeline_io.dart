import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'offline_vector_tile_debug.dart';
import 'offline_vector_tile_pipeline.dart';
import 'poi_categories.dart';

class _OfflineVectorTilePipelineIo implements OfflineVectorTilePipeline {
  Database? _db;
  String? _activePath;
  String? _activeTilesDir;
  OfflineVectorMapConfig? _activeConfig;
  late Map<String, String> _metadata;
  late List<String> _vectorLayers;

  @override
  Future<OfflineVectorMapConfig?> ensureStarted({required String mbtilesPath}) async {
    final file = File(mbtilesPath);
    if (!file.existsSync()) {
      return null;
    }

    if (_activePath == mbtilesPath && _activeTilesDir != null && _activeConfig != null) {
      return _activeConfig;
    }

    await dispose();

    _db = sqlite3.open(mbtilesPath, mode: OpenMode.readOnly);
    _metadata = _readMetadata(_db!);
    _vectorLayers = _extractVectorLayerIds(_metadata['json']);
    _activePath = mbtilesPath;
    final tilesDir = await _materializeTiles(mbtilesPath, _db!);
    _activeTilesDir = tilesDir.path;

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
    _db?.dispose();
    _db = null;
    _activePath = null;
    _activeTilesDir = null;
    _activeConfig = null;
  }

  bool _isGzip(List<int> data) {
    return data.length >= 2 && data[0] == 0x1f && data[1] == 0x8b;
  }

  List<int> _decodeIfGzip(List<int> data) {
    if (!_isGzip(data)) {
      return data;
    }
    try {
      return gzip.decode(data);
    } catch (_) {
      return data;
    }
  }


  Future<Directory> _materializeTiles(String mbtilesPath, Database db) async {
    final root = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}blackout_tiles_${mbtilesPath.hashCode.abs()}',
    );
    final readyMarker = File('${root.path}${Platform.pathSeparator}.ready');
    if (root.existsSync() && readyMarker.existsSync()) {
      final markerValue = readyMarker.readAsStringSync().trim();
      if (markerValue == mbtilesPath) {
        final exportedCount = root
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((f) => f.path.endsWith('.pbf'))
            .length;
        offlineTileDebugStats.value = offlineTileDebugStats.value.copyWith(
          exportedTiles: exportedCount,
          lastStatus: 'file-source-cached:${root.path}',
        );
        return root;
      }
    }

    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
    root.createSync(recursive: true);

    final declaredScheme = (_metadata['scheme'] ?? '').toLowerCase();
    final rows = db.select(
      'SELECT zoom_level, tile_column, tile_row, tile_data FROM tiles ORDER BY zoom_level, tile_column, tile_row',
    );

    int written = 0;
    for (final row in rows) {
      final int z = (row['zoom_level'] as num).toInt();
      final int x = (row['tile_column'] as num).toInt();
      final int tileRow = (row['tile_row'] as num).toInt();
      final dynamic raw = row['tile_data'];
      if (raw is! List<int>) {
        continue;
      }

      final int maxIndex = (1 << z) - 1;
      final int yXyz = declaredScheme == 'xyz' ? tileRow : (maxIndex - tileRow);
      if (yXyz < 0 || yXyz > maxIndex) {
        continue;
      }

      final dir = Directory(
        '${root.path}${Platform.pathSeparator}$z${Platform.pathSeparator}$x',
      );
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final outFile = File('${dir.path}${Platform.pathSeparator}$yXyz.pbf');
      outFile.writeAsBytesSync(_decodeIfGzip(raw), flush: false);
      written += 1;
    }

    readyMarker.writeAsStringSync(mbtilesPath, flush: true);
    offlineTileDebugStats.value = offlineTileDebugStats.value.copyWith(
      requests: written,
      hits: written,
      misses: 0,
      exportedTiles: written,
      lastStatus: 'file-source-ready:$written',
    );
    return root;
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
    final tilesDir = _activeTilesDir;
    if (tilesDir == null || tilesDir.isEmpty) {
      return json.encode({'version': 8, 'name': 'Blackout Offline', 'sources': {}, 'layers': const []});
    }
    final baseUri = Uri.directory(tilesDir);
    final tileUrls = <String>['${baseUri.toString()}{z}/{x}/{y}.pbf'];

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
        'paint': {'background-color': '#0B1118'},
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
            'fill-color': '#17222E',
            'fill-outline-color': '#2D4258',
            'fill-opacity': 0.95,
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
          'paint': {'line-color': '#F7B21A', 'line-width': 1.2, 'line-opacity': 0.9},
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
            'line-color': '#FF6A3D',
            'line-width': 1.6,
            'line-opacity': 0.95,
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
            'line-color': '#6FE3FF',
            'line-width': [
              'interpolate',
              ['linear'],
              ['zoom'],
              4,
              0.9,
              9,
              1.8,
              13,
              2.9,
            ],
            'line-opacity': 0.98,
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
        'landcover': '#203526', 'landuse': '#243528', 'park': '#1F4A33',
        'water': '#113A5E', 'aeroway': '#2F3136', 'building': '#3A2E2A',
      };
      const omtLines = {
        'waterway': '#49A6FF', 'boundary': '#F7B21A', 'transportation': '#8CE1FF',
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
          // Always expose XYZ to renderer and translate internally for TMS packs.
          'scheme': 'xyz',
          'minzoom': minZoom.toInt(),
          'maxzoom': maxZoom.toInt(),
          'tiles': tileUrls,
        }
      },
      'layers': layers,
    };

    return json.encode(style);
  }
}

OfflineVectorTilePipeline createOfflineVectorTilePipelineImpl() =>
    _OfflineVectorTilePipelineIo();
