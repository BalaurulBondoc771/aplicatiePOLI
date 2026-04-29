package com.blackoutlink.data.security

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.spec.ECGenParameterSpec
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

data class EncryptedPayload(
    val iv: ByteArray,
    val cipherText: ByteArray
)

class CryptoManager : PayloadCrypto {
    private val keyStore: KeyStore? = runCatching {
        KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    }.getOrNull()
    private val alias = "blackout_link_aes_key"
    private var fallbackKey: SecretKey? = null
    private val identityKeyPair: KeyPair by lazy {
        val generator = KeyPairGenerator.getInstance("EC")
        generator.initialize(ECGenParameterSpec("secp256r1"))
        generator.generateKeyPair()
    }

    private fun getOrCreateKey(): SecretKey {
        val ks = keyStore
        if (ks != null) {
            val existing = ks.getKey(alias, null) as? SecretKey
            if (existing != null) return existing

            val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            val spec = KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()

            keyGenerator.init(spec)
            return keyGenerator.generateKey()
        }

        val existingFallback = fallbackKey
        if (existingFallback != null) return existingFallback
        val generator = KeyGenerator.getInstance("AES")
        generator.init(256)
        return generator.generateKey().also { fallbackKey = it }
    }

    override fun encrypt(plainText: ByteArray): EncryptedPayload {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        return EncryptedPayload(
            iv = cipher.iv,
            cipherText = cipher.doFinal(plainText)
        )
    }

    override fun decrypt(payload: EncryptedPayload): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val spec = GCMParameterSpec(128, payload.iv)
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), spec)
        return cipher.doFinal(payload.cipherText)
    }

    fun getIdentityPublicKeyEncoded(): ByteArray {
        return identityKeyPair.public.encoded
    }

    fun deriveSessionKey(peerPublicKeyEncoded: ByteArray): ByteArray {
        val keyFactory = KeyFactory.getInstance("EC")
        val peerPublicKey = keyFactory.generatePublic(X509EncodedKeySpec(peerPublicKeyEncoded))
        val agreement = KeyAgreement.getInstance("ECDH")
        agreement.init(identityKeyPair.private)
        agreement.doPhase(peerPublicKey, true)
        val sharedSecret = agreement.generateSecret()
        return MessageDigest.getInstance("SHA-256").digest(sharedSecret)
    }

    fun encryptWithSessionKey(plainText: ByteArray, sessionKey: ByteArray): EncryptedPayload {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val key = SecretKeySpec(sessionKey.copyOf(32), "AES")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        return EncryptedPayload(
            iv = cipher.iv,
            cipherText = cipher.doFinal(plainText)
        )
    }

    fun decryptWithSessionKey(payload: EncryptedPayload, sessionKey: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val key = SecretKeySpec(sessionKey.copyOf(32), "AES")
        val spec = GCMParameterSpec(128, payload.iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)
        return cipher.doFinal(payload.cipherText)
    }
}
