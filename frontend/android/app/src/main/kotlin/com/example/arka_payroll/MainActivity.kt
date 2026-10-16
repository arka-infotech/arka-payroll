package com.example.arka_payroll

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Switches launcher activity-aliases so the home-screen icon matches
 * the in-app theme (light / dark / system).
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.example.arka_payroll/launcher_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setLauncherIcon" -> {
                        val mode = call.argument<String>("mode") ?: "system"
                        try {
                            applyLauncherIcon(mode)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ICON_SWITCH_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun applyLauncherIcon(mode: String) {
        val pm = packageManager
        val pkg = packageName
        val system = ComponentName(pkg, "$pkg.IconSystem")
        val light = ComponentName(pkg, "$pkg.IconLight")
        val dark = ComponentName(pkg, "$pkg.IconDark")

        fun setEnabled(component: ComponentName, enabled: Boolean) {
            pm.setComponentEnabledSetting(
                component,
                if (enabled) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                },
                PackageManager.DONT_KILL_APP,
            )
        }

        when (mode) {
            "light" -> {
                setEnabled(system, false)
                setEnabled(light, true)
                setEnabled(dark, false)
            }
            "dark" -> {
                setEnabled(system, false)
                setEnabled(light, false)
                setEnabled(dark, true)
            }
            else -> {
                setEnabled(system, true)
                setEnabled(light, false)
                setEnabled(dark, false)
            }
        }
    }
}
