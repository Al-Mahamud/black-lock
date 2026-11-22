package com.blacklock.black_lock

import android.app.Activity
import android.os.Bundle

/** Invisible, instant activity the tile opens: it starts the lock and closes straight away. */
class StartLockActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        LockService.lock(this)
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }
}
