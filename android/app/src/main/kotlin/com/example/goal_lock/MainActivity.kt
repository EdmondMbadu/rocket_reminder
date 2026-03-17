package com.example.goal_lock

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private lateinit var goalLockPlatformPlugin: GoalLockPlatformPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        goalLockPlatformPlugin = GoalLockPlatformPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (::goalLockPlatformPlugin.isInitialized &&
            goalLockPlatformPlugin.onRequestPermissionsResult(
                requestCode,
                permissions,
                grantResults,
            )
        ) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
