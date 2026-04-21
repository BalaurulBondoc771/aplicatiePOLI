package com.blackoutlink.ui.power

import androidx.lifecycle.ViewModel
import com.blackoutlink.data.storage.SettingsStore
import kotlinx.coroutines.flow.StateFlow

data class PowerUiState(
    val batterySaverEnabled: Boolean = false,
    val estimatedRuntimeHours: Int = 0,
    val scanIntervalMs: Long = 1000L
)

class PowerViewModel(
    private val settingsStore: SettingsStore,
    private val estimatedRuntimeProvider: (Boolean) -> Int = { if (it) 16 else 9 }
) : ViewModel() {
    val batterySaverEnabled: StateFlow<Boolean> = settingsStore.batterySaverEnabled

    fun setBatterySaver(enabled: Boolean) {
        settingsStore.setBatterySaverEnabled(enabled)
    }

    fun setScanIntervalMs(value: Long) {
        settingsStore.setScanIntervalMs(value)
    }

    fun estimatedRuntime(enabled: Boolean): Int = estimatedRuntimeProvider(enabled)
}
