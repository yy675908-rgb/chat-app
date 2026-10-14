package com.yy675908.character_chat_app

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "linjian/proactive_notifications"
        private const val NOTIFICATION_PERMISSION_REQUEST = 7302
        private const val LOCATION_PERMISSION_REQUEST = 7303
    }

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingLocationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> requestNotificationPermission(result)
                "canNotify" -> result.success(canNotify())
                "schedule" -> scheduleNotification(call, result)
                "cancel" -> cancelNotification(call, result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "linjian/location"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> requestLocationPermission(result)
                "currentPlace" -> currentPlace(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun hasLocationPermission(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (hasLocationPermission()) {
            result.success(true)
            return
        }
        if (pendingLocationPermissionResult != null) {
            result.success(false)
            return
        }
        pendingLocationPermissionResult = result
        requestPermissions(
            arrayOf(
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION
            ),
            LOCATION_PERMISSION_REQUEST
        )
    }

    private fun currentPlace(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            result.success(null)
            return
        }
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
            .filter { provider -> manager.isProviderEnabled(provider) }
        if (providers.isEmpty()) {
            result.success(null)
            return
        }
        val completed = AtomicBoolean(false)
        val fixResolved = AtomicBoolean(false)
        val handler = Handler(Looper.getMainLooper())
        val listeners = mutableListOf<LocationListener>()
        var coordinateFallback: String? = null
        fun stopUpdates() {
            listeners.forEach { listener ->
                try {
                    manager.removeUpdates(listener)
                } catch (_: SecurityException) {
                    // Permission may have been revoked while a fix was pending.
                }
            }
        }
        fun finish(place: String?) {
            if (completed.compareAndSet(false, true)) {
                stopUpdates()
                result.success(place)
            }
        }
        handler.postDelayed({ finish(coordinateFallback) }, 9000L)

        fun resolve(location: Location) {
            if (!fixResolved.compareAndSet(false, true)) return
            stopUpdates()
            coordinateFallback = String.format(
                Locale.US,
                "约纬度 %.2f，经度 %.2f（地点名称暂不可用）",
                location.latitude,
                location.longitude
            )
            Thread {
                val place = try {
                    if (!Geocoder.isPresent()) null else {
                        @Suppress("DEPRECATION")
                        val address = Geocoder(this, Locale.SIMPLIFIED_CHINESE)
                            .getFromLocation(location.latitude, location.longitude, 1)
                            ?.firstOrNull()
                        listOfNotNull(
                            address?.adminArea,
                            address?.locality,
                            address?.subAdminArea,
                            address?.subLocality
                        ).map { it.trim() }.filter { it.isNotEmpty() }.distinct()
                            .joinToString(" ").ifEmpty { null }
                    }
                } catch (_: Exception) {
                    null
                }
                handler.post { finish(place ?: coordinateFallback) }
            }.start()
        }

        try {
            val recent = providers.mapNotNull { manager.getLastKnownLocation(it) }
                .filter { System.currentTimeMillis() - it.time in 0L..120000L }
                .maxByOrNull { it.time }
            if (recent != null) {
                resolve(recent)
            } else {
                providers.forEach { provider ->
                    val listener = object : LocationListener {
                        override fun onLocationChanged(location: Location) {
                            resolve(location)
                        }
                    }
                    listeners.add(listener)
                    try {
                        @Suppress("DEPRECATION")
                        manager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
                    } catch (_: IllegalArgumentException) {
                        listeners.remove(listener)
                    }
                }
                if (listeners.isEmpty()) finish(null)
            }
        } catch (_: SecurityException) {
            finish(null)
        } catch (_: IllegalArgumentException) {
            finish(null)
        }
    }

    private fun canNotify(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            getSystemService(NotificationManager::class.java).areNotificationsEnabled()
        } else {
            true
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(canNotify())
            return
        }
        if (canNotify()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LOCATION_PERMISSION_REQUEST) {
            pendingLocationPermissionResult?.success(hasLocationPermission())
            pendingLocationPermissionResult = null
            return
        }
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    private fun notificationPendingIntent(id: Int): PendingIntent {
        val intent = Intent(this, ProactiveNotificationReceiver::class.java)
        return PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleNotification(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Int>("id") ?: 7301
        val triggerAtMillis =
            (call.argument<Number>("triggerAtMillis")?.toLong() ?: 0L)
                .coerceAtLeast(System.currentTimeMillis() + 1000L)
        val title = call.argument<String>("title")?.trim().orEmpty()
        val body = call.argument<String>("body")?.trim().orEmpty()

        val intent = Intent(this, ProactiveNotificationReceiver::class.java).apply {
            putExtra("notificationId", id)
            putExtra("title", title)
            putExtra("body", body)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        } else {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        }
        result.success(null)
    }

    private fun cancelNotification(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Int>("id") ?: 7301
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(notificationPendingIntent(id))
        getSystemService(NotificationManager::class.java).cancel(id)
        result.success(null)
    }
}
