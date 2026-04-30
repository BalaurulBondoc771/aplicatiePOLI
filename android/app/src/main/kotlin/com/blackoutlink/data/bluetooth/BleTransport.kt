package com.blackoutlink.data.bluetooth

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.os.Build
import android.os.ParcelUuid
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import java.util.UUID

import android.util.Log
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Handles BLE advertising (so other devices can discover us), a GATT server
 * (to receive incoming mesh messages), and GATT client connections (to send
 * messages to discovered peers).
 *
 * Wire format: raw UTF-8 JSON produced by MeshProtocol.encode().
 * MTU negotiation is performed before each send to support payloads up to 512 bytes.
 */
@SuppressLint("MissingPermission")
class BleTransport(private val context: Context) {
    // Per-peer mutex for BLE send serialization
    private val peerMutexes = ConcurrentHashMap<String, Mutex>()
    private fun log(msg: String) {
        Log.d("BleTransport", msg)
    }

    data class IncomingPacket(
        val sourceAddress: String,
        val payload: ByteArray
    )

    companion object {
        /** Blackout mesh BLE service UUID — advertised so peers can find us. */
        val MESH_SERVICE_UUID: UUID = UUID.fromString("0000aa01-0000-1000-8000-00805f9b34fb")

        /** Writable characteristic used to deliver encoded mesh messages. */
        val MESSAGE_CHAR_UUID: UUID = UUID.fromString("0000aa02-0000-1000-8000-00805f9b34fb")

        const val MESH_ADVERTISEMENT_SIGNATURE = "BLC1"

        private const val SEND_TIMEOUT_MS = 12_000L
        private const val TARGET_MTU = 512
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter get() = bluetoothManager.adapter

    private var gattServer: BluetoothGattServer? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var localDisplayName: String? = null
    private var localStatusPresetCode: String = "SI"
    private var localBatterySaverEnabled: Boolean = false
    private var localMeshRoleCode: String = "R"
    private var advertiseMode: Int = AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY
    private var txPowerLevel: Int = AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM

    // Incoming packets received by the GATT server, including source BLE address.
    private val _incomingBytes = MutableSharedFlow<IncomingPacket>(extraBufferCapacity = 64)
    val incomingBytes: SharedFlow<IncomingPacket> = _incomingBytes.asSharedFlow()

    // ── GATT server ──────────────────────────────────────────────────────────

    fun startServer() {
        val adapter = bluetoothAdapter ?: return
        if (!adapter.isEnabled || gattServer != null) return

        val server = try {
            bluetoothManager.openGattServer(context, gattServerCallback)
        } catch (_: SecurityException) {
            null
        }
        gattServer = server
        if (server == null) return

        val service = BluetoothGattService(
            MESH_SERVICE_UUID,
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )
        val msgChar = BluetoothGattCharacteristic(
            MESSAGE_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or
                    BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        service.addCharacteristic(msgChar)
        try {
            gattServer?.addService(service)
        } catch (_: SecurityException) {
            stopServer()
        }
    }

    fun stopServer() {
        gattServer?.close()
        gattServer = null
    }

    // ── BLE advertising ───────────────────────────────────────────────────────

    fun configureIdentity(displayName: String?) {
        localDisplayName = displayName?.trim()?.takeIf { it.isNotEmpty() }
        val adapter = bluetoothAdapter ?: return
        if (!adapter.isEnabled || localDisplayName == null) return
        try {
            adapter.name = localDisplayName
        } catch (_: SecurityException) {
        } catch (_: Throwable) {
        }
    }

    fun configureAdvertiseProfile(mode: Int, txPower: Int) {
        advertiseMode = mode
        txPowerLevel = txPower
    }

    fun configureStatusPresetMetadata(code: String) {
        localStatusPresetCode = code.ifBlank { "SI" }
    }

    fun configurePeerMetadata(statusPresetCode: String, batterySaverEnabled: Boolean, meshRoleCode: String) {
        localStatusPresetCode = statusPresetCode.ifBlank { "SI" }
        localBatterySaverEnabled = batterySaverEnabled
        localMeshRoleCode = meshRoleCode.ifBlank { "R" }
    }

    fun startAdvertising() {
        val adapter = bluetoothAdapter ?: return
        if (!adapter.isEnabled || advertiseCallback != null) return

        configureIdentity(localDisplayName)

        val advertiser = adapter.bluetoothLeAdvertiser ?: return

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(advertiseMode)
            .setTxPowerLevel(txPowerLevel)
            .setConnectable(true)
            .setTimeout(0)
            .build()

        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(MESH_SERVICE_UUID))
            .addServiceData(
                ParcelUuid(MESH_SERVICE_UUID),
                "$MESH_ADVERTISEMENT_SIGNATURE|$localStatusPresetCode|${if (localBatterySaverEnabled) 1 else 0}|$localMeshRoleCode"
                    .toByteArray(Charsets.UTF_8)
            )
            .setIncludeDeviceName(false)
            .build()

        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .build()

        val cb = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {}
            override fun onStartFailure(errorCode: Int) {
                advertiseCallback = null
            }
        }
        advertiseCallback = cb
        try {
            advertiser.startAdvertising(settings, data, scanResponse, cb)
        } catch (_: SecurityException) {
            advertiseCallback = null
        }
    }

    fun stopAdvertising() {
        val cb = advertiseCallback ?: return
        advertiseCallback = null
        try {
            bluetoothAdapter?.bluetoothLeAdvertiser?.stopAdvertising(cb)
        } catch (_: Exception) {
        }
    }

