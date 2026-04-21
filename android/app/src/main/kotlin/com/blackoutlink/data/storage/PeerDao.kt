package com.blackoutlink.data.storage

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface PeerDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<PeerEntity>)

    @Query("SELECT * FROM peers ORDER BY lastSeenAt DESC LIMIT :limit")
    suspend fun getRecent(limit: Int = 20): List<PeerEntity>

    @Query("SELECT * FROM peers ORDER BY lastSeenAt DESC LIMIT :limit")
    fun observeRecent(limit: Int = 20): Flow<List<PeerEntity>>

    @Query("UPDATE peers SET trusted = :trusted WHERE id = :peerId")
    suspend fun markTrusted(peerId: String, trusted: Boolean)

    @Query("SELECT id FROM peers WHERE trusted = 1")
    suspend fun getTrustedPeerIds(): List<String>
}
