package com.blackoutlink.data.security

import android.util.Base64
import android.util.Log
import kotlinx.coroutines.delay
import java.util.concurrent.ConcurrentHashMap

class E2ESessionManager(
    private val cryptoManager: CryptoManager = CryptoManager(),
    private val normalizePeerId: (String?) -> String?,
    private val loggerTag: String = "E2ESessionManager",
) {
    companion object {
        const val E2E_PREFIX = "BKE2"
    }

    data class HandshakeConfig(
        val waitMs: Long = 7_000L,
        val pollMs: Long = 100L,
        val resendMs: Long = 900L,
    )

    data class E2eEnvelope(
        val type: String,
        val partA: String,
        val partB: String? = null,
    )

    sealed interface IncomingPacketResult {
        data class HandshakeHelloReceived(
            val peerId: String,
            val ackPayload: ByteArray,
        ) : IncomingPacketResult

        data class HandshakeAckReceived(
            val peerId: String,
        ) : IncomingPacketResult

        data class DecryptedMessage(
            val peerId: String,
            val decryptedPayload: ByteArray,
        ) : IncomingPacketResult

        data class HandshakeRecoveryRequired(
            val peerId: String,
            val helloPayload: ByteArray,
        ) : IncomingPacketResult

        data class DecryptFailed(
            val peerId: String,
            val reason: String,
        ) : IncomingPacketResult

        data object NotE2E : IncomingPacketResult
    }

    private val sessionKeys = ConcurrentHashMap<String, ByteArray>()


    fun encodeHandshakeHello(): ByteArray {
        val pub = Base64.encodeToString(cryptoManager.getIdentityPublicKeyEncoded(), Base64.NO_WRAP)
        Log.d(loggerTag, "encodeHandshakeHello: HS1 sent")
        return "$E2E_PREFIX|HS1|$pub".encodeToByteArray()
    }


    fun encodeHandshakeAck(): ByteArray {
        val pub = Base64.encodeToString(cryptoManager.getIdentityPublicKeyEncoded(), Base64.NO_WRAP)
        Log.d(loggerTag, "encodeHandshakeAck: HS2 sent")
        return "$E2E_PREFIX|HS2|$pub".encodeToByteArray()
    }


    fun hasSession(peerId: String?): Boolean {
        val normalizedPeer = normalize(peerId) ?: return false
        val has = sessionKeys[normalizedPeer] != null
        Log.d(loggerTag, "hasSession($normalizedPeer) = $has")
        return has
    }

    fun pruneSessions(activePeerIds: Set<String>) {
        if (activePeerIds.isEmpty()) return
        val iterator = sessionKeys.keys.iterator()
        while (iterator.hasNext()) {
            val peerId = iterator.next()
            if (peerId !in activePeerIds) {
                iterator.remove()
            }
        }
    }

    fun encryptForPeer(peerId: String, plainPacket: ByteArray): ByteArray? {
        val normalizedPeer = normalize(peerId) ?: return null
        val sessionKey = sessionKeys[normalizedPeer] ?: return null
        val encrypted = cryptoManager.encryptWithSessionKey(plainPacket, sessionKey)
        return encodeEncryptedPayload(encrypted.iv, encrypted.cipherText)
    }


    suspend fun ensureSession(
        peerId: String,
        onSendHello: (String, ByteArray) -> Unit,
        config: HandshakeConfig = HandshakeConfig(),
    ): Boolean {
        val normalizedPeer = normalize(peerId) ?: return false
        if (sessionKeys[normalizedPeer] != null) {
            Log.d(loggerTag, "ensureSession: already exists for $normalizedPeer")
            return true
        }

        var waited = 0L
        var lastHelloAt = -config.resendMs
        while (waited < config.waitMs) {
            if (sessionKeys[normalizedPeer] != null) {
                Log.d(loggerTag, "ensureSession: session created for $normalizedPeer after $waited ms")
                return true
            }

            if ((waited - lastHelloAt) >= config.resendMs) {
                lastHelloAt = waited
                Log.d(loggerTag, "ensureSession: sending HS1 to $normalizedPeer at $waited ms")
                onSendHello(normalizedPeer, encodeHandshakeHello())
            }

            delay(config.pollMs)
            waited += config.pollMs
        }

        val ok = sessionKeys[normalizedPeer] != null
        Log.d(loggerTag, "ensureSession: session ${if (ok) "created" else "FAILED"} for $normalizedPeer after $waited ms")
        return ok
    }


    fun processIncomingPacket(peerId: String, payload: ByteArray): IncomingPacketResult {
        val normalizedPeer = normalize(peerId) ?: peerId
        val envelope = decodeEnvelope(payload) ?: return IncomingPacketResult.NotE2E

        when (envelope.type) {
            "HS1" -> Log.d(loggerTag, "HS1 received from $normalizedPeer")
            "HS2" -> Log.d(loggerTag, "HS2 received from $normalizedPeer")
            "MSG" -> Log.d(loggerTag, "MSG received from $normalizedPeer")
        }

        return when (envelope.type) {
            "HS1" -> {
                val remotePub = Base64.decode(envelope.partA, Base64.DEFAULT)
                val sessionKey = cryptoManager.deriveSessionKey(remotePub)
                sessionKeys[normalizedPeer] = sessionKey
                Log.d(loggerTag, "session created/refreshed for $normalizedPeer (HS1)")
                IncomingPacketResult.HandshakeHelloReceived(
                    peerId = normalizedPeer,
                    ackPayload = encodeHandshakeAck(),
                )
            }

            "HS2" -> {
                val remotePub = Base64.decode(envelope.partA, Base64.DEFAULT)
                val sessionKey = cryptoManager.deriveSessionKey(remotePub)
                sessionKeys[normalizedPeer] = sessionKey
                Log.d(loggerTag, "session created/refreshed for $normalizedPeer (HS2)")
                IncomingPacketResult.HandshakeAckReceived(peerId = normalizedPeer)
            }

            "MSG" -> {
                val sessionKey = sessionKeys[normalizedPeer]
                if (sessionKey == null) {
                    Log.w(loggerTag, "MSG received without session for $normalizedPeer — trigger handshake, save pending")
                    IncomingPacketResult.HandshakeRecoveryRequired(
                        peerId = normalizedPeer,
                        helloPayload = encodeHandshakeHello(),
                    )
                } else {
                    val iv = Base64.decode(envelope.partA, Base64.DEFAULT)
                    val cipher = Base64.decode(envelope.partB ?: "", Base64.DEFAULT)
                    val decryptedPacket = runCatching {
                        cryptoManager.decryptWithSessionKey(
                            payload = EncryptedPayload(iv = iv, cipherText = cipher),
                            sessionKey = sessionKey,
                        )
                    }.onFailure {
                        Log.w(
                            loggerTag,
                            "decrypt failed for $normalizedPeer: ${it.javaClass.simpleName}: ${it.message}"
                        )
                    }.getOrNull()

                    if (decryptedPacket == null) {
                        Log.w(loggerTag, "decrypt failed for $normalizedPeer (MSG)")
                        IncomingPacketResult.DecryptFailed(
                            peerId = normalizedPeer,
                            reason = "decrypt_failed",
                        )
                    } else {
                        Log.d(loggerTag, "decrypt success for $normalizedPeer (MSG)")
                        IncomingPacketResult.DecryptedMessage(
                            peerId = normalizedPeer,
                            decryptedPayload = decryptedPacket,
                        )
                    }
                }
            }

            else -> IncomingPacketResult.NotE2E
        }
    }

    private fun normalize(peerId: String?): String? {
        return normalizePeerId(peerId)?.takeIf { it.isNotBlank() }
    }

    private fun encodeEncryptedPayload(iv: ByteArray, cipherText: ByteArray): ByteArray {
        val ivPart = Base64.encodeToString(iv, Base64.NO_WRAP)
        val dataPart = Base64.encodeToString(cipherText, Base64.NO_WRAP)
        return "$E2E_PREFIX|MSG|$ivPart|$dataPart".encodeToByteArray()
    }

    private fun decodeEnvelope(payload: ByteArray): E2eEnvelope? {
        val text = runCatching { payload.decodeToString() }.getOrNull() ?: return null
        if (!text.startsWith("$E2E_PREFIX|")) return null
        val parts = text.split('|')
        if (parts.size < 3) return null
        return E2eEnvelope(
            type = parts[1].uppercase(),
            partA = parts[2],
            partB = parts.getOrNull(3),
        )
    }
}