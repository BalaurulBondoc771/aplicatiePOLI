enum QuickStatusType {
  iAmSafe,
  onMyWay,
  needWater,
  lowBattery,
  needHelp,
}

extension QuickStatusTypeWire on QuickStatusType {
  String get wireValue {
    switch (this) {
      case QuickStatusType.iAmSafe:
        return 'I_AM_SAFE';
      case QuickStatusType.onMyWay:
        return 'ON_MY_WAY';
      case QuickStatusType.needWater:
        return 'NEED_WATER';
      case QuickStatusType.lowBattery:
        return 'LOW_BATTERY';
      case QuickStatusType.needHelp:
        return 'NEED_HELP';
    }
  }
}

class BroadcastResultDto {
  const BroadcastResultDto({
    required this.ok,
    required this.sentCount,
    required this.deliveredCount,
    required this.failedCount,
    this.error,
  });

  final bool ok;
  final int sentCount;
  final int deliveredCount;
  final int failedCount;
  final String? error;

  factory BroadcastResultDto.fromMap(Map<String, dynamic> map) {
    return BroadcastResultDto(
      ok: map['ok'] == true,
      sentCount: (map['sentCount'] as num?)?.toInt() ?? 0,
      deliveredCount: (map['deliveredCount'] as num?)?.toInt() ?? 0,
      failedCount: (map['failedCount'] as num?)?.toInt() ?? 0,
      error: map['error'] != null ? '${map['error']}' : null,
    );
  }

  String toBannerText() {
    if (!ok && error != null) {
      return 'Broadcast failed: $error';
    }
    return 'Broadcast summary: sent $sentCount, delivered $deliveredCount, failed $failedCount';
  }
}
