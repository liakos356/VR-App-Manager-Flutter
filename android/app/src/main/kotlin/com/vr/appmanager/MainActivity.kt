package com.vr.appmanager

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.vr.appmanager/install"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val apkPath = call.argument<String>("apkPath")
                if (apkPath != null) {
                    val success = installApk(apkPath)
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENT", "APK path not provided", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun installApk(apkPath: String): Boolean {
        return try {
            val file = File(apkPath)
            if (!file.exists()) return false

            val pm = packageManager
            val info = pm.getPackageArchiveInfo(apkPath, 0)
            if (info == null) {
                // The APK is either drastically corrupt, incompletely downloaded, 
                // or entirely unsupported by the system's package parser (e.g. wrong architecture).
                return false
            }

            val intent = Intent(Intent.ACTION_VIEW)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            
            // Use FileProvider for correct API 24+ file sharing
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val providerUri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
                // Explicitly grant perms to the package installer to avoid bugs with FLAG_ACTIVITY_NEW_TASK overriding URI grants
                val resInfoList = pm.queryIntentActivities(intent.apply { setDataAndType(providerUri, "application/vnd.android.package-archive") }, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY)
                for (resolveInfo in resInfoList) {
                    val pName = resolveInfo.activityInfo.packageName
                    context.grantUriPermission(pName, providerUri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                }
                providerUri
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
}
