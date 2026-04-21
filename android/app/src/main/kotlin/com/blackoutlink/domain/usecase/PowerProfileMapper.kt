package com.blackoutlink.domain.usecase

data class PowerProfile(
    val lowPowerBluetoothEnabled: Boolean,
    val scanIntervalMs: Int,
    val refreshIntervalMs: Long,
    val scanMode: String
)

class PowerProfileMapper {
    fun map(lowPowerBluetoothEnabled: Boolean, scanIntervalMs: Int): PowerProfile {
        return if (lowPowerBluetoothEnabled) {
            PowerProfile(
                lowPowerBluetoothEnabled = true,
                scanIntervalMs = 120_000,
                refreshIntervalMs = 120_000L,
                scanMode = "LOW_POWER"
            )
        } else {
            PowerProfile(
                lowPowerBluetoothEnabled = false,
                scanIntervalMs = scanIntervalMs,
                refreshIntervalMs = scanIntervalMs.toLong(),
                scanMode = "LOW_LATENCY"
            )
        }
    }
}
