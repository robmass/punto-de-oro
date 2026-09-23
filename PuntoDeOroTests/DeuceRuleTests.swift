import Testing
@testable import PuntoDeOro

struct DeuceRuleTests {
    @Test func underAdvantageRepeatedReturnsToDeuceAreNeverDecisive() {
        let rules = Rules(deuceRule: .advantage)
        let fourthDeuce = deuce + [.us, .them, .them, .us, .us, .them]
        #expect(!Match(rules: rules, pointsWonBy: deuce).score.isDecidingPoint)
        #expect(!Match(rules: rules, pointsWonBy: fourthDeuce).score.isDecidingPoint)

        let backToAdvantage = Match(rules: rules, pointsWonBy: fourthDeuce + [.them]).score
        #expect(backToAdvantage.points(.them) == "AD")
        #expect(backToAdvantage.games(.them) == 0)
    }

    @Test func underGoldenPointTheFirstDeuceDecides() {
        let rules = Rules(deuceRule: .goldenPoint)
        let atDeuce = Match(rules: rules, pointsWonBy: deuce).score
        #expect(atDeuce.isDecidingPoint)

        let won = Match(rules: rules, pointsWonBy: deuce + [.them]).score
        #expect(won.games(.them) == 1)
        #expect(won.points(.them) == "0")
        #expect(!won.isDecidingPoint)
    }

    @Test func underSilverPointOneAdvantageThenTheSecondDeuceDecides() {
        let rules = Rules(deuceRule: .silverPoint)
        #expect(!Match(rules: rules, pointsWonBy: deuce).score.isDecidingPoint)

        let advantage = Match(rules: rules, pointsWonBy: deuce + [.us]).score
        #expect(advantage.points(.us) == "AD")
        #expect(!advantage.isDecidingPoint)

        let secondDeuce = deuce + [.us, .them]
        #expect(Match(rules: rules, pointsWonBy: secondDeuce).score.isDecidingPoint)

        let won = Match(rules: rules, pointsWonBy: secondDeuce + [.them]).score
        #expect(won.games(.them) == 1)
        #expect(!won.isDecidingPoint)
    }

    @Test func underStarPointTwoAdvantagesThenTheThirdDeuceDecides() {
        let rules = Rules(deuceRule: .starPoint)
        let secondDeuce = deuce + [.us, .them]
        #expect(!Match(rules: rules, pointsWonBy: deuce).score.isDecidingPoint)
        #expect(!Match(rules: rules, pointsWonBy: secondDeuce).score.isDecidingPoint)
        #expect(Match(rules: rules, pointsWonBy: secondDeuce + [.them]).score.points(.them) == "AD")

        let thirdDeuce = secondDeuce + [.them, .us]
        #expect(Match(rules: rules, pointsWonBy: thirdDeuce).score.isDecidingPoint)

        let won = Match(rules: rules, pointsWonBy: thirdDeuce + [.us]).score
        #expect(won.games(.us) == 1)
        #expect(!won.isDecidingPoint)
    }

    @Test func theDeuceCountResetsEveryGame() {
        let rules = Rules(deuceRule: .silverPoint)
        let firstGameWonFromAdvantage = deuce + [.us, .us]
        let score = Match(rules: rules, pointsWonBy: firstGameWonFromAdvantage + deuce).score
        #expect(score.games(.us) == 1)
        #expect(!score.isDecidingPoint)
    }

    @Test func aTieBreakNeverHasADecidingPoint() {
        let rules = Rules(deuceRule: .goldenPoint)
        let threeAll = sixAll + [.us, .them, .us, .them, .us, .them]
        let score = Match(rules: rules, pointsWonBy: threeAll).score
        #expect(score.isTieBreak)
        #expect(!score.isDecidingPoint)

        let fourThree = Match(rules: rules, pointsWonBy: threeAll + [.us]).score
        #expect(fourThree.isTieBreak)
        #expect(fourThree.points(.us) == "4")
    }

    @Test func undoPastADecidingPointClearsItAndUndoToOneRestoresIt() {
        var match = Match(rules: Rules(deuceRule: .goldenPoint), pointsWonBy: deuce + [.us])
        #expect(!match.score.isDecidingPoint)

        match.undo()
        #expect(match.score.isDecidingPoint)

        match.undo()
        #expect(!match.score.isDecidingPoint)
        #expect(match.score.points(.us) == "40")
        #expect(match.score.points(.them) == "30")
    }
}

/// The Points that bring the first Game to its first Deuce.
private let deuce: [Team] = [.us, .us, .us, .them, .them, .them]
