package com.example.blackoutapp

import com.example.blackoutapp.channels.BlackoutChannelCoordinator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
	private var channelCoordinator: BlackoutChannelCoordinator? = null

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
}
