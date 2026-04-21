package com.blackoutlink

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.blackoutlink.data.repository.MeshRepository
import com.blackoutlink.data.storage.BlackoutDatabase
import com.blackoutlink.domain.model.MessageDeliveryStatus
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class MeshRepositoryIntegrationTests {

    private lateinit var db: BlackoutDatabase
    private lateinit var fakeScanner: FakeMeshScanner

    @Before
    fun setup() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        db = Room.inMemoryDatabaseBuilder(context, BlackoutDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        fakeScanner = FakeMeshScanner()
    }

    @After
    fun tearDown() {
        db.close()
    }

    @Test
    fun repository_saveQueuedMessage_thenMarkSent() = runTest {
        val repo = MeshRepository(
            bleScanner = fakeScanner,
            messageDao = db.messageDao(),
            conversationDao = db.conversationDao(),
            peerDao = db.peerDao(),
            sosAlertDao = db.sosAlertDao(),
            cryptoManager = PassThroughCrypto(),
            ioDispatcher = StandardTestDispatcher(testScheduler),
            transportSend = { true }
        )

        repo.sendTextMessage(senderId = "self", receiverId = "peer-1", content = "ping")

        val stored = db.messageDao().observeAll().first()
        assertEquals(1, stored.size)
        assertEquals(MessageDeliveryStatus.SENT.name, stored.first().status)
    }

    @Test
    fun repository_saveQueuedMessage_thenMarkFailed() = runTest {
        val repo = MeshRepository(
            bleScanner = fakeScanner,
            messageDao = db.messageDao(),
            conversationDao = db.conversationDao(),
            peerDao = db.peerDao(),
            sosAlertDao = db.sosAlertDao(),
            cryptoManager = PassThroughCrypto(),
            ioDispatcher = StandardTestDispatcher(testScheduler),
            transportSend = { false }
        )

        repo.sendTextMessage(senderId = "self", receiverId = "peer-2", content = "ping")

        val stored = db.messageDao().observeAll().first()
        assertEquals(1, stored.size)
        assertEquals(MessageDeliveryStatus.FAILED.name, stored.first().status)
    }

    @Test
    fun meshPeers_staleCleanup_likeFlow_excludesOldEntriesInRecipientLogic() {
        val now = 500_000L
        val resolver = com.blackoutlink.domain.usecase.QuickStatusRecipientResolver(staleMs = 15_000)
        val oldPeer = com.blackoutlink.domain.model.PeerDevice(
            id = "stale",
            name = "Stale",
            address = "00:11",
            rssi = -90,
            estimatedDistanceMeters = 50.0,
            status = com.blackoutlink.domain.model.PeerStatus.CONNECTED,
            lastSeenAt = now - 50_000
        )
        val freshPeer = oldPeer.copy(id = "fresh", lastSeenAt = now - 1000)

        val resolved = resolver.resolve(listOf(oldPeer, freshPeer), now)

        assertEquals(1, resolved.size)
        assertEquals("fresh", resolved.first().id)
    }

    @Test
    fun batterySaver_changesScannerConfig() {
        val repo = MeshRepository(
            bleScanner = fakeScanner,
            cryptoManager = PassThroughCrypto(),
            messageDao = db.messageDao(),
            ioDispatcher = kotlinx.coroutines.Dispatchers.Unconfined
        )

        repo.setLowPowerBluetoothEnabled(enabled = true, scanIntervalMs = 120_000L)

        assertTrue(fakeScanner.lastLowPowerEnabled == true)
        assertEquals(120_000L, fakeScanner.lastRefreshIntervalMs)

        repo.setLowPowerBluetoothEnabled(enabled = false, scanIntervalMs = 5_000L)

        assertFalse(fakeScanner.lastLowPowerEnabled == true)
        assertEquals(5_000L, fakeScanner.lastRefreshIntervalMs)
    }
}
