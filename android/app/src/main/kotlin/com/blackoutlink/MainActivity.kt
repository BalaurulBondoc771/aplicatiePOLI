package com.blackoutlink

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.room.Room
import com.blackoutlink.data.bluetooth.BleScanner
import com.blackoutlink.data.location.LocationTracker
import com.blackoutlink.data.repository.MeshRepository
import com.blackoutlink.data.security.CryptoManager
import com.blackoutlink.data.storage.BlackoutDatabase
import com.blackoutlink.data.storage.SettingsStore
import com.blackoutlink.ui.home.HomeScreen
import com.blackoutlink.ui.home.HomeViewModel
import com.blackoutlink.ui.navigation.BlackoutApp
import com.blackoutlink.ui.theme.BlackoutTheme

class MainActivity : ComponentActivity() {
    
    private lateinit var database: BlackoutDatabase
    private lateinit var bleScanner: BleScanner
    private lateinit var locationTracker: LocationTracker
    private lateinit var settingsStore: SettingsStore
    private lateinit var cryptoManager: CryptoManager
    private lateinit var repository: MeshRepository

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allGranted = permissions.values.all { it }
        if (allGranted && bleScanner.hasPermissions()) {
            bleScanner.startScan()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize components
        database = Room.databaseBuilder(
            applicationContext,
            BlackoutDatabase::class.java,
            "blackout_db"
        ).build()

        bleScanner = BleScanner(applicationContext)
        locationTracker = LocationTracker(applicationContext)
        settingsStore = SettingsStore(applicationContext)
        cryptoManager = CryptoManager()
        repository = MeshRepository(
            bleScanner = bleScanner,
            locationTracker = locationTracker,
            settingsStore = settingsStore,
            cryptoManager = cryptoManager,
            messageDao = database.messageDao()
        )

        requestPermissionsIfNeeded()

        setContent {
            BlackoutTheme {
                BlackoutApp()
            }
        }
    }

    private fun requestPermissionsIfNeeded() {
        val permissions = mutableListOf<String>().apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                add(Manifest.permission.BLUETOOTH_SCAN)
                add(Manifest.permission.BLUETOOTH_CONNECT)
            }
            add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        val missingPermissions = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isNotEmpty()) {
            permissionLauncher.launch(missingPermissions.toTypedArray())
        } else if (bleScanner.isBluetoothEnabled()) {
            bleScanner.startScan()
        }
    }

    override fun onDestroy() {
        bleScanner.stopScan()
        super.onDestroy()
    }
}

