import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'offline_vector_tile_pipeline.dart';

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

    _activeConfig = OfflineVectorMapConfig(
      styleUrl: 'http://127.0.0.1:${server.port}/style.json',
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
      final tmsY = ((1 << z) - 1) - yXyz;

      final db = _db;
      if (db == null) {
        response.statusCode = HttpStatus.serviceUnavailable;
        response.close();
        return;
      }

      final stmt = db.prepare(
        'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ? LIMIT 1',
      );
      final result = stmt.select([z, x, tmsY]);
      stmt.dispose();

      if (result.isEmpty) {
        response.statusCode = HttpStatus.notFound;
        response.close();
        return;
      }

      final tileData = result.first.columnAt(0);
      if (tileData is! List<int>) {
        response.statusCode = HttpStatus.notFound;
        response.close();
        return;
      }

      response.headers.set(HttpHeaders.contentTypeHeader, 'application/x-protobuf');
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
    final layers = <Map<String, dynamic>>[
      {
        'id': 'background',
        'type': 'background',
        'paint': {'background-color': '#0b111a'}
      }
    ];

    for (final sourceLayer in _vectorLayers) {
      final lower = sourceLayer.toLowerCase();
      if (lower.contains('point')) {
        layers.add({
          'id': 'pt_$sourceLayer',
          'type': 'circle',
          'source': 'offline',
          'source-layer': sourceLayer,
          'paint': {
            'circle-radius': 2.2,
            'circle-color': '#f7b21a',
            'circle-opacity': 0.85,
          }
        });
      } else if (lower.contains('line')) {
        layers.add({
          'id': 'ln_$sourceLayer',
          'type': 'line',
          'source': 'offline',
          'source-layer': sourceLayer,
          'paint': {
            'line-color': '#8ea0b6',
            'line-width': 1.1,
            'line-opacity': 0.85,
          }
        });
      } else {
        layers.add({
          'id': 'fill_$sourceLayer',
          'type': 'fill',
          'source': 'offline',
          'source-layer': sourceLayer,
          'paint': {
            'fill-color': '#1a2633',
            'fill-outline-color': '#2e4157',
            'fill-opacity': 0.7,
          }
        });
      }
    }

    final style = {
      'version': 8,
      'name': 'Blackout Offline Vector',
      'sources': {
        'offline': {
          'type': 'vector',
          'scheme': 'xyz',
          'minzoom': minZoom,
          'maxzoom': maxZoom,
          'tiles': ['http://127.0.0.1:${_server?.port ?? 0}/tiles/{z}/{x}/{y}.pbf'],
        }
      },
      'layers': layers,
    };

    return json.encode(style);
  }
}

OfflineVectorTilePipeline createOfflineVectorTilePipelineImpl() =>
    _OfflineVectorTilePipelineIo();
