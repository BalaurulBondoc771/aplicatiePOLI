import 'offline_vector_tile_pipeline_stub.dart'
    if (dart.library.io) 'offline_vector_tile_pipeline_io.dart';

class OfflineVectorMapConfig {
  const OfflineVectorMapConfig({
    required this.styleUrl,
    required this.centerLat,
    required this.centerLon,
    required this.minZoom,
    required this.maxZoom,
  });

  final String styleUrl;
  final double centerLat;
  final double centerLon;
  final double minZoom;
  final double maxZoom;
}

abstract class OfflineVectorTilePipeline {
  Future<OfflineVectorMapConfig?> ensureStarted({required String mbtilesPath});
  Future<void> dispose();
}

OfflineVectorTilePipeline createOfflineVectorTilePipeline() =>
    createOfflineVectorTilePipelineImpl();
