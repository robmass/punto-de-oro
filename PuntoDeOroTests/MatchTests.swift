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
}

extension Match {
    /// A Match whose Point log holds these Points, played in order.
    init(pointsWonBy winners: [Team]) {
        self.init()
        for team in winners { scorePoint(for: team) }
    }
}
