import 'package:flutter/foundation.dart';

class OfflineTileDebugStats {
  const OfflineTileDebugStats({
    required this.requests,
    required this.hits,
    required this.misses,
    required this.exportedTiles,
    required this.lastStatus,
  });

  final int requests;
  final int hits;
  final int misses;
  final int exportedTiles;
  final String lastStatus;

  OfflineTileDebugStats copyWith({
    int? requests,
    int? hits,
    int? misses,
    int? exportedTiles,
    String? lastStatus,
  }) {
    return OfflineTileDebugStats(
      requests: requests ?? this.requests,
      hits: hits ?? this.hits,
      misses: misses ?? this.misses,
      exportedTiles: exportedTiles ?? this.exportedTiles,
      lastStatus: lastStatus ?? this.lastStatus,
    );
  }
}

final ValueNotifier<OfflineTileDebugStats> offlineTileDebugStats =
    ValueNotifier<OfflineTileDebugStats>(
  const OfflineTileDebugStats(
    requests: 0,
    hits: 0,
    misses: 0,
    exportedTiles: 0,
    lastStatus: 'idle',
  ),
);
