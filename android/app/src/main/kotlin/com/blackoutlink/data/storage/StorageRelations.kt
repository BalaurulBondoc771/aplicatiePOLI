package com.blackoutlink.data.storage

import androidx.room.Embedded
import androidx.room.Junction
import androidx.room.Relation

data class ConversationWithMessages(
    @Embedded val conversation: ConversationEntity,
    @Relation(
        parentColumn = "id",
        entityColumn = "conversationId"
    )
    val messages: List<MessageEntity>
)

data class SosAlertWithRecipients(
    @Embedded val alert: SosAlertEntity,
    @Relation(
        parentColumn = "id",
        entity = EmergencyRecipientEntity::class,
        entityColumn = "id",
        associateBy = Junction(
            value = SosAlertRecipientCrossRef::class,
            parentColumn = "sosAlertId",
            entityColumn = "recipientId"
        )
    )
    val recipients: List<EmergencyRecipientEntity>
)
