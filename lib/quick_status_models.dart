enum QuickStatusType {
  iAmSafe,
  onMyWay,
  needWater,
  lowBattery,
  needHelp,
}

extension QuickStatusTypeLabel on QuickStatusType {
  String get label {
    switch (this) {
      case QuickStatusType.iAmSafe:
        return 'I AM SAFE';
      case QuickStatusType.onMyWay:
        return 'ON MY WAY';
      case QuickStatusType.needWater:
        return 'NEED WATER';
      case QuickStatusType.lowBattery:
        return 'LOW BATTERY';
      case QuickStatusType.needHelp:
        return 'NEED HELP';
    }
  }
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

extension QuickStatusTypeParse on QuickStatusType {
  static QuickStatusType? fromWireValue(String? raw) {
    final String wire = (raw ?? '').trim().toUpperCase();
    switch (wire) {
      case 'I_AM_SAFE':
        return QuickStatusType.iAmSafe;
      case 'ON_MY_WAY':
      case 'EN_ROUTE':
        return QuickStatusType.onMyWay;
      case 'NEED_WATER':
        return QuickStatusType.needWater;
      case 'LOW_BATTERY':
        return QuickStatusType.lowBattery;
      case 'NEED_HELP':
        return QuickStatusType.needHelp;
      default:
        return null;
    }
  }
}

class QuickStatusPayload {
  const QuickStatusPayload({
    required this.wireStatus,
    required this.deviceName,
    required this.expiresAtMs,
  });

  final String wireStatus;
  final String deviceName;
  final int expiresAtMs;

  static QuickStatusPayload? fromMessageContent(String content) {
    if (!content.startsWith('STATUS:')) {
      return null;
    }

    final String raw = content.substring('STATUS:'.length);
    final List<String> parts = raw.split('|');
    if (parts.isEmpty || parts.first.trim().isEmpty) {
      return null;
    }

    final String wire = parts.first.trim().toUpperCase();
    String device = 'UNKNOWN DEVICE';
    int expires = 0;

    for (final String part in parts.skip(1)) {
      final int idx = part.indexOf('=');
      if (idx <= 0 || idx >= part.length - 1) continue;
      final String key = part.substring(0, idx).trim().toUpperCase();
      final String value = part.substring(idx + 1).trim();
      if (key == 'DEVICE' && value.isNotEmpty) {
        device = value;
      }
      if (key == 'EXP') {
        expires = int.tryParse(value) ?? 0;
      }
    }

    return QuickStatusPayload(
      wireStatus: wire,
      deviceName: device,
      expiresAtMs: expires,
    );
  }

  String get statusLabel {
    switch (wireStatus) {
      case 'I_AM_SAFE':
        return 'I AM SAFE';
      case 'ON_MY_WAY':
      case 'EN_ROUTE':
        return 'ON MY WAY';
      case 'NEED_WATER':
        return 'NEED WATER';
      case 'LOW_BATTERY':
        return 'LOW BATTERY';
      case 'NEED_HELP':
        return 'NEED HELP';
      default:
        return wireStatus.replaceAll('_', ' ');
    }
  }

  bool get isExpired {
    if (expiresAtMs <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch >= expiresAtMs;
  }

  String get remainingLabel {
    if (isExpired || expiresAtMs <= 0) {
      return 'STANDBY';
    }
    final int remainingMs = expiresAtMs - DateTime.now().millisecondsSinceEpoch;
    final int clamped = remainingMs < 0 ? 0 : remainingMs;
    final int totalSec = (clamped / 1000).ceil();
    final int mm = totalSec ~/ 60;
    final int ss = totalSec % 60;
    final String mmTxt = mm.toString().padLeft(2, '0');
    final String ssTxt = ss.toString().padLeft(2, '0');
    return '$mmTxt:$ssTxt';
  }
}

class BroadcastResultDto {
  const BroadcastResultDto({
    required this.ok,
    required this.sentCount,
    required this.deliveredCount,
    required this.failedCount,
    required this.queuedForDelivery,
    this.error,
  });

  final bool ok;
  final int sentCount;
  final int deliveredCount;
  final int failedCount;
  final bool queuedForDelivery;
  final String? error;

  factory BroadcastResultDto.fromMap(Map<String, dynamic> map) {
    return BroadcastResultDto(
      ok: map['ok'] == true,
      sentCount: (map['sentCount'] as num?)?.toInt() ?? 0,
      deliveredCount: (map['deliveredCount'] as num?)?.toInt() ?? 0,
      failedCount: (map['failedCount'] as num?)?.toInt() ?? 0,
      queuedForDelivery: map['queuedForDelivery'] == true,
      error: map['error'] != null ? '${map['error']}' : null,
    );
  }

  String toBannerText() {
    if (queuedForDelivery) {
      return 'No active peers now. Status was saved and will be delivered when a peer is discovered.';
    }
    if (!ok && error != null) {
      return 'Broadcast failed: $error';
    }
    return 'Broadcast summary: sent $sentCount, delivered $deliveredCount, failed $failedCount';
  }
}
