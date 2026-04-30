package com.example.blackoutapp

import android.content.Intent
import android.os.Build
import android.util.Log
import com.blackoutlink.data.storage.SettingsStore
import com.example.blackoutapp.channels.BlackoutChannelCoordinator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
	private var channelCoordinator: BlackoutChannelCoordinator? = null

	override fun onStart() {
		super.onStart()
		// Foreground runtime owns chat transport; stop background beacon to avoid competing GATT servers.
		try {
			stopService(Intent(this, MeshBeaconService::class.java))
		} catch (t: Throwable) {
			Log.w("MainActivity", "stopService(MeshBeaconService) failed: ${t.message}")
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		channelCoordinator = BlackoutChannelCoordinator(
			messenger = flutterEngine.dartExecutor.binaryMessenger,
			activity = this
		)
	}

	override fun onRequestPermissionsResult(
		requestCode: Int,
		permissions: Array<out String>,
		grantResults: IntArray
	) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
			channelCoordinator?.onRequestPermissionsResult(requestCode, permissions, grantResults)
	}

	override fun onStop() {
		super.onStop()
		try {
			channelCoordinator?.onHostStopped()
		} catch (t: Throwable) {
			Log.w("MainActivity", "onHostStopped failed: ${t.message}")
		}
		val backgroundBeaconEnabled = try {
			SettingsStore(applicationContext).isBackgroundBeaconEnabled()
		} catch (_: Throwable) {
			false
		}
		if (!backgroundBeaconEnabled) {
			return
		}

		val intent = Intent(this, MeshBeaconService::class.java)
		try {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				startForegroundService(intent)
			} else {
				startService(intent)
			}
		} catch (t: Throwable) {
			Log.w("MainActivity", "start MeshBeaconService failed: ${t.message}")
		}
	}
}
