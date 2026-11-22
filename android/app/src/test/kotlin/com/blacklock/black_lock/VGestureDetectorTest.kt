package com.blacklock.black_lock

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VGestureDetectorTest {

    private val detector = VGestureDetector(minArmPx = 200f)

    /** Draws a stroke through [points] (x, y pairs) over [ms], with 10 moves per segment. */
    private fun stroke(vararg points: Pair<Float, Float>, ms: Long = 500): Boolean {
        val steps = (points.size - 1) * 10
        detector.down(points[0].first, points[0].second, 0)
        var step = 0
        for (s in 0 until points.size - 1) {
            val (x0, y0) = points[s]
            val (x1, y1) = points[s + 1]
            for (i in 1..10) {
                step++
                val f = i / 10f
                val x = x0 + (x1 - x0) * f
                val y = y0 + (y1 - y0) * f
                val t = ms * step / steps
                if (step == steps) return detector.up(x, y, t)
                detector.move(x, y, t)
            }
        }
        error("unreachable")
    }

    private fun p(x: Int, y: Int) = x.toFloat() to y.toFloat()

    // --- Vs that unlock ---

    @Test fun vLeftToRightUnlocks() = assertTrue(stroke(p(300, 800), p(500, 1200), p(700, 800)))
    @Test fun vRightToLeftUnlocks() = assertTrue(stroke(p(700, 800), p(500, 1200), p(300, 800)))
    @Test fun narrowVUnlocks() = assertTrue(stroke(p(410, 700), p(500, 1100), p(590, 700)))
    @Test fun wideVUnlocks() = assertTrue(stroke(p(100, 900), p(500, 1250), p(900, 900)))
    @Test fun lopsidedVUnlocks() = assertTrue(stroke(p(350, 900), p(500, 1200), p(750, 700)))

    @Test fun wobblyVUnlocks() = assertTrue(
        stroke(p(300, 800), p(360, 905), p(390, 1000), p(460, 1110), p(500, 1200),
            p(545, 1095), p(590, 1010), p(640, 905), p(700, 800)),
    )

    // --- gestures that do not unlock ---

    @Test fun tapDoesNotUnlock() {
        detector.down(500f, 500f, 0)
        assertFalse(detector.up(502f, 501f, 80))
    }

    @Test fun straightSwipeDownDoesNotUnlock() = assertFalse(stroke(p(500, 600), p(500, 1300)))
    @Test fun straightSwipeUpDoesNotUnlock() = assertFalse(stroke(p(500, 1300), p(500, 600)))
    @Test fun swipeAcrossDoesNotUnlock() = assertFalse(stroke(p(100, 1000), p(900, 1000)))
    @Test fun diagonalSwipeDoesNotUnlock() = assertFalse(stroke(p(200, 700), p(700, 1300)))

    @Test fun saggingSwipeAcrossDoesNotUnlock() =
        assertFalse(stroke(p(100, 1000), p(500, 1150), p(900, 1000)))

    @Test fun upsideDownVDoesNotUnlock() = assertFalse(stroke(p(300, 1200), p(500, 800), p(700, 1200)))

    @Test fun downAndBackUpSameLineDoesNotUnlock() =
        assertFalse(stroke(p(500, 700), p(510, 1200), p(500, 700)))

    @Test fun bothArmsOnSameSideDoNotUnlock() =
        assertFalse(stroke(p(300, 800), p(500, 1200), p(350, 750)))

    @Test fun tooSmallVDoesNotUnlock() = assertFalse(stroke(p(400, 1000), p(470, 1150), p(540, 1000)))

    @Test fun checkMarkWithShortArmDoesNotUnlock() =
        assertFalse(stroke(p(380, 1050), p(450, 1200), p(750, 700)))

    @Test fun slowVDoesNotUnlock() =
        assertFalse(stroke(p(300, 800), p(500, 1200), p(700, 800), ms = 2500))

    @Test fun wDoesNotUnlock() =
        assertFalse(stroke(p(100, 800), p(300, 1200), p(500, 850), p(700, 1200), p(900, 800)))

    @Test fun secondFingerCancels() {
        detector.down(300f, 800f, 0)
        detector.move(500f, 1200f, 200)
        detector.extraPointer()
        assertFalse(detector.up(700f, 800f, 400))
    }

    @Test fun cancelledGestureDoesNotUnlock() {
        detector.down(300f, 800f, 0)
        detector.move(500f, 1200f, 200)
        detector.cancel()
        assertFalse(detector.up(700f, 800f, 400))
    }

    @Test fun upWithoutDownDoesNotUnlock() = assertFalse(detector.up(500f, 900f, 200))

    @Test fun eachGestureStartsFresh() {
        assertFalse(stroke(p(500, 600), p(500, 1300)))
        assertTrue(stroke(p(300, 800), p(500, 1200), p(700, 800)))
        assertFalse(detector.up(700f, 800f, 600))
    }
}
