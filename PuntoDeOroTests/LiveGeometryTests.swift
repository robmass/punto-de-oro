import CoreGraphics
import Testing
@testable import PuntoDeOro

struct LiveGeometryTests {
    /// Half heights from the 40mm design floor to the 49mm Ultra (spec §6).
    private let halfHeights: [CGFloat] = [63, 72, 76, 77, 86, 89, 90]

    @Test func theScoreIsSeventyPercentOfItsHalf() {
        #expect(LiveGeometry.scoreSize(halfHeight: 63) == 63 * 0.7)
        #expect(LiveGeometry.scoreSize(halfHeight: 90) == 90 * 0.7)
    }

    @Test func aTeamLabelAtItsCapStaysClearOfTheScoreOnEveryWatch() {
        for height in halfHeights {
            let score = LiveGeometry.scoreSize(halfHeight: height)
            let gap = (height - score * LiveGeometry.capHeight) / 2
            let label = LiveGeometry.maxTeamLabelSize(halfHeight: height)
            #expect(LiveGeometry.teamLabelInset + label * LiveGeometry.capAndDescent < gap)
        }
    }

    @Test func theCapNeverShrinksATeamLabelBelowItsDefaultSize() {
        for height in halfHeights {
            #expect(LiveGeometry.maxTeamLabelSize(halfHeight: height) >= LiveGeometry.teamLabelSize)
        }
    }

    @Test func largerWatchesLetATeamLabelGrowFurther() {
        #expect(LiveGeometry.maxTeamLabelSize(halfHeight: 90) > LiveGeometry.maxTeamLabelSize(halfHeight: 63) + 4)
    }
}
