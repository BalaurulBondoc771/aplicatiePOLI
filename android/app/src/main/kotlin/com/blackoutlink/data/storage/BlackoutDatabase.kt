package com.blackoutlink.data.storage

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [
        MessageEntity::class,
        ConversationEntity::class,
        PeerEntity::class,
        SosAlertEntity::class,
        EmergencyRecipientEntity::class,
        SosAlertRecipientCrossRef::class,
    ],
    version = 2,
    exportSchema = false,
)
abstract class BlackoutDatabase : RoomDatabase() {
    abstract fun messageDao(): MessageDao
    abstract fun conversationDao(): ConversationDao
    abstract fun peerDao(): PeerDao
    abstract fun sosAlertDao(): SosAlertDao

    companion object {
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    "ALTER TABLE messages ADD COLUMN conversationId TEXT NOT NULL DEFAULT 'default_conversation'"
                )

                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS conversations (" +
                        "id TEXT NOT NULL, " +
                        "peerId TEXT, " +
                        "title TEXT NOT NULL, " +
                        "lastMessagePreview TEXT NOT NULL, " +
                        "updatedAt INTEGER NOT NULL, " +
                        "unreadCount INTEGER NOT NULL, " +
                        "PRIMARY KEY(id))"
                )

                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS peers (" +
                        "id TEXT NOT NULL, " +
                        "name TEXT NOT NULL, " +
                        "address TEXT NOT NULL, " +
                        "status TEXT NOT NULL, " +
                        "rssi INTEGER NOT NULL, " +
                        "distanceMeters REAL NOT NULL, " +
                        "lastSeenAt INTEGER NOT NULL, " +
                        "trusted INTEGER NOT NULL, " +
                        "relayCapable INTEGER NOT NULL, " +
                        "updatedAt INTEGER NOT NULL, " +
                        "PRIMARY KEY(id))"
                )

                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS sos_alerts (" +
                        "id TEXT NOT NULL, " +
                        "createdAt INTEGER NOT NULL, " +
                        "latitude REAL NOT NULL, " +
                        "longitude REAL NOT NULL, " +
                        "accuracyMeters REAL NOT NULL, " +
                        "sentCount INTEGER NOT NULL, " +
                        "deliveredCount INTEGER NOT NULL, " +
                        "failedCount INTEGER NOT NULL, " +
                        "status TEXT NOT NULL, " +
                        "error TEXT, " +
                        "PRIMARY KEY(id))"
                )

                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS emergency_recipients (" +
                        "id TEXT NOT NULL, " +
                        "displayName TEXT NOT NULL, " +
                        "channelType TEXT NOT NULL, " +
                        "trusted INTEGER NOT NULL, " +
                        "isPrimary INTEGER NOT NULL, " +
                        "lastUsedAt INTEGER, " +
                        "PRIMARY KEY(id))"
                )

                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS sos_alert_recipients (" +
                        "sosAlertId TEXT NOT NULL, " +
                        "recipientId TEXT NOT NULL, " +
                        "deliveryStatus TEXT NOT NULL, " +
                        "error TEXT, " +
                        "PRIMARY KEY(sosAlertId, recipientId))"
                )

                db.execSQL("CREATE INDEX IF NOT EXISTS index_messages_conversationId ON messages(conversationId)")
                db.execSQL("CREATE INDEX IF NOT EXISTS index_peers_lastSeenAt ON peers(lastSeenAt)")
                db.execSQL("CREATE INDEX IF NOT EXISTS index_sos_alerts_createdAt ON sos_alerts(createdAt)")
            }
        }
    }
}
