package my.linkguard

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

/** Android events are sent to a separate headless Dart engine for offline classification. */
class LinkNotificationListener : NotificationListenerService() {
    companion object {
        const val CHANNEL = "phishing_warnings"
        @Volatile var connected = false
            private set
        @Volatile var engineReady = false
            private set
        @Volatile var dropped = 0
            private set
        @Volatile var failures = 0
            private set
        var active: LinkNotificationListener? = null
            private set
    }
    private data class Job(val source: String, val text: String)
    private val queue = ArrayDeque<Job>()
    private val handler = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var bridge: MethodChannel? = null
    private var busy = false
    private var sequence = 0L
    private var lastWarning = -30_000L
    private val prefs by lazy { AppSettings(this) }
    private fun allowed(source: String) = connected && prefs.enabled && prefs.consent && source != packageName && (prefs.allApps || source in prefs.selected)
    override fun onListenerConnected() { super.onListenerConnected(); active = this; connected = true; preferencesChanged() }
    override fun onListenerDisconnected() { connected = false; stopEngine(); super.onListenerDisconnected() }
    override fun onDestroy() { connected = false; active = null; stopEngine(); super.onDestroy() }
    fun preferencesChanged() {
        if (!prefs.enabled || !prefs.consent) { queue.clear(); return }
        if (connected) ensureEngine()
    }
    private fun stopEngine() {
        sequence++; busy = false; engineReady = false; queue.clear(); handler.removeCallbacksAndMessages(null)
        bridge?.setMethodCallHandler(null); bridge = null; engine?.destroy(); engine = null
    }
    private fun ensureEngine() {
        if (engine != null) return
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext); loader.ensureInitializationComplete(applicationContext, null)
            val created = FlutterEngine(applicationContext); engine = created
            bridge = MethodChannel(created.dartExecutor.binaryMessenger, "my.linkguard/background")
            bridge!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    "ready" -> { engineReady = true; result.success(null); drain() }
                    "unavailable" -> { failures++; result.success(null); stopEngine() }
                    else -> result.notImplemented()
                }
            }
            created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "notificationMain"))
            handler.postDelayed({ if (!engineReady && engine === created) { failures++; stopEngine() } }, 15_000)
        } catch (_: Exception) { failures++; stopEngine() }
    }
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!allowed(sbn.packageName) || sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val extras = sbn.notification.extras
        val text = buildString {
            for (key in listOf(Notification.EXTRA_TITLE, Notification.EXTRA_TEXT, Notification.EXTRA_BIG_TEXT)) {
                append(extras.getCharSequence(key)?.take(8192) ?: ""); append('\n')
            }
            extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.take(20)?.forEach { append(it.take(2048)); append('\n') }
            @Suppress("DEPRECATION")
            extras.getParcelableArray(Notification.EXTRA_MESSAGES)?.takeLast(20)?.forEach {
                append((it as? android.os.Bundle)?.getCharSequence("text")?.take(2048) ?: ""); append('\n')
            }
        }.take(32768)
        if (queue.size >= 32) { dropped++; return }
        queue.addLast(Job(sbn.packageName, text)); ensureEngine(); drain()
    }
    private fun drain() {
        if (busy || !engineReady) return
        var job: Job? = null
        while (queue.isNotEmpty() && job == null) { val next = queue.removeFirst(); if (allowed(next.source)) job = next }
        val current = job ?: return
        busy = true; val ticket = ++sequence
        val timeout = Runnable { if (ticket == sequence && busy) { failures++; stopEngine() } }
        handler.postDelayed(timeout, 10_000)
        bridge!!.invokeMethod("scanNotification", mapOf("source" to current.source, "text" to current.text), object : MethodChannel.Result {
            private fun complete(suspicious: Boolean, failed: Boolean) {
                if (ticket != sequence) return
                handler.removeCallbacks(timeout); busy = false
                if (failed) failures++
                if (suspicious && allowed(current.source)) warn()
                drain()
            }
            override fun success(result: Any?) = complete((result as? Map<*, *>)?.get("suspicious") == true, false)
            override fun error(code: String, message: String?, details: Any?) = complete(false, true)
            override fun notImplemented() = complete(false, true)
        })
    }
    private fun warn() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, if (prefs.language == "en") "Suspicious link warnings" else "Amaran link mencurigakan", NotificationManager.IMPORTANCE_HIGH))
        if (!nm.areNotificationsEnabled() || nm.getNotificationChannel(CHANNEL).importance == NotificationManager.IMPORTANCE_NONE) return
        val now = SystemClock.elapsedRealtime()
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        nm.notify(1001, Notification.Builder(this, CHANNEL).setSmallIcon(R.drawable.ic_shield)
            .setContentTitle(if (prefs.language == "en") "Suspicious link detected" else "Link mencurigakan dikesan")
            .setContentText(if (prefs.language == "en") "Take care before opening a link in the message you just received." else "Berhati-hati sebelum membuka link dalam mesej yang baru diterima.")
            .setContentIntent(open).setAutoCancel(true).setOnlyAlertOnce(now - lastWarning < 30_000)
            .setVisibility(Notification.VISIBILITY_SECRET).build())
        lastWarning = now
    }
}
