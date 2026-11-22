package com.blacklock.black_lock

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/** Quick Settings tile: tap to black out the screen from inside any app. */
class LockTileService : TileService() {

    override fun onStartListening() {
        val tile = qsTile ?: return
        tile.state = if (LockService.state == LockService.State.IDLE) Tile.STATE_INACTIVE else Tile.STATE_ACTIVE
        tile.updateTile()
    }

    override fun onClick() {
        if (LockService.state != LockService.State.IDLE) {
            LockService.unlock()
            return
        }
        if (isLocked) unlockAndRun { openLockScreen() } else openLockScreen()
    }

    /**
     * Starting the foreground service goes through a see-through activity: Android always
     * allows that from a visible activity, while a tile tap alone is not guaranteed to be enough.
     */
    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun openLockScreen() {
        val target = if (Settings.canDrawOverlays(this)) StartLockActivity::class.java else MainActivity::class.java
        val intent = Intent(this, target).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
