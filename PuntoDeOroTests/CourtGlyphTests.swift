import Foundation
import Testing

/// The launcher complication's drawing (spec §10), on its 100×100 canvas.
struct CourtGlyphTests {
    /// Half a stroke either side of a centred line: where the ink actually sits.
    private func inked(_ rect: CGRect) -> CGRect {
        rect.insetBy(dx: -CourtGlyph.stroke / 2, dy: -CourtGlyph.stroke / 2)
    }

    @Test func strokesAreAboutSevenPercentOfTheCanvas() {
        #expect((0.06...0.08).contains(CourtGlyph.stroke / CourtGlyph.canvas))
    }

    /// Any closer and the ball and the net merge at ~24pt.
    @Test func theBallSitsWellClearOfTheNet() {
        let netBottom = CourtGlyph.netY + CourtGlyph.stroke / 2
        #expect(CourtGlyph.ball.minY - netBottom >= CourtGlyph.stroke / 2)
    }

    @Test func theBallStaysInsideTheBoxWithoutTouchingIt() {
        let inside = CourtGlyph.box.insetBy(dx: CourtGlyph.stroke / 2, dy: CourtGlyph.stroke / 2)
        #expect(inside.contains(CourtGlyph.ball))
        #expect(CourtGlyph.ball.maxY < inside.maxY)
    }

    @Test func theBoxAndTheNetFitTheCanvas() {
        let canvas = CGRect(x: 0, y: 0, width: CourtGlyph.canvas, height: CourtGlyph.canvas)
        #expect(canvas.contains(inked(CourtGlyph.box)))
        #expect(CourtGlyph.box.minY < CourtGlyph.netY && CourtGlyph.netY < CourtGlyph.box.maxY)
    }
}
