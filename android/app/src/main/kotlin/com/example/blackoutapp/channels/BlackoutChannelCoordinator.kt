package com.example.blackoutapp.channels

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.content.Intent
import android.provider.Settings
import androidx.core.app.ActivityCompat
import com.blackoutlink.data.bluetooth.BleScanner
import com.blackoutlink.data.bluetooth.BleTransport
import com.blackoutlink.data.location.LocationTracker
import com.blackoutlink.data.permissions.PermissionManager
import com.blackoutlink.data.protocol.MeshProtocol
import com.blackoutlink.data.repository.MeshRepository
import com.blackoutlink.data.security.CryptoManager
import com.blackoutlink.data.storage.BlackoutDatabase
import com.blackoutlink.data.storage.MessageEntity
import com.blackoutlink.data.storage.SettingsStore
import com.blackoutlink.domain.model.MeshMessage
import com.blackoutlink.domain.model.MeshStats
import com.blackoutlink.domain.model.MessageDeliveryStatus
import com.blackoutlink.domain.model.MessageType
import com.blackoutlink.domain.model.PeerDevice
import com.blackoutlink.domain.usecase.LocationFallbackResolver
import com.blackoutlink.domain.usecase.MessageValidationUseCase
import com.blackoutlink.domain.usecase.PowerProfileMapper
import com.blackoutlink.domain.usecase.QuickStatusRecipientResolver
import com.blackoutlink.domain.usecase.SystemHealthAggregator
import com.blackoutlink.domain.usecase.SystemHealthInput
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import androidx.room.Room
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.abs
import kotlin.math.roundToInt
import java.util.UUID

