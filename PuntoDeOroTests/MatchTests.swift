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

    @Test func changeOfEndsIsCuedAfterEveryOddGameOfASetAndClearsOnTheNextPoint() {
        let cues = (0...3).map { Match(pointsWonBy: gamesToLove(.us, $0)).score.isChangeOfEnds }
        #expect(cues == [false, true, false, true])

        #expect(!Match(pointsWonBy: gamesToLove(.us, 1) + [.them]).score.isChangeOfEnds)
    }

    @Test func aSetEndingOnAnOddTotalCuesAtTheSetEnd() {
        let sixThree = gamesToLove(.them, 3) + gamesToLove(.us, 6)
        #expect(Match(pointsWonBy: sixThree).score.isChangeOfEnds)

        let sevenSix = Match(pointsWonBy: sixAll + Array(repeating: .us, count: 7)).score
        #expect(sevenSix.setScores == [[7, 6]])
        #expect(sevenSix.isChangeOfEnds)
    }

    @Test func aSetEndingOnAnEvenTotalCuesAfterTheFirstGameOfTheNextSet() {
        let sixFour = gamesToLove(.them, 4) + gamesToLove(.us, 6)
        #expect(!Match(pointsWonBy: sixFour).score.isChangeOfEnds)
        #expect(Match(pointsWonBy: sixFour + gamesToLove(.them, 1)).score.isChangeOfEnds)
    }

    @Test func inATieBreakChangeOfEndsIsCuedEverySixPoints() {
        #expect(!Match(pointsWonBy: sixAll).score.isChangeOfEnds)

        let alternating = (0..<14).map { $0.isMultiple(of: 2) ? Team.us : .them }
        let cued = (1...13).filter {
            Match(pointsWonBy: sixAll + alternating.prefix($0)).score.isChangeOfEnds
        }
        #expect(cued == [6, 12])
    }

    @Test func undoingBackToABoundaryReshowsTheCue() {
        var match = Match(pointsWonBy: gamesToLove(.us, 1) + [.them])
        #expect(!match.score.isChangeOfEnds)

        match.undo()

        #expect(match.score.isChangeOfEnds)
    }

    @Test func theWinningPointNeverCuesAChangeOfEnds() {
        let sixThree = gamesToLove(.them, 3) + gamesToLove(.us, 6)
        let score = Match(pointsWonBy: sixThree + sixThree).score
        #expect(score.isDecided)
        #expect(!score.isChangeOfEnds)
    }

    @Test func aSuperTieBreakCuesAChangeOfEndsEverySixPoints() {
        let oneSetAll = gamesToLove(.us, 6) + gamesToLove(.them, 6)
        let alternating = (0..<14).map { $0.isMultiple(of: 2) ? Team.us : .them }
        let cued = (1...14).filter {
            let log = oneSetAll + alternating.prefix($0)
            return Match(rules: twoSetsPlusSuperTieBreak, pointsWonBy: log).score.isChangeOfEnds
        }
        #expect(cued == [6, 12])
    }

    @Test func anInfiniteMatchCuesAChangeOfEndsAfterEveryOddGameOfItsRunningCount() {
        let cued = (1...14).filter {
            Match(rules: infinite, pointsWonBy: gamesToLove(.us, $0)).score.isChangeOfEnds
        }
        #expect(cued == [1, 3, 5, 7, 9, 11, 13])
    }

    @Test func aProSetIsWonByTheFirstTeamToNineGamesWithATwoGameLead() {
        let eightSeven = gamesToLove(.us, 8) + gamesToLove(.them, 7)
        #expect(!Match(rules: proSetToTieBreak, pointsWonBy: eightSeven).score.isDecided)

        let nineSeven = gamesToLove(.them, 7) + gamesToLove(.us, 9)
        let score = Match(rules: proSetToTieBreak, pointsWonBy: nineSeven).score
        #expect(score.isDecided)
        #expect(score.winner == .us)
        #expect(score.setScores == [[9, 7]])
    }

    @Test func atEightAllAProSetIsDecidedByATieBreakToSevenAndRecordedNineEight() {
        let eightAll = gamesToLove(.us, 8) + gamesToLove(.them, 8)
        let tieBreak = Match(rules: proSetToTieBreak, pointsWonBy: eightAll).score
        #expect(tieBreak.tieBreak == .tieBreak)

        let tieBreakWon = eightAll + Array(repeating: .them, count: 7)
        let decided = Match(rules: proSetToTieBreak, pointsWonBy: tieBreakWon).score
        #expect(decided.winner == .them)
        #expect(decided.setScores == [[8, 9]])
    }

    @Test func atEightAllAProSetCanBeDecidedByASuperTieBreakToTenAndRecordedNineEight() {
        let eightAll = gamesToLove(.us, 8) + gamesToLove(.them, 8)
        #expect(Match(rules: proSetToSuperTieBreak, pointsWonBy: eightAll).score.tieBreak == .superTieBreak)

        let sevenLoveLog = eightAll + Array(repeating: .us, count: 7)
        let sevenLove = Match(rules: proSetToSuperTieBreak, pointsWonBy: sevenLoveLog).score
        #expect(!sevenLove.isDecided)
        #expect(sevenLove.points(.us) == "7")

        let nineAll = eightAll + Array(repeating: .us, count: 9) + Array(repeating: .them, count: 9)
        let tenNine = Match(rules: proSetToSuperTieBreak, pointsWonBy: nineAll + [.us]).score
        #expect(!tenNine.isDecided)
        #expect(tenNine.points(.us) == "10")
        #expect(tenNine.points(.them) == "9")

        let decided = Match(rules: proSetToSuperTieBreak, pointsWonBy: nineAll + [.us, .us]).score
        #expect(decided.winner == .us)
        #expect(decided.setScores == [[9, 8]])
    }

    @Test func atOneSetAllASuperTieBreakToTenReplacesTheThirdSet() {
        let oneSetAll = gamesToLove(.us, 2) + gamesToLove(.them, 4) + gamesToLove(.us, 4)
            + gamesToLove(.us, 3) + gamesToLove(.them, 6)
        let superTieBreak = Match(rules: twoSetsPlusSuperTieBreak, pointsWonBy: oneSetAll).score
        #expect(superTieBreak.setScores == [[6, 4], [3, 6]])
        #expect(superTieBreak.tieBreak == .superTieBreak)

        let sevenAll = oneSetAll + Array(repeating: .us, count: 7) + Array(repeating: .them, count: 7)
        let nineSeven = Match(rules: twoSetsPlusSuperTieBreak, pointsWonBy: sevenAll + [.us, .us]).score
        #expect(!nineSeven.isDecided)
        #expect(nineSeven.points(.us) == "9")

        let decided = Match(rules: twoSetsPlusSuperTieBreak, pointsWonBy: sevenAll + [.us, .us, .us]).score
        #expect(decided.winner == .us)
        #expect(decided.setScores == [[6, 4], [3, 6], [10, 7]])
        #expect(decided.sets.last?.isSuperTieBreak == true)
    }

    @Test func theThirdSetSuperTieBreakIsServedLikeATieBreak() {
        // 19 Games played, so Them are due to serve the twentieth.
        let oneSetAll = gamesToLove(.us, 2) + gamesToLove(.them, 4) + gamesToLove(.us, 4)
            + gamesToLove(.us, 3) + gamesToLove(.them, 6)
        let servers = (0..<5).map { played in
            let log = oneSetAll + Array(repeating: .us, count: played)
            return Match(rules: twoSetsPlusSuperTieBreak, pointsWonBy: log).score.servingTeam
        }
        #expect(servers == [.them, .us, .us, .them, .them])
    }

    @Test func theDeuceRuleNeverAppliesInsideASuperTieBreak() {
        let goldenPoint = Rules(format: .twoSetsPlusSuperTieBreak, deuceRule: .goldenPoint)
        let oneSetAll = gamesToLove(.us, 6) + gamesToLove(.them, 6)
        let threeAll = oneSetAll + [.us, .us, .us, .them, .them, .them]
        #expect(!Match(rules: goldenPoint, pointsWonBy: threeAll).score.isDecidingPoint)

        let nineAll = oneSetAll + Array(repeating: .us, count: 9) + Array(repeating: .them, count: 9)
        let tenNine = Match(rules: goldenPoint, pointsWonBy: nineAll + [.them]).score
        #expect(!tenNine.isDecided)
        #expect(tenNine.points(.them) == "10")
    }

    @Test func twoSetsToLoveNeedsNoSuperTieBreak() {
        let decided = Match(rules: twoSetsPlusSuperTieBreak, pointsWonBy: gamesToLove(.them, 12)).score
        #expect(decided.winner == .them)
        #expect(decided.setScores == [[0, 6], [0, 6]])
        #expect(decided.tieBreak == nil)
    }

    @Test func anInfiniteMatchKeepsARunningCountOfGamesWithNoSetsOrTieBreaks() {
        let score = Match(rules: infinite, pointsWonBy: gamesToLove(.us, 7) + gamesToLove(.them, 9)).score
        #expect(score.games(.us) == 7)
        #expect(score.games(.them) == 9)
        #expect(score.sets.isEmpty)
        #expect(!score.isTieBreak)
        #expect(!score.isDecided)
    }

    @Test func anInfiniteMatchIsWonOnCompletedGamesOnly() {
        let log = gamesToLove(.them, 3) + gamesToLove(.us, 2) + [.us, .us, .us]
        let score = Match(rules: infinite, pointsWonBy: log).score
        #expect(score.points(.us) == "40")
        #expect(score.result == .won(.them))
    }

    @Test func levelCompletedGamesInAnInfiniteMatchAreADrawWhateverTheUnfinishedGame() {
        let log = gamesToLove(.them, 4) + gamesToLove(.us, 4) + [.us, .us, .us]
        let score = Match(rules: infinite, pointsWonBy: log).score
        #expect(score.result == .draw)
    }

    @Test func aSetBasedMatchEndedBeforeItsWinningPointIsUnfinished() {
        #expect(Match(pointsWonBy: gamesToLove(.us, 8)).score.result == .unfinished)
        #expect(Match(pointsWonBy: gamesToLove(.us, 12)).score.result == .won(.us))
    }
}

private let proSetToTieBreak = Rules(format: .proSet(decider: .tieBreak))
private let proSetToSuperTieBreak = Rules(format: .proSet(decider: .superTieBreak))
private let twoSetsPlusSuperTieBreak = Rules(format: .twoSetsPlusSuperTieBreak)
private let infinite = Rules(format: .infinite)
