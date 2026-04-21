package com.blackoutlink

import com.blackoutlink.data.protocol.MeshProtocol
import com.blackoutlink.data.security.CryptoManager
import com.blackoutlink.domain.model.LocationSnapshot
import com.blackoutlink.domain.model.MeshMessage
import com.blackoutlink.domain.model.MessageType
import com.blackoutlink.domain.model.PeerDevice
import com.blackoutlink.domain.model.PeerStatus
import com.blackoutlink.domain.usecase.LocationFallbackResolver
import com.blackoutlink.domain.usecase.MessageValidationUseCase
import com.blackoutlink.domain.usecase.PowerProfileMapper
import com.blackoutlink.domain.usecase.QuickStatusRecipientResolver
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MeshProtocolCryptoAndUseCaseTests {

    @Test
    fun protocol_encodeDecode_roundTrip() {
        val original = MeshMessage(
            id = "m1",
            senderId = "node-a",
            receiverId = "node-b",
            type = MessageType.TEXT,
            content = "hello",
            createdAt = 1234L,
            ttlSeconds = 45,
            hopCount = 1,
            requiresAck = false
        )

        val bytes = MeshProtocol.encode(original)
        val decoded = MeshProtocol.decode(bytes)

        assertEquals(original, decoded)
    }

    @Test
    fun crypto_encryptDecrypt_roundTrip() {
        val crypto = CryptoManager()
        val payload = "BLACKOUT-LINK".encodeToByteArray()

        val encrypted = crypto.encrypt(payload)
        val decrypted = crypto.decrypt(encrypted)

        assertNotEquals(String(payload), String(encrypted.cipherText))
        assertTrue(encrypted.iv.isNotEmpty())
        assertEquals(String(payload), String(decrypted))
    }

    @Test
    fun sendMessage_validation_rejectsBlankDraft() {
        val validator = MessageValidationUseCase()

        val result = validator.validateDraft("   ")

        assertFalse(result.valid)
        assertEquals("empty_draft", result.errorCode)
    }

    @Test
    fun quickStatus_recipientResolution_prefersTrustedFreshPeers() {
        val now = 100_000L
        val resolver = QuickStatusRecipientResolver(staleMs = 15_000L)
        val peers = listOf(
            PeerDevice(
                id = "a",
                name = "A",
                address = "AA",
                rssi = -50,
                estimatedDistanceMeters = 1.0,
                status = PeerStatus.CONNECTED,
                lastSeenAt = now - 1000,
                trusted = true
            ),
            PeerDevice(
                id = "b",
                name = "B",
                address = "BB",
                rssi = -45,
                estimatedDistanceMeters = 1.5,
                status = PeerStatus.SCANNING,
                lastSeenAt = now - 500,
                trusted = false
            ),
            PeerDevice(
                id = "c",
                name = "C",
                address = "CC",
                rssi = -60,
                estimatedDistanceMeters = 2.0,
                status = PeerStatus.CONNECTED,
                lastSeenAt = now - 20_000,
                trusted = true
            )
        )

        val recipients = resolver.resolve(peers, now)

        assertEquals(1, recipients.size)
        assertEquals("a", recipients.first().id)
    }

    @Test
    fun sos_locationFallback_usesLastKnownWhenCurrentMissing() {
        val resolver = LocationFallbackResolver()
        val lastKnown = LocationSnapshot(
            latitude = 44.4,
            longitude = 26.1,
            accuracyMeters = 12f,
            timestamp = 999L
        )

        val result = resolver.resolve(current = null, lastKnown = lastKnown)

        assertTrue(result.usedFallback)
        assertNotNull(result.location)
        assertEquals(44.4, result.location?.latitude ?: 0.0, 0.0001)
    }

    @Test
    fun powerProfile_mapping_changesScannerProfile() {
        val mapper = PowerProfileMapper()

        val lowPower = mapper.map(lowPowerBluetoothEnabled = true, scanIntervalMs = 1000)
        val lowLatency = mapper.map(lowPowerBluetoothEnabled = false, scanIntervalMs = 3000)

        assertEquals(120_000, lowPower.scanIntervalMs)
        assertEquals("LOW_POWER", lowPower.scanMode)
        assertEquals(3000, lowLatency.scanIntervalMs)
        assertEquals("LOW_LATENCY", lowLatency.scanMode)
    }
}
