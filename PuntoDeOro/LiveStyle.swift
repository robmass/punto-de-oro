import SwiftUI

/// How one surface of the live screen is painted: its background fill, an optional outline drawn
/// inside its edge, and the colour of what sits on it. Neither the fill nor the outline takes part
/// in layout, so repainting a surface never moves it.
struct Paint: Equatable {
    var fill: Color
    var outline: Color?
    var foreground: Color
}

/// The live screen's paint, active and in Always On. Dimmed, every filled background becomes an
/// outline on black in the colour it was filled with, or its text colour, so the team colours
/// survive in text and outlines and nothing lights a whole surface.
enum LiveStyle {
    static func half(_ team: Team, isDimmed: Bool) -> Paint {
        isDimmed
            ? Paint(fill: .black, outline: team.color, foreground: team.color)
            : Paint(fill: team.halfBackground, outline: nil, foreground: team.color)
    }

    /// At a Deciding point the strip turns solid gold with everything on it black; dimmed, it
    /// becomes a gold outline with gold text, the rule's name still readable.
    static func strip(isDecidingPoint: Bool, isDimmed: Bool) -> Paint {
        switch (isDecidingPoint, isDimmed) {
        case (true, false): Paint(fill: Palette.gold, outline: nil, foreground: .black)
        case (true, true): Paint(fill: .black, outline: Palette.gold, foreground: Palette.gold)
        case (false, false): Paint(fill: Palette.strip, outline: nil, foreground: .white)
        case (false, true): Paint(fill: .black, outline: Palette.stripOutline, foreground: .white)
        }
    }

    /// A Team's Games on the strip: in its team colour, except at a Deciding point, where they take
    /// the strip's own colour like everything else on it.
    static func games(_ team: Team, isDecidingPoint: Bool, isDimmed: Bool) -> Color {
        isDecidingPoint
            ? strip(isDecidingPoint: true, isDimmed: isDimmed).foreground
            : team.color
    }
}

enum Palette {
    /// Reserved for the Deciding point strip; spent nowhere else in the app.
    static let gold = Color(red: 0xFF / 255, green: 0xCC / 255, blue: 0x00 / 255)
    static let serveMarker = Color(red: 0xD4 / 255, green: 0xFF / 255, blue: 0x3A / 255)
    static let strip = Color(white: 0x11 / 255)
    /// Brighter than the strip's fill, which would vanish as an outline on black.
    static let stripOutline = Color(white: 0x4D / 255)
}

extension Team {
    var color: Color {
        switch self {
        case .us: Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
        case .them: Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x0A / 255)
        }
    }

    var halfBackground: Color {
        switch self {
        case .us: Color(red: 0x0F / 255, green: 0x3D / 255, blue: 0x1C / 255)
        case .them: Color(red: 0x4A / 255, green: 0x2E / 255, blue: 0x05 / 255)
        }
    }
}
