import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'offline_map_service.dart';

class _IoOfflineMapService implements OfflineMapService {
  static const String _fileName = 'romania.mbtiles';
  static const String _folderName = 'maps';
  static const String _fallbackUrl = 'https://example.com/maps/romania.mbtiles';
  static const String _configuredUrl = String.fromEnvironment(
    'ROMANIA_MAP_URL',
    defaultValue: _fallbackUrl,
  );

  @override
  String get romaniaMapUrl => _configuredUrl;

  Future<File> _packFile() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory mapsDir = Directory('${docs.path}${Platform.pathSeparator}$_folderName');
    if (!mapsDir.existsSync()) {
      mapsDir.createSync(recursive: true);
    }
    return File('${mapsDir.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<MapPackInspection> inspectRomaniaPack() async {
    final File file = await _packFile();
    if (!file.existsSync()) {
      return const MapPackInspection(exists: false, corrupted: false);
    }
    final int size = await file.length();
    final bool corrupted = size <= 1024;
    return MapPackInspection(
      exists: !corrupted,
      corrupted: corrupted,
      localPath: file.path,
      fileSizeBytes: size,
    );
  }

  @override
  Future<MapPackInspection> downloadRomaniaPack({required void Function(double progress) onProgress}) async {
    if (_configuredUrl.contains('example.com')) {
      return _copyBundledPack(onProgress: onProgress);
    }

    final File file = await _packFile();
    final File temp = File('${file.path}.part');
    if (temp.existsSync()) {
      temp.deleteSync();
    }

    final HttpClient client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    final HttpClientRequest request = await client.getUrl(Uri.parse(_configuredUrl));
    final HttpClientResponse response = await request.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Failed to download map pack (HTTP ${response.statusCode})');
    }

    final IOSink sink = temp.openWrite();
    final int total = response.contentLength;
    int received = 0;

    await for (final List<int> chunk in response) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        onProgress((received / total).clamp(0, 1));
      }
    }

    await sink.flush();
    await sink.close();

    final int size = await temp.length();
    if (size <= 1024) {
      temp.deleteSync();
      throw const FileSystemException('Downloaded map pack is empty or corrupted.');
    }

    if (file.existsSync()) {
      file.deleteSync();
    }
    temp.renameSync(file.path);

    return MapPackInspection(
      exists: true,
      corrupted: false,
      localPath: file.path,
      fileSizeBytes: size,
    );
  }

  Future<MapPackInspection> _copyBundledPack({required void Function(double progress) onProgress}) async {
    final File file = await _packFile();
    final File temp = File('${file.path}.part');
    if (temp.existsSync()) {
      temp.deleteSync();
    }

    try {
      onProgress(0);
      final ByteData data = await rootBundle.load('map-host/romania.mbtiles');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await temp.writeAsBytes(bytes, flush: true);
      onProgress(1);
    } catch (_) {
      throw const FileSystemException(
        'Map pack is not bundled in app assets. Add map-host/romania.mbtiles in pubspec assets or set ROMANIA_MAP_URL.',
      );
    }

    final int size = await temp.length();
    if (size <= 1024) {
      temp.deleteSync();
      throw const FileSystemException('Bundled map pack is empty or corrupted.');
    }

    if (file.existsSync()) {
      file.deleteSync();
    }
    temp.renameSync(file.path);

    return MapPackInspection(
      exists: true,
      corrupted: false,
      localPath: file.path,
      fileSizeBytes: size,
    );
  }

  @override
  Future<void> deleteRomaniaPack() async {
    final File file = await _packFile();
    if (file.existsSync()) {
      await file.delete();
    }
  }
}

OfflineMapService createOfflineMapServiceImpl() => _IoOfflineMapService();
