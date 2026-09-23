import Testing
@testable import PuntoDeOro

struct LiveAccessibilityTests {
    @Test func aHalfReadsItsTeamAndPointScoreAndHowToScoreForIt() {
        let score = Match(pointsWonBy: [.them, .them, .us]).score
        #expect(score.spokenHalf(.them) == SpokenHalf(
            label: "Them", value: "30", hint: "Double-tap to score a point for Them."
        ))
        #expect(score.spokenHalf(.us) == SpokenHalf(
            label: "Us", value: "15", hint: "Double-tap to score a point for Us."
        ))
    }

    @Test func advantageIsSpokenAsAWordAndTieBreakPointsAsNumbers() {
        let advantage = Match(pointsWonBy: [.us, .us, .us, .them, .them, .them, .us]).score
        #expect(advantage.spokenHalf(.us).value == "Advantage")
        #expect(advantage.spokenHalf(.them).value == "40")

        let tieBreak = Match(pointsWonBy: sixAll + [.us, .us, .them]).score
        #expect(tieBreak.spokenHalf(.us).value == "2")
        #expect(tieBreak.spokenHalf(.them).value == "1")
    }

    @Test func theStripReadsGamesThenSetsUsFirst() {
        let match = Match(pointsWonBy: gamesToLove(.us, 6) + gamesToLove(.them, 6) + gamesToLove(.us, 2))
        #expect(match.spokenStrip == "Games 2-0. Sets, Us 6-0, 0-6.")
    }

    @Test func theStripReadsOnlyGamesBeforeTheFirstSetEnds() {
        let match = Match(pointsWonBy: gamesToLove(.us, 4) + gamesToLove(.them, 2))
        #expect(match.spokenStrip == "Games 4-2.")
    }

    @Test func theStripNamesTheDecidingPoint() {
        let match = Match(
            rules: Rules(deuceRule: .goldenPoint),
            pointsWonBy: gamesToLove(.them, 4) + gamesToLove(.us, 6) + gamesToLove(.us, 4)
                + gamesToLove(.them, 3) + [.us, .us, .us, .them, .them, .them]
        )
        #expect(match.spokenStrip == "Games 4-3. Sets, Us 6-4. Golden point.")
    }

    @Test func theStripNamesTheTieBreakAndAChangeOfEndsInIt() {
        #expect(Match(pointsWonBy: sixAll).spokenStrip == "Games 6-6. Tie-break.")
        #expect(Match(pointsWonBy: sixAll + [Team](repeating: .us, count: 6)).spokenStrip
            == "Games 6-6. Tie-break. Change ends.")
    }

    @Test func theStripNamesAChangeOfEndsBetweenGames() {
        #expect(Match(pointsWonBy: gamesToLove(.them, 1)).spokenStrip == "Games 0-1. Change ends.")
    }

    @Test func aSuperTieBreakInPlaceOfTheThirdSetHasNoGamesToRead() {
        let match = Match(
            rules: Rules(format: .twoSetsPlusSuperTieBreak),
            pointsWonBy: gamesToLove(.us, 6) + gamesToLove(.them, 6) + [.us]
        )
        #expect(match.spokenStrip == "Sets, Us 6-0, 0-6. Super tie-break.")
    }

    @Test func anInfiniteMatchReadsItsRunningGameCount() {
        let match = Match(rules: Rules(format: .infinite), pointsWonBy: gamesToLove(.them, 12) + gamesToLove(.us, 2))
        #expect(match.spokenStrip == "Games 2-12.")
    }

    @Test func theStatusShownOnTheStripIsWhatItReads() {
        let match = Match(pointsWonBy: sixAll + [Team](repeating: .us, count: 6))
        #expect(match.stripStatuses == ["Tie-break", "Change ends"])
    }
}
