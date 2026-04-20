package com.example.talkiyo_caller

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.util.Log

class RingtoneService : Service() {

    private var mediaPlayer: MediaPlayer? = null

    companion object {
        private const val CHANNEL_ID = "talkiyo_ringtone_fg"
        private const val NOTIFICATION_ID = 8877
        private const val TAG = "RingtoneService"

        fun start(context: Context, callerName: String, callId: String) {
            val intent = Intent(context, RingtoneService::class.java).apply {
                putExtra("callerName", callerName)
                putExtra("callId", callId)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, RingtoneService::class.java))
        }
    }

    override fun onCreate() {
        super.onCreate()
        createForegroundChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val callerName = intent?.getStringExtra("callerName") ?: "Unknown"
        val callId = intent?.getStringExtra("callId") ?: ""
        startForeground(NOTIFICATION_ID, buildForegroundNotification(callerName, callId))
        playRingtone()
        return START_STICKY
    }

    private fun playRingtone() {
        try {
            mediaPlayer?.release()
            val rawId = resources.getIdentifier("iphone", "raw", packageName)
            if (rawId == 0) {
                Log.e(TAG, "Raw resource 'iphone' not found in $packageName")
                return
            }
            mediaPlayer = MediaPlayer.create(this, rawId)?.apply {
                isLooping = true
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                start()
                Log.d(TAG, "Ringtone started")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play ringtone", e)
        }
    }

    private fun createForegroundChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Ringtone",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setSound(null, null)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(callerName: String, callId: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("callId", callId)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }.apply {
            setContentTitle("Incoming Call")
            setContentText("$callerName is calling...")
            setSmallIcon(android.R.drawable.ic_menu_call)
            setContentIntent(pendingIntent)
            setOngoing(true)
        }.build()
    }

    override fun onDestroy() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
        Log.d(TAG, "Ringtone stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
