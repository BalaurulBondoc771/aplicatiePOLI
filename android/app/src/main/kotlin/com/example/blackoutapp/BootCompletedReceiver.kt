package com.example.blackoutapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import com.blackoutlink.data.storage.SettingsStore

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val settingsStore = SettingsStore(context.applicationContext)
        if (!settingsStore.isBackgroundBeaconEnabled()) return
        val serviceIntent = Intent(context, MeshBeaconService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
