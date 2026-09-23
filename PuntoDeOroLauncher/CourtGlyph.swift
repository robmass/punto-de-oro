import SwiftUI
import WidgetKit

/// The launcher complication's drawing (spec §10): the icon's court reduced to box, net and ball.
///
/// A separate drawing, not an export of the icon — stripped of colour at 24pt the icon's service
/// lines merge into a striped ladder, so they and the centre line are dropped and the strokes
/// thickened. Drawn in the foreground style and `.widgetAccentable()`, so the system paints it:
/// the ball reads as a solid mass, never as gold.
struct CourtGlyph: View {
    /// The side of the square canvas the geometry below is drawn on.
    nonisolated static let canvas: CGFloat = 100
    nonisolated static let box = CGRect(x: 22, y: 16, width: 56, height: 68)
    nonisolated static let boxCornerRadius: CGFloat = 5
    nonisolated static let netY: CGFloat = 50
    nonisolated static let stroke: CGFloat = 7
    /// A solid ball of radius 7 centred at (63, 65), on the near court clear of the net.
    nonisolated static let ball = CGRect(x: 56, y: 58, width: 14, height: 14)

    var body: some View {
        ZStack {
            GlyphElement(Path(roundedRect: Self.box, cornerRadius: Self.boxCornerRadius), stroke: Self.stroke)
            GlyphElement(Path { net in
                net.addLines([CGPoint(x: Self.box.minX, y: Self.netY), CGPoint(x: Self.box.maxX, y: Self.netY)])
            }, stroke: Self.stroke)
            GlyphElement(Path(ellipseIn: Self.ball))
        }
        .aspectRatio(1, contentMode: .fit)
        .widgetAccentable()
    }
}

/// One element of the glyph, drawn on the 100-unit canvas and scaled to the largest centred square
/// that fits. Stroked elements are filled as their outline, so every element fills in one style.
private struct GlyphElement: Shape {
    let canvasPath: Path

    init(_ path: Path, stroke: CGFloat? = nil) {
        canvasPath = stroke.map { path.strokedPath(StrokeStyle(lineWidth: $0)) } ?? path
    }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / CourtGlyph.canvas
        let transform = CGAffineTransform(
            translationX: rect.midX - CourtGlyph.canvas / 2 * scale,
            y: rect.midY - CourtGlyph.canvas / 2 * scale
        ).scaledBy(x: scale, y: scale)
        return canvasPath.applying(transform)
    }
}

#Preview {
    CourtGlyph()
        .frame(width: 48, height: 48)
}
