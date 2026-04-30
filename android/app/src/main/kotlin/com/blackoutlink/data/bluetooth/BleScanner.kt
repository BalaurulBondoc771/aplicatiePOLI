package com.blackoutlink.data.bluetooth

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import androidx.core.content.ContextCompat
import com.blackoutlink.domain.model.PeerDevice
import com.blackoutlink.domain.model.PeerStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.pow

class BleScanner(
    private val context: Context
) : MeshScanner {
    data class ScanCommandResult(
        val ok: Boolean,
        val reason: String? = null
    )

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
    private val scanner: BluetoothLeScanner?
        get() = bluetoothAdapter?.bluetoothLeScanner

    private val _peers = MutableStateFlow<List<PeerDevice>>(emptyList())
    override val peers: StateFlow<List<PeerDevice>> = _peers.asStateFlow()

    private val _scanInProgress = MutableStateFlow(false)
    override val scanInProgress: StateFlow<Boolean> = _scanInProgress.asStateFlow()

    private var cleanupJob: Job? = null
    private val peerMap = linkedMapOf<String, PeerDevice>()
    private var lowPowerModeEnabled: Boolean = false
    private var cleanupIntervalMs: Long = 1_000L
    private var localDisplayName: String? = null

    companion object {
        private const val CONNECTED_WINDOW_MS = 4_000L
        private const val LOST_WINDOW_MS = 12_000L
        private const val REMOVE_WINDOW_MS = 25_000L

        fun requiredPermissions(): Array<String> {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                arrayOf(
                    Manifest.permission.BLUETOOTH_SCAN,
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_ADVERTISE
                )
            } else {
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION
                )
            }
        }
    }

    override fun isBluetoothEnabled(): Boolean = bluetoothAdapter?.isEnabled == true

    override fun hasPermissions(): Boolean {
        val requiredForScan = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        // Do not block scanning if ADVERTISE is denied; scanning still works and can discover peers.
        return requiredForScan.all { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }
    }

    override fun getCurrentPeers(): List<PeerDevice> = _peers.value

    override fun configurePowerProfile(lowPowerEnabled: Boolean, refreshIntervalMs: Long) {
        lowPowerModeEnabled = lowPowerEnabled
        cleanupIntervalMs = refreshIntervalMs.coerceIn(1_000L, 120_000L)
    }

    override fun setLocalDisplayName(displayName: String?) {
        localDisplayName = displayName?.trim()?.takeIf { it.isNotEmpty() }
        val adapter = bluetoothAdapter ?: return
        if (!adapter.isEnabled) return
        try {
            adapter.name = localDisplayName ?: adapter.name
        } catch (_: SecurityException) {
        } catch (_: Throwable) {
        }
    }

    @SuppressLint("MissingPermission")
    override fun startScan(): ScanCommandResult {
        if (!hasPermissions()) return ScanCommandResult(ok = false, reason = "permissions_denied")
        if (!isBluetoothEnabled()) return ScanCommandResult(ok = false, reason = "bluetooth_off")
        if (_scanInProgress.value) return ScanCommandResult(ok = false, reason = "scan_already_active")

        val settings = ScanSettings.Builder()
            .setScanMode(
                if (lowPowerModeEnabled) {
                    ScanSettings.SCAN_MODE_LOW_POWER
                } else {
                    ScanSettings.SCAN_MODE_LOW_LATENCY
                }
            )
            .build()

        val filters = listOf(
            ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(BleTransport.MESH_SERVICE_UUID))
                .build()
        )

        peerMap.clear()
        _scanInProgress.value = true
        scanner?.startScan(filters, settings, scanCallback)

        cleanupJob?.cancel()
        cleanupJob = scope.launch {
            while (isActive) {
                val now = System.currentTimeMillis()
                peerMap.entries.removeAll { (_, peer) -> now - peer.lastSeenAt > REMOVE_WINDOW_MS }
                _peers.value = peerMap.values
                    .map { peer ->
                        val age = now - peer.lastSeenAt
                        val status = when {
                            age <= CONNECTED_WINDOW_MS -> PeerStatus.CONNECTED
                            age <= LOST_WINDOW_MS -> PeerStatus.SCANNING
                            else -> PeerStatus.LOST
                        }
                        peer.copy(status = status)
                    }
                    .sortedByDescending { it.lastSeenAt }
                delay(cleanupIntervalMs)
            }
        }

        return ScanCommandResult(ok = true)
    }

    @SuppressLint("MissingPermission")
    override fun stopScan(): ScanCommandResult {
        if (!_scanInProgress.value) return ScanCommandResult(ok = false, reason = "scan_not_active")
        scanner?.stopScan(scanCallback)
        _scanInProgress.value = false
        cleanupJob?.cancel()

        val now = System.currentTimeMillis()
        _peers.value = _peers.value.map { peer ->
            val age = now - peer.lastSeenAt
            if (age > CONNECTED_WINDOW_MS) peer.copy(status = PeerStatus.LOST) else peer
        }

        return ScanCommandResult(ok = true)
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device ?: return
            val key = device.address ?: return
            val now = System.currentTimeMillis()
            val normalizedAddress = key.uppercase()
            val existing = peerMap[normalizedAddress]
            val metadataRaw = result.scanRecord
                ?.getServiceData(ParcelUuid(BleTransport.MESH_SERVICE_UUID))
                ?.toString(Charsets.UTF_8)
                ?.trim()
            val metadataParts = metadataRaw?.split('|') ?: emptyList()
            val presetCode = metadataParts.getOrNull(0)
            val batterySaverRaw = metadataParts.getOrNull(1)
            val roleCode = metadataParts.getOrNull(2)
            val advertisedName = sanitizePeerName(device.name)
            val existingName = sanitizePeerName(existing?.name)
            val resolvedName = advertisedName
                ?: existingName
                ?: normalizedAddress
            val peer = PeerDevice(
                id = normalizedAddress,
                name = resolvedName,
                address = normalizedAddress,
                rssi = result.rssi,
                estimatedDistanceMeters = rssiToDistance(result.rssi),
                status = PeerStatus.CONNECTED,
                lastSeenAt = now,
                statusPreset = mapStatusPresetCode(presetCode) ?: existing?.statusPreset,
                batterySaverEnabled = mapBatterySaverFlag(batterySaverRaw) ?: existing?.batterySaverEnabled,
                meshRole = mapMeshRoleCode(roleCode) ?: existing?.meshRole,
                trusted = existing?.trusted ?: false,
                relayCapable = existing?.relayCapable ?: true
            )
            peerMap[normalizedAddress] = peer
            _peers.value = peerMap.values.sortedByDescending { it.lastSeenAt }
        }

        override fun onScanFailed(errorCode: Int) {
            _scanInProgress.value = false
        }
    }

    private fun rssiToDistance(rssi: Int, txPower: Int = -59): Double {
        return 10.0.pow((txPower - rssi) / 20.0)
    }

    private fun mapStatusPresetCode(code: String?): String? {
        return when (code?.uppercase()) {
            "SI" -> "SILENT / INCOGNITO"
            "FR" -> "FIELD READY"
            "OB" -> "OPEN BROADCAST"
            "EW" -> "EMERGENCY WATCH"
            else -> null
        }
    }

    private fun mapBatterySaverFlag(raw: String?): Boolean? {
        return when (raw?.trim()) {
            "1" -> true
            "0" -> false
            else -> null
        }
    }

    private fun mapMeshRoleCode(code: String?): String? {
        return when (code?.uppercase()) {
            "S" -> "STEALTH"
            "W" -> "WATCH"
            "R" -> "RELAY"
            else -> null
        }
    }

    private fun sanitizePeerName(raw: String?): String? {
        val candidate = raw?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val upper = candidate.uppercase()
        if (upper == "OPERATOR_X" || upper == "UNKNOWN_NODE") {
            return null
        }
        // Ignore accidental self-name echoes from adapter-level naming.
        if (localDisplayName?.trim()?.equals(candidate, ignoreCase = true) == true) {
            return null
        }
        return candidate
    }
}
