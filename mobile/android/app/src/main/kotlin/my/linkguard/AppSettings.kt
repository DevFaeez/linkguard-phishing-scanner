package my.linkguard

import android.content.ComponentName
import android.content.Context
import android.provider.Settings

class AppSettings(context: Context) {
    private val prefs = context.getSharedPreferences("monitor_settings", Context.MODE_PRIVATE)
    var language: String
        get() = prefs.getString("language", "ms")!!.let { if (it == "en") "en" else "ms" }
        set(value) { if (value in setOf("ms", "en")) prefs.edit().putString("language", value).apply() }
    var enabled: Boolean
        get() = prefs.getBoolean("enabled", false)
        set(value) { prefs.edit().putBoolean("enabled", value).apply() }
    var consent: Boolean
        get() = prefs.getBoolean("consent", false)
        set(value) { prefs.edit().putBoolean("consent", value).apply() }
    var allApps: Boolean
        get() = prefs.getBoolean("all_apps", false)
        set(value) { prefs.edit().putBoolean("all_apps", value).apply() }
    var selected: Set<String>
        get() = prefs.getStringSet("selected", emptySet())!!.toSet()
        set(value) { prefs.edit().putStringSet("selected", value.toSet()).apply() }
    var setupPending: Boolean
        get() = prefs.getBoolean("setup_pending", false)
        set(value) { prefs.edit().putBoolean("setup_pending", value).apply() }
    var warningRequested: Boolean
        get() = prefs.getBoolean("warning_requested", false)
        set(value) { prefs.edit().putBoolean("warning_requested", value).apply() }
    companion object {
        val commonApps = linkedMapOf("WhatsApp" to "com.whatsapp", "WhatsApp Business" to "com.whatsapp.w4b", "Telegram" to "org.telegram.messenger", "Google Messages" to "com.google.android.apps.messaging", "Samsung Messages" to "com.samsung.android.messaging", "Gmail" to "com.google.android.gm", "Outlook" to "com.microsoft.office.outlook")
        fun hasAccess(context: Context): Boolean {
            val expected = ComponentName(context, LinkNotificationListener::class.java)
            return Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
                ?.split(':')?.mapNotNull(ComponentName::unflattenFromString)?.contains(expected) == true
        }
    }
}
