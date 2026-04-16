package com.example.talkiyo_caller

import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.telecom.TelecomManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "talkiyo/default_dialer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultDialer" -> result.success(isDefaultDialer())
                "requestDefaultDialer" -> result.success(requestDefaultDialer())
                else -> result.notImplemented()
            }
        }
    }

    private fun isDefaultDialer(): Boolean {
        val telecomManager = getSystemService(TelecomManager::class.java)
        return telecomManager?.defaultDialerPackage == packageName
    }

    private fun requestDefaultDialer(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(RoleManager::class.java)
                if (roleManager?.isRoleAvailable(RoleManager.ROLE_DIALER) == true &&
                    !roleManager.isRoleHeld(RoleManager.ROLE_DIALER)
                ) {
                    startActivity(roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER))
                    true
                } else {
                    false
                }
            } else {
                val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER).apply {
                    putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
                }
                startActivity(intent)
                true
            }
        } catch (error: Exception) {
            false
        }
    }
}
