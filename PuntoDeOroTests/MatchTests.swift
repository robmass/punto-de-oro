import Testing
@testable import PuntoDeOro

struct MatchTests {
    @Test func aNewMatchIsLoveAllWithUsServing() {
        let score = Match().score
        #expect(score.points(.us) == "0")
        #expect(score.points(.them) == "0")
        #expect(score.games(.us) == 0)
        #expect(score.games(.them) == 0)
        #expect(score.servingTeam == .us)
    }

    @Test func pointsWithinAGameCountFifteenThirtyForty() {
        let score = Match(pointsWonBy: [.us, .us, .them, .us]).score
        #expect(score.points(.us) == "40")
        #expect(score.points(.them) == "15")
    }

    @Test func winningAGameAddsToTheTallyAndResetsThePointScore() {
        let score = Match(pointsWonBy: [.them, .them, .us, .them, .them]).score
        #expect(score.games(.them) == 1)
        #expect(score.games(.us) == 0)
        #expect(score.points(.them) == "0")
        #expect(score.points(.us) == "0")
    }

    @Test func serveAlternatesEveryGame() {
        let oneGame = Match(pointsWonBy: [.us, .us, .us, .us])
        #expect(oneGame.score.servingTeam == .them)

        let twoGames = Match(pointsWonBy: [.us, .us, .us, .us, .them, .them, .them, .them])
        #expect(twoGames.score.servingTeam == .us)
    }

    @Test func fromDeuceUnderAdvantageAGameNeedsTwoPointsInARow() {
        let deuce: [Team] = [.us, .us, .us, .them, .them, .them]
        #expect(Match(pointsWonBy: deuce).score.points(.us) == "40")

        let advantage = Match(pointsWonBy: deuce + [.them]).score
        #expect(advantage.points(.them) == "AD")
        #expect(advantage.points(.us) == "40")

        let backToDeuce = Match(pointsWonBy: deuce + [.them, .us]).score
        #expect(backToDeuce.points(.them) == "40")
        #expect(backToDeuce.games(.them) == 0)

        let won = Match(pointsWonBy: deuce + [.them, .us, .them, .them]).score
        #expect(won.games(.them) == 1)
    }

    @Test func undoAcrossAGameBoundaryRestoresThePointScoreAndServe() {
        var match = Match(pointsWonBy: [.us, .them, .us, .us, .us])
        #expect(match.score.games(.us) == 1)
        #expect(match.score.servingTeam == .them)

        match.undo()

        let score = match.score
        #expect(score.games(.us) == 0)
        #expect(score.points(.us) == "40")
        #expect(score.points(.them) == "15")
        #expect(score.servingTeam == .us)
    }

    @Test func undoIsUnlimitedBackToAnEmptyLog() {
        var match = Match(pointsWonBy: [.us, .them, .us, .us, .us, .them])
        for _ in 0..<6 { match.undo() }
        #expect(match.points.isEmpty)
        #expect(match.undo() == nil)
        #expect(match.points.isEmpty)
    }

    @Test func undoNamesThePointItRemovedAndTheScoreItLeaves() {
        var match = Match(pointsWonBy: [.us, .us, .them, .them])
        #expect(match.undo() == "Undone · point Them · 30–15")
    }

    @Test func aSetIsWonByTheFirstTeamToSixGamesWithATwoGameLead() {
        let fiveAll = gamesToLove(.us, 5) + gamesToLove(.them, 5)
        #expect(Match(pointsWonBy: fiveAll + gamesToLove(.us, 1)).score.sets.isEmpty)

        let score = Match(pointsWonBy: fiveAll + gamesToLove(.us, 2)).score
        #expect(score.setScores == [[7, 5]])
        #expect(score.games(.us) == 0)
        #expect(score.games(.them) == 0)
    }

