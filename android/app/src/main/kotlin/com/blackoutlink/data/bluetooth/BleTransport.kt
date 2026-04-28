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
import java.util.UUID

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

    companion object {
        /** Blackout mesh BLE service UUID — advertised so peers can find us. */
        val MESH_SERVICE_UUID: UUID = UUID.fromString("0000aa01-0000-1000-8000-00805f9b34fb")

        /** Writable characteristic used to deliver encoded mesh messages. */
        val MESSAGE_CHAR_UUID: UUID = UUID.fromString("0000aa02-0000-1000-8000-00805f9b34fb")

        private const val SEND_TIMEOUT_MS = 12_000L
        private const val TARGET_MTU = 512
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter get() = bluetoothManager.adapter

    private var gattServer: BluetoothGattServer? = null
    private var advertiseCallback: AdvertiseCallback? = null

    // Raw incoming bytes received by the GATT server — callers decode these.
    private val _incomingBytes = MutableSharedFlow<ByteArray>(extraBufferCapacity = 64)
    val incomingBytes: SharedFlow<ByteArray> = _incomingBytes.asSharedFlow()

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

    fun startAdvertising() {
        val adapter = bluetoothAdapter ?: return
        if (!adapter.isEnabled || advertiseCallback != null) return

        val advertiser = adapter.bluetoothLeAdvertiser ?: return

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(true)
            .setTimeout(0)
            .build()

        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(MESH_SERVICE_UUID))
            .setIncludeDeviceName(false)
            .build()

        val cb = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {}
            override fun onStartFailure(errorCode: Int) {
                advertiseCallback = null
            }
        }
        advertiseCallback = cb
        try {
            advertiser.startAdvertising(settings, data, cb)
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

        val resultDeferred = CompletableDeferred<Boolean>()

        val gattCallback = object : BluetoothGattCallback() {

            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> gatt.requestMtu(TARGET_MTU)
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        gatt.close()
                        if (!resultDeferred.isCompleted) resultDeferred.complete(false)
                    }
                }
            }

            override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                // Discover services regardless of whether MTU negotiation succeeded.
                gatt.discoverServices()
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    gatt.disconnect()
                    if (!resultDeferred.isCompleted) resultDeferred.complete(false)
                    return
                }

                val char = gatt.getService(MESH_SERVICE_UUID)
                    ?.getCharacteristic(MESSAGE_CHAR_UUID)

                if (char == null) {
                    gatt.disconnect()
                    if (!resultDeferred.isCompleted) resultDeferred.complete(false)
                    return
                }

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
                    gatt.disconnect()
                    if (!resultDeferred.isCompleted) resultDeferred.complete(false)
                }
            }

            override fun onCharacteristicWrite(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int
            ) {
                if (!resultDeferred.isCompleted) {
                    resultDeferred.complete(status == BluetoothGatt.GATT_SUCCESS)
                }
                gatt.disconnect()
            }
        }

        val device = try {
            adapter.getRemoteDevice(address)
        } catch (_: Exception) {
            return@withContext false
        }

        val gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            @Suppress("DEPRECATION")
            device.connectGatt(context, false, gattCallback)
        } ?: return@withContext false

        val result = withTimeoutOrNull(SEND_TIMEOUT_MS) { resultDeferred.await() } ?: false
        if (!resultDeferred.isCompleted) {
            gatt.disconnect()
            gatt.close()
        }
        result
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
            if (characteristic.uuid == MESSAGE_CHAR_UUID && value != null && value.isNotEmpty()) {
                _incomingBytes.tryEmit(value)
            }
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
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
