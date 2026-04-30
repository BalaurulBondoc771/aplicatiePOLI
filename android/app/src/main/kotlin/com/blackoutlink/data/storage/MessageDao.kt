package com.blackoutlink.data.storage

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface MessageDao {
    @Query("SELECT * FROM messages ORDER BY createdAt ASC")
    fun observeAll(): Flow<List<MessageEntity>>

    @Query("SELECT * FROM messages WHERE conversationId = :conversationId ORDER BY createdAt ASC")
    fun observeByConversation(conversationId: String): Flow<List<MessageEntity>>

    @Query("SELECT * FROM messages ORDER BY createdAt ASC")
    suspend fun getAll(): List<MessageEntity>

    @Query("SELECT * FROM messages WHERE conversationId = :conversationId ORDER BY createdAt ASC")
    suspend fun getByConversation(conversationId: String): List<MessageEntity>

    @Query(
        "SELECT * FROM messages " +
            "WHERE senderId = :senderId " +
            "AND receiverId = :receiverId " +
            "AND type = 'TEXT' " +
            "AND status = :status " +
            "ORDER BY createdAt ASC LIMIT :limit"
    )
    suspend fun getQueuedOutgoingForPeer(
        senderId: String,
        receiverId: String,
        status: String = "QUEUED",
        limit: Int = 25
    ): List<MessageEntity>

    @Query(
        "SELECT * FROM messages " +
            "WHERE senderId = :senderId " +
            "AND receiverId = :receiverId " +
            "AND type = 'SOS' " +
            "AND status = :status " +
            "ORDER BY createdAt ASC LIMIT :limit"
    )
    suspend fun getQueuedSosForPeer(
        senderId: String,
        receiverId: String,
        status: String = "QUEUED",
        limit: Int = 10
    ): List<MessageEntity>

    @Query(
        "SELECT * FROM messages " +
            "WHERE senderId = :senderId " +
            "AND receiverId = :receiverId " +
            "AND status = :status " +
            "AND content LIKE :contentLike " +
            "ORDER BY createdAt ASC LIMIT :limit"
    )
    suspend fun getPendingEncryptedIncomingForPeer(
        senderId: String,
        receiverId: String,
        status: String = "QUEUED",
        contentLike: String = "PENDING_E2E:%",
        limit: Int = 25
    ): List<MessageEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: MessageEntity)

    @Query("UPDATE messages SET status = :status WHERE id = :messageId")
    suspend fun updateStatus(messageId: String, status: String)

    @Query("DELETE FROM messages WHERE id = :messageId")
    suspend fun deleteById(messageId: String)
}