    // ── GATT client (send) ────────────────────────────────────────────────────

    /**
     * Connects to [address] (MAC), negotiates MTU, discovers services, then
     * writes [payload] to the Blackout message characteristic.
     *
     * @return true if the write was acknowledged by the remote device.
     */

    suspend fun sendTo(address: String, payload: ByteArray): Boolean = withContext(Dispatchers.IO) {
        val adapter = bluetoothAdapter ?: return@withContext false
        if (!adapter.isEnabled || payload.isEmpty()) return@withContext false

        val mutex = peerMutexes.getOrPut(address) { Mutex() }
        mutex.withLock {
            log("sendTo called for $address, bytes=${payload.size}")
            val resultDeferred = CompletableDeferred<Boolean>()
            var gatt: BluetoothGatt? = null
            val gattCallback = object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                    log("[BLE] onConnectionStateChange $address status=$status newState=$newState")
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        if (status != BluetoothGatt.GATT_SUCCESS) {
                            log("[BLE] connect fail $address")
                            gatt.disconnect()
                            if (!resultDeferred.isCompleted) resultDeferred.complete(false)
                            return
                        }
                        log("[BLE] connected, requesting MTU $address")
                        val mtuRequested = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            gatt.requestMtu(TARGET_MTU)
                        } else false
                        if (!mtuRequested) gatt.discoverServices()
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        log("[BLE] disconnected $address")
                        gatt.close()
                        if (!resultDeferred.isCompleted) resultDeferred.complete(false)
                    }
                }
                override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                    log("[BLE] onMtuChanged $address mtu=$mtu status=$status")
                    gatt.discoverServices()
                }
                override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                    log("[BLE] onServicesDiscovered $address status=$status")
                    if (status != BluetoothGatt.GATT_SUCCESS) {
                        log("[BLE] service discovery fail $address")
                        gatt.disconnect()
                        if (!resultDeferred.isCompleted) resultDeferred.complete(false)
                        return
                    }
                    val char = gatt.getService(MESH_SERVICE_UUID)?.getCharacteristic(MESSAGE_CHAR_UUID)
                    if (char == null) {
                        log("[BLE] characteristic not found $address")
                        gatt.disconnect()
                        if (!resultDeferred.isCompleted) resultDeferred.complete(false)
                        return
                    }
                    log("[BLE] writeCharacteristic called $address")
                    val wrote = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val code = gatt.writeCharacteristic(
                            char,
                            payload,
                            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                        )
                        code == BluetoothStatusCodes.SUCCESS
                    } else {
                        @Suppress("DEPRECATION")
                        char.value = payload
                        @Suppress("DEPRECATION")
                        char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                        @Suppress("DEPRECATION")
                        gatt.writeCharacteristic(char)
                    }
                    if (!wrote) {
                        log("[BLE] writeCharacteristic failed $address")
                        gatt.disconnect()
                        if (!resultDeferred.isCompleted) resultDeferred.complete(false)
                    }
                }
                override fun onCharacteristicWrite(
                    gatt: BluetoothGatt,
                    characteristic: BluetoothGattCharacteristic,
                    status: Int
                ) {
                    log("[BLE] onCharacteristicWrite $address status=$status")
                    gatt.disconnect()
                    if (!resultDeferred.isCompleted) resultDeferred.complete(status == BluetoothGatt.GATT_SUCCESS)
                }
            }
            val device = try {
                log("[BLE] getRemoteDevice $address")
                adapter.getRemoteDevice(address)
            } catch (_: Exception) {
                log("[BLE] getRemoteDevice failed for $address")
                return@withLock false
            }
            gatt = try {
                log("[BLE] connecting GATT $address")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
                } else {
                    @Suppress("DEPRECATION")
                    device.connectGatt(context, false, gattCallback)
                }
            } catch (_: Throwable) {
                log("[BLE] connectGatt exception $address")
                null
            }
            if (gatt == null) return@withLock false
            val result = withTimeoutOrNull(8000) { resultDeferred.await() } ?: false
            if (!resultDeferred.isCompleted) {
                log("[BLE] write timeout or disconnect $address")
                try { gatt.disconnect() } catch (_: Throwable) {}
                try { gatt.close() } catch (_: Throwable) {}
            }
            return@withLock result
        }
    }

    // ── GATT server callbacks ─────────────────────────────────────────────────

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {}

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            try {
                if (characteristic.uuid == MESSAGE_CHAR_UUID && value != null && value.isNotEmpty()) {
                    val source = device.address?.trim()?.uppercase()
                    val payloadStr = try { value.toString(Charsets.UTF_8) } catch (_: Throwable) { "<binary>" }
                    log("[BLE] onCharacteristicWriteRequest from $source, bytes=${value.size}, payload=$payloadStr")
                    if (payloadStr == "PING_FROM_BLACKOUT_LINK") {
                        log("[BLE] DIAGNOSTIC PING RECEIVED from $source")
                    }
                    if (!source.isNullOrEmpty()) {
                        _incomingBytes.tryEmit(IncomingPacket(sourceAddress = source, payload = value))
                    }
                }
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                }
            } catch (_: Throwable) {
                if (responseNeeded) {
                    try {
                        gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
                    } catch (_: Throwable) {
                    }
                }
            }
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    fun destroy() {
        stopAdvertising()
        stopServer()
        scope.cancel()
    }
}
