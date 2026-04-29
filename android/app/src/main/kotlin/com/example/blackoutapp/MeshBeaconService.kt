package com.example.blackoutapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.le.AdvertiseSettings
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.blackoutlink.data.bluetooth.BleTransport
import com.blackoutlink.data.storage.SettingsStore

class MeshBeaconService : Service() {
    companion object {
        private const val CHANNEL_ID = "blackout_mesh_beacon"
        private const val NOTIFICATION_ID = 4107

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private lateinit var bleTransport: BleTransport
    private lateinit var settingsStore: SettingsStore

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        bleTransport = BleTransport(applicationContext)
        settingsStore = SettingsStore(applicationContext)
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        startBeacon()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!settingsStore.isBackgroundBeaconEnabled()) {
            stopSelf()
            return START_NOT_STICKY
        }
        startBeacon()
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        bleTransport.stopAdvertising()
        bleTransport.stopServer()
        bleTransport.destroy()
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
