package com.blackoutlink

import com.blackoutlink.domain.model.PeerDevice
import com.blackoutlink.domain.model.PeerStatus
import com.blackoutlink.domain.model.SystemState
import com.blackoutlink.domain.usecase.SystemHealthAggregator
import com.blackoutlink.domain.usecase.SystemHealthInput
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemHealthAggregatorTests {

    @Test
    fun aggregate_returnsOperational_whenAllSignalsHealthy() {
        val now = System.currentTimeMillis()
        val peer = PeerDevice(
            id = "peer-1",
            name = "Node 1",
            address = "AA:BB",
            rssi = -42,
            estimatedDistanceMeters = 120.0,
            status = PeerStatus.CONNECTED,
            lastSeenAt = now - 1000,
            trusted = true,
            relayCapable = true
        )
        val input = SystemHealthInput(
            bluetoothEnabled = true,
            permissionsMissing = false,
            batteryPercent = 74,
            peers = listOf(peer),
            scanInProgress = true,
            locationAvailable = true,
            staleScanResults = false,
            lastError = null
        )

        val snapshot = SystemHealthAggregator().aggregate(input)

        assertEquals(SystemState.OPERATIONAL, snapshot.state)
        assertEquals(1, snapshot.nodesActive)
        assertTrue(snapshot.meshRadiusKm > 0.0)
    }

    @Test
    fun aggregate_returnsDegraded_whenPermissionsMissing() {
        val input = SystemHealthInput(
            bluetoothEnabled = true,
            permissionsMissing = true,
            batteryPercent = 50,
            peers = emptyList(),
            scanInProgress = true,
            locationAvailable = true,
            staleScanResults = false,
            lastError = null
        )

        val snapshot = SystemHealthAggregator().aggregate(input)

        assertEquals(SystemState.DEGRADED, snapshot.state)
    }
}
