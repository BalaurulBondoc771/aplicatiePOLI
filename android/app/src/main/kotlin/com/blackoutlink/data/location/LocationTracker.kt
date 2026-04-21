package com.blackoutlink.data.location

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.core.content.ContextCompat
import com.blackoutlink.domain.model.LocationSnapshot
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlin.coroutines.resume

class LocationTracker(
    context: Context
) {
    private val client: FusedLocationProviderClient = LocationServices.getFusedLocationProviderClient(context)
    private val appContext = context.applicationContext

    fun isGpsEnabled(): Boolean {
        val manager = appContext.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (manager == null) return false
        return manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    suspend fun getCurrentLocation(timeoutMs: Long = 2_500L): LocationSnapshot? {
        if (!hasPermission()) return null
        return withTimeoutOrNull(timeoutMs) {
            locationUpdates(intervalMs = 1_000L).first()
        }
    }

    suspend fun getLastKnownLocation(): LocationSnapshot? {
        if (!hasPermission()) return null
        return getLastKnownLocationSnapshot()
    }

    suspend fun getCurrentOrLastKnown(timeoutMs: Long = 2_500L): LocationSnapshot? {
        if (!hasPermission()) return null

        val current = getCurrentLocation(timeoutMs)
        if (current != null) return current

        return getLastKnownLocation()
    }

    @SuppressLint("MissingPermission")
    private suspend fun getLastKnownLocationSnapshot(): LocationSnapshot? {
        return suspendCancellableCoroutine { cont ->
            client.lastLocation
                .addOnSuccessListener { location ->
                    if (location == null) {
                        cont.resume(null)
                    } else {
                        cont.resume(
                            LocationSnapshot(
                                latitude = location.latitude,
                                longitude = location.longitude,
                                accuracyMeters = location.accuracy,
                                timestamp = location.time
                            )
                        )
                    }
                }
                .addOnFailureListener {
                    cont.resume(null)
                }
        }
    }

    fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(appContext, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    @SuppressLint("MissingPermission")
    fun locationUpdates(intervalMs: Long = 5_000L): Flow<LocationSnapshot> = callbackFlow {
        if (!hasPermission()) {
            close(IllegalStateException("Location permission missing"))
            return@callbackFlow
        }

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, intervalMs)
            .setMinUpdateIntervalMillis(intervalMs)
            .build()

        val callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val location = result.lastLocation ?: return
                trySend(
                    LocationSnapshot(
                        latitude = location.latitude,
                        longitude = location.longitude,
                        accuracyMeters = location.accuracy,
                        timestamp = location.time
                    )
                )
            }
        }

        client.requestLocationUpdates(request, callback, appContext.mainLooper)
        awaitClose { client.removeLocationUpdates(callback) }
    }
}
