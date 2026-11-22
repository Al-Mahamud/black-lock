package com.blacklock.black_lock

import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * Decides whether a one-finger gesture is a deliberately drawn "V" (the unlock gesture).
 *
 * The lowest point of the stroke is the V's tip. The gesture counts when, from finger down to finger up:
 *  - only one finger touched the screen, and it took no longer than [maxDurationMs],
 *  - the tip lies between the start and the end: the two arms go up to opposite sides,
 *  - each arm rises at least [minArmPx] from the tip,
 *  - each arm is slanted: neither a vertical line (down and back up the same way)
 *    nor a near-horizontal one (a sideways swipe that sags a little),
 *  - each arm is roughly straight (straight-line length / path walked >= [minStraightness]).
 *
 * Either drawing direction works (left arm first, or right arm first).
 * Taps, straight swipes, an upside-down V, zig-zags and pocket rubbing fail at least one rule.
 * Times are in milliseconds from any monotonic clock.
 */
class VGestureDetector(
    var minArmPx: Float,
    private val maxDurationMs: Long = 1500,
    private val minStraightness: Float = 0.8f,
) {
    private var tracking = false
    private var startTime = 0L
    private val xs = ArrayList<Float>()
    private val ys = ArrayList<Float>()

    fun down(x: Float, y: Float, time: Long) {
        tracking = true
        startTime = time
        xs.clear(); ys.clear()
        add(x, y)
    }

    fun move(x: Float, y: Float, time: Long) {
        if (!tracking) return
        if (time - startTime > maxDurationMs) {
            tracking = false
            return
        }
        add(x, y)
    }

    /** A second finger landed: this gesture can no longer unlock. */
    fun extraPointer() {
        tracking = false
    }

    fun cancel() {
        tracking = false
    }

    /** Returns true when the gesture that just ended is a V. */
    fun up(x: Float, y: Float, time: Long): Boolean {
        move(x, y, time)
        if (!tracking) return false
        tracking = false
        return isV()
    }

    private fun add(x: Float, y: Float) {
        if (xs.size >= MAX_POINTS) {
            tracking = false
            return
        }
        xs.add(x); ys.add(y)
    }

    private fun isV(): Boolean {
        val last = xs.size - 1
        if (last < 2) return false
        // Screen y grows downwards, so the tip is the point with the largest y.
        var tip = 0
        for (i in 1..last) if (ys[i] > ys[tip]) tip = i
        if (tip == 0 || tip == last) return false
        val opposite = (xs[0] - xs[tip]) * (xs[last] - xs[tip]) < 0
        return opposite && isArm(0, tip) && isArm(last, tip)
    }

    /** The stroke between point [end] (top of the arm) and point [tip] is one arm of a V. */
    private fun isArm(end: Int, tip: Int): Boolean {
        val dx = abs(xs[tip] - xs[end])
        val dy = ys[tip] - ys[end]
        if (dy < minArmPx) return false
        if (dx < MIN_SLANT * dy) return false // too close to vertical
        if (dy < MIN_STEEPNESS * dx) return false // too close to horizontal
        var path = 0f
        for (i in min(end, tip) until max(end, tip)) {
            path += hypot(xs[i + 1] - xs[i], ys[i + 1] - ys[i])
        }
        return path > 0f && hypot(dx, dy) / path >= minStraightness
    }

    private companion object {
        /** Each arm's sideways travel must be at least this share of its height (about 11° off vertical). */
        const val MIN_SLANT = 0.2f

        /** Each arm's height must be at least this share of its sideways travel (about 22° off horizontal). */
        const val MIN_STEEPNESS = 0.4f

        /** Plenty for 1.5 s of touch events; a longer stream is not a quick V. */
        const val MAX_POINTS = 1000
    }
}
