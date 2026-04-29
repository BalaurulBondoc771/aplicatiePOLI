package com.blackoutlink.domain.model

import kotlinx.serialization.Serializable

enum class SystemState {
    OPERATIONAL,
    DEGRADED,
    OFFLINE
}

enum class PeerStatus {
    CONNECTED,
    SCANNING,
    LOST
}

enum class MessageType {
    TEXT,
    SOS,
    STATUS_SAFE,
    STATUS_ON_MY_WAY,
    STATUS_NEED_WATER,
    STATUS_NEED_HELP
}

enum class MessageDeliveryStatus {
    QUEUED,
    SENT,
    RELAYED,
    DELIVERED,
    FAILED
}

@Serializable
data class MeshMessage(
    val id: String,
    val senderId: String,
    val receiverId: String? = null,
    val type: MessageType,
    val content: String,
    val createdAt: Long,
    val ttlSeconds: Int = 120,
    val hopCount: Int = 0,
    val requiresAck: Boolean = true
)

data class PeerDevice(
    val id: String,
    val name: String,
    val address: String,
    val rssi: Int,
    val estimatedDistanceMeters: Double,
    val status: PeerStatus,
    val lastSeenAt: Long,
    val statusPreset: String? = null,
    val batterySaverEnabled: Boolean? = null,
    val meshRole: String? = null,
    val trusted: Boolean = false,
    val relayCapable: Boolean = true
)

data class MeshStats(
    val detected: Int = 0,
    val active: Int = 0,
    val trusted: Int = 0,
    val relayCapable: Int = 0,
    val radiusMeters: Double = 0.0
)

data class LocationSnapshot(
    val latitude: Double,
    val longitude: Double,
    val accuracyMeters: Float,
    val timestamp: Long
)

data class HomeUiState(
    val systemState: SystemState = SystemState.OFFLINE,
    val batteryPercent: Int = 0,
    val batterySaverEnabled: Boolean = false,
    val peers: List<PeerDevice> = emptyList(),
    val meshStats: MeshStats = MeshStats(),
    val currentLocation: LocationSnapshot? = null,
    val sosInProgress: Boolean = false,
    val isBluetoothEnabled: Boolean = false,
    val scanInProgress: Boolean = false,
    val errorMessage: String? = null
)
