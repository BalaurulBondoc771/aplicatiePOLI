import 'offline_vector_tile_pipeline.dart';

class _UnsupportedOfflineVectorTilePipeline implements OfflineVectorTilePipeline {
  @override
  Future<OfflineVectorMapConfig?> ensureStarted({required String mbtilesPath}) async {
    return null;
  }

  @override
  Future<void> dispose() async {}
}

OfflineVectorTilePipeline createOfflineVectorTilePipelineImpl() =>
    _UnsupportedOfflineVectorTilePipeline();
