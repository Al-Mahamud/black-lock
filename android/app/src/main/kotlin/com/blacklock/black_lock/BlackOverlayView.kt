package com.blacklock.black_lock

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.os.SystemClock
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import kotlin.math.max
import kotlin.math.min

/**
 * The pure-black cover. It swallows every touch and the Back key, and calls [onUnlock]
 * when [SwipeDetector] sees a deliberate swipe in any direction.
 */
@SuppressLint("ViewConstructor")
class BlackOverlayView(context: Context, private val onUnlock: () -> Unit) : View(context) {

    private val density = resources.displayMetrics.density
    private val detector = SwipeDetector(minDistancePx = 120 * density)
    private val shownAt = SystemClock.uptimeMillis()

    init {
        setBackgroundColor(Color.BLACK)
        isFocusable = true
        isFocusableInTouchMode = true
        isHapticFeedbackEnabled = true
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        // At least 120dp, or 30% of the short side of the screen, whichever is longer.
        detector.minDistancePx = max(120 * density, 0.3f * min(w, h))
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val t = event.eventTime
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN ->
                // Ignore the finger that just tapped "Lock" (button or tile) still touching down.
                if (t - shownAt < GRACE_MS) detector.cancel() else detector.down(event.x, event.y, t)
            MotionEvent.ACTION_POINTER_DOWN -> detector.extraPointer()
            MotionEvent.ACTION_MOVE -> detector.move(event.x, event.y, t)
            MotionEvent.ACTION_UP -> if (detector.up(event.x, event.y, t)) onUnlock()
            MotionEvent.ACTION_CANCEL -> detector.cancel()
        }
        return true
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // Swallow Back so it can't close the app underneath. Volume keys still work.
        if (event.keyCode == KeyEvent.KEYCODE_BACK) return true
        return super.dispatchKeyEvent(event)
    }

    private companion object {
        const val GRACE_MS = 600L
    }
}
