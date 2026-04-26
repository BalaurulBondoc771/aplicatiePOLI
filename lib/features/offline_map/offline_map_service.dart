import 'offline_map_service_stub.dart'
    if (dart.library.io) 'offline_map_service_io.dart';

class MapPackInspection {
  const MapPackInspection({
    required this.exists,
    required this.corrupted,
    this.localPath,
    this.fileSizeBytes,
  });

  final bool exists;
  final bool corrupted;
  final String? localPath;
  final int? fileSizeBytes;
}

abstract class OfflineMapService {
  String get romaniaMapUrl;

  Future<bool> isSupported();
  Future<MapPackInspection> inspectRomaniaPack();
  Future<MapPackInspection> downloadRomaniaPack({required void Function(double progress) onProgress});
  Future<void> deleteRomaniaPack();
}

OfflineMapService createOfflineMapService() => createOfflineMapServiceImpl();
