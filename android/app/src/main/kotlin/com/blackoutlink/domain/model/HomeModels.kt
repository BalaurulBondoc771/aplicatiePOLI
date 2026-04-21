package com.blackoutlink.domain.model

enum class SystemState {
    OPERATIONAL,
    DEGRADED,
    DISCONNECTED
}

enum class PeerStatus {
    CONNECTED,
    SCANNING,
    LOST
}

data class PeerDevice(
    val id: String,
    val name: String,
    val status: PeerStatus,
    val signalLabel: String? = null
)

data class MeshNodeStats(
    val detected: Int,
    val active: Int,
    val trusted: Int,
    val relayCapable: Int
)

data class HomeUiState(
    val systemState: SystemState = SystemState.OPERATIONAL,
    val bluetoothEnabled: Boolean = true,
    val batteryPercent: Int = 84,
    val estimatedRuntimeHours: Int = 9,
    val batterySaverEnabled: Boolean = false,
    val meshStats: MeshNodeStats = MeshNodeStats(
        detected = 14,
        active = 9,
        trusted = 6,
        relayCapable = 4
    ),
    val sosEnabled: Boolean = false,
    val peers: List<PeerDevice> = emptyList()
)
