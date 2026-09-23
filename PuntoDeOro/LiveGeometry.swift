import CoreGraphics

/// The live screen's pinned geometry. The top bar and strip keep their heights on every watch and
/// the halves split the rest; the score scales with its half and nothing else, so Dynamic Type can
/// never move or shrink it.
enum LiveGeometry {
    /// Tall enough to hold the system clock, which sits lowest (bottom at 33.5pt) on the 49mm Ultra.
    static let topBarHeight: CGFloat = 36
    static let stripHeight: CGFloat = 34

    /// The largest element on screen, as large as its half allows.
    static func scoreSize(halfHeight: CGFloat) -> CGFloat { halfHeight * 0.7 }

    /// The US / THEM label's size at the default Dynamic Type size.
    static let teamLabelSize: CGFloat = 12
    /// From the half's outer edge to the label, clear of the Always On outline.
    static let teamLabelInset: CGFloat = 3
    /// SF's digit (cap) height, and its cap height plus descender, as fractions of the point size.
    static let capHeight: CGFloat = 0.705
    static let capAndDescent: CGFloat = 0.95

    /// A strip chip's size at the default Dynamic Type size, and the most it may scale to: two
    /// stacked still fit the strip.
    static let chipSize: CGFloat = 11
    static let maxChipSize: CGFloat = 13

    /// The largest a US / THEM label may scale to: it sits in the gap between the half's outer edge
    /// and the score's digits, which are centred in the half, and must stay out of them.
    static func maxTeamLabelSize(halfHeight: CGFloat) -> CGFloat {
        let gap = (halfHeight - scoreSize(halfHeight: halfHeight) * capHeight) / 2
        let clearance: CGFloat = 1
        return (gap - teamLabelInset - clearance) / capAndDescent
    }
}
