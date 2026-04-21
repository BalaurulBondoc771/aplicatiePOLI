package com.blackoutlink.domain.usecase

import com.blackoutlink.domain.model.PeerDevice

class QuickStatusRecipientResolver(
    private val staleMs: Long = 15_000L,
) {
    fun resolve(peers: List<PeerDevice>, now: Long = System.currentTimeMillis()): List<PeerDevice> {
        val activeFresh = peers.filter { peer ->
            val active = peer.status.name == "CONNECTED" || peer.status.name == "SCANNING"
            val stale = (now - peer.lastSeenAt) > staleMs
            active && !stale
        }

        val deduped = linkedMapOf<String, PeerDevice>()
        for (peer in activeFresh) {
            deduped[peer.id] = peer
        }

        val unique = deduped.values.toList()
        val trusted = unique.filter { it.trusted }
        return if (trusted.isNotEmpty()) trusted else unique
    }
}
