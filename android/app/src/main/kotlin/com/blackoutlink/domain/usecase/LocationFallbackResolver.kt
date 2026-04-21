package com.blackoutlink.domain.usecase

import com.blackoutlink.domain.model.LocationSnapshot

data class LocationFallbackResult(
    val location: LocationSnapshot?,
    val usedFallback: Boolean
)

class LocationFallbackResolver {
    fun resolve(current: LocationSnapshot?, lastKnown: LocationSnapshot?): LocationFallbackResult {
        return if (current != null) {
            LocationFallbackResult(location = current, usedFallback = false)
        } else {
            LocationFallbackResult(location = lastKnown, usedFallback = lastKnown != null)
        }
    }
}
