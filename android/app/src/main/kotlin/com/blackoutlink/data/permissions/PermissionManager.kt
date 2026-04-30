package com.blackoutlink.data.permissions

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class PermissionManager(
    private val activity: Activity
) {
    private val appContext = activity.applicationContext
    private val requestedPermissions = mutableSetOf<String>()

    fun getPermissionStatus(includeMicrophone: Boolean = false): Map<String, Any?> {
        val keys = permissionKeys(includeMicrophone)
        val statuses = mutableMapOf<String, String>()
        for (permission in keys) {
            statuses[permission] = computeStatus(permission)
        }

        val bluetoothEnabled = isBluetoothEnabled()
        val locationServiceEnabled = isLocationServiceEnabled()

        val scanGranted = statuses[Manifest.permission.BLUETOOTH_SCAN] in grantedLikeStatuses()
        val connectGranted = statuses[Manifest.permission.BLUETOOTH_CONNECT] in grantedLikeStatuses()
        val advertiseGranted = statuses[Manifest.permission.BLUETOOTH_ADVERTISE] in grantedLikeStatuses()
        val fineLocationGranted = statuses[Manifest.permission.ACCESS_FINE_LOCATION] == "granted"

        return mapOf(
            "ok" to true,
            "permissions" to statuses,
            "bluetoothEnabled" to bluetoothEnabled,
            "locationServiceEnabled" to locationServiceEnabled,
            "allGrantedCore" to (scanGranted && connectGranted && advertiseGranted && fineLocationGranted),
        )
    }

    fun requestablePermissions(includeMicrophone: Boolean = false): List<String> {
        val keys = permissionKeys(includeMicrophone)
        val list = mutableListOf<String>()
        for (permission in keys) {
            val status = computeStatus(permission)
            if (status == "denied" || status == "permanently_denied") {
                list.add(permission)
                requestedPermissions.add(permission)
            }
        }
        return list
    }

    fun onRequestPermissionsResult(permissions: Array<out String>) {
        requestedPermissions.addAll(permissions)
    }

    private fun permissionKeys(includeMicrophone: Boolean): List<String> {
        val list = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            list.add(Manifest.permission.BLUETOOTH_SCAN)
            list.add(Manifest.permission.BLUETOOTH_CONNECT)
            list.add(Manifest.permission.BLUETOOTH_ADVERTISE)
        } else {
            // Android < 31 does not require runtime BT_SCAN/BT_CONNECT.
            list.add(Manifest.permission.BLUETOOTH_SCAN)
            list.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        list.add(Manifest.permission.ACCESS_FINE_LOCATION)
        if (includeMicrophone) {
            list.add(Manifest.permission.RECORD_AUDIO)
        }
        return list
    }

    private fun computeStatus(permission: String): String {
        if (isNotRequired(permission)) {
            return "not_required"
        }

        val granted = ContextCompat.checkSelfPermission(appContext, permission) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            return "granted"
        }

        val requestedBefore = requestedPermissions.contains(permission)
        val shouldShowRationale = ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
        if (requestedBefore && !shouldShowRationale) {
            return "permanently_denied"
        }

        return "denied"
    }

    private fun isNotRequired(permission: String): Boolean {
        return when (permission) {
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_ADVERTISE -> Build.VERSION.SDK_INT < Build.VERSION_CODES.S
            else -> false
        }
    }

    private fun grantedLikeStatuses(): Set<String> {
        return setOf("granted", "not_required")
    }

    private fun isBluetoothEnabled(): Boolean {
        val manager = appContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter: BluetoothAdapter? = manager?.adapter
        return adapter?.isEnabled == true
    }

    private fun isLocationServiceEnabled(): Boolean {
        val manager = appContext.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (manager == null) return false
        return manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }
}
