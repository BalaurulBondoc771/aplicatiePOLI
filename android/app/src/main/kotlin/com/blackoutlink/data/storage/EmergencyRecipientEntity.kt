package com.blackoutlink.data.storage

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "emergency_recipients")
data class EmergencyRecipientEntity(
    @PrimaryKey val id: String,
    val displayName: String,
    val channelType: String,
    val trusted: Boolean,
    val isPrimary: Boolean,
    val lastUsedAt: Long?
)

@Entity(
    tableName = "sos_alert_recipients",
    primaryKeys = ["sosAlertId", "recipientId"],
    indices = [Index("recipientId")]
)
data class SosAlertRecipientCrossRef(
    val sosAlertId: String,
    val recipientId: String,
    val deliveryStatus: String,
    val error: String?
)
