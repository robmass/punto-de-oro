import Testing
@testable import PuntoDeOro

struct HapticTests {
    /// The haptics fired by the next Point, won by this Team after these Points.
    private func haptics(_ team: Team, after winners: [Team], rules: Rules = Rules()) -> [Haptic] {
        var match = Match(rules: rules, pointsWonBy: winners)
        return match.scorePoint(for: team)
    }

    @Test func aPointForUsClicksOnceAndForThemTwice() {
        #expect(haptics(.us, after: [.them]) == [.click])
        #expect(haptics(.them, after: [.us]) == [.click, .click])
    }

    @Test func winningAGameReplacesThePointClicks() {
        let oneAllAtForty = gamesToLove(.us, 1) + [.them, .them, .them]
        #expect(haptics(.them, after: oneAllAtForty) == [.success])
    }

    @Test func winningASetOrTheMatchReplacesTheGameHaptic() {
        let fiveFourAtForty = gamesToLove(.us, 5) + gamesToLove(.them, 4) + [.us, .us, .us]
        #expect(haptics(.us, after: fiveFourAtForty) == [.notification])

        let proSetEightLoveAtForty = gamesToLove(.us, 8) + [.us, .us, .us]
        #expect(haptics(.us, after: proSetEightLoveAtForty, rules: Rules(format: .proSet(decider: .tieBreak)))
            == [.notification])
    }

    @Test func winningTheSuperTieBreakThatReplacesTheThirdSetWinsTheMatch() {
        let oneSetAll = gamesToLove(.us, 6) + gamesToLove(.them, 6)
        let nineLove = [Team](repeating: .them, count: 9)
        #expect(haptics(.them, after: oneSetAll + nineLove, rules: Rules(format: .twoSetsPlusSuperTieBreak))
            == [.notification])
    }

    @Test func reachingADecidingPointAddsARetryAfterThePointHaptic() {
        let golden = Rules(deuceRule: .goldenPoint)
        #expect(haptics(.them, after: [.us, .us, .us, .them, .them], rules: golden) == [.click, .click, .retry])
        #expect(haptics(.us, after: [.us, .us, .them, .them, .them], rules: golden) == [.click, .retry])
    }

    @Test func aDeuceUnderAdvantageIsNoDecidingPoint() {
        #expect(haptics(.them, after: [.us, .us, .us, .them, .them]) == [.click, .click])
    }

    @Test func aChangeOfEndsFollowsTheGameHaptic() {
        #expect(haptics(.us, after: [.us, .us, .us]) == [.success, .directionUp])

        let fiveThreeAtForty = gamesToLove(.us, 5) + gamesToLove(.them, 3) + [.us, .us, .us]
        #expect(haptics(.us, after: fiveThreeAtForty) == [.notification, .directionUp])

        #expect(haptics(.them, after: [.them, .them, .them], rules: Rules(format: .infinite))
            == [.success, .directionUp])

        let tieBreakAtSixFive = sixAll + [.us, .us, .us, .us, .us, .us]
        #expect(haptics(.us, after: tieBreakAtSixFive) == [.notification, .directionUp])
    }

    @Test func insideATieBreakAChangeOfEndsFollowsThePointHaptic() {
        #expect(haptics(.them, after: sixAll + [.us, .us, .us, .us, .us]) == [.click, .click, .directionUp])
        #expect(haptics(.us, after: sixAll + [.us, .us, .us, .us, .us, .them]) == [.click])

        let oneSetAll = gamesToLove(.us, 6) + gamesToLove(.them, 6)
        #expect(haptics(.us, after: oneSetAll + [.them, .them, .them, .them, .them],
                        rules: Rules(format: .twoSetsPlusSuperTieBreak)) == [.click, .directionUp])
    }

    @Test func noPointAfterTheWinningOneFiresNothing() {
        let proSetWon = gamesToLove(.us, 9)
        #expect(haptics(.us, after: proSetWon, rules: Rules(format: .proSet(decider: .tieBreak))).isEmpty)
    }
}
