package com.blackoutlink.data.storage

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "peers")
data class PeerEntity(
    @PrimaryKey val id: String,
    val name: String,
    val address: String,
    val status: String,
    val rssi: Int,
    val distanceMeters: Double,
    val lastSeenAt: Long,
    val trusted: Boolean,
    val relayCapable: Boolean,
    val updatedAt: Long
)
