package com.blackoutlink.data.repository

import com.blackoutlink.data.bluetooth.MeshScanner
import com.blackoutlink.data.location.LocationTracker
import com.blackoutlink.data.protocol.MeshProtocol
import com.blackoutlink.data.security.PayloadCrypto
import com.blackoutlink.data.storage.ConversationDao
import com.blackoutlink.data.storage.ConversationEntity
import com.blackoutlink.data.storage.EmergencyRecipientEntity
import com.blackoutlink.data.storage.MessageDao
import com.blackoutlink.data.storage.MessageEntity
import com.blackoutlink.data.storage.PeerDao
import com.blackoutlink.data.storage.PeerEntity
import com.blackoutlink.data.storage.SettingsStore
import com.blackoutlink.data.storage.SosAlertDao
import com.blackoutlink.data.storage.SosAlertEntity
import com.blackoutlink.data.storage.SosAlertRecipientCrossRef
import com.blackoutlink.domain.model.MeshMessage
import com.blackoutlink.domain.model.MeshStats
import com.blackoutlink.domain.model.MessageDeliveryStatus
import com.blackoutlink.domain.model.MessageType
import com.blackoutlink.domain.model.PeerDevice
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

class MeshRepository(
    private val bleScanner: MeshScanner,
    private val locationTracker: LocationTracker? = null,
    private val settingsStore: SettingsStore? = null,
    private val cryptoManager: PayloadCrypto? = null,
    private val messageDao: MessageDao? = null,
    private val conversationDao: ConversationDao? = null,
    private val peerDao: PeerDao? = null,
    private val sosAlertDao: SosAlertDao? = null,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val transportSend: suspend (ByteArray) -> Boolean = { payload ->
        simulatedRetrySend(payload)
    }
) {
    private val outgoingEvents = MutableSharedFlow<MeshMessage>(extraBufferCapacity = 64)
    private val _batterySaverFallback = MutableStateFlow(false)
    private val repoScope = CoroutineScope(SupervisorJob() + ioDispatcher)

    val peers: StateFlow<List<PeerDevice>> = bleScanner.peers
    val scanInProgress = bleScanner.scanInProgress
    val batterySaverEnabled: StateFlow<Boolean> = settingsStore?.batterySaverEnabled ?: _batterySaverFallback.asStateFlow()

    val meshStats: StateFlow<MeshStats> = MutableStateFlow(MeshStats()).also { statsFlow ->
        repoScope.launch {
            peers.collect { list ->
                statsFlow.value = computeMeshStats(list)
            }
        }
    }.asStateFlow()

    private fun computeMeshStats(list: List<PeerDevice>): MeshStats =
        MeshStats(
            detected = list.size,
            active = list.count { it.status.name == "CONNECTED" },
            trusted = list.count { it.trusted },
            relayCapable = list.count { it.relayCapable },
            radiusMeters = list.maxOfOrNull { it.estimatedDistanceMeters } ?: 0.0
        )

    fun startScan() = bleScanner.startScan()
    fun stopScan() = bleScanner.stopScan()
    fun getCurrentPeers(): List<PeerDevice> = bleScanner.getCurrentPeers()
    fun getMeshStats(): MeshStats = computeMeshStats(getCurrentPeers())
    fun isBluetoothEnabled(): Boolean = bleScanner.isBluetoothEnabled()
    fun hasPermissions(): Boolean = bleScanner.hasPermissions()
    fun setBatterySaverEnabled(enabled: Boolean) {
        settingsStore?.setBatterySaverEnabled(enabled)
        if (settingsStore == null) {
            _batterySaverFallback.value = enabled
        }
    }

    fun setLowPowerBluetoothEnabled(enabled: Boolean, scanIntervalMs: Long) {
        settingsStore?.setLowPowerBluetoothEnabled(enabled)
        settingsStore?.setScanIntervalMs(scanIntervalMs)
        bleScanner.configurePowerProfile(enabled, scanIntervalMs)
    }

    fun locationUpdates() = locationTracker?.locationUpdates() ?: emptyFlow()

    fun observeMessages() = messageDao?.observeAll() ?: emptyFlow()

    suspend fun loadConversationList(): List<ConversationEntity> = withContext(ioDispatcher) {
        conversationDao?.getAll() ?: emptyList()
    }

    suspend fun saveRecentPeers(peers: List<PeerDevice>) = withContext(ioDispatcher) {
        val dao = peerDao ?: return@withContext
        val trustedIds = dao.getTrustedPeerIds().toSet()
        val now = System.currentTimeMillis()
        val entities = peers.map { peer ->
            PeerEntity(
                id = peer.id,
                name = peer.name,
                address = peer.address,
                status = peer.status.name,
                rssi = peer.rssi,
                distanceMeters = peer.estimatedDistanceMeters,
                lastSeenAt = peer.lastSeenAt,
                trusted = peer.id in trustedIds || peer.trusted,
                relayCapable = peer.relayCapable,
                updatedAt = now
            )
        }
        dao.upsertAll(entities)
    }

    suspend fun getRecentPeers(limit: Int = 20): List<PeerEntity> = withContext(ioDispatcher) {
        peerDao?.getRecent(limit) ?: emptyList()
    }

    suspend fun markTrustedPeer(peerId: String, trusted: Boolean) = withContext(ioDispatcher) {
        peerDao?.markTrusted(peerId, trusted)
    }

    suspend fun saveSosAlertHistory(
        alertId: String,
        createdAt: Long,
        latitude: Double,
        longitude: Double,
        accuracyMeters: Float,
        sentCount: Int,
        deliveredCount: Int,
        failedCount: Int,
        status: String,
        error: String?,
        recipients: List<SosRecipientHistory>
    ) = withContext(ioDispatcher) {
        val dao = sosAlertDao ?: return@withContext
        dao.upsert(
            SosAlertEntity(
                id = alertId,
                createdAt = createdAt,
                latitude = latitude,
                longitude = longitude,
                accuracyMeters = accuracyMeters,
                sentCount = sentCount,
                deliveredCount = deliveredCount,
                failedCount = failedCount,
                status = status,
                error = error
            )
        )

        if (recipients.isNotEmpty()) {
            dao.upsertRecipients(
                recipients.map {
                    EmergencyRecipientEntity(
                        id = it.id,
                        displayName = it.name,
                        channelType = "mesh",
                        trusted = it.trusted,
                        isPrimary = false,
                        lastUsedAt = createdAt
                    )
                }
            )
            dao.upsertAlertRecipients(
                recipients.map {
                    SosAlertRecipientCrossRef(
                        sosAlertId = alertId,
                        recipientId = it.id,
                        deliveryStatus = it.status,
                        error = it.error
                    )
                }
            )
        }
    }

    suspend fun loadSosHistory(limit: Int = 50) = withContext(ioDispatcher) {
        sosAlertDao?.getHistoryWithRecipients(limit) ?: emptyList()
    }

    suspend fun sendTextMessage(senderId: String, receiverId: String?, content: String) {
        val message = MeshMessage(
            id = UUID.randomUUID().toString(),
            senderId = senderId,
            receiverId = receiverId,
            type = MessageType.TEXT,
            content = content,
            createdAt = System.currentTimeMillis()
        )
        queueAndSend(message)
    }

    suspend fun sendQuickStatus(senderId: String, type: MessageType) {
        val message = MeshMessage(
            id = UUID.randomUUID().toString(),
            senderId = senderId,
            receiverId = null,
            type = type,
            content = type.name,
            createdAt = System.currentTimeMillis()
        )
        queueAndSend(message)
    }

    suspend fun sendSos(senderId: String, payload: String) {
        val message = MeshMessage(
            id = UUID.randomUUID().toString(),
            senderId = senderId,
            receiverId = null,
            type = MessageType.SOS,
            content = payload,
            createdAt = System.currentTimeMillis(),
            ttlSeconds = 600
        )
        queueAndSend(message)
    }

    private suspend fun queueAndSend(message: MeshMessage) = withContext(ioDispatcher) {
        val dao = messageDao ?: return@withContext
        val crypto = cryptoManager ?: return@withContext

        val conversationId = message.receiverId ?: "broadcast"
        dao.upsert(
            MessageEntity(
                id = message.id,
                senderId = message.senderId,
                receiverId = message.receiverId,
                type = message.type.name,
                content = message.content,
                createdAt = message.createdAt,
                status = MessageDeliveryStatus.QUEUED.name,
                conversationId = conversationId
            )
        )

        conversationDao?.upsert(
            ConversationEntity(
                id = conversationId,
                peerId = message.receiverId,
                title = message.receiverId ?: "BROADCAST",
                lastMessagePreview = message.content.take(120),
                updatedAt = message.createdAt,
                unreadCount = 0
            )
        )

        val packet = MeshProtocol.encode(message)
        val encrypted = crypto.encrypt(packet)
        val success = transportSend(encrypted.cipherText)

        dao.updateStatus(
            message.id,
            if (success) MessageDeliveryStatus.SENT.name else MessageDeliveryStatus.FAILED.name
        )

        if (success) outgoingEvents.tryEmit(message)
    }

    private suspend fun simulatedRetrySend(payload: ByteArray): Boolean {
        var attempt = 0
        var backoff = 500L
        while (attempt < 4) {
            delay(backoff)
            if (payload.isNotEmpty()) return true
            attempt++
            backoff *= 2
        }
        return false
    }

    data class SosRecipientHistory(
        val id: String,
        val name: String,
        val status: String,
        val error: String? = null,
        val trusted: Boolean = false
    )
}
