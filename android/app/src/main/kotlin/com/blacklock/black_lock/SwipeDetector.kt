package com.blacklock.black_lock

import kotlin.math.hypot

/**
 * Decides whether a one-finger gesture is a deliberate unlock swipe.
 *
 * A swipe counts when, from finger down to finger up:
 *  - only one finger touched the screen,
 *  - the finger ended at least [minDistancePx] away from where it started (any direction),
 *  - it took no longer than [maxDurationMs],
 *  - the path was roughly straight (straight-line distance / path walked >= [minStraightness]).
 *
 * Palms, taps, slow drags and fabric rubbing in a pocket fail at least one of these.
 * Times are in milliseconds from any monotonic clock.
 */
class SwipeDetector(
    var minDistancePx: Float,
    private val maxDurationMs: Long = 1000,
    private val minStraightness: Float = 0.75f,
) {
    private var tracking = false
    private var startX = 0f
    private var startY = 0f
    private var startTime = 0L
    private var lastX = 0f
    private var lastY = 0f
    private var pathLength = 0f

    fun down(x: Float, y: Float, time: Long) {
        tracking = true
        startX = x; startY = y; startTime = time
        lastX = x; lastY = y
        pathLength = 0f
    }

    fun move(x: Float, y: Float, time: Long) {
        if (!tracking) return
        pathLength += hypot(x - lastX, y - lastY)
        lastX = x; lastY = y
        if (time - startTime > maxDurationMs) tracking = false
    }

    /** A second finger landed: this gesture can no longer unlock. */
    fun extraPointer() {
        tracking = false
    }

    fun cancel() {
        tracking = false
    }

    /** Returns true when the gesture that just ended is an unlock swipe. */
    fun up(x: Float, y: Float, time: Long): Boolean {
        move(x, y, time)
        if (!tracking) return false
        tracking = false
        val distance = hypot(x - startX, y - startY)
        if (distance < minDistancePx) return false
        return pathLength > 0f && distance / pathLength >= minStraightness
    }
}
