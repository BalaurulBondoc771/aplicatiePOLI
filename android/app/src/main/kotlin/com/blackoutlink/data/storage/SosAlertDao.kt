package com.blackoutlink.data.storage

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

@Dao
interface SosAlertDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: SosAlertEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertRecipients(entities: List<EmergencyRecipientEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAlertRecipients(entities: List<SosAlertRecipientCrossRef>)

    @Query("SELECT * FROM sos_alerts ORDER BY createdAt DESC LIMIT :limit")
    suspend fun getHistory(limit: Int = 50): List<SosAlertEntity>

    @Transaction
    @Query("SELECT * FROM sos_alerts ORDER BY createdAt DESC LIMIT :limit")
    suspend fun getHistoryWithRecipients(limit: Int = 50): List<SosAlertWithRecipients>

    @Query("SELECT * FROM sos_alerts ORDER BY createdAt DESC LIMIT :limit")
    fun observeHistory(limit: Int = 50): Flow<List<SosAlertEntity>>
}
