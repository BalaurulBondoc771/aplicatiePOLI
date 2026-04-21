package com.blackoutlink.data.security

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

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
}
