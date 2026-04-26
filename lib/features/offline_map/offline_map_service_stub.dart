import 'offline_map_service.dart';

class _UnsupportedOfflineMapService implements OfflineMapService {
  static const String _url = 'https://example.com/maps/romania.mbtiles';

  @override
  String get romaniaMapUrl => _url;

  @override
  Future<MapPackInspection> downloadRomaniaPack({required void Function(double progress) onProgress}) async {
    throw UnsupportedError('Offline map pack download is not available on this platform.');
  }

  @override
  Future<void> deleteRomaniaPack() async {}

  @override
  Future<MapPackInspection> inspectRomaniaPack() async {
    return const MapPackInspection(exists: false, corrupted: false);
  }

  @override
  Future<bool> isSupported() async => false;
}

OfflineMapService createOfflineMapServiceImpl() => _UnsupportedOfflineMapService();
