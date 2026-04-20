package com.example.talkiyo_reciever

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class CallFirebaseMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        if (isIncomingCall(data)) {
            val callId = data["callId"] ?: data["call_id"] ?: data["id"] ?: ""
            val callerName = data["callerName"] ?: data["caller_name"] ?: "Unknown"
            if (callId.isNotEmpty()) {
                Log.d("CallFCMService", "Incoming call detected, starting ringtone for $callId")
                RingtoneService.start(applicationContext, callerName, callId)
            }
        }
        // Delegate to Flutter's background message handler
        super.onMessageReceived(message)
    }

    private fun isIncomingCall(data: Map<String, String>): Boolean {
        val callId = data["callId"] ?: data["call_id"] ?: data["id"]
        if (callId.isNullOrEmpty()) return false
        val type = data["type"] ?: data["notificationType"]
        if (type.isNullOrEmpty()) return true
        return type in setOf("incoming_call", "call_invite", "call")
    }
}
