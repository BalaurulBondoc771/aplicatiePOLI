package com.blackoutlink.data.security

interface PayloadCrypto {
    fun encrypt(plainText: ByteArray): EncryptedPayload
    fun decrypt(payload: EncryptedPayload): ByteArray
}
