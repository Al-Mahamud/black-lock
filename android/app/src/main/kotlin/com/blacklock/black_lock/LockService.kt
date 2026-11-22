package com.blacklock.black_lock

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.service.quicksettings.TileService
import android.view.HapticFeedbackConstants
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.Toast

/**
 * Holds the black cover on screen. Runs as a foreground service so Android keeps it alive
 * while another app (video, music, navigation) is in front underneath it.
 *
 * Ways out, all of which call [unlock]:
 *  - drawing a V on the cover (the normal way),
 *  - pressing the power button (screen off),
 *  - the "Unlock" button on its notification, or tapping the Quick Settings tile.
 */
class LockService : Service() {

    enum class State { IDLE, PENDING, LOCKED }

    companion object {
        private const val ACTION_LOCK = "com.blacklock.LOCK"
        private const val ACTION_UNLOCK = "com.blacklock.UNLOCK"
        private const val EXTRA_DELAY_MS = "delayMs"
        private const val CHANNEL_ID = "lock"
        private const val NOTIFICATION_ID = 1

        @Volatile
        var state = State.IDLE
            private set

        private var instance: LockService? = null

        /** Must be called while the app is in front (activity or tile tap). */
        fun lock(context: Context, delayMs: Long = 0) {
            val intent = Intent(context, LockService::class.java)
                .setAction(ACTION_LOCK)
                .putExtra(EXTRA_DELAY_MS, delayMs)
            context.startForegroundService(intent)
        }

        /** Main thread only. */
        fun unlock() {
            instance?.unlock()
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val windowManager by lazy { getSystemService(WindowManager::class.java) }
    private var overlay: BlackOverlayView? = null
    private var screenOffReceiver: BroadcastReceiver? = null
    private val showOverlayRunnable = Runnable { showOverlay() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_LOCK -> {
                val delayMs = intent.getLongExtra(EXTRA_DELAY_MS, 0)
                // startForeground must come first on every path after startForegroundService.
                goForeground(pending = delayMs > 0 && overlay == null)
                if (!Settings.canDrawOverlays(this)) {
                    Toast.makeText(this, R.string.need_permission, Toast.LENGTH_LONG).show()
                    unlock()
                } else if (overlay == null) {
                    handler.removeCallbacks(showOverlayRunnable)
                    if (delayMs > 0) {
                        setState(State.PENDING)
                        handler.postDelayed(showOverlayRunnable, delayMs)
                    } else {
                        showOverlay()
                    }
                }
            }
            ACTION_UNLOCK -> unlock()
            else -> if (state == State.IDLE) stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun showOverlay() {
        if (overlay != null) return
        val view = BlackOverlayView(this) { unlockWithFeedback() }

        @Suppress("DEPRECATION")
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
            PixelFormat.OPAQUE,
        ).apply {
            screenBrightness = 0.01f // as dim as the panel goes; the cover is black anyway
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                fitInsetsTypes = 0 // cover the status and navigation bar areas too
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }

        try {
            windowManager.addView(view, params)
        } catch (e: RuntimeException) {
            Toast.makeText(this, R.string.lock_failed, Toast.LENGTH_LONG).show()
            unlock()
            return
        }
        overlay = view
        hideSystemBars(view)
        view.requestFocus()
        registerScreenOff()
        setState(State.LOCKED)
        notify(buildNotification(pending = false))
    }

    private fun hideSystemBars(view: View) {
        @Suppress("DEPRECATION")
        view.systemUiVisibility = View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            view.post {
                view.windowInsetsController?.hide(WindowInsets.Type.systemBars())
            }
        }
    }

    /** Turning the screen off ends the lock, so the phone never wakes up to a "dead" black screen. */
    private fun registerScreenOff() {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) = unlock()
        }
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
        screenOffReceiver = receiver
    }

    private fun unlockWithFeedback() {
        val constant = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            HapticFeedbackConstants.CONFIRM
        } else {
            HapticFeedbackConstants.VIRTUAL_KEY
        }
        overlay?.performHapticFeedback(constant)
        unlock()
    }

    fun unlock() {
        handler.removeCallbacks(showOverlayRunnable)
        overlay?.let { view ->
            try {
                windowManager.removeView(view)
            } catch (_: RuntimeException) {
            }
        }
        overlay = null
        screenOffReceiver?.let { unregisterReceiver(it) }
        screenOffReceiver = null
        setState(State.IDLE)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        if (state != State.IDLE) unlock()
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun setState(newState: State) {
        state = newState
        TileService.requestListeningState(this, ComponentName(this, LockTileService::class.java))
    }

    // ---- notification ----

    private fun goForeground(pending: Boolean) {
        val notification = buildNotification(pending)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun notify(notification: Notification) {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(pending: Boolean): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.channel_name),
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { setShowBadge(false) },
            )
        }
        val unlockIntent = PendingIntent.getService(
            this,
            0,
            Intent(this, LockService::class.java).setAction(ACTION_UNLOCK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_lock)
            .setContentTitle(getString(if (pending) R.string.notif_pending else R.string.notif_locked))
            .setContentText(getString(R.string.notif_text))
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .addAction(
                Notification.Action.Builder(
                    null,
                    getString(if (pending) R.string.cancel else R.string.unlock),
                    unlockIntent,
                ).build(),
            )
            .build()
    }
}
