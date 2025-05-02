package com.example.reciperealm

import io.flutter.embedding.android.FlutterActivity
import android.os.Build
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Bundle

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Create notification channel for Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "meal_reminders"
            val channelName = "Meal Reminders"
            val channelDescription = "Notifications reminding users about their meals"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}
