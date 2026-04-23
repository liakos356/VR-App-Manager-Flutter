package com.vr.appmanager

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.vr.appmanager/install"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call,
                result ->
            when (call.method) {
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath != null) {
                        val success = installApk(apkPath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "APK path not provided", null)
                    }
                }
                "silentInstallApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    if (apkPath != null) {
                        silentInstallApk(apkPath, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "APK path not provided", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(apkPath: String): Boolean {
        return try {
            val file = File(apkPath)
            if (!file.exists()) return false

            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)

            // Use FileProvider for correct API 24+ file sharing
            val uri =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        FileProvider.getUriForFile(
                                context,
                                "${context.packageName}.fileprovider",
                                file
                        )
                    } else {
                        Uri.fromFile(file)
                    }

            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Attempts a silent install using the `pm install` shell command.
     *
     * This works without a user confirmation dialog when the app has been granted the
     * INSTALL_PACKAGES permission (e.g. via ADB: adb shell pm grant com.vr.appmanager
     * android.permission.INSTALL_PACKAGES or on devices with developer options / shell access
     * already elevated).
     *
     * Returns true on success, false on failure. On failure the caller should fall back to the
     * standard [installApk] UI flow.
     */
    private fun silentInstallApk(apkPath: String, result: MethodChannel.Result) {
        Thread {
                    try {
                        val process =
                                ProcessBuilder("pm", "install", "-r", "-t", apkPath)
                                        .redirectErrorStream(true)
                                        .start()
                        val output = process.inputStream.bufferedReader().readText().trim()
                        val exitCode = process.waitFor()
                        val success = exitCode == 0 && output.contains("Success", ignoreCase = true)
                        Handler(Looper.getMainLooper()).post { result.success(success) }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        Handler(Looper.getMainLooper()).post {
                            result.error("SILENT_INSTALL_FAILED", e.message, null)
                        }
                    }
                }
                .start()
    }
}
