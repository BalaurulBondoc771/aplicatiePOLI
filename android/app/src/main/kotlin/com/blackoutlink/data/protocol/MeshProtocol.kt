package com.blackoutlink.data.protocol

import com.blackoutlink.domain.model.MeshMessage
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

object MeshProtocol {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    fun encode(message: MeshMessage): ByteArray {
        return json.encodeToString(message).encodeToByteArray()
    }

    fun decode(bytes: ByteArray): MeshMessage {
        return json.decodeFromString<MeshMessage>(bytes.decodeToString())
    }
}
