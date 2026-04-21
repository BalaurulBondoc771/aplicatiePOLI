package com.blackoutlink.data.storage

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "conversations")
data class ConversationEntity(
    @PrimaryKey val id: String,
    val peerId: String?,
    val title: String,
    val lastMessagePreview: String,
    val updatedAt: Long,
    val unreadCount: Int = 0
)
