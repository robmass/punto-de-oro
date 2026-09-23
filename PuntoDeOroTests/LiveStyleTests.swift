import SwiftUI
import Testing
@testable import PuntoDeOro

struct LiveStyleTests {
    @Test func anActiveHalfIsFilledInItsTeamsColours() {
        #expect(LiveStyle.half(.us, isDimmed: false)
            == Paint(fill: Team.us.halfBackground, outline: nil, foreground: Team.us.color))
        #expect(LiveStyle.half(.them, isDimmed: false)
            == Paint(fill: Team.them.halfBackground, outline: nil, foreground: Team.them.color))
    }

    @Test func aDimmedHalfIsOutlinedOnBlackAndKeepsItsTeamColour() {
        #expect(LiveStyle.half(.us, isDimmed: true)
            == Paint(fill: .black, outline: Team.us.color, foreground: Team.us.color))
        #expect(LiveStyle.half(.them, isDimmed: true)
            == Paint(fill: .black, outline: Team.them.color, foreground: Team.them.color))
    }

    @Test func theStripIsFilledActiveAndOutlinedDimmedAndItsGamesKeepTheirTeamColours() {
        #expect(LiveStyle.strip(isDecidingPoint: false, isDimmed: false)
            == Paint(fill: Palette.strip, outline: nil, foreground: .white))
        #expect(LiveStyle.strip(isDecidingPoint: false, isDimmed: true)
            == Paint(fill: .black, outline: Palette.stripOutline, foreground: .white))
        for isDimmed in [false, true] {
            #expect(LiveStyle.games(.us, isDecidingPoint: false, isDimmed: isDimmed) == Team.us.color)
            #expect(LiveStyle.games(.them, isDecidingPoint: false, isDimmed: isDimmed) == Team.them.color)
        }
    }

    @Test func theDecidingPointStripIsSolidGoldActiveAndAGoldOutlineWithGoldTextDimmed() {
        #expect(LiveStyle.strip(isDecidingPoint: true, isDimmed: false)
            == Paint(fill: Palette.gold, outline: nil, foreground: .black))
        #expect(LiveStyle.strip(isDecidingPoint: true, isDimmed: true)
            == Paint(fill: .black, outline: Palette.gold, foreground: Palette.gold))
        #expect(LiveStyle.games(.us, isDecidingPoint: true, isDimmed: false) == .black)
        #expect(LiveStyle.games(.them, isDecidingPoint: true, isDimmed: true) == Palette.gold)
    }

    @Test func goldIsSpentOnlyAtADecidingPoint() {
        for isDimmed in [false, true] {
            let paints = [LiveStyle.strip(isDecidingPoint: false, isDimmed: isDimmed),
                          LiveStyle.half(.us, isDimmed: isDimmed),
                          LiveStyle.half(.them, isDimmed: isDimmed)]
            let colours = paints.flatMap { [$0.fill, $0.outline, $0.foreground].compactMap(\.self) }
                + [Team.us, .them].map { LiveStyle.games($0, isDecidingPoint: false, isDimmed: isDimmed) }
            #expect(!colours.contains(Palette.gold))
        }
    }
}
