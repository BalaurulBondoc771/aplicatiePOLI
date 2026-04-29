package com.blackoutlink.data.bluetooth

import com.blackoutlink.domain.model.PeerDevice
import kotlinx.coroutines.flow.StateFlow

interface MeshScanner {
    val peers: StateFlow<List<PeerDevice>>
    val scanInProgress: StateFlow<Boolean>

    fun startScan(): BleScanner.ScanCommandResult
    fun stopScan(): BleScanner.ScanCommandResult
    fun getCurrentPeers(): List<PeerDevice>
    fun isBluetoothEnabled(): Boolean
    fun hasPermissions(): Boolean
    fun configurePowerProfile(lowPowerEnabled: Boolean, refreshIntervalMs: Long)
    fun setLocalDisplayName(displayName: String?)
}
