package com.blackoutlink.domain.usecase

import com.blackoutlink.domain.model.PeerDevice
import com.blackoutlink.domain.model.SystemState
import kotlin.math.max

data class SystemHealthInput(
    val bluetoothEnabled: Boolean,
    val permissionsMissing: Boolean,
    val batteryPercent: Int?,
    val peers: List<PeerDevice>,
    val scanInProgress: Boolean,
    val locationAvailable: Boolean,
    val staleScanResults: Boolean,
    val lastError: String?
)

data class SystemHealthSnapshot(
    val state: SystemState,
    val batteryAvailable: Boolean,
    val batteryPercent: Int,
    val peersAvailable: Boolean,
    val nodesActive: Int,
    val scanInProgress: Boolean,
    val meshRadiusKm: Double,
    val btRangeKm: Double,
    val locationAvailable: Boolean,
    val staleScanResults: Boolean,
    val signalState: String,
    val lastError: String?
)

class SystemHealthAggregator {
    fun aggregate(input: SystemHealthInput): SystemHealthSnapshot {
        val now = System.currentTimeMillis()
        var maxMeters = 0.0
        var nodesActive = 0
        var freshPeers = 0

        for (peer in input.peers) {
            maxMeters = max(maxMeters, peer.estimatedDistanceMeters)
            if (peer.status.name == "CONNECTED") {
                nodesActive++
            }
            val fresh = (now - peer.lastSeenAt) <= 15_000L
            if (fresh) {
                freshPeers++
            }
        }

        val peersAvailable = freshPeers > 0
        val batteryAvailable = input.batteryPercent != null
        val battery = (input.batteryPercent ?: 0).coerceIn(0, 100)
        val km = maxMeters / 1000.0

        val state = when {
            !input.bluetoothEnabled -> SystemState.OFFLINE
            input.permissionsMissing -> SystemState.DEGRADED
            !batteryAvailable -> SystemState.DEGRADED
            battery <= 2 -> SystemState.OFFLINE
            !input.locationAvailable -> SystemState.DEGRADED
            input.staleScanResults -> SystemState.DEGRADED
            !peersAvailable && !input.scanInProgress -> SystemState.DEGRADED
            !input.lastError.isNullOrBlank() -> SystemState.DEGRADED
            else -> SystemState.OPERATIONAL
        }

        val signalState = if (peersAvailable && !input.staleScanResults) "optimal" else "standby"

        return SystemHealthSnapshot(
            state = state,
            batteryAvailable = batteryAvailable,
            batteryPercent = battery,
            peersAvailable = peersAvailable,
            nodesActive = nodesActive,
            scanInProgress = input.scanInProgress,
            meshRadiusKm = km,
            btRangeKm = km,
            locationAvailable = input.locationAvailable,
            staleScanResults = input.staleScanResults,
            signalState = signalState,
            lastError = input.lastError
        )
    }
}
