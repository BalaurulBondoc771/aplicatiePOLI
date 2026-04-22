package com.blackoutlink.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.blackoutlink.data.repository.MeshRepository
import com.blackoutlink.domain.model.HomeUiState
import com.blackoutlink.domain.model.SystemState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import org.json.JSONObject

class HomeViewModel(
    private val repository: MeshRepository,
    private val batteryReader: () -> Int = { 84 }
) : ViewModel() {

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        observeState()
        repository.startScan()
    }

    private fun observeState() {
        viewModelScope.launch {
            combine(
                repository.peers,
                repository.meshStats,
                repository.batterySaverEnabled,
                repository.scanInProgress
            ) { peers, stats, batterySaver, scanInProgress ->
                HomeUiState(
                    systemState = when {
                        !repository.isBluetoothEnabled() -> SystemState.OFFLINE
                        peers.isEmpty() -> SystemState.DEGRADED
                        else -> SystemState.OPERATIONAL
                    },
                    batteryPercent = batteryReader(),
                    batterySaverEnabled = batterySaver,
                    peers = peers,
                    meshStats = stats,
                    isBluetoothEnabled = repository.isBluetoothEnabled(),
                    scanInProgress = scanInProgress
                )
            }.collect {
                _uiState.value = it
            }
        }

        viewModelScope.launch {
            repository.locationUpdates().collect { location ->
                _uiState.value = _uiState.value.copy(currentLocation = location)
            }
        }
    }

    fun onToggleBatterySaver() {
        repository.setBatterySaverEnabled(!_uiState.value.batterySaverEnabled)
    }

    fun onRefreshScan() {
        repository.stopScan()
        repository.startScan()
    }

    fun onActivateSos() {
        viewModelScope.launch {
            // Keep payload minimal; coordinator/repository handles actual routing.
            repository.sendSos(
                senderId = "LOCAL_NODE",
                payload = JSONObject(
                    mapOf(
                        "type" to "manual_sos",
                        "timestamp" to System.currentTimeMillis()
                    )
                ).toString()
            )
        }
    }

    override fun onCleared() {
        repository.stopScan()
        super.onCleared()
    }
}
