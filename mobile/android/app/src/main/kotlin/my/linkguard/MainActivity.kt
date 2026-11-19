package my.linkguard

import android.Manifest
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.service.notification.NotificationListenerService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** System integration only; the consumer UI and scan engine are Dart. */
class MainActivity : FlutterActivity() {
    private var bridge: MethodChannel? = null
    private var sharedText: String? = null
    private var pendingWarnings: MethodChannel.Result? = null
    override fun onCreate(savedInstanceState: Bundle?) { consumeShare(intent); super.onCreate(savedInstanceState) }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent); setIntent(intent); consumeShare(intent)
        bridge?.invokeMethod("shareChanged", null)
    }
    private fun consumeShare(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND) sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)?.take(32768)
    }
    /** Delete only image_picker's temporary copies inside this app's own cache. */
    private fun cleanupQrImages() {
        val root = cacheDir.canonicalFile
        val pickerDirectory = Regex("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
        root.listFiles()?.forEach { item ->
            if (item.canonicalFile.parentFile != root) return@forEach
            if (item.isDirectory && pickerDirectory.matches(item.name)) {
                item.listFiles()?.forEach { file ->
                    if (file.isFile && file.canonicalFile.parentFile == item.canonicalFile) file.delete()
                }
                item.delete() // Only succeeds after removing the app-owned picker copies.
            } else if (item.isFile && item.name.startsWith("scaled_")) {
                item.delete()
            }
        }
    }
    private fun warningsAllowed(): Boolean {
        val manager = getSystemService(NotificationManager::class.java)
        return manager.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
            manager.getNotificationChannel(LinkNotificationListener.CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE
    }
    private fun openNotificationAccess() {
        if (Build.VERSION.SDK_INT >= 30) {
            try {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                    .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        ComponentName(this, LinkNotificationListener::class.java).flattenToString()))
                return
            } catch (_: ActivityNotFoundException) { /* Older/custom Settings apps use the list. */ }
        }
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }
    private fun requestWarnings(result: MethodChannel.Result, prefs: AppSettings) {
        if (warningsAllowed()) { result.success(true); return }
        if (pendingWarnings != null) { result.error("request_in_progress", "A permission request is already open.", null); return }
        pendingWarnings = result
        try {
            if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
                (!prefs.warningRequested || shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS))) {
                prefs.warningRequested = true
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 12)
            } else {
                val manager = getSystemService(NotificationManager::class.java)
                val channelDisabled = manager.getNotificationChannel(LinkNotificationListener.CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE
                val intent = if (channelDisabled) Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, LinkNotificationListener.CHANNEL)
                else Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                @Suppress("DEPRECATION")
                startActivityForResult(intent, 13)
            }
        } catch (_: Exception) { pendingWarnings?.success(false); pendingWarnings = null }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 12) { pendingWarnings?.success(warningsAllowed()); pendingWarnings = null }
    }
    @Deprecated("Android Activity result API retained for system Settings compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 13) { pendingWarnings?.success(warningsAllowed()); pendingWarnings = null }
    }
    override fun onDestroy() { pendingWarnings?.success(false); pendingWarnings = null; super.onDestroy() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "my.linkguard/device")
        bridge!!.setMethodCallHandler { call, result ->
            val prefs = AppSettings(this)
            when (call.method) {
                "status" -> result.success(mapOf("language" to prefs.language, "enabled" to prefs.enabled, "consent" to prefs.consent,
                    "allApps" to prefs.allApps, "selected" to prefs.selected.toList(), "setupPending" to prefs.setupPending,
                    "access" to AppSettings.hasAccess(this), "warnings" to warningsAllowed(),
                    "connected" to LinkNotificationListener.connected, "engineReady" to LinkNotificationListener.engineReady,
                    "dropped" to LinkNotificationListener.dropped, "failures" to LinkNotificationListener.failures))
                "update" -> {
                    val values = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    (values["language"] as? String)?.let { prefs.language = it }
                    (values["consent"] as? Boolean)?.let { prefs.consent = it }
                    (values["enabled"] as? Boolean)?.let { prefs.enabled = it && prefs.consent }
                    (values["allApps"] as? Boolean)?.let { prefs.allApps = it }
                    (values["setupPending"] as? Boolean)?.let { prefs.setupPending = it }
                    @Suppress("UNCHECKED_CAST")
                    (values["selected"] as? List<String>)?.let { prefs.selected = it.toSet() }
                    LinkNotificationListener.active?.preferencesChanged()
                    if (prefs.enabled && prefs.consent && AppSettings.hasAccess(this) && !LinkNotificationListener.connected) {
                        NotificationListenerService.requestRebind(ComponentName(this, LinkNotificationListener::class.java))
                    }
                    result.success(null)
                }
                "openAccess" -> try { openNotificationAccess(); result.success(null) }
                    catch (_: Exception) { result.error("settings_unavailable", "Android settings cannot be opened.", null) }
                "openAppSettings" -> try {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        android.net.Uri.parse("package:$packageName")))
                    result.success(null)
                } catch (_: Exception) { result.error("settings_unavailable", "Android settings cannot be opened.", null) }
                "cleanupQrImages" -> try { cleanupQrImages(); result.success(null) }
                    catch (_: Exception) { result.error("cleanup_failed", "Temporary image cleanup failed.", null) }
                "requestWarnings" -> requestWarnings(result, prefs)
                "consumeShare" -> { result.success(sharedText); sharedText = null }
                else -> result.notImplemented()
            }
        }
    }
}
