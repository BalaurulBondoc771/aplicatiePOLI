package com.example.blackoutapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.le.AdvertiseSettings
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.Base64
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.room.Room
import com.blackoutlink.data.bluetooth.BleScanner
import com.blackoutlink.data.bluetooth.BleTransport
import com.blackoutlink.data.protocol.MeshProtocol
import com.blackoutlink.data.security.CryptoManager
import com.blackoutlink.data.security.E2ESessionManager
import com.blackoutlink.data.storage.BlackoutDatabase
import com.blackoutlink.data.storage.ConversationEntity
import com.blackoutlink.data.storage.MessageEntity
import com.blackoutlink.data.storage.SettingsStore
import com.blackoutlink.domain.model.MessageDeliveryStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

class MeshBeaconService : Service() {
    companion object {
        private const val CHANNEL_ID = "blackout_mesh_beacon"
        private const val NOTIFICATION_ID = 4107
        private const val MSG_NOTIFICATION_ID = 4108
        private const val TAG = "MeshBeaconService"
        private const val PENDING_E2E_PREFIX = "PENDING_E2E:"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private enum class BackgroundPacketKind {
        SOS,
        QUICK_STATUS,
        PLAINTEXT_TEXT,
        E2E_ENCRYPTED,
        UNKNOWN,
    }

    private lateinit var bleTransport: BleTransport
    private lateinit var bleScanner: BleScanner
    private lateinit var settingsStore: SettingsStore
    private lateinit var database: BlackoutDatabase
    private val cryptoManager = CryptoManager()
    private val e2eSessionManager = E2ESessionManager(
        cryptoManager = cryptoManager,
        normalizePeerId = { peerId -> peerId?.uppercase()?.trim()?.takeIf { it.isNotBlank() } },
        loggerTag = TAG,
    )
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var receiveJob: Job? = null
    private val localNodeId: String by lazy {
        (Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
            ?.uppercase()
            ?.takeIf { it.isNotBlank() }) ?: "LOCAL_NODE"
    }

    override fun onCreate() {
        super.onCreate()
        try {
            isRunning = true
            bleTransport = BleTransport(applicationContext)
            bleScanner = BleScanner(applicationContext)
            settingsStore = SettingsStore(applicationContext)
            database = Room.databaseBuilder(
                applicationContext,
                BlackoutDatabase::class.java,
                "blackout_db"
            ).addMigrations(BlackoutDatabase.MIGRATION_1_2).build()
            createNotificationChannel()
            startForeground(NOTIFICATION_ID, buildNotification())
            startBeacon()
        } catch (t: Throwable) {
            Log.e(TAG, "onCreate failed: ${t.message}", t)
            isRunning = false
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val enabled = try {
            settingsStore.isBackgroundBeaconEnabled()
        } catch (t: Throwable) {
            Log.w(TAG, "settings read failed: ${t.message}")
            false
        }
        if (!enabled) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            startBeacon()
        } catch (t: Throwable) {
            Log.e(TAG, "startBeacon failed: ${t.message}", t)
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        receiveJob?.cancel()
        try {
            bleScanner.stopScan()
        } catch (t: Throwable) {
            Log.w(TAG, "stopScan failed: ${t.message}")
        }
        try {
            bleTransport.stopAdvertising()
            bleTransport.stopServer()
            bleTransport.destroy()
        } catch (t: Throwable) {
            Log.w(TAG, "cleanup failed: ${t.message}")
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startBeacon() {
        val displayName = settingsStore.getDisplayName()
        val statusPreset = settingsStore.getStatusPreset()
        val batterySaver = settingsStore.isBatterySaverEnabled()
        bleTransport.configureIdentity(displayName)
        bleTransport.configurePeerMetadata(
            statusPresetCode = mapStatusPresetCode(statusPreset),
            batterySaverEnabled = batterySaver,
            meshRoleCode = mapMeshRoleCode(statusPreset)
        )
        bleTransport.configureAdvertiseProfile(
            AdvertiseSettings.ADVERTISE_MODE_LOW_POWER,
            AdvertiseSettings.ADVERTISE_TX_POWER_LOW
        )
        bleTransport.startServer()
        bleTransport.startAdvertising()
        bleScanner.startScan()
        startReceiving()
    }

    private fun startReceiving() {
        receiveJob?.cancel()
        receiveJob = scope.launch {
            bleTransport.incomingBytes.collect { packet ->
                try {
                    val peerId = packet.sourceAddress.uppercase().trim()
                    when (val e2eResult = e2eSessionManager.processIncomingPacket(peerId, packet.payload)) {
                        is E2ESessionManager.IncomingPacketResult.HandshakeHelloReceived -> {
                            sendWithRetry(e2eResult.peerId, e2eResult.ackPayload)
                            Log.i(TAG, "background HS1 handled for ${e2eResult.peerId}")
                            return@collect
                        }

                        is E2ESessionManager.IncomingPacketResult.HandshakeAckReceived -> {
                            Log.i(TAG, "background HS2 handled for ${e2eResult.peerId}")
                            return@collect
                        }

                        is E2ESessionManager.IncomingPacketResult.DecryptedMessage -> {
                            val message = MeshProtocol.decode(e2eResult.decryptedPayload)
                            persistIncomingMessage(
                                peerId = e2eResult.peerId,
                                messageId = message.id,
                                receiverId = message.receiverId,
                                type = message.type.name,
                                content = message.content,
                                createdAt = message.createdAt,
                                preview = message.content
                            )
                            showMessageNotification(message.content)
                            return@collect
                        }

                        is E2ESessionManager.IncomingPacketResult.HandshakeRecoveryRequired -> {
                            Log.w(TAG, "background decrypt pending for ${e2eResult.peerId}: missing session")
                            sendWithRetry(e2eResult.peerId, e2eResult.helloPayload)
                            persistPendingEncrypted(e2eResult.peerId, packet.payload)
                            showMessageNotification("Encrypted message pending sync")
                            return@collect
                        }

                        is E2ESessionManager.IncomingPacketResult.DecryptFailed -> {
                            Log.w(TAG, "background decrypt failed for ${e2eResult.peerId}: ${e2eResult.reason}")
                            persistPendingEncrypted(e2eResult.peerId, packet.payload)
                            showMessageNotification("Encrypted message pending sync")
                            return@collect
                        }

                        E2ESessionManager.IncomingPacketResult.NotE2E -> Unit
                    }

                    val message = MeshProtocol.decode(packet.payload)
                    when (classifyPlaintextMessage(message.type.name, message.content)) {
                        BackgroundPacketKind.SOS -> {
                            persistIncomingMessage(
                                peerId = peerId,
                                messageId = message.id,
                                receiverId = message.receiverId,
                                type = message.type.name,
                                content = message.content,
                                createdAt = message.createdAt,
                                preview = message.content
                            )
                            showMessageNotification(message.content)
                        }

                        BackgroundPacketKind.QUICK_STATUS -> {
                            persistIncomingMessage(
                                peerId = peerId,
                                messageId = message.id,
                                receiverId = message.receiverId,
                                type = message.type.name,
                                content = message.content,
                                createdAt = message.createdAt,
                                preview = "Quick status received"
                            )
                            showMessageNotification("Quick status received")
                        }

                        BackgroundPacketKind.PLAINTEXT_TEXT,
                        BackgroundPacketKind.E2E_ENCRYPTED -> {
                            persistIncomingMessage(
                                peerId = peerId,
                                messageId = message.id,
                                receiverId = message.receiverId,
                                type = message.type.name,
                                content = message.content,
                                createdAt = message.createdAt,
                                preview = message.content
                            )
                            showMessageNotification(message.content)
                        }

                        BackgroundPacketKind.UNKNOWN -> {
                            // Unknown packet kinds are ignored until the protocol has an explicit handler.
                        }
                    }
                } catch (_: Throwable) {
                    // Malformed packet — ignore.
                }
            }
        }
    }

    private suspend fun sendWithRetry(
        peerId: String,
        payload: ByteArray,
        attempts: Int = 3,
        retryDelayMs: Long = 350L,
    ): Boolean {
        var attempt = 0
        while (attempt < attempts) {
            if (bleTransport.sendTo(peerId, payload)) {
                return true
            }
            attempt++
            if (attempt < attempts) {
                kotlinx.coroutines.delay(retryDelayMs)
            }
        }
        return false
    }

    private suspend fun persistIncomingMessage(
        peerId: String,
        messageId: String,
        receiverId: String?,
        type: String,
        content: String,
        createdAt: Long,
        preview: String,
    ) {
        val now = System.currentTimeMillis()
        withContext(Dispatchers.IO) {
            database.messageDao().upsert(
                MessageEntity(
                    id = messageId,
                    senderId = peerId,
                    receiverId = receiverId,
                    type = type,
                    content = content,
                    createdAt = createdAt,
                    status = MessageDeliveryStatus.DELIVERED.name,
                    conversationId = peerId
                )
            )
            database.conversationDao().upsert(
                ConversationEntity(
                    id = peerId,
                    peerId = peerId,
                    title = peerId,
                    lastMessagePreview = preview.take(120),
                    updatedAt = now,
                    unreadCount = 1
                )
            )
        }
    }

    private suspend fun persistPendingEncrypted(peerId: String, rawPayload: ByteArray) {
        val createdAt = System.currentTimeMillis()
        val encodedPayload = Base64.encodeToString(rawPayload, Base64.NO_WRAP)
        withContext(Dispatchers.IO) {
            database.messageDao().upsert(
                MessageEntity(
                    id = UUID.randomUUID().toString(),
                    senderId = peerId,
                    receiverId = localNodeId,
                    type = "TEXT",
                    content = "$PENDING_E2E_PREFIX$encodedPayload",
                    createdAt = createdAt,
                    status = MessageDeliveryStatus.QUEUED.name,
                    conversationId = peerId
                )
            )
            database.conversationDao().upsert(
                ConversationEntity(
                    id = peerId,
                    peerId = peerId,
                    title = peerId,
                    lastMessagePreview = "Encrypted message pending sync",
                    updatedAt = createdAt,
                    unreadCount = 1
                )
            )
        }
    }

    private fun classifyPlaintextMessage(type: String, content: String): BackgroundPacketKind {
        if (type.equals("SOS", ignoreCase = true)) {
            return BackgroundPacketKind.SOS
        }
        if (content.startsWith("STATUS:")) {
            return BackgroundPacketKind.QUICK_STATUS
        }
        if (type.startsWith("STATUS_", ignoreCase = true)) {
            return BackgroundPacketKind.QUICK_STATUS
        }
        if (type.equals("TEXT", ignoreCase = true)) {
            return BackgroundPacketKind.PLAINTEXT_TEXT
        }
        return BackgroundPacketKind.UNKNOWN
    }

    private fun showMessageNotification(preview: String) {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("New message")
            .setContentText(preview.take(80))
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        manager.notify(MSG_NOTIFICATION_ID, notification)
    }

    private fun mapStatusPresetCode(preset: String): String {
        return when (preset.trim().uppercase()) {
            "FIELD READY" -> "FR"
            "OPEN BROADCAST" -> "OB"
            "EMERGENCY WATCH" -> "EW"
            else -> "SI"
        }
    }

    private fun mapMeshRoleCode(preset: String): String {
        return when (preset.trim().uppercase()) {
            "SILENT / INCOGNITO" -> "S"
            "EMERGENCY WATCH" -> "W"
            else -> "R"
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Blackout mesh active")
            .setContentText("Device remains discoverable while the app is closed.")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Blackout mesh beacon",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Keeps the local mesh beacon active in the background."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }
}
