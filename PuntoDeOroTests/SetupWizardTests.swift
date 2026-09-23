import Testing
@testable import PuntoDeOro

struct SetupWizardTests {
    @Test func aFreshMatchWalksFormatDeuceServeReady() {
        var wizard = SetupWizard(lastRules: nil)
        #expect(wizard.path.isEmpty)

        wizard.choose(.twoSetsPlusSuperTieBreak)
        #expect(wizard.path == [.deuce])
        wizard.choose(.goldenPoint)
        #expect(wizard.path == [.deuce, .serve])
        wizard.choose(firstServer: .them)
        #expect(wizard.path == [.deuce, .serve, .ready])

        #expect(wizard.rules == Rules(format: .twoSetsPlusSuperTieBreak, deuceRule: .goldenPoint, firstServer: .them))
    }

    @Test func aProSetAsksWhatDecidesItAtEightAll() {
        var wizard = SetupWizard(lastRules: nil)

        wizard.choose(.proSet(decider: .tieBreak))
        #expect(wizard.path == [.decider])
        wizard.choose(TieBreak.superTieBreak)
        #expect(wizard.path == [.decider, .deuce])
        wizard.choose(.starPoint)
        wizard.choose(firstServer: .us)

        #expect(wizard.path == [.decider, .deuce, .serve, .ready])
        #expect(wizard.rules.format == .proSet(decider: .superTieBreak))
    }

    @Test func theFormatListStaysFourRows() {
        let wizard = SetupWizard(lastRules: nil)
        #expect(wizard.formatRows == [.threeSets, .twoSetsPlusSuperTieBreak, .proSet(decider: .tieBreak), .infinite])
    }

    @Test func aFirstRunHasNothingToPlayAgain() {
        var wizard = SetupWizard(lastRules: nil)

        wizard.playAgain()

        #expect(wizard.lastRules == nil)
        #expect(wizard.path.isEmpty)
    }

    @Test func playAgainJumpsStraightToServeWithTheLastRules() {
        let last = Rules(format: .proSet(decider: .superTieBreak), deuceRule: .silverPoint, firstServer: .them)
        var wizard = SetupWizard(lastRules: last)

        wizard.playAgain()

        #expect(wizard.path == [.serve])
        #expect(wizard.rules == last)
        wizard.choose(firstServer: .us)
        #expect(wizard.path == [.serve, .ready])
        #expect(wizard.rules == Rules(format: .proSet(decider: .superTieBreak), deuceRule: .silverPoint, firstServer: .us))
    }

    @Test func theLastRulesAreTickedOnEveryScreen() {
        let last = Rules(format: .proSet(decider: .superTieBreak), deuceRule: .starPoint, firstServer: .them)
        let wizard = SetupWizard(lastRules: last)

        #expect(wizard.rules == last)
        #expect(wizard.formatRows.filter(wizard.isTicked) == [.proSet(decider: .superTieBreak)])
    }

    @Test func choosingProSetAgainKeepsItsDecider() throws {
        var wizard = SetupWizard(lastRules: Rules(format: .proSet(decider: .superTieBreak)))

        let proSetRow = try #require(wizard.formatRows.first { $0.proSetDecider != nil })
        wizard.choose(proSetRow)

        #expect(wizard.rules.format == .proSet(decider: .superTieBreak))
        #expect(wizard.path == [.decider])
    }
}
