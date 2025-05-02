package com.example.reciperealm

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import android.util.Log

class MyFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d("MyFirebaseService", "Message received from: ${remoteMessage.from}")

        remoteMessage.notification?.let {
            Log.d("MyFirebaseService", "Notification Title: ${it.title}")
            Log.d("MyFirebaseService", "Notification Body: ${it.body}")
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d("MyFirebaseService", "New FCM token: $token")
    }
}