class BlackoutChannelCoordinator(
    messenger: BinaryMessenger,
    private val activity: Activity
) {
    companion object {
        private const val CHAT_CHANNEL = "blackout_link/chat"
        private const val MESH_CHANNEL = "blackout_link/mesh"
        private const val SOS_CHANNEL = "blackout_link/sos"
        private const val LOCATION_CHANNEL = "blackout_link/location"
        private const val PERMISSIONS_CHANNEL = "blackout_link/permissions"
        private const val POWER_CHANNEL = "blackout_link/power"
        private const val SYSTEM_CHANNEL = "blackout_link/system"

        private const val CHAT_INCOMING_CHANNEL = "blackout_link/chat/incoming"
        private const val CHAT_CONNECTION_CHANNEL = "blackout_link/chat/connection"
        private const val MESH_PEERS_CHANNEL = "blackout_link/mesh/peers"
        private const val SOS_STATE_CHANNEL = "blackout_link/sos/state"
        private const val LOCATION_UPDATES_CHANNEL = "blackout_link/location/updates"
        private const val POWER_STATE_CHANNEL = "blackout_link/power/state"
        private const val SYSTEM_STATUS_CHANNEL = "blackout_link/system/status"
        private const val MESH_PERMISSIONS_REQUEST_CODE = 3401
        private const val LOCATION_PERMISSIONS_REQUEST_CODE = 3402
        private const val APP_PERMISSIONS_REQUEST_CODE = 3403
        private const val PEER_STALE_MS = 15_000L
        private const val STALE_LOCATION_MS = 30_000L
        private const val QUICK_STATUS_TTL_MS = 5 * 60 * 1000L
        private const val FALLBACK_DISCHARGE_UA = 180_000.0
    }

    private var chatSink: EventChannel.EventSink? = null
    private var chatConnectionSink: EventChannel.EventSink? = null
    private var meshSink: EventChannel.EventSink? = null
    private var sosSink: EventChannel.EventSink? = null
    private var locationSink: EventChannel.EventSink? = null
    private var powerSink: EventChannel.EventSink? = null
    private var systemSink: EventChannel.EventSink? = null

    private var batterySaverEnabled = false
    private var scanIntervalMs = 1000
    private var lowPowerBluetoothEnabled = false
    private var grayscaleUiEnabled = false
    private var criticalTasksOnlyEnabled = false
    private var sosActive = false
    private val chatSessionByPeerId = mutableMapOf<String, String>()
    private val chatSessionMeta = mutableMapOf<String, Map<String, Any?>>()
    private val localNodeId: String by lazy {
        (Settings.Secure.getString(activity.contentResolver, Settings.Secure.ANDROID_ID)
            ?.uppercase()
            ?.takeIf { it.isNotBlank() }) ?: "LOCAL_NODE"
    }

    private val bleScanner = BleScanner(activity.applicationContext)
    private val bleTransport = BleTransport(activity.applicationContext)
    private val database: BlackoutDatabase = Room.databaseBuilder(
        activity.applicationContext,
        BlackoutDatabase::class.java,
        "blackout_db"
    )
        .addMigrations(BlackoutDatabase.MIGRATION_1_2)
        .build()
    private val locationTracker = LocationTracker(activity.applicationContext)
    private val permissionManager = PermissionManager(activity)
    private val settingsStore = SettingsStore(activity.applicationContext)
    private val cryptoManager = CryptoManager()
    private val meshRepository = MeshRepository(
        bleScanner = bleScanner,
        locationTracker = locationTracker,
        settingsStore = settingsStore,
        cryptoManager = cryptoManager,
        messageDao = database.messageDao(),
        conversationDao = database.conversationDao(),
        peerDao = database.peerDao(),
        sosAlertDao = database.sosAlertDao()
    )

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var meshEventJob: Job? = null
    private var locationEventJob: Job? = null
    private var systemHealthTickerJob: Job? = null
    private val systemHealthAggregator = SystemHealthAggregator()
    private val messageValidationUseCase = MessageValidationUseCase()
    private val quickStatusRecipientResolver = QuickStatusRecipientResolver(staleMs = PEER_STALE_MS)
    private val locationFallbackResolver = LocationFallbackResolver()
    private val powerProfileMapper = PowerProfileMapper()
    private var pendingPermissionsResult: MethodChannel.Result? = null

    private data class MeshState(
        val peers: List<PeerDevice> = emptyList(),
        val stats: MeshStats = MeshStats(),
        val scanActive: Boolean = false,
        val bluetoothEnabled: Boolean = true,
        val permissionsMissing: Boolean = false,
        val lastError: String? = null
    )

    private val _meshState = MutableStateFlow(MeshState())
    private val meshState = _meshState.asStateFlow()

    init {
        hydratePowerSettingsFromStore()
        applyBluetoothPowerProfile()
        configureMethodChannels(messenger)
        configureEventChannels(messenger)
        startMeshCollectors()
        startSystemHealthTicker()
        subscribeToIncomingTransport()
    }

    fun requestMeshRuntimePermissionsIfNeeded() {
        if (!bleScanner.hasPermissions()) {
            ActivityCompat.requestPermissions(
                activity,
                BleScanner.requiredPermissions(),
                MESH_PERMISSIONS_REQUEST_CODE
            )
            refreshSystemStatus()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == APP_PERMISSIONS_REQUEST_CODE) {
            permissionManager.onRequestPermissionsResult(permissions)
            val payload = permissionManager.getPermissionStatus(includeMicrophone = true).toMutableMap()
            payload["method"] = "requestPermissions"
            payload["requestCode"] = requestCode
            pendingPermissionsResult?.success(payload)
            pendingPermissionsResult = null
            refreshSystemStatus()
            return
        }

        refreshSystemStatus()
        emitMeshUpdate()
    }

    private fun configureMethodChannels(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHAT_CHANNEL).setMethodCallHandler(::onChatMethodCall)
        MethodChannel(messenger, MESH_CHANNEL).setMethodCallHandler(::onMeshMethodCall)
        MethodChannel(messenger, SOS_CHANNEL).setMethodCallHandler(::onSosMethodCall)
        MethodChannel(messenger, LOCATION_CHANNEL).setMethodCallHandler(::onLocationMethodCall)
        MethodChannel(messenger, PERMISSIONS_CHANNEL).setMethodCallHandler(::onPermissionsMethodCall)
        MethodChannel(messenger, POWER_CHANNEL).setMethodCallHandler(::onPowerMethodCall)
        MethodChannel(messenger, SYSTEM_CHANNEL).setMethodCallHandler(::onSystemMethodCall)
    }

    private fun configureEventChannels(messenger: BinaryMessenger) {
        EventChannel(messenger, CHAT_INCOMING_CHANNEL).setStreamHandler(
            createHandler(
                onListen = { sink ->
                    chatSink = sink
                    sink.success(
                        mapOf(
                            "event" to "chat_connected",
                            "status" to "listening"
                        )
                    )
                },
                onCancel = { chatSink = null }
            )
        )

        EventChannel(messenger, CHAT_CONNECTION_CHANNEL).setStreamHandler(
            createHandler(
                onListen = { sink ->
                    chatConnectionSink = sink
                    emitChatConnectionState(
                        state = "disconnected",
                        latencyMs = 0,
                        sessionState = "idle"
                    )
                },
                onCancel = { chatConnectionSink = null }
            )
        )

        EventChannel(messenger, MESH_PEERS_CHANNEL).setStreamHandler(
            createHandler(
                onListen = { sink ->
                    meshSink = sink
                    sink.success(meshPayload(event = "peers_snapshot"))
                },
                onCancel = { meshSink = null }
            )
        )

        EventChannel(messenger, SOS_STATE_CHANNEL).setStreamHandler(
            createHandler(
                onListen = { sink ->
                    sosSink = sink
                    sink.success(
                        mapOf(
                            "event" to "sos_state",
                            "state" to "idle"
                        )
                    )
                },
                onCancel = { sosSink = null }
            )
        )

        EventChannel(messenger, LOCATION_UPDATES_CHANNEL).setStreamHandler(
            createHandler(
                onListen = { sink ->
                    locationSink = sink
                    startLocationUpdates()
                },
                onCancel = {
                    locationSink = null
                    stopLocationUpdates()
                }
            )
        )

        EventChannel(messenger, POWER_STATE_CHANNEL).setStreamHandler(
            createHandler(
                onListen = { sink ->
                    powerSink = sink
                    sink.success(powerSettingsPayload(event = "power_settings"))
                },
                onCancel = { powerSink = null }
            )
        )

        EventChannel(messenger, SYSTEM_STATUS_CHANNEL).setStreamHandler(
            createHandler(
                onListen = { sink ->
                    systemSink = sink
                    refreshSystemStatus()
                },
                onCancel = { systemSink = null }
            )
        )
    }

    private fun onChatMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startOfflineChat" -> {
                emitChatConnectionState(
                    state = "connecting",
                    latencyMs = 0,
                    sessionState = "starting"
                )
                if (!bleScanner.isBluetoothEnabled()) {
                    emitChatConnectionState(
                        state = "disconnected",
                        latencyMs = 0,
                        sessionState = "bluetooth_off"
                    )
                    result.success(
                        mapOf(
                            "ok" to false,
                            "method" to "startOfflineChat",
                            "error" to "bluetooth_disabled"
                        )
                    )
                    return
                }

                if (!bleScanner.hasPermissions()) {
                    emitChatConnectionState(
                        state = "error",
                        latencyMs = 0,
                        sessionState = "permissions_missing"
                    )
                    result.success(
                        mapOf(
                            "ok" to false,
                            "method" to "startOfflineChat",
                            "error" to "permissions_missing"
                        )
                    )
                    return
                }

                val peerIdArg = normalizePeerId(call.argument<String>("peerId"))
                val activePeers = meshRepository.getCurrentPeers().filter {
                    val status = it.status.name
                    status == "CONNECTED" || status == "SCANNING"
                }

                val selectedPeer = when {
                    peerIdArg != null -> activePeers.firstOrNull {
                        normalizePeerId(it.id) == peerIdArg
                    }
                    activePeers.isNotEmpty() -> activePeers.first()
                    else -> null
                }

                if (peerIdArg != null && selectedPeer == null) {
                    emitChatConnectionState(
                        state = "error",
                        latencyMs = 0,
                        sessionState = "peer_not_found"
                    )
                    result.success(
                        mapOf(
                            "ok" to false,
                            "method" to "startOfflineChat",
                            "error" to "peer_not_found"
                        )
                    )
                    return
                }

                try {
                    val now = System.currentTimeMillis()
                    val sessionMap = if (selectedPeer != null) {
                        val existingSessionId = chatSessionByPeerId[selectedPeer.id]
                        val sessionId = existingSessionId ?: UUID.randomUUID().toString().also {
                            chatSessionByPeerId[selectedPeer.id] = it
                        }

                        val session = mapOf(
                            "sessionId" to sessionId,
                            "peerId" to selectedPeer.id,
                            "peerName" to selectedPeer.name,
                            "connected" to true,
                            "standby" to false,
                            "status" to "connected",
                            "startedAtMs" to now
                        )
                        chatSessionMeta[sessionId] = session
                        session
                    } else {
                        mapOf(
                            "sessionId" to "standby_$now",
                            "peerId" to null,
                            "peerName" to "NO_ACTIVE_PEER",
                            "connected" to false,
                            "standby" to true,
                            "status" to "disconnected",
                            "startedAtMs" to now
                        )
                    }

                    emitChatConnectionState(
                        state = if (selectedPeer != null) "connected" else "disconnected",
                        latencyMs = if (selectedPeer != null) 14 else 0,
                        sessionState = if (selectedPeer != null) "active" else "standby",
                        sessionId = sessionMap["sessionId"]?.toString(),
                        peerId = sessionMap["peerId"]?.toString(),
                        peerName = sessionMap["peerName"]?.toString()
                    )

                    result.success(
                        mapOf(
                            "ok" to true,
                            "method" to "startOfflineChat",
                            "session" to sessionMap
                        )
                    )
                } catch (_: Throwable) {
                    emitChatConnectionState(
                        state = "error",
                        latencyMs = 0,
                        sessionState = "session_open_failed"
                    )
                    result.success(
                        mapOf(
                            "ok" to false,
                            "method" to "startOfflineChat",
                            "error" to "session_open_failed"
                        )
                    )
                }
            }

            "sendMessage" -> {
                val content = call.argument<String>("content").orEmpty().trim()
                val receiverId = normalizePeerId(call.argument<String>("receiverId"))
                val sessionId = call.argument<String>("sessionId")
                scope.launch {
                    val response = try {
                        processSendMessage(
                            content = content,
                            receiverId = receiverId,
                            sessionId = sessionId
                        )
                    } catch (_: Throwable) {
                        mapOf(
                            "ok" to false,
                            "method" to "sendMessage",
                            "status" to MessageDeliveryStatus.FAILED.name,
                            "error" to "native_send_exception"
                        )
                    }
                    result.success(response)
                }
            }

            "broadcastQuickStatus" -> {
                val rawStatus = call.argument<String>("status").orEmpty().trim()
                scope.launch {
                    val response = processQuickStatusBroadcast(rawStatus)
                    result.success(response)
                }
            }

            "fetchHistory" -> {
                val chatId = call.argument<String>("chatId")
                scope.launch {
                    val messages = withContext(Dispatchers.IO) {
                        val dao = database.messageDao()
                        if (chatId.isNullOrBlank()) dao.getAll() else dao.getByConversation(chatId)
                    }
                    result.success(
                        mapOf(
                            "ok" to true,
                            "method" to "fetchHistory",
                            "messages" to messages.map { entity ->
                                mapOf(
                                    "id" to entity.id,
                                    "conversationId" to entity.conversationId,
                                    "senderId" to entity.senderId,
                                    "receiverId" to entity.receiverId,
                                    "content" to entity.content,
                                    "type" to entity.type,
                                    "createdAt" to entity.createdAt,
                                    "deliveryStatus" to entity.status,
                                    "outgoing" to (entity.senderId == localNodeId),
                                    "peerId" to if (entity.senderId == localNodeId) {
                                        entity.receiverId
                                    } else {
                                        entity.senderId
                                    }
                                )
                            }
                        )
                    )
                }
            }

            "getConversationList" -> {
                scope.launch {
                    val conversations = withContext(Dispatchers.IO) {
                        meshRepository.loadConversationList()
                    }
                    result.success(
                        mapOf(
                            "ok" to true,
                            "method" to "getConversationList",
                            "conversations" to conversations.map {
                                mapOf(
                                    "id" to it.id,
                                    "peerId" to it.peerId,
                                    "title" to it.title,
                                    "lastMessagePreview" to it.lastMessagePreview,
                                    "updatedAt" to it.updatedAt,
                                    "unreadCount" to it.unreadCount
                                )
                            }
                        )
                    )
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun onMeshMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startScan" -> {
                if (!bleScanner.hasPermissions()) {
                    ActivityCompat.requestPermissions(
                        activity,
                        BleScanner.requiredPermissions(),
                        MESH_PERMISSIONS_REQUEST_CODE
                    )
                    _meshState.update {
                        it.copy(
                            permissionsMissing = true,
                            lastError = "permissions_denied"
                        )
                    }
                    refreshSystemStatus()
                    emitMeshUpdate()
                    result.success(
                        mapOf(
                            "ok" to false,
                            "method" to "startScan",
                            "reason" to "permissions_denied",
                            "permissionsMissing" to true,
                            "bluetoothEnabled" to bleScanner.isBluetoothEnabled(),
                            "scanActive" to meshRepository.scanInProgress.value
                        )
                    )
                    return
                }

                bleTransport.startServer()
                val response = meshRepository.startScan()
                bleTransport.startAdvertising()
                _meshState.update {
                    it.copy(
                        permissionsMissing = !bleScanner.hasPermissions(),
                        bluetoothEnabled = bleScanner.isBluetoothEnabled(),
                        scanActive = meshRepository.scanInProgress.value,
                        lastError = response.reason
                    )
                }
                refreshSystemStatus()
                emitMeshUpdate()

                result.success(
                    mapOf(
                        "ok" to response.ok,
                        "method" to "startScan",
                        "state" to if (response.ok) "scanning" else "idle",
                        "reason" to response.reason,
                        "permissionsMissing" to !bleScanner.hasPermissions(),
                        "bluetoothEnabled" to bleScanner.isBluetoothEnabled(),
                        "scanActive" to meshRepository.scanInProgress.value
                    )
                )
            }

            "stopScan" -> {
                val response = meshRepository.stopScan()
                bleTransport.stopAdvertising()
                bleTransport.stopServer()
                _meshState.update {
                    it.copy(
                        scanActive = meshRepository.scanInProgress.value,
                        lastError = response.reason,
                        bluetoothEnabled = bleScanner.isBluetoothEnabled(),
                        permissionsMissing = !bleScanner.hasPermissions()
                    )
                }
                refreshSystemStatus()
                emitMeshUpdate()
                result.success(
                    mapOf(
                        "ok" to response.ok,
                        "method" to "stopScan",
                        "state" to "idle",
                        "reason" to response.reason,
                        "scanActive" to meshRepository.scanInProgress.value
                    )
                )
            }

            "getCurrentPeers" -> {
                val peers = meshRepository.getCurrentPeers().map { it.toChannelMap() }
                result.success(
                    mapOf(
                        "ok" to true,
                        "method" to "getCurrentPeers",
                        "peers" to peers,
                        "scanActive" to meshRepository.scanInProgress.value
                    )
                )
            }

            "getMeshStats" -> {
                val stats = meshRepository.getMeshStats()
                result.success(
                    mapOf(
                        "ok" to true,
                        "method" to "getMeshStats",
                        "stats" to stats.toChannelMap()
                    )
                )
            }

            "refreshPeers" -> {
                emitMeshUpdate()
                result.success(
                    mapOf(
                        "ok" to true,
                        "method" to "refreshPeers",
                        "peers" to meshRepository.getCurrentPeers().map { it.toChannelMap() },
                        "stats" to meshRepository.getMeshStats().toChannelMap()
                    )
                )
            }

            "getRecentPeers" -> {
                val limit = (call.argument<Int>("limit") ?: 20).coerceIn(1, 100)
                scope.launch {
                    val peers = withContext(Dispatchers.IO) {
                        meshRepository.getRecentPeers(limit)
                    }
                    result.success(
                        mapOf(
                            "ok" to true,
                            "method" to "getRecentPeers",
                            "peers" to peers.map {
                                mapOf(
                                    "id" to it.id,
                                    "name" to it.name,
                                    "address" to it.address,
                                    "status" to it.status.lowercase(),
                                    "rssi" to it.rssi,
                                    "distanceMeters" to it.distanceMeters,
                                    "lastSeenMs" to it.lastSeenAt,
                                    "trusted" to it.trusted,
                                    "relayCapable" to it.relayCapable
                                )
                            }
                        )
                    )
                }
            }

            "markTrustedPeer" -> {
                val peerId = call.argument<String>("peerId").orEmpty()
                val trusted = call.argument<Boolean>("trusted") ?: true
                if (peerId.isBlank()) {
                    result.success(
                        mapOf(
                            "ok" to false,
                            "method" to "markTrustedPeer",
                            "error" to "peer_id_required"
                        )
                    )
                    return
                }
                scope.launch {
                    withContext(Dispatchers.IO) {
                        meshRepository.markTrustedPeer(peerId, trusted)
                    }
                    result.success(
                        mapOf(
                            "ok" to true,
                            "method" to "markTrustedPeer",
                            "peerId" to peerId,
                            "trusted" to trusted
                        )
                    )
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun onSosMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sendSos" -> {
                sosActive = true
                sosSink?.success(
                    mapOf(
                        "event" to "sos_state",
                        "state" to "sending",
                        "timestamp" to System.currentTimeMillis()
                    )
                )
                scope.launch {
                    val response = processSendSos()
                    result.success(response)
                    sosSink?.success(
                        mapOf(
                            "event" to "sos_state",
                            "state" to if (response["ok"] == true) "sent" else "error",
                            "timestamp" to System.currentTimeMillis()
                        )
                    )
                }
            }

            "triggerSos" -> {
                sosActive = true
                val lat = call.argument<Double>("latitude")
                val lng = call.argument<Double>("longitude")
                result.success(
                    mapOf(
                        "ok" to true,
                        "method" to "triggerSos",
                        "state" to "broadcasting",
                        "location" to mapOf("latitude" to lat, "longitude" to lng)
                    )
                )
                sosSink?.success(
                    mapOf(
                        "event" to "sos_state",
                        "state" to "broadcasting",
                        "timestamp" to System.currentTimeMillis()
                    )
                )
            }

            "cancelSos" -> {
                sosActive = false
                result.success(mapOf("ok" to true, "method" to "cancelSos", "state" to "idle"))
                sosSink?.success(mapOf("event" to "sos_state", "state" to "idle"))
            }

            "getSosHistory" -> {
                val limit = (call.argument<Int>("limit") ?: 50).coerceIn(1, 200)
                scope.launch {
                    val history = withContext(Dispatchers.IO) {
                        meshRepository.loadSosHistory(limit)
                    }
                    result.success(
                        mapOf(
                            "ok" to true,
                            "method" to "getSosHistory",
                            "alerts" to history.map { row ->
                                mapOf(
                                    "id" to row.alert.id,
                                    "createdAt" to row.alert.createdAt,
                                    "latitude" to row.alert.latitude,
                                    "longitude" to row.alert.longitude,
                                    "accuracyMeters" to row.alert.accuracyMeters,
                                    "sentCount" to row.alert.sentCount,
                                    "deliveredCount" to row.alert.deliveredCount,
                                    "failedCount" to row.alert.failedCount,
                                    "status" to row.alert.status,
                                    "error" to row.alert.error,
                                    "recipients" to row.recipients.map {
                                        mapOf(
                                            "id" to it.id,
                                            "name" to it.displayName,
                                            "channelType" to it.channelType,
                                            "trusted" to it.trusted,
                                            "isPrimary" to it.isPrimary,
                                            "lastUsedAt" to it.lastUsedAt
                                        )
                                    }
                                )
                            }
                        )
                    )
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun onLocationMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCurrentLocation" -> {
                scope.launch {
                    if (!locationTracker.hasPermission()) {
                        ActivityCompat.requestPermissions(
                            activity,
                            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                            LOCATION_PERMISSIONS_REQUEST_CODE
                        )
                        result.success(
                            mapOf(
                                "ok" to false,
                                "method" to "getCurrentLocation",
                                "error" to "location_permission_missing",
                                "permissionGranted" to false,
                                "gpsEnabled" to locationTracker.isGpsEnabled()
                            )
                        )
                        return@launch
                    }

                    if (!locationTracker.isGpsEnabled()) {
                        result.success(
                            mapOf(
                                "ok" to false,
                                "method" to "getCurrentLocation",
                                "error" to "gps_disabled",
                                "permissionGranted" to true,
                                "gpsEnabled" to false
                            )
                        )
                        return@launch
                    }

                    val snapshot = withContext(Dispatchers.IO) {
                        locationTracker.getCurrentLocation()
                    }

                    if (snapshot == null) {
                        result.success(
                            mapOf(
                                "ok" to false,
                                "method" to "getCurrentLocation",
                                "error" to "location_unavailable",
                                "permissionGranted" to true,
                                "gpsEnabled" to true
                            )
                        )
                        return@launch
                    }

                    result.success(
                        mapLocationPayload(
                            snapshot.latitude,
                            snapshot.longitude,
                            snapshot.accuracyMeters,
                            snapshot.timestamp,
                            source = "current",
                            isFallback = false,
                            permissionGranted = true,
                            gpsEnabled = true
                        ) + ("ok" to true) + ("method" to "getCurrentLocation")
                    )
                }
            }

            "getLastKnownLocation" -> {
                scope.launch {
                    if (!locationTracker.hasPermission()) {
                        ActivityCompat.requestPermissions(
                            activity,
                            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                            LOCATION_PERMISSIONS_REQUEST_CODE
                        )
                        result.success(
                            mapOf(
                                "ok" to false,
                                "method" to "getLastKnownLocation",
                                "error" to "location_permission_missing",
                                "permissionGranted" to false,
                                "gpsEnabled" to locationTracker.isGpsEnabled()
                            )
                        )
                        return@launch
                    }

                    val snapshot = withContext(Dispatchers.IO) {
                        locationTracker.getLastKnownLocation()
                    }

                    if (snapshot == null) {
                        result.success(
                            mapOf(
                                "ok" to false,
                                "method" to "getLastKnownLocation",
                                "error" to "location_unavailable",
                                "permissionGranted" to true,
                                "gpsEnabled" to locationTracker.isGpsEnabled()
                            )
                        )
                        return@launch
                    }

                    result.success(
                        mapLocationPayload(
                            snapshot.latitude,
                            snapshot.longitude,
                            snapshot.accuracyMeters,
                            snapshot.timestamp,
                            source = "last_known",
                            isFallback = true,
                            permissionGranted = true,
                            gpsEnabled = locationTracker.isGpsEnabled()
                        ) + ("ok" to true) + ("method" to "getLastKnownLocation")
                    )
                }
            }

            "observeLocationUpdates" -> {
                startLocationUpdates()
                result.success(
                    mapOf(
                        "ok" to true,
                        "method" to "observeLocationUpdates",
                        "state" to "listening"
                    )
                )
            }

            else -> result.notImplemented()
        }
    }

    private fun onPermissionsMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPermissionStatus" -> {
                val includeMicrophone = call.argument<Boolean>("includeMicrophone") ?: false
                val payload = permissionManager.getPermissionStatus(includeMicrophone).toMutableMap()
                payload["method"] = "getPermissionStatus"
                result.success(payload)
            }

            "requestPermissions" -> {
                val includeMicrophone = call.argument<Boolean>("includeMicrophone") ?: false
                if (pendingPermissionsResult != null) {
                    result.success(
                        mapOf(
                            "ok" to false,
                            "method" to "requestPermissions",
                            "error" to "permission_request_in_progress"
                        )
                    )
                    return
                }

                val requestable = permissionManager.requestablePermissions(includeMicrophone)
                if (requestable.isEmpty()) {
                    val payload = permissionManager.getPermissionStatus(includeMicrophone).toMutableMap()
                    payload["method"] = "requestPermissions"
                    result.success(payload)
                    return
                }

                pendingPermissionsResult = result
                ActivityCompat.requestPermissions(
                    activity,
                    requestable.toTypedArray(),
                    APP_PERMISSIONS_REQUEST_CODE
                )
            }

            else -> result.notImplemented()
        }
    }

    private fun onPowerMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setBatterySaver" -> {
                batterySaverEnabled = call.argument<Boolean>("enabled") ?: false
                settingsStore.setBatterySaverEnabled(batterySaverEnabled)
                meshRepository.setBatterySaverEnabled(batterySaverEnabled)
                val payload = powerSettingsPayload(method = "setBatterySaver")
                result.success(payload)
                powerSink?.success(powerSettingsPayload(event = "power_settings"))
            }

            "setScanIntervalMs" -> {
                scanIntervalMs = (call.argument<Int>("value") ?: 1000).coerceIn(1_000, 120_000)
                settingsStore.setScanIntervalMs(scanIntervalMs.toLong())
                lowPowerBluetoothEnabled = scanIntervalMs >= 60_000
                settingsStore.setLowPowerBluetoothEnabled(lowPowerBluetoothEnabled)
                applyBluetoothPowerProfile()
                val payload = powerSettingsPayload(method = "setScanIntervalMs")
                result.success(payload)
                powerSink?.success(powerSettingsPayload(event = "power_settings"))
            }

            "setLowPowerBluetooth" -> {
                lowPowerBluetoothEnabled = call.argument<Boolean>("enabled") ?: false
                scanIntervalMs = if (lowPowerBluetoothEnabled) 120_000 else 1_000
                settingsStore.setLowPowerBluetoothEnabled(lowPowerBluetoothEnabled)
                settingsStore.setScanIntervalMs(scanIntervalMs.toLong())
                applyBluetoothPowerProfile()
                val payload = powerSettingsPayload(method = "setLowPowerBluetooth")
                result.success(payload)
                powerSink?.success(powerSettingsPayload(event = "power_settings"))
            }

            "setGrayscaleUi" -> {
                grayscaleUiEnabled = call.argument<Boolean>("enabled") ?: false
                settingsStore.setGrayscaleUiEnabled(grayscaleUiEnabled)
                val payload = powerSettingsPayload(method = "setGrayscaleUi")
                result.success(payload)
                powerSink?.success(powerSettingsPayload(event = "power_settings"))
            }

            "killBackgroundApps" -> {
                criticalTasksOnlyEnabled = true
                settingsStore.setCriticalTasksOnlyEnabled(true)
                if (!sosActive) {
                    batterySaverEnabled = true
                    settingsStore.setBatterySaverEnabled(true)
                    lowPowerBluetoothEnabled = true
                    settingsStore.setLowPowerBluetoothEnabled(true)
                    scanIntervalMs = 120_000
                    settingsStore.setScanIntervalMs(scanIntervalMs.toLong())
                    applyBluetoothPowerProfile()
                }

                val openedSettings = openBatteryOptimizationSettings()
                val payload = powerSettingsPayload(method = "killBackgroundApps") +
                    mapOf(
                        "optimizationApplied" to true,
                        "criticalServicesProtected" to true,
                        "openedSettingsDeepLink" to openedSettings
                    )
                result.success(payload)
                powerSink?.success(powerSettingsPayload(event = "power_settings"))
            }

            "getPowerSettings", "getSettings" -> {
                result.success(powerSettingsPayload(method = "getPowerSettings"))
            }

            "getRuntimeEstimate" -> {
                val estimateMinutes = computeRuntimeEstimateMinutes()
                val estimateSeconds = computeRuntimeEstimateSeconds()
                val battPct = readBatteryPercent()
                result.success(
                    mapOf(
                        "ok" to true,
                        "method" to "getRuntimeEstimate",
                        "minutes" to estimateMinutes,
                        "seconds" to estimateSeconds,
                        "hours" to (estimateMinutes / 60),
                        "minsRemainder" to (estimateMinutes % 60),
                        "runtimeLabel" to formatRuntimeLabel(estimateSeconds / 60),
                        "batteryPercent" to (battPct ?: -1),
                        "runtimeSource" to if (hasRealtimeDischargeTelemetry()) "realtime_current" else "battery_percent",
                        "criticalServicesProtected" to true
                    )
                )
            }

            else -> result.notImplemented()
        }
    }

    private fun hydratePowerSettingsFromStore() {
        batterySaverEnabled = settingsStore.isBatterySaverEnabled()
        lowPowerBluetoothEnabled = settingsStore.isLowPowerBluetoothEnabled()
        grayscaleUiEnabled = settingsStore.isGrayscaleUiEnabled()
        criticalTasksOnlyEnabled = settingsStore.isCriticalTasksOnlyEnabled()
        scanIntervalMs = settingsStore.getScanIntervalMs().toInt().coerceIn(1_000, 120_000)
    }

    private fun applyBluetoothPowerProfile() {
        val profile = powerProfileMapper.map(lowPowerBluetoothEnabled, scanIntervalMs)
        scanIntervalMs = profile.scanIntervalMs
        meshRepository.setLowPowerBluetoothEnabled(profile.lowPowerBluetoothEnabled, profile.refreshIntervalMs)
    }

    private fun powerSettingsPayload(method: String? = null, event: String? = null): Map<String, Any?> {
        val base = mutableMapOf<String, Any?>(
            "ok" to true,
            "batterySaverEnabled" to batterySaverEnabled,
            "lowPowerBluetoothEnabled" to lowPowerBluetoothEnabled,
            "grayscaleUiEnabled" to grayscaleUiEnabled,
            "criticalTasksOnlyEnabled" to criticalTasksOnlyEnabled,
            "scanIntervalMs" to scanIntervalMs,
            "sosActive" to sosActive,
            "criticalServicesProtected" to true
        )
        if (method != null) base["method"] = method
        if (event != null) base["event"] = event
        return base
    }

    private fun computeRuntimeEstimateMinutes(): Int {
        return (computeRuntimeEstimateSeconds() / 60).coerceAtLeast(0)
    }

    private fun computeRuntimeEstimateSeconds(): Int {
        val realtime = readRuntimeFromBatteryTelemetrySeconds()
        if (realtime != null) {
            return realtime.coerceIn(0, 72 * 3600)
        }

        // Fallback estimate based on current battery percent and selected power profile.
        var baseFullMinutes = 24 * 60
        if (batterySaverEnabled) baseFullMinutes += 8 * 60
        if (lowPowerBluetoothEnabled) baseFullMinutes += 10 * 60
        if (grayscaleUiEnabled) baseFullMinutes += 3 * 60
        if (criticalTasksOnlyEnabled) baseFullMinutes += 4 * 60
        if (sosActive) baseFullMinutes -= 6 * 60
        baseFullMinutes = baseFullMinutes.coerceIn(120, 72 * 60)

        val pct = readBatteryPercent()
        val estMinutes = if (pct != null && pct in 0..100) {
            (baseFullMinutes * pct / 100.0).roundToInt().coerceAtLeast(0)
        } else {
            baseFullMinutes
        }
        return (estMinutes * 60).coerceIn(0, 72 * 3600)
    }

    private fun hasRealtimeDischargeTelemetry(): Boolean {
        return readRuntimeFromBatteryTelemetrySeconds() != null
    }

    private fun readRuntimeFromBatteryTelemetrySeconds(): Int? {
        return try {
            val manager = activity.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                ?: return null
            val chargeCounterUah = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
            val currentNowUa = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)

            if (chargeCounterUah <= 0) {
                return null
            }

            val dischargeCurrentUa = when {
                currentNowUa < -1_000 -> abs(currentNowUa).toDouble()
                currentNowUa > 1_000 -> currentNowUa.toDouble()
                else -> FALLBACK_DISCHARGE_UA
            }
            if (dischargeCurrentUa <= 0.0) {
                return null
            }

            ((chargeCounterUah / dischargeCurrentUa) * 3600.0).roundToInt()
        } catch (_: Throwable) {
            null
        }
    }

    private fun formatRuntimeLabel(minutes: Int): String {
        val hours = minutes / 60
        val mins = minutes % 60
        return String.format("%02d:%02d", hours, mins)
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            activity.startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun onSystemMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> {
                scope.launch {
                    result.success(buildSystemStatusPayload(method = "getStatus"))
                }
            }

            "ping" -> result.success(mapOf("ok" to true, "method" to "ping", "timestamp" to System.currentTimeMillis()))
            else -> result.notImplemented()
        }
    }

    private fun createHandler(
        onListen: (EventChannel.EventSink) -> Unit,
        onCancel: () -> Unit
    ): EventChannel.StreamHandler {
        return object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (events == null) return
                onListen(events)
            }

            override fun onCancel(arguments: Any?) {
                onCancel()
            }
        }
    }

    private fun startMeshCollectors() {
        meshEventJob?.cancel()
        meshEventJob = scope.launch {
            launch {
                meshRepository.peers.collect { peers ->
                    withContext(Dispatchers.IO) {
                        meshRepository.saveRecentPeers(peers)
                        flushPendingQuickStatusIfPossible()
                    }
                    _meshState.update {
                        it.copy(
                            peers = peers,
                            stats = meshRepository.getMeshStats(),
                            bluetoothEnabled = bleScanner.isBluetoothEnabled(),
                            permissionsMissing = !bleScanner.hasPermissions()
                        )
                    }
                    refreshSystemStatus()
                    emitMeshUpdate()
                }
            }

            launch {
                meshRepository.scanInProgress.collect { active ->
                    _meshState.update {
                        it.copy(
                            scanActive = active,
                            bluetoothEnabled = bleScanner.isBluetoothEnabled(),
                            permissionsMissing = !bleScanner.hasPermissions()
                        )
                    }
                    refreshSystemStatus()
                    emitMeshUpdate()
                }
            }
        }
    }

    private fun meshPayload(event: String): Map<String, Any?> {
        val state = meshState.value
        return mapOf(
            "event" to event,
            "peers" to state.peers.map { it.toChannelMap() },
            "stats" to state.stats.toChannelMap(),
            "scanActive" to state.scanActive,
            "bluetoothEnabled" to state.bluetoothEnabled,
            "permissionsMissing" to state.permissionsMissing,
            "error" to state.lastError,
            "timestamp" to System.currentTimeMillis()
        )
    }

    private fun emitMeshUpdate() {
        meshSink?.success(meshPayload(event = "peers_update"))
    }

    private fun refreshSystemStatus() {
        scope.launch {
            systemSink?.success(buildSystemStatusPayload(event = "system_status"))
        }
    }

    private fun startSystemHealthTicker() {
        systemHealthTickerJob?.cancel()
        systemHealthTickerJob = scope.launch {
            while (true) {
                refreshSystemStatus()
                kotlinx.coroutines.delay(3_000L)
            }
        }
    }

    private suspend fun buildSystemStatusPayload(
        method: String? = null,
        event: String? = null
    ): Map<String, Any?> {
        val bluetoothEnabled = bleScanner.isBluetoothEnabled()
        val permissionsMissing = !bleScanner.hasPermissions()
        val peers = meshRepository.getCurrentPeers()
        val scanInProgress = meshRepository.scanInProgress.value
        val batteryPercent = readBatteryPercent()
        val locationAvailable = withContext(Dispatchers.IO) {
            if (!locationTracker.hasPermission()) {
                false
            } else {
                locationTracker.getLastKnownLocation() != null
            }
        }

        val now = System.currentTimeMillis()
        val staleScanResults = peers.isNotEmpty() && peers.all { (now - it.lastSeenAt) > PEER_STALE_MS }

        val health = systemHealthAggregator.aggregate(
            SystemHealthInput(
                bluetoothEnabled = bluetoothEnabled,
                permissionsMissing = permissionsMissing,
                batteryPercent = batteryPercent,
                peers = peers,
                scanInProgress = scanInProgress,
                locationAvailable = locationAvailable,
                staleScanResults = staleScanResults,
                lastError = meshState.value.lastError
            )
        )

        val payload = mutableMapOf<String, Any?>(
            "ok" to true,
            "state" to health.state.name.lowercase(),
            "bluetoothEnabled" to bluetoothEnabled,
            "permissionsMissing" to permissionsMissing,
            "batteryAvailable" to health.batteryAvailable,
            "batteryPercent" to health.batteryPercent,
            "peersAvailable" to health.peersAvailable,
            "nodesActive" to health.nodesActive,
            "scanInProgress" to health.scanInProgress,
            "scanState" to if (health.scanInProgress) "scanning" else "idle",
            "btRangeKm" to ((health.btRangeKm * 100.0).roundToInt() / 100.0),
            "meshRadiusKm" to ((health.meshRadiusKm * 100.0).roundToInt() / 100.0),
            "locationAvailable" to health.locationAvailable,
            "staleScanResults" to health.staleScanResults,
            "signalState" to health.signalState,
            "lastError" to health.lastError,
            "timestamp" to now
        )
        if (method != null) {
            payload["method"] = method
        }
        if (event != null) {
            payload["event"] = event
        }
        return payload
    }

    private fun readBatteryPercent(): Int? {
        return try {
            val intent = activity.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            if (level < 0 || scale <= 0) {
                null
            } else {
                ((level * 100f) / scale.toFloat()).roundToInt().coerceIn(0, 100)
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun PeerDevice.toChannelMap(): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "name" to name,
            "address" to address,
            "status" to status.name.lowercase(),
            "rssi" to rssi,
            "distanceMeters" to ((estimatedDistanceMeters * 100.0).roundToInt() / 100.0),
            "trusted" to trusted,
            "relayCapable" to relayCapable,
            "lastSeenMs" to lastSeenAt
        )
    }

    private fun MeshStats.toChannelMap(): Map<String, Any?> {
        return mapOf(
            "detected" to detected,
            "active" to active,
            "trusted" to trusted,
            "relayCapable" to relayCapable,
            "radiusMeters" to ((radiusMeters * 100.0).roundToInt() / 100.0)
        )
    }

    private suspend fun processSendMessage(
        content: String,
        receiverId: String?,
        sessionId: String?
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        try {
        val validation = messageValidationUseCase.validateDraft(content)
        if (!validation.valid) {
            return@withContext mapOf(
                "ok" to false,
                "method" to "sendMessage",
                "error" to (validation.errorCode ?: "invalid_draft"),
                "status" to MessageDeliveryStatus.FAILED.name
            )
        }

        val messageId = UUID.randomUUID().toString()
        val createdAt = System.currentTimeMillis()
        val senderId = localNodeId
        val resolvedReceiver = normalizePeerId(receiverId ?: resolvePeerIdFromSession(sessionId))

        val message = MeshMessage(
            id = messageId,
            senderId = senderId,
            receiverId = resolvedReceiver,
            type = MessageType.TEXT,
            content = content,
            createdAt = createdAt
        )

        val dao = try { database.messageDao() } catch (e: Throwable) {
            Log.e("BLC", "db_open_failed: ${e.javaClass.simpleName}: ${e.message}", e)
            return@withContext mapOf("ok" to false, "method" to "sendMessage",
                "status" to MessageDeliveryStatus.FAILED.name, "error" to "db_open_failed")
        }
        val conversationDao = try { database.conversationDao() } catch (e: Throwable) {
            Log.e("BLC", "conv_dao_failed: ${e.javaClass.simpleName}: ${e.message}", e)
            return@withContext mapOf("ok" to false, "method" to "sendMessage",
                "status" to MessageDeliveryStatus.FAILED.name, "error" to "db_open_failed")
        }
        val conversationId = resolvedReceiver ?: "broadcast"
        try {
            dao.upsert(
                MessageEntity(
                    id = messageId,
                    senderId = senderId,
                    receiverId = resolvedReceiver,
                    type = MessageType.TEXT.name,
                    content = content,
                    createdAt = createdAt,
                    status = MessageDeliveryStatus.QUEUED.name,
                    conversationId = conversationId
                )
            )
        } catch (e: Throwable) {
            Log.e("BLC", "msg_upsert_failed: ${e.javaClass.simpleName}: ${e.message}", e)
            return@withContext mapOf("ok" to false, "method" to "sendMessage",
                "status" to MessageDeliveryStatus.FAILED.name, "error" to "db_msg_write_failed")
        }
        try {
            conversationDao.upsert(
                com.blackoutlink.data.storage.ConversationEntity(
                    id = conversationId,
                    peerId = resolvedReceiver,
                    title = resolvedReceiver ?: "BROADCAST",
                    lastMessagePreview = content.take(120),
                    updatedAt = createdAt,
                    unreadCount = 0
                )
            )
        } catch (e: Throwable) {
            Log.e("BLC", "conv_upsert_failed: ${e.javaClass.simpleName}: ${e.message}", e)
            // Non-fatal: conversation metadata failure does not block sending
        }

        val packet = MeshProtocol.encode(message)

        if (resolvedReceiver == null && !hasActiveTransport(null)) {
            withContext(Dispatchers.Main) {
                emitChatConnectionState(
                    state = "disconnected",
                    latencyMs = 0,
                    sessionState = "no_transport",
                    sessionId = sessionId,
                    peerId = resolvedReceiver
                )
            }
            return@withContext mapOf(
                "ok" to false,
                "method" to "sendMessage",
                "messageId" to messageId,
                "status" to MessageDeliveryStatus.FAILED.name,
                "createdAt" to createdAt,
                "error" to "no_active_transport"
            )
        }

        val sent = if (resolvedReceiver != null) {
            bleTransport.sendTo(resolvedReceiver, packet)
        } else {
            val connectedPeers = meshRepository.getCurrentPeers().filter {
                it.status.name == "CONNECTED" || it.status.name == "SCANNING"
            }
            var any = false
            for (peer in connectedPeers) {
                if (bleTransport.sendTo(peer.id, packet)) any = true
            }
            any
        }
        val finalStatus = if (sent) MessageDeliveryStatus.SENT else MessageDeliveryStatus.FAILED
        dao.updateStatus(messageId, finalStatus.name)

        withContext(Dispatchers.Main) {
            if (sent) {
                emitChatConnectionState(
                    state = "connected",
                    latencyMs = 0,
                    sessionState = "active",
                    sessionId = sessionId,
                    peerId = resolvedReceiver
                )
            } else {
                emitChatConnectionState(
                    state = "error",
                    latencyMs = 0,
                    sessionState = "send_failed",
                    sessionId = sessionId,
                    peerId = resolvedReceiver
                )
            }
        }

        mapOf(
            "ok" to sent,
            "method" to "sendMessage",
            "messageId" to messageId,
            "status" to finalStatus.name,
            "createdAt" to createdAt,
            "error" to if (sent) null else "transport_send_failed"
        )
        } catch (e: Throwable) {
            Log.e("BLC", "processSendMessage exception: ${e.javaClass.simpleName}: ${e.message}", e)
            mapOf(
                "ok" to false,
                "method" to "sendMessage",
                "status" to MessageDeliveryStatus.FAILED.name,
                "error" to "native_send_exception",
                "detail" to "${e.javaClass.simpleName}: ${e.message?.take(120)}"
            )
        }
    }

    private suspend fun processQuickStatusBroadcast(rawStatus: String): Map<String, Any?> =
        withContext(Dispatchers.IO) {
            val normalizedStatus = rawStatus.substringBefore("|").uppercase()
            val type = mapQuickStatusType(normalizedStatus)
            val expiresAtMs = System.currentTimeMillis() + QUICK_STATUS_TTL_MS
            val localDeviceName = Build.MODEL ?: "UNKNOWN_DEVICE"
            val statusPayload = "STATUS:$normalizedStatus|DEVICE=$localDeviceName|EXP=$expiresAtMs"

            if (!bleScanner.isBluetoothEnabled()) {
                settingsStore.setPendingQuickStatus(normalizedStatus, expiresAtMs)
                return@withContext mapOf(
                    "ok" to true,
                    "method" to "broadcastQuickStatus",
                    "sentCount" to 0,
                    "deliveredCount" to 0,
                    "failedCount" to 0,
                    "queuedForDelivery" to true,
                    "error" to null
                )
            }

            val recipients = resolveBroadcastRecipients()
            if (recipients.isEmpty()) {
                settingsStore.setPendingQuickStatus(normalizedStatus, expiresAtMs)
                return@withContext mapOf(
                    "ok" to true,
                    "method" to "broadcastQuickStatus",
                    "sentCount" to 0,
                    "deliveredCount" to 0,
                    "failedCount" to 0,
                    "queuedForDelivery" to true,
                    "error" to null
                )
            }

            val dao = database.messageDao()
            val conversationDao = database.conversationDao()
            var sentCount = 0
            var deliveredCount = 0
            var failedCount = 0

            for (peer in recipients) {
                val messageId = UUID.randomUUID().toString()
                val createdAt = System.currentTimeMillis()

                dao.upsert(
                    MessageEntity(
                        id = messageId,
                        senderId = localNodeId,
                        receiverId = peer.id,
                        type = type.name,
                        content = statusPayload,
                        createdAt = createdAt,
                        status = MessageDeliveryStatus.QUEUED.name,
                        conversationId = peer.id
                    )
                )
                conversationDao.upsert(
                    com.blackoutlink.data.storage.ConversationEntity(
                        id = peer.id,
                        peerId = peer.id,
                        title = peer.name,
                        lastMessagePreview = statusPayload,
                        updatedAt = createdAt,
                        unreadCount = 0
                    )
                )

                val meshMessage = MeshMessage(
                    id = messageId,
                    senderId = localNodeId,
                    receiverId = peer.id,
                    type = type,
                    content = statusPayload,
                    createdAt = createdAt
                )

                val packet = MeshProtocol.encode(meshMessage)
                val canSend = hasActiveTransport(peer.id)
                if (!canSend) {
                    failedCount++
                    dao.updateStatus(messageId, MessageDeliveryStatus.FAILED.name)
                    continue
                }

                val sent = bleTransport.sendTo(peer.id, packet)
                if (sent) {
                    sentCount++
                    deliveredCount++
                    dao.updateStatus(messageId, MessageDeliveryStatus.SENT.name)
                } else {
                    failedCount++
                    dao.updateStatus(messageId, MessageDeliveryStatus.FAILED.name)
                }
            }

            if (failedCount == 0) {
                settingsStore.clearPendingQuickStatus()
            }

            mapOf(
                "ok" to (failedCount == 0),
                "method" to "broadcastQuickStatus",
                "sentCount" to sentCount,
                "deliveredCount" to deliveredCount,
                "failedCount" to failedCount,
                "queuedForDelivery" to false,
                "error" to if (failedCount > 0) "partial_failure" else null
            )
        }

    private suspend fun flushPendingQuickStatusIfPossible() {
        val pendingStatus = settingsStore.getPendingQuickStatus()?.trim()?.uppercase()
        val expiresAtMs = settingsStore.getPendingQuickStatusExpiresAtMs()
        if (pendingStatus.isNullOrBlank()) {
            settingsStore.clearPendingQuickStatus()
            return
        }
        if (expiresAtMs <= System.currentTimeMillis()) {
            settingsStore.clearPendingQuickStatus()
            return
        }
        if (!bleScanner.isBluetoothEnabled()) {
            return
        }

        val recipients = resolveBroadcastRecipients()
        if (recipients.isEmpty()) {
            return
        }

        val localDeviceName = Build.MODEL ?: "UNKNOWN_DEVICE"
        val statusPayload = "STATUS:$pendingStatus|DEVICE=$localDeviceName|EXP=$expiresAtMs"
        val type = mapQuickStatusType(pendingStatus)
        val dao = database.messageDao()
        val conversationDao = database.conversationDao()
        var successfulSends = 0

        for (peer in recipients) {
            val messageId = UUID.randomUUID().toString()
            val createdAt = System.currentTimeMillis()

            dao.upsert(
                MessageEntity(
                    id = messageId,
                    senderId = localNodeId,
                    receiverId = peer.id,
                    type = type.name,
                    content = statusPayload,
                    createdAt = createdAt,
                    status = MessageDeliveryStatus.QUEUED.name,
                    conversationId = peer.id
                )
            )
            conversationDao.upsert(
                com.blackoutlink.data.storage.ConversationEntity(
                    id = peer.id,
                    peerId = peer.id,
                    title = peer.name,
                    lastMessagePreview = statusPayload,
                    updatedAt = createdAt,
                    unreadCount = 0
                )
            )

            val meshMessage = MeshMessage(
                id = messageId,
                senderId = localNodeId,
                receiverId = peer.id,
                type = type,
                content = statusPayload,
                createdAt = createdAt
            )

            val packet = MeshProtocol.encode(meshMessage)
            val canSend = hasActiveTransport(peer.id)
            if (!canSend) {
                dao.updateStatus(messageId, MessageDeliveryStatus.FAILED.name)
                continue
            }

            val sent = bleTransport.sendTo(peer.id, packet)
            if (sent) {
                successfulSends++
                dao.updateStatus(messageId, MessageDeliveryStatus.SENT.name)
            } else {
                dao.updateStatus(messageId, MessageDeliveryStatus.FAILED.name)
            }
        }

        if (successfulSends > 0) {
            settingsStore.clearPendingQuickStatus()
        }
    }

    private suspend fun processSendSos(): Map<String, Any?> = withContext(Dispatchers.IO) {
        if (!bleScanner.isBluetoothEnabled()) {
            return@withContext mapOf(
                "ok" to false,
                "method" to "sendSos",
                "sentCount" to 0,
                "deliveredCount" to 0,
                "failedCount" to 0,
                "error" to "bluetooth_disabled"
            )
        }

        if (!locationTracker.hasPermission()) {
            return@withContext mapOf(
                "ok" to false,
                "method" to "sendSos",
                "sentCount" to 0,
                "deliveredCount" to 0,
                "failedCount" to 0,
                "error" to "location_permission_missing"
            )
        }

        val recipients = resolveBroadcastRecipients()
        if (recipients.isEmpty()) {
            return@withContext mapOf(
                "ok" to false,
                "method" to "sendSos",
                "sentCount" to 0,
                "deliveredCount" to 0,
                "failedCount" to 0,
                "error" to "zero_recipients"
            )
        }

        val currentLocation = locationTracker.getCurrentLocation()
        val fallback = locationTracker.getLastKnownLocation()
        val resolvedLocation = locationFallbackResolver.resolve(currentLocation, fallback)
        val location = resolvedLocation.location
        val usedFallback = resolvedLocation.usedFallback
        val gpsEnabled = locationTracker.isGpsEnabled()
        if (location == null) {
            return@withContext mapOf(
                "ok" to false,
                "method" to "sendSos",
                "sentCount" to 0,
                "deliveredCount" to 0,
                "failedCount" to 0,
                "error" to if (!gpsEnabled) "gps_disabled" else "location_unavailable",
                "gpsEnabled" to gpsEnabled,
                "permissionGranted" to true
            )
        }

        val sosAlertId = "sos_${System.currentTimeMillis()}"
        val timestamp = System.currentTimeMillis()
        val payloadContent = "SOS:$sosAlertId:${location.latitude},${location.longitude}:$timestamp"
        val dao = database.messageDao()
        val conversationDao = database.conversationDao()

        var sentCount = 0
        var deliveredCount = 0
        var failedCount = 0
        val recipientStatuses = mutableListOf<Map<String, Any?>>()

        for (peer in recipients) {
            val messageId = UUID.randomUUID().toString()
            val createdAt = System.currentTimeMillis()

            dao.upsert(
                MessageEntity(
                    id = messageId,
                    senderId = localNodeId,
                    receiverId = peer.id,
                    type = MessageType.SOS.name,
                    content = payloadContent,
                    createdAt = createdAt,
                    status = MessageDeliveryStatus.QUEUED.name,
                    conversationId = peer.id
                )
            )
            conversationDao.upsert(
                com.blackoutlink.data.storage.ConversationEntity(
                    id = peer.id,
                    peerId = peer.id,
                    title = peer.name,
                    lastMessagePreview = payloadContent.take(120),
                    updatedAt = createdAt,
                    unreadCount = 0
                )
            )

            val meshMessage = MeshMessage(
                id = messageId,
                senderId = localNodeId,
                receiverId = peer.id,
                type = MessageType.SOS,
                content = payloadContent,
                createdAt = createdAt,
                ttlSeconds = 600
            )

            val packet = MeshProtocol.encode(meshMessage)
            val canSend = hasActiveTransport(peer.id)

            if (!canSend) {
                failedCount++
                dao.updateStatus(messageId, MessageDeliveryStatus.FAILED.name)
                recipientStatuses.add(
                    mapOf(
                        "recipientId" to peer.id,
                        "recipientName" to peer.name,
                        "status" to "FAILED",
                        "error" to "no_active_transport"
                    )
                )
                continue
            }

            val sent = bleTransport.sendTo(peer.id, packet)
            if (sent) {
                sentCount++
                deliveredCount++
                dao.updateStatus(messageId, MessageDeliveryStatus.SENT.name)
                recipientStatuses.add(
                    mapOf(
                        "recipientId" to peer.id,
                        "recipientName" to peer.name,
                        "status" to "DELIVERED",
                        "error" to null
                    )
                )
            } else {
                failedCount++
                dao.updateStatus(messageId, MessageDeliveryStatus.FAILED.name)
                recipientStatuses.add(
                    mapOf(
                        "recipientId" to peer.id,
                        "recipientName" to peer.name,
                        "status" to "FAILED",
                        "error" to "transport_send_failed"
                    )
                )
            }
        }

        val recipientsForHistory = recipientStatuses.map {
            MeshRepository.SosRecipientHistory(
                id = "${it["recipientId"]}",
                name = "${it["recipientName"]}",
                status = "${it["status"]}",
                error = it["error"]?.toString(),
                trusted = recipients.any { peer -> peer.id == it["recipientId"] && peer.trusted }
            )
        }

        meshRepository.saveSosAlertHistory(
            alertId = sosAlertId,
            createdAt = timestamp,
            latitude = location.latitude,
            longitude = location.longitude,
            accuracyMeters = location.accuracyMeters,
            sentCount = sentCount,
            deliveredCount = deliveredCount,
            failedCount = failedCount,
            status = if (failedCount == 0) "DELIVERED" else "PARTIAL_FAILURE",
            error = if (failedCount > 0) "partial_failure" else null,
            recipients = recipientsForHistory
        )

        return@withContext mapOf(
            "ok" to (failedCount == 0),
            "method" to "sendSos",
            "sosAlertId" to sosAlertId,
            "sentCount" to sentCount,
            "deliveredCount" to deliveredCount,
            "failedCount" to failedCount,
            "location" to mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracyMeters" to location.accuracyMeters
            ),
            "timestamp" to timestamp,
            "isStale" to ((System.currentTimeMillis() - location.timestamp) > STALE_LOCATION_MS),
            "isFallback" to usedFallback,
            "source" to if (usedFallback) "last_known" else "current",
            "gpsEnabled" to gpsEnabled,
            "permissionGranted" to true,
            "recipients" to recipientStatuses,
            "error" to if (failedCount > 0) "partial_failure" else null
        )
    }

    private fun resolvePeerIdFromSession(sessionId: String?): String? {
        if (sessionId.isNullOrBlank()) return null
        val meta = chatSessionMeta[sessionId] ?: return null
        return normalizePeerId(meta["peerId"]?.toString())
    }

    private fun hasActiveTransport(peerId: String?): Boolean {
        val peers = meshRepository.getCurrentPeers()
        if (peers.isEmpty()) return false
        val active = peers.filter { it.status.name == "CONNECTED" || it.status.name == "SCANNING" }
        if (active.isEmpty()) return false
        val normalizedPeerId = normalizePeerId(peerId)
        return if (normalizedPeerId.isNullOrBlank()) {
            true
        } else {
            active.any { normalizePeerId(it.id) == normalizedPeerId }
        }
    }

    private fun normalizePeerId(raw: String?): String? {
        val value = raw?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        return value.uppercase()
    }

    private fun resolveBroadcastRecipients(): List<PeerDevice> {
        return quickStatusRecipientResolver.resolve(meshRepository.getCurrentPeers())
    }

    private fun mapQuickStatusType(rawStatus: String): MessageType {
        return when (rawStatus.uppercase()) {
            "I_AM_SAFE" -> MessageType.STATUS_SAFE
            "ON_MY_WAY", "EN_ROUTE" -> MessageType.STATUS_ON_MY_WAY
            "NEED_WATER", "LOW_BATTERY" -> MessageType.STATUS_NEED_WATER
            "NEED_HELP" -> MessageType.STATUS_NEED_HELP
            else -> MessageType.STATUS_NEED_HELP
        }
    }

    private fun startLocationUpdates() {
        if (locationEventJob?.isActive == true) return
        locationEventJob = scope.launch {
            if (!locationTracker.hasPermission()) {
                locationSink?.success(
                    mapOf(
                        "event" to "location_update",
                        "ok" to false,
                        "error" to "location_permission_missing",
                        "permissionGranted" to false,
                        "gpsEnabled" to locationTracker.isGpsEnabled(),
                        "timestamp" to System.currentTimeMillis()
                    )
                )
                return@launch
            }

            if (!locationTracker.isGpsEnabled()) {
                locationSink?.success(
                    mapOf(
                        "event" to "location_update",
                        "ok" to false,
                        "error" to "gps_disabled",
                        "permissionGranted" to true,
                        "gpsEnabled" to false,
                        "timestamp" to System.currentTimeMillis()
                    )
                )
                return@launch
            }

            locationTracker.locationUpdates().collect { snapshot ->
                locationSink?.success(
                    mapLocationPayload(
                        snapshot.latitude,
                        snapshot.longitude,
                        snapshot.accuracyMeters,
                        snapshot.timestamp,
                        source = "current",
                        isFallback = false,
                        permissionGranted = true,
                        gpsEnabled = true
                    ) +
                        mapOf(
                            "event" to "location_update",
                            "ok" to true
                        )
                )
            }
        }
    }

    private fun stopLocationUpdates() {
        locationEventJob?.cancel()
        locationEventJob = null
    }

    private fun mapLocationPayload(
        latitude: Double,
        longitude: Double,
        accuracyMeters: Float,
        timestamp: Long,
        source: String,
        isFallback: Boolean,
        permissionGranted: Boolean,
        gpsEnabled: Boolean
    ): Map<String, Any?> {
        val stale = (System.currentTimeMillis() - timestamp) > STALE_LOCATION_MS
        return mapOf(
            "latitude" to latitude,
            "longitude" to longitude,
            "accuracyMeters" to accuracyMeters,
            "timestamp" to timestamp,
            "isStale" to stale,
            "isFallback" to isFallback,
            "source" to source,
            "permissionGranted" to permissionGranted,
            "gpsEnabled" to gpsEnabled
        )
    }

    private fun emitIncomingMessage(
        id: String,
        conversationId: String,
        senderId: String,
        peerId: String,
        content: String,
        type: String,
        createdAt: Long,
        deliveryStatus: String
    ) {
        try {
            chatSink?.success(
                mapOf(
                    "event" to "incoming_message",
                    "id" to id,
                    "conversationId" to conversationId,
                    "senderId" to senderId,
                    "peerId" to peerId,
                    "outgoing" to false,
                    "content" to content,
                    "type" to type,
                    "createdAt" to createdAt,
                    "deliveryStatus" to deliveryStatus
                )
            )
        } catch (_: Throwable) {
        }
    }

    private fun emitChatConnectionState(
        state: String,
        latencyMs: Int,
        sessionState: String,
        sessionId: String? = null,
        peerId: String? = null,
        peerName: String? = null
    ) {
        try {
            chatConnectionSink?.success(
                mapOf(
                    "event" to "connection_state",
                    "state" to state,
                    "latencyMs" to latencyMs,
                    "sessionState" to sessionState,
                    "sessionId" to sessionId,
                    "peerId" to peerId,
                    "peerName" to peerName,
                    "timestamp" to System.currentTimeMillis()
                )
            )
        } catch (_: Throwable) {
        }
    }

    private fun subscribeToIncomingTransport() {
        scope.launch {
            bleTransport.incomingBytes.collect { packet ->
                try {
                    val message = MeshProtocol.decode(packet.payload)
                    val now = System.currentTimeMillis()
                    val peerId = normalizePeerId(packet.sourceAddress) ?: message.senderId
                    val conversationId = peerId
                    withContext(Dispatchers.IO) {
                        database.messageDao().upsert(
                            MessageEntity(
                                id = message.id,
                                senderId = peerId,
                                receiverId = message.receiverId,
                                type = message.type.name,
                                content = message.content,
                                createdAt = message.createdAt,
                                status = MessageDeliveryStatus.DELIVERED.name,
                                conversationId = conversationId
                            )
                        )
                        database.conversationDao().upsert(
                            com.blackoutlink.data.storage.ConversationEntity(
                                id = conversationId,
                                peerId = peerId,
                                title = peerId,
                                lastMessagePreview = message.content.take(120),
                                updatedAt = now,
                                unreadCount = 1
                            )
                        )
                    }
                    emitIncomingMessage(
                        id = message.id,
                        conversationId = conversationId,
                        senderId = peerId,
                        peerId = peerId,
                        content = message.content,
                        type = message.type.name,
                        createdAt = message.createdAt,
                        deliveryStatus = MessageDeliveryStatus.DELIVERED.name
                    )
                } catch (_: Throwable) {
                    // Malformed or incompatible message — discard silently.
                }
            }
        }
    }
}