    @Test func atSixAllATieBreakIsPlayedToSevenWinByTwoAndTheSetIsRecordedSevenSix() {
        #expect(Match(pointsWonBy: sixAll).score.isTieBreak)

        let threeTwo = Match(pointsWonBy: sixAll + [.us, .them, .us, .them, .us]).score
        #expect(threeTwo.points(.us) == "3")
        #expect(threeTwo.points(.them) == "2")

        let sixAllInTheTieBreak = sixAll + Array(repeating: .us, count: 6) + Array(repeating: .them, count: 6)
        let sevenSix = Match(pointsWonBy: sixAllInTheTieBreak + [.them]).score
        #expect(sevenSix.isTieBreak)
        #expect(sevenSix.points(.them) == "7")
        #expect(sevenSix.sets.isEmpty)

        let won = Match(pointsWonBy: sixAllInTheTieBreak + [.them, .us, .them, .them]).score
        #expect(!won.isTieBreak)
        #expect(won.setScores == [[6, 7]])
    }

    @Test func inATieBreakTheTeamDueServesOnePointThenServeChangesEveryTwo() {
        let servers = (0..<6).map { played in
            Match(pointsWonBy: sixAll + Array(repeating: .them, count: played)).score.servingTeam
        }
        #expect(servers == [.us, .them, .them, .us, .us, .them])
    }

    @Test func theNextSetIsServedFirstByTheTeamThatDidNotServeFirstInTheTieBreak() {
        #expect(Match(pointsWonBy: sixAll).score.servingTeam == .us)

        let nextSet = Match(pointsWonBy: sixAll + Array(repeating: .us, count: 7)).score
        #expect(nextSet.sets.count == 1)
        #expect(nextSet.servingTeam == .them)
    }

    @Test func winningTwoSetsDecidesTheMatch() {
        let firstSetInATieBreak = sixAll + [.them, .us, .us, .us, .them, .us, .them, .them, .us, .them, .us, .us]
        let thirdSet = gamesToLove(.them, 3) + gamesToLove(.us, 6)
        let log = firstSetInATieBreak + gamesToLove(.them, 6) + thirdSet

        let beforeMatchPoint = Match(pointsWonBy: log.dropLast())
        #expect(!beforeMatchPoint.score.isDecided)

        let decided = Match(pointsWonBy: log).score
        #expect(decided.isDecided)
        #expect(decided.winner == .us)
        #expect(decided.setScores == [[7, 6], [0, 6], [6, 3]])
    }

    @Test func aDecidedMatchTakesNoMorePoints() {
        var match = Match(pointsWonBy: gamesToLove(.them, 12))
        #expect(match.score.isDecided)

        match.scorePoint(for: .us)

        #expect(match.points.count == 48)
        #expect(match.score.points(.us) == "0")
    }

    @Test func undoRewindsAcrossSetAndTieBreakBoundariesServeIncluded() {
        var match = Match(pointsWonBy: sixAll + [.them, .them, .them, .them, .them, .them, .them])
        #expect(match.score.sets.count == 1)
        #expect(match.score.servingTeam == .them)

        match.undo()

        let score = match.score
        #expect(score.sets.isEmpty)
        #expect(score.isTieBreak)
        #expect(score.points(.them) == "6")
        #expect(score.points(.us) == "0")
        #expect(score.servingTeam == .them)
        #expect(score.games(.us) == 6)
    }

    @Test func undoReopensADecidedMatch() {
        var match = Match(pointsWonBy: gamesToLove(.them, 12))
        match.undo()

        let score = match.score
        #expect(!score.isDecided)
        #expect(score.sets.count == 1)
        #expect(score.games(.them) == 5)
        #expect(score.points(.them) == "40")
        #expect(score.servingTeam == .them)
    }
}

/// The Points that win this many Games in a row to love.
private func gamesToLove(_ team: Team, _ count: Int) -> [Team] {
    Array(repeating: team, count: 4 * count)
}

/// The Points that bring the first Set level at 6–6, with Us due to serve the Tie-break.
private let sixAll = gamesToLove(.us, 5) + gamesToLove(.them, 6) + gamesToLove(.us, 1)

extension Score {
    /// The completed Sets as [Us, Them] Games.
    var setScores: [[Int]] { sets.map { [$0.games(.us), $0.games(.them)] } }
}

extension Match {
    /// A Match whose Point log holds these Points, played in order.
    init(pointsWonBy winners: [Team]) {
        self.init()
        for team in winners { scorePoint(for: team) }
    }
}
