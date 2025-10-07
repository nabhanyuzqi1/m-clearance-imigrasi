package com.android.imigrasi

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val notificationChannelId = "mclearance_updates"
  private val methodChannelName = "com.android.imigrasi/notifications"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "showBubble" -> {
            val args = call.arguments as? Map<*, *>
            if (args != null) {
              showBubbleNotification(args)
              result.success(null)
            } else {
              result.error("invalid_args", "Expected map arguments", null)
            }
          }
          "updateBadge" -> {
            val args = call.arguments as? Map<*, *>
            val badge = (args?.get("badge") as? Int) ?: 0
            updateBadgeCount(badge)
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
  }

  private fun showBubbleNotification(args: Map<*, *>) {
    val context = applicationContext
    val title = args["title"] as? String ?: context.getString(R.string.app_name)
    val body = args["body"] as? String ?: ""
    val badge = (args["badge"] as? Int) ?: 0
    val muted = args["muted"] as? Boolean ?: false

    if (!canPostNotifications(context)) {
      return
    }

    val notificationManager = ensureNotificationChannel(context)
    val notificationManagerCompat = NotificationManagerCompat.from(context)

    val intent = Intent(context, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }

    val pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    val pendingIntent = PendingIntent.getActivity(context, 0, intent, pendingIntentFlags)

    val builder = NotificationCompat.Builder(context, notificationChannelId)
      .setSmallIcon(R.mipmap.launcher_icon)
      .setContentTitle(title)
      .setContentText(body)
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setCategory(NotificationCompat.CATEGORY_MESSAGE)
      .setAutoCancel(true)
      .setContentIntent(pendingIntent)
      .setNumber(badge)
      .setOnlyAlertOnce(muted)

    if (muted) {
      builder.setSound(null)
      builder.setVibrate(LongArray(0))
      builder.setSilent(true)
    }

    var bubblesAllowed = false
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      bubblesAllowed = notificationManager?.areBubblesAllowed() == true
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        when (notificationManager?.bubblePreference) {
          NotificationManager.BUBBLE_PREFERENCE_ALL -> bubblesAllowed = true
          NotificationManager.BUBBLE_PREFERENCE_NONE -> bubblesAllowed = false
        }
      }
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && bubblesAllowed) {
      val icon = IconCompat.createWithResource(context, R.mipmap.launcher_icon)
      val bubbleIntent = PendingIntent.getActivity(context, 1, intent, pendingIntentFlags)
      val bubbleMetadata = NotificationCompat.BubbleMetadata.Builder(bubbleIntent, icon)
        .setDesiredHeight(400)
        .setAutoExpandBubble(true)
        .setSuppressNotification(false)
        .build()
      val person = Person.Builder().setName(context.getString(R.string.app_name)).build()
      builder.setBubbleMetadata(bubbleMetadata)
      builder.setStyle(
        NotificationCompat.MessagingStyle(person).addMessage(
          body,
          System.currentTimeMillis(),
          person,
        ),
      )
    } else {
      builder.setStyle(NotificationCompat.BigTextStyle().bigText(body))
    }

    notificationManagerCompat.notify(System.currentTimeMillis().toInt(), builder.build())
    updateBadgeCount(badge)
  }

  private fun updateBadgeCount(badge: Int) {
    val context = applicationContext
    if (!canPostNotifications(context)) {
      return
    }

    ensureNotificationChannel(context)

    val notificationManager = NotificationManagerCompat.from(context)
    val safeBadge = if (badge < 0) 0 else badge
    val builder = NotificationCompat.Builder(context, notificationChannelId)
      .setSmallIcon(R.mipmap.launcher_icon)
      .setContentTitle(context.getString(R.string.app_name))
      .setContentText(context.getString(R.string.app_name))
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .setNumber(safeBadge)
      .setAutoCancel(true)
      .setOnlyAlertOnce(true)
      .setSilent(true)

    if (safeBadge == 0) {
      notificationManager.cancel(badgeNotificationId)
    } else {
      notificationManager.notify(badgeNotificationId, builder.build())
    }
  }

  private fun canPostNotifications(context: Context): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      val permissionGranted = ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.POST_NOTIFICATIONS,
      ) == PackageManager.PERMISSION_GRANTED
      if (!permissionGranted) {
        return false
      }
    }
    return NotificationManagerCompat.from(context).areNotificationsEnabled()
  }

  private fun ensureNotificationChannel(context: Context): NotificationManager? {
    val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager != null) {
      if (manager.getNotificationChannel(notificationChannelId) == null) {
        val channel = NotificationChannel(
          notificationChannelId,
          "M-Clearance Updates",
          NotificationManager.IMPORTANCE_HIGH,
        ).apply {
          description = "Status updates and announcements"
          setShowBadge(true)
        }
        manager.createNotificationChannel(channel)
      }
    }
    return manager
  }

  companion object {
    private const val badgeNotificationId = 1001
  }
}
