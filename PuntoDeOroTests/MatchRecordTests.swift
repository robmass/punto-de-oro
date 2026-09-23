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

    @Test func aStartedMatchIsTheOneToResume() throws {
        let context = try relaunch()
        #expect(try MatchRecord.resumable(in: context) == nil)

        MatchRecord.start(Rules(deuceRule: .goldenPoint), in: context)

        let resumed = try #require(try MatchRecord.resumable(in: relaunch()))
        #expect(resumed.state == .inProgress)
        #expect(resumed.match.points.isEmpty)
        #expect(resumed.decidedAt == nil)
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

        let resumed = try #require(try MatchRecord.resumable(in: relaunch()))
        #expect(resumed.rules == rules)
    }

    @Test func everyPointIsSavedAsItIsScored() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch())
        let startDate = record.startDate
        let played = Date(timeIntervalSinceReferenceDate: 1_000)
        for (offset, team) in (gamesToLove(.them, 1) + [.us, .us, .them]).enumerated() {
            record.scorePoint(for: team, at: played + Double(offset))
        }

        let resumed = try #require(try MatchRecord.resumable(in: relaunch()))
        #expect(resumed.match.points.map(\.winner) == gamesToLove(.them, 1) + [.us, .us, .them])
        #expect(resumed.match.points.last?.timestamp == played + 6)
        #expect(resumed.startDate == startDate)
        let score = resumed.match.score
        #expect(score.games(.them) == 1)
        #expect(score.points(.us) == "30")
        #expect(score.points(.them) == "15")
    }

    @Test func undoIsSaved() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch())
        for team: Team in [.us, .them, .us] { record.scorePoint(for: team) }

        #expect(record.undo() == "Undone · point Us · 15–15")

        let resumed = try #require(try MatchRecord.resumable(in: relaunch()))
        #expect(resumed.match.points.map(\.winner) == [.us, .them])
    }

    @Test func theWinningPointDecidesTheMatchAndUndoReopensIt() throws {
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch())
        for team in gamesToLove(.us, 8) + gamesToLove(.them, 3) + [.us, .us, .us] { record.scorePoint(for: team) }
        let winningPoint = Date(timeIntervalSinceReferenceDate: 2_000)
        record.scorePoint(for: .us, at: winningPoint)

        var resumed = try #require(try MatchRecord.resumable(in: relaunch()))
        #expect(resumed.state == .decided)
        #expect(resumed.decidedAt == winningPoint)
        #expect(resumed.match.score.winner == .us)

        record.undo()

        resumed = try #require(try MatchRecord.resumable(in: relaunch()))
        #expect(resumed.state == .inProgress)
        #expect(resumed.decidedAt == nil)
    }

    @Test func aPointAfterTheMatchIsDecidedIsNotRecorded() throws {
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch())
        for team in gamesToLove(.us, 9) { record.scorePoint(for: team) }
        let decidedAt = record.decidedAt

        record.scorePoint(for: .them)

        #expect(record.match.points.count == 36)
        #expect(record.decidedAt == decidedAt)
    }

    @Test func finishedRecordsAreKeptButNeverResumed() throws {
        let context = try relaunch()
        let first = MatchRecord.start(Rules(), in: context)
        first.scorePoint(for: .us)
        first.finish()

        #expect(try MatchRecord.resumable(in: relaunch()) == nil)
        let kept = try relaunch().fetch(FetchDescriptor<MatchRecord>())
        #expect(kept.count == 1)
        #expect(kept.first?.state == .finished)
        #expect(kept.first?.match.points.count == 1)

        MatchRecord.start(Rules(deuceRule: .starPoint), in: context)

        let resumed = try #require(try MatchRecord.resumable(in: relaunch()))
        #expect(resumed.rules.deuceRule == .starPoint)
    }
}
