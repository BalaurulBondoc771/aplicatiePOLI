package com.blackoutlink.data.storage

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class SettingsStore(context: Context) {
    private val prefs = context.getSharedPreferences("blackout_link_prefs", Context.MODE_PRIVATE)

    private val _batterySaverEnabled = MutableStateFlow(prefs.getBoolean(KEY_BATTERY_SAVER, false))
    val batterySaverEnabled: StateFlow<Boolean> = _batterySaverEnabled.asStateFlow()

    private val _lowPowerBluetoothEnabled = MutableStateFlow(prefs.getBoolean(KEY_LOW_POWER_BLUETOOTH, false))
    val lowPowerBluetoothEnabled: StateFlow<Boolean> = _lowPowerBluetoothEnabled.asStateFlow()

    private val _grayscaleUiEnabled = MutableStateFlow(prefs.getBoolean(KEY_GRAYSCALE_UI, false))
    val grayscaleUiEnabled: StateFlow<Boolean> = _grayscaleUiEnabled.asStateFlow()

    private val _criticalTasksOnlyEnabled = MutableStateFlow(prefs.getBoolean(KEY_CRITICAL_TASKS_ONLY, false))
    val criticalTasksOnlyEnabled: StateFlow<Boolean> = _criticalTasksOnlyEnabled.asStateFlow()

    fun getDisplayName(): String = prefs.getString(KEY_DISPLAY_NAME, "OPERATOR_X") ?: "OPERATOR_X"
    fun setDisplayName(value: String) {
        prefs.edit().putString(KEY_DISPLAY_NAME, value.ifBlank { "OPERATOR_X" }).apply()
    }

    fun getStatusPreset(): String = prefs.getString(KEY_STATUS_PRESET, "SILENT / INCOGNITO") ?: "SILENT / INCOGNITO"
    fun setStatusPreset(value: String) {
        prefs.edit().putString(KEY_STATUS_PRESET, value.ifBlank { "SILENT / INCOGNITO" }).apply()
    }

    fun setBatterySaverEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_BATTERY_SAVER, enabled).apply()
        _batterySaverEnabled.value = enabled
    }

    fun isBatterySaverEnabled(): Boolean = _batterySaverEnabled.value

    fun isLowPowerBluetoothEnabled(): Boolean = _lowPowerBluetoothEnabled.value
    fun setLowPowerBluetoothEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_LOW_POWER_BLUETOOTH, enabled).apply()
        _lowPowerBluetoothEnabled.value = enabled
    }

    fun isGrayscaleUiEnabled(): Boolean = _grayscaleUiEnabled.value
    fun setGrayscaleUiEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_GRAYSCALE_UI, enabled).apply()
        _grayscaleUiEnabled.value = enabled
    }

    fun isCriticalTasksOnlyEnabled(): Boolean = _criticalTasksOnlyEnabled.value
    fun setCriticalTasksOnlyEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_CRITICAL_TASKS_ONLY, enabled).apply()
        _criticalTasksOnlyEnabled.value = enabled
    }

    fun getScanIntervalMs(): Long = prefs.getLong(KEY_SCAN_INTERVAL_MS, 1_000L)
    fun setScanIntervalMs(value: Long) {
        prefs.edit().putLong(KEY_SCAN_INTERVAL_MS, value).apply()
    }

    fun getBatteryPercentHint(): Int = prefs.getInt(KEY_BATTERY_PERCENT_HINT, 63)
    fun setBatteryPercentHint(value: Int) {
        prefs.edit().putInt(KEY_BATTERY_PERCENT_HINT, value.coerceIn(1, 100)).apply()
    }

    fun isBackgroundBeaconEnabled(): Boolean = prefs.getBoolean(KEY_BACKGROUND_BEACON_ENABLED, true)

    fun setBackgroundBeaconEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_BACKGROUND_BEACON_ENABLED, enabled).apply()
    }

    fun setPendingQuickStatus(status: String, expiresAtMs: Long, deviceName: String? = null) {
        prefs.edit()
            .putString(KEY_PENDING_QUICK_STATUS, status)
            .putLong(KEY_PENDING_QUICK_STATUS_EXPIRES_AT_MS, expiresAtMs)
            .putString(KEY_PENDING_QUICK_STATUS_DEVICE_NAME, deviceName)
            .apply()
    }

    fun getPendingQuickStatus(): String? = prefs.getString(KEY_PENDING_QUICK_STATUS, null)

    fun getPendingQuickStatusExpiresAtMs(): Long =
        prefs.getLong(KEY_PENDING_QUICK_STATUS_EXPIRES_AT_MS, 0L)

    fun getPendingQuickStatusDeviceName(): String? =
        prefs.getString(KEY_PENDING_QUICK_STATUS_DEVICE_NAME, null)

    fun clearPendingQuickStatus() {
        prefs.edit()
            .remove(KEY_PENDING_QUICK_STATUS)
            .remove(KEY_PENDING_QUICK_STATUS_EXPIRES_AT_MS)
            .remove(KEY_PENDING_QUICK_STATUS_DEVICE_NAME)
            .apply()
    }

    companion object {
        private const val KEY_BATTERY_SAVER = "battery_saver"
        private const val KEY_LOW_POWER_BLUETOOTH = "low_power_bluetooth"
        private const val KEY_GRAYSCALE_UI = "grayscale_ui"
        private const val KEY_CRITICAL_TASKS_ONLY = "critical_tasks_only"
        private const val KEY_DISPLAY_NAME = "display_name"
        private const val KEY_STATUS_PRESET = "status_preset"
        private const val KEY_SCAN_INTERVAL_MS = "scan_interval_ms"
        private const val KEY_BATTERY_PERCENT_HINT = "battery_percent_hint"
        private const val KEY_BACKGROUND_BEACON_ENABLED = "background_beacon_enabled"
        private const val KEY_PENDING_QUICK_STATUS = "pending_quick_status"
        private const val KEY_PENDING_QUICK_STATUS_EXPIRES_AT_MS = "pending_quick_status_expires_at_ms"
        private const val KEY_PENDING_QUICK_STATUS_DEVICE_NAME = "pending_quick_status_device_name"
    }
}
