package com.blacklock.black_lock

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SwipeDetectorTest {

    private val detector = SwipeDetector(minDistancePx = 300f)

    /** Straight swipe from (x0,y0) to (x1,y1) over [ms], with intermediate moves. */
    private fun swipe(x0: Float, y0: Float, x1: Float, y1: Float, ms: Long = 250): Boolean {
        detector.down(x0, y0, 0)
        for (i in 1..9) {
            val f = i / 10f
            detector.move(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, ms * i / 10)
        }
        return detector.up(x1, y1, ms)
    }

    @Test fun swipeUpUnlocks() = assertTrue(swipe(500f, 1500f, 500f, 900f))
    @Test fun swipeDownUnlocks() = assertTrue(swipe(500f, 500f, 500f, 1100f))
    @Test fun swipeLeftUnlocks() = assertTrue(swipe(900f, 1000f, 200f, 1000f))
    @Test fun swipeRightUnlocks() = assertTrue(swipe(100f, 1000f, 800f, 1000f))
    @Test fun diagonalSwipeUnlocks() = assertTrue(swipe(200f, 1400f, 700f, 900f))

    @Test fun tapDoesNotUnlock() {
        detector.down(500f, 500f, 0)
        assertFalse(detector.up(502f, 501f, 80))
    }

    @Test fun shortSwipeDoesNotUnlock() = assertFalse(swipe(500f, 1000f, 500f, 800f))

    @Test fun slowDragDoesNotUnlock() = assertFalse(swipe(500f, 1500f, 500f, 900f, ms = 2500))

    @Test fun secondFingerCancels() {
        detector.down(500f, 1500f, 0)
        detector.move(500f, 1300f, 100)
        detector.extraPointer()
        detector.move(500f, 1100f, 150)
        assertFalse(detector.up(500f, 900f, 200))
    }

    @Test fun zigZagDoesNotUnlock() {
        // Ends 400px away, but walks ~1600px getting there.
        detector.down(0f, 0f, 0)
        detector.move(400f, 300f, 100)
        detector.move(0f, 600f, 200)
        detector.move(400f, 300f, 300)
        assertFalse(detector.up(400f, 0f, 400))
    }

    @Test fun cancelledGestureDoesNotUnlock() {
        detector.down(500f, 1500f, 0)
        detector.cancel()
        assertFalse(detector.up(500f, 900f, 200))
    }

    @Test fun upWithoutDownDoesNotUnlock() = assertFalse(detector.up(500f, 900f, 200))

    @Test fun eachGestureStartsFresh() {
        assertFalse(swipe(500f, 1000f, 500f, 900f))
        assertTrue(swipe(500f, 1500f, 500f, 900f))
        assertFalse(detector.up(500f, 300f, 400))
    }
}
