package com.blackoutlink

import com.blackoutlink.data.bluetooth.BleScanner
import com.blackoutlink.data.bluetooth.MeshScanner
import com.blackoutlink.data.security.EncryptedPayload
import com.blackoutlink.data.security.PayloadCrypto
import com.blackoutlink.domain.model.PeerDevice
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class FakeMeshScanner : MeshScanner {
    private val peerFlow = MutableStateFlow<List<PeerDevice>>(emptyList())
    private val scanFlow = MutableStateFlow(false)

    var lastLowPowerEnabled: Boolean? = null
    var lastRefreshIntervalMs: Long? = null

    override val peers: StateFlow<List<PeerDevice>> = peerFlow
    override val scanInProgress: StateFlow<Boolean> = scanFlow

    override fun startScan(): BleScanner.ScanCommandResult {
        scanFlow.value = true
        return BleScanner.ScanCommandResult(ok = true)
    }

    override fun stopScan(): BleScanner.ScanCommandResult {
        scanFlow.value = false
        return BleScanner.ScanCommandResult(ok = true)
    }

    override fun getCurrentPeers(): List<PeerDevice> = peerFlow.value

    override fun isBluetoothEnabled(): Boolean = true

    override fun hasPermissions(): Boolean = true

    override fun configurePowerProfile(lowPowerEnabled: Boolean, refreshIntervalMs: Long) {
        lastLowPowerEnabled = lowPowerEnabled
        lastRefreshIntervalMs = refreshIntervalMs
    }

    override fun setLocalDisplayName(displayName: String?) = Unit

    fun emitPeers(peers: List<PeerDevice>) {
        peerFlow.value = peers
    }
}

class PassThroughCrypto : PayloadCrypto {
    override fun encrypt(plainText: ByteArray): EncryptedPayload =
        EncryptedPayload(iv = byteArrayOf(1, 2, 3), cipherText = plainText)

    override fun decrypt(payload: EncryptedPayload): ByteArray = payload.cipherText
}
