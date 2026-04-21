package com.blackoutlink.data.storage

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "sos_alerts")
data class SosAlertEntity(
    @PrimaryKey val id: String,
    val createdAt: Long,
    val latitude: Double,
    val longitude: Double,
    val accuracyMeters: Float,
    val sentCount: Int,
    val deliveredCount: Int,
    val failedCount: Int,
    val status: String,
    val error: String?
)
