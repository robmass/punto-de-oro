import Testing
@testable import PuntoDeOro

struct MatchSummaryTests {
    /// The Points of a Set won 6–4 by this Team.
    private func sixFour(_ team: Team) -> [Team] {
        gamesToLove(team, 5) + gamesToLove(team.opponent, 4) + gamesToLove(team, 1)
    }

    /// The Points of a tie-break this Team wins by two, the other Team reaching `loserPoints`.
    private func tieBreak(wonBy team: Team, loserPoints: Int, target: Int = 7) -> [Team] {
        Array(repeating: [team, team.opponent], count: loserPoints).flatMap { $0 }
            + Array(repeating: team, count: max(target - loserPoints, 2))
    }

    @Test func theHeaderNamesTheWinnerADrawOrAnUnfinishedMatch() {
        #expect(Match.Result.won(.us).title == "Us win")
        #expect(Match.Result.won(.them).title == "Them win")
        #expect(Match.Result.draw.title == "Draw")
        #expect(Match.Result.unfinished.title == "Unfinished")
    }

    @Test func eachSetIsAColumnUsFirstWithTheTieBreakLosersPointsRaised() {
        let match = Match(pointsWonBy: sixFour(.us) + sixFour(.them) + sixAll + tieBreak(wonBy: .us, loserPoints: 5))

        #expect(match.score.isDecided)
        #expect(match.score.summary == "6–4 4–6 7–6⁽⁵⁾")
    }

    @Test func aTieBreakLostByUsRaisesOurPointsAndTwoDigitsStayRaised() {
        let match = Match(pointsWonBy: sixFour(.them) + sixAll + tieBreak(wonBy: .them, loserPoints: 12))

        #expect(match.score.summary == "4–6 6–7⁽¹²⁾")
    }

    @Test func aSuperTieBreakShowsItsPoints() {
        let match = Match(
            rules: Rules(format: .twoSetsPlusSuperTieBreak),
            pointsWonBy: sixFour(.us) + sixFour(.them) + tieBreak(wonBy: .us, loserPoints: 8, target: 10)
        )

        #expect(match.score.isDecided)
        #expect(match.score.summary == "6–4 4–6 10–8")
    }

    @Test func aProSetDecidedByASuperTieBreakIsNineEightWithItsDetail() {
        let eightAll = gamesToLove(.us, 8) + gamesToLove(.them, 8)
        let match = Match(
            rules: Rules(format: .proSet(decider: .superTieBreak)),
            pointsWonBy: eightAll + tieBreak(wonBy: .them, loserPoints: 6, target: 10)
        )

        #expect(match.score.summary == "8–9⁽⁶⁾")
    }

    @Test func anUnfinishedMatchAddsTheSetAndGameAsTheyStood() {
        let match = Match(pointsWonBy: sixFour(.us) + gamesToLove(.us, 3) + gamesToLove(.them, 4) + [.us, .us, .them])

        #expect(match.score.result == .unfinished)
        #expect(match.score.summary == "6–4 3–4 (30–15)")
    }

    @Test func anUnfinishedMatchBetweenGamesShowsNoPoints() {
        let match = Match(pointsWonBy: sixFour(.us) + gamesToLove(.them, 1))

        #expect(match.score.summary == "6–4 0–1")
    }

    @Test func anUnfinishedTieBreakShowsItsPoints() {
        let match = Match(pointsWonBy: sixAll + [.us, .us, .them])

        #expect(match.score.summary == "6–6 (2–1)")
    }

    @Test func anUnfinishedSuperTieBreakShowsOnlyItsPointsAfterTheSets() {
        let match = Match(
            rules: Rules(format: .twoSetsPlusSuperTieBreak),
            pointsWonBy: sixFour(.us) + sixFour(.them) + [.us, .them, .them]
        )

        #expect(match.score.summary == "6–4 4–6 (1–2)")
    }

    @Test func anInfiniteMatchShowsItsCompletedGamesOnly() {
        let match = Match(
            rules: Rules(format: .infinite),
            pointsWonBy: gamesToLove(.us, 14) + gamesToLove(.them, 11) + [.them, .them]
        )

        #expect(match.score.summary == "14–11")
    }

    @Test func theStatsLineShowsActiveEnergyAndAverageHeartRate() {
        #expect(WorkoutStats(activeEnergy: 412.6, averageHeartRate: 131.4).line == "413 kcal · 131 bpm avg")
        #expect(WorkoutStats().line == "– kcal · – bpm avg")
    }
}
