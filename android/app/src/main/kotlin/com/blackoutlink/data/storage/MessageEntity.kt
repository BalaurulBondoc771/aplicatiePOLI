package com.blackoutlink.data.storage

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "messages")
data class MessageEntity(
    @PrimaryKey val id: String,
    val senderId: String,
    val receiverId: String?,
    val type: String,
    val content: String,
    val createdAt: Long,
    val status: String,
    val conversationId: String = "default_conversation"
)
