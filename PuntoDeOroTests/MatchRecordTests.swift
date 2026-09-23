import Foundation
import SwiftData
import Testing
@testable import PuntoDeOro

@MainActor
final class MatchRecordTests {
    /// A store on disk, so reopening it stands in for relaunching the app after it died.
    private let storeURL = FileManager.default.temporaryDirectory
        .appending(path: "MatchRecordTests-\(UUID().uuidString).store")
    /// A context does not keep its container alive, so every container opened lives as long as the test.
    private var containers: [ModelContainer] = []

    /// The app relaunched: a fresh container on the same store, sharing nothing in memory.
    private func relaunch() throws -> ModelContext {
        let container = try ModelContainer.matches(ModelConfiguration(url: storeURL))
        containers.append(container)
        return container.mainContext
    }

    @Test func aStartedMatchIsTheCurrentOne() throws {
        let context = try relaunch()
        #expect(try MatchRecord.current(in: context) == nil)

        MatchRecord.start(Rules(deuceRule: .goldenPoint), in: context)

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.state == .inProgress)
        #expect(relaunched.match.points.isEmpty)
        #expect(relaunched.decidedAt == nil)
    }

    @Test(arguments: [
        Rules(format: .threeSets, deuceRule: .advantage, firstServer: .us),
        Rules(format: .twoSetsPlusSuperTieBreak, deuceRule: .goldenPoint, firstServer: .them),
        Rules(format: .proSet(decider: .tieBreak), deuceRule: .silverPoint, firstServer: .us),
        Rules(format: .proSet(decider: .superTieBreak), deuceRule: .starPoint, firstServer: .them),
        Rules(format: .infinite, deuceRule: .advantage, firstServer: .them),
    ])
    func theRulesSurviveARelaunch(rules: Rules) throws {
        MatchRecord.start(rules, in: try relaunch())

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.rules == rules)
    }

    @Test func everyPointIsSavedAsItIsScored() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch())
        let startDate = record.startDate
        let played = Date(timeIntervalSinceReferenceDate: 1_000)
        for (offset, team) in (gamesToLove(.them, 1) + [.us, .us, .them]).enumerated() {
            record.scorePoint(for: team, at: played + Double(offset))
        }

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.match.points.map(\.winner) == gamesToLove(.them, 1) + [.us, .us, .them])
        #expect(relaunched.match.points.last?.timestamp == played + 6)
        #expect(relaunched.startDate == startDate)
        let score = relaunched.match.score
        #expect(score.games(.them) == 1)
        #expect(score.points(.us) == "30")
        #expect(score.points(.them) == "15")
    }

    @Test func undoIsSaved() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch())
        for team: Team in [.us, .them, .us] { record.scorePoint(for: team) }

        #expect(record.undo() == "Undone · point Us · 15–15")

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.match.points.map(\.winner) == [.us, .them])
    }

    @Test func theWinningPointDecidesTheMatchAndUndoReopensIt() throws {
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch())
        let matchPoint = gamesToLove(.us, 8) + gamesToLove(.them, 3) + [.us, .us, .us]
        for team in matchPoint { record.scorePoint(for: team) }
        let winningPoint = Date(timeIntervalSinceReferenceDate: 2_000)
        record.scorePoint(for: .us, at: winningPoint)

        var relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.state == .decided)
        #expect(relaunched.decidedAt == winningPoint)
        #expect(relaunched.match.score.winner == .us)

        record.undo()

        relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.state == .inProgress)
        #expect(relaunched.decidedAt == nil)
    }

    @Test func aPointAfterTheMatchIsDecidedIsNotRecorded() throws {
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch())
        for team in gamesToLove(.us, 9) { record.scorePoint(for: team) }
        let decidedAt = record.decidedAt

        record.scorePoint(for: .them)

        #expect(record.match.points.count == 36)
        #expect(record.decidedAt == decidedAt)
    }

    @Test func finishedRecordsAreKeptButNeverCurrent() throws {
        let context = try relaunch()
        let first = MatchRecord.start(Rules(), in: context)
        first.scorePoint(for: .us)
        first.finish()

        #expect(try MatchRecord.current(in: relaunch()) == nil)
        let kept = try relaunch().fetch(FetchDescriptor<MatchRecord>())
        #expect(kept.count == 1)
        #expect(kept.first?.state == .finished)
        #expect(kept.first?.match.points.count == 1)

        MatchRecord.start(Rules(deuceRule: .starPoint), in: context)

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.rules.deuceRule == .starPoint)
    }

    @Test func theLastRulesAreTheMostRecentRecordsFinishedOrNot() throws {
        let context = try relaunch()
        #expect(try context.fetch(MatchRecord.latestDescriptor).isEmpty)

        MatchRecord.start(Rules(deuceRule: .goldenPoint), at: Date(timeIntervalSinceReferenceDate: 1), in: context)
            .finish()
        let latest = Rules(format: .infinite, deuceRule: .silverPoint, firstServer: .them)
        MatchRecord.start(latest, at: Date(timeIntervalSinceReferenceDate: 2), in: context).finish()

        let relaunched = try relaunch().fetch(MatchRecord.latestDescriptor)
        #expect(relaunched.map(\.rules) == [latest])
    }

    @Test func aFinishedMatchIsFinal() throws {
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch())
        for team in gamesToLove(.us, 9) { record.scorePoint(for: team) }
        record.finish()

        #expect(record.undo() == nil)
        record.scorePoint(for: .them)

        let kept = try #require(try relaunch().fetch(FetchDescriptor<MatchRecord>()).first)
        #expect(kept.state == .finished)
        #expect(kept.match.points.count == 36)
        #expect(kept.decidedAt != nil)
    }

    @Test func savingAnEndedSetBasedMatchDecidesItUnfinished() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch())
        for team in gamesToLove(.us, 1) + [.them, .them] { record.scorePoint(for: team) }
        #expect(record.endNeedsConfirmation)
        let endedAt = Date(timeIntervalSinceReferenceDate: 3_000)

        record.endAndSave(at: endedAt)

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.state == .decided)
        #expect(relaunched.decidedAt == endedAt)
        #expect(relaunched.match.score.result == .unfinished)
        #expect(relaunched.match.points.count == 6)
    }

    @Test func savingAnEndedInfiniteMatchKeepsItsNormalResult() throws {
        let record = MatchRecord.start(Rules(format: .infinite), in: try relaunch())
        for team in gamesToLove(.them, 2) + gamesToLove(.us, 1) + [.us, .us] { record.scorePoint(for: team) }

        record.endAndSave()

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.state == .decided)
        #expect(relaunched.match.score.result == .won(.them))
    }

    @Test func aMatchEndedAndSavedTakesNoMorePoints() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch())
        record.scorePoint(for: .us)
        record.endAndSave()

        record.scorePoint(for: .them)

        #expect(record.match.points.map(\.winner) == [.us])
        #expect(record.state == .decided)
    }

    @Test func abandoningAMatchLeavesNoRecord() throws {
        let context = try relaunch()
        MatchRecord.start(Rules(), in: context).finish()
        let record = MatchRecord.start(Rules(deuceRule: .goldenPoint), in: context)
        record.scorePoint(for: .them)

        record.abandon()

        #expect(try MatchRecord.current(in: relaunch()) == nil)
        let kept = try relaunch().fetch(FetchDescriptor<MatchRecord>())
        #expect(kept.map(\.rules) == [Rules()])
    }

    @Test func anEmptyMatchNeedsNoConfirmationToEnd() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch())
        #expect(!record.endNeedsConfirmation)
        record.scorePoint(for: .us)
        record.undo()
        #expect(!record.endNeedsConfirmation)
    }

    @Test func aDecidedMatchCanNoLongerBeEnded() throws {
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch())
        for team in gamesToLove(.us, 9) { record.scorePoint(for: team) }
        let decidedAt = record.decidedAt
        #expect(!record.canEnd)

        record.endAndSave()
        record.abandon()

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.decidedAt == decidedAt)
        #expect(relaunched.match.score.result == .won(.us))
    }
}
