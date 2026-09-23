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
    /// Stands in for the Health workout every Match runs as.
    private let workout = WorkoutSpy()

    /// The app relaunched: a fresh container on the same store, sharing nothing in memory.
    private func relaunch() throws -> ModelContext {
        let container = try ModelContainer.matches(ModelConfiguration(url: storeURL))
        containers.append(container)
        return container.mainContext
    }

    @Test func aStartedMatchIsTheCurrentOne() throws {
        let context = try relaunch()
        #expect(try MatchRecord.current(in: context) == nil)

        MatchRecord.start(Rules(deuceRule: .goldenPoint), in: context, workout: workout)

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
        MatchRecord.start(rules, in: try relaunch(), workout: workout)

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.rules == rules)
    }

    @Test func everyPointIsSavedAsItIsScored() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch(), workout: workout)
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
        let record = MatchRecord.start(Rules(), in: try relaunch(), workout: workout)
        for team: Team in [.us, .them, .us] { record.scorePoint(for: team) }

        #expect(record.undo() == "Undone · point Us · 15–15")

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.match.points.map(\.winner) == [.us, .them])
    }

    @Test func theWinningPointDecidesTheMatchAndUndoReopensIt() throws {
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch(), workout: workout)
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
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch(), workout: workout)
        for team in gamesToLove(.us, 9) { record.scorePoint(for: team) }
        let decidedAt = record.decidedAt

        record.scorePoint(for: .them)

        #expect(record.match.points.count == 36)
        #expect(record.decidedAt == decidedAt)
    }

    @Test func finishedRecordsAreKeptButNeverCurrent() throws {
        let context = try relaunch()
        let first = MatchRecord.start(Rules(), in: context, workout: workout)
        first.scorePoint(for: .us)
        first.finish(workout: workout)

        #expect(try MatchRecord.current(in: relaunch()) == nil)
        let kept = try relaunch().fetch(FetchDescriptor<MatchRecord>())
        #expect(kept.count == 1)
        #expect(kept.first?.state == .finished)
        #expect(kept.first?.match.points.count == 1)

        MatchRecord.start(Rules(deuceRule: .starPoint), in: context, workout: workout)

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.rules.deuceRule == .starPoint)
    }

    @Test func theLastRulesAreTheMostRecentRecordsFinishedOrNot() throws {
        let context = try relaunch()
        #expect(try context.fetch(MatchRecord.latestDescriptor).isEmpty)

        MatchRecord.start(Rules(deuceRule: .goldenPoint), at: Date(timeIntervalSinceReferenceDate: 1), in: context, workout: workout)
            .finish(workout: workout)
        let latest = Rules(format: .infinite, deuceRule: .silverPoint, firstServer: .them)
        MatchRecord.start(latest, at: Date(timeIntervalSinceReferenceDate: 2), in: context, workout: workout).finish(workout: workout)

        let relaunched = try relaunch().fetch(MatchRecord.latestDescriptor)
        #expect(relaunched.map(\.rules) == [latest])
    }

    @Test func aFinishedMatchIsFinal() throws {
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch(), workout: workout)
        for team in gamesToLove(.us, 9) { record.scorePoint(for: team) }
        record.finish(workout: workout)

        #expect(record.undo() == nil)
        record.scorePoint(for: .them)

        let kept = try #require(try relaunch().fetch(FetchDescriptor<MatchRecord>()).first)
        #expect(kept.state == .finished)
        #expect(kept.match.points.count == 36)
        #expect(kept.decidedAt != nil)
    }

    @Test func savingAnEndedSetBasedMatchDecidesItUnfinished() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch(), workout: workout)
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
        let record = MatchRecord.start(Rules(format: .infinite), in: try relaunch(), workout: workout)
        for team in gamesToLove(.them, 2) + gamesToLove(.us, 1) + [.us, .us] { record.scorePoint(for: team) }

        record.endAndSave()

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.state == .decided)
        #expect(relaunched.match.score.result == .won(.them))
    }

    @Test func aMatchEndedAndSavedTakesNoMorePoints() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch(), workout: workout)
        record.scorePoint(for: .us)
        record.endAndSave()

        record.scorePoint(for: .them)

        #expect(record.match.points.map(\.winner) == [.us])
        #expect(record.state == .decided)
    }

    @Test func abandoningAMatchLeavesNoRecord() throws {
        let context = try relaunch()
        MatchRecord.start(Rules(), in: context, workout: workout).finish(workout: workout)
        let record = MatchRecord.start(Rules(deuceRule: .goldenPoint), in: context, workout: workout)
        record.scorePoint(for: .them)

        record.abandon(workout: workout)

        #expect(try MatchRecord.current(in: relaunch()) == nil)
        let kept = try relaunch().fetch(FetchDescriptor<MatchRecord>())
        #expect(kept.map(\.rules) == [Rules()])
    }

    @Test func anEmptyMatchNeedsNoConfirmationToEnd() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch(), workout: workout)
        #expect(!record.endNeedsConfirmation)
        record.scorePoint(for: .us)
        record.undo()
        #expect(!record.endNeedsConfirmation)
    }

    @Test func aDecidedMatchCanNoLongerBeEnded() throws {
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch(), workout: workout)
        for team in gamesToLove(.us, 9) { record.scorePoint(for: team) }
        let decidedAt = record.decidedAt
        #expect(!record.canEnd)

        record.endAndSave()
        record.abandon(workout: workout)

        let relaunched = try #require(try MatchRecord.current(in: relaunch()))
        #expect(relaunched.decidedAt == decidedAt)
        #expect(relaunched.match.score.result == .won(.us))
    }

    // MARK: - The workout

    @Test func startingAMatchBeginsItsWorkoutAtTheStart() throws {
        let startDate = Date(timeIntervalSinceReferenceDate: 500)

        MatchRecord.start(Rules(), at: startDate, in: try relaunch(), workout: workout)

        #expect(workout.calls == [.begin(startDate)])
    }

    @Test func theWorkoutNeverPausesBeforeTheMatchIsFinished() throws {
        let startDate = Date(timeIntervalSinceReferenceDate: 500)
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), at: startDate, in: try relaunch(), workout: workout)
        for team in gamesToLove(.us, 9) { record.scorePoint(for: team) }
        record.undo()
        record.scorePoint(for: .us)
        record.endAndSave()

        #expect(workout.calls == [.begin(startDate)])
    }

    @Test func finishingSavesTheWorkoutBackdatedToTheDecidedMoment() throws {
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch(), workout: workout)
        let played = Date(timeIntervalSinceReferenceDate: 1_000)
        for (offset, team) in gamesToLove(.us, 9).enumerated() {
            record.scorePoint(for: team, at: played + Double(offset))
        }
        let decidedAt = try #require(record.decidedAt)
        workout.calls.removeAll()

        record.finish(workout: workout)

        #expect(decidedAt == played + 35)
        #expect(workout.calls == [.end(decidedAt)])
    }

    @Test func finishingAMatchEndedEarlyBackdatesItsWorkoutToTheEnd() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch(), workout: workout)
        record.scorePoint(for: .them)
        let endedAt = Date(timeIntervalSinceReferenceDate: 3_000)
        record.endAndSave(at: endedAt)
        workout.calls.removeAll()

        record.finish(workout: workout)

        #expect(workout.calls == [.end(endedAt)])
    }

    @Test func aMatchIsFinishedOnceAndSavesOneWorkout() throws {
        let record = MatchRecord.start(Rules(format: .proSet(decider: .tieBreak)), in: try relaunch(), workout: workout)
        for team in gamesToLove(.us, 9) { record.scorePoint(for: team) }
        workout.calls.removeAll()

        record.finish(workout: workout)
        record.finish(workout: workout)

        #expect(workout.calls.count == 1)
    }

    @Test(arguments: [[Team](), [.us, .them]])
    func abandoningAMatchDiscardsItsWorkout(pointsWonBy winners: [Team]) throws {
        let record = MatchRecord.start(Rules(), in: try relaunch(), workout: workout)
        for team in winners { record.scorePoint(for: team) }
        workout.calls.removeAll()

        record.abandon(workout: workout)

        #expect(workout.calls == [.discard])
    }

    @Test func aDecidedMatchKeepsItsWorkout() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch(), workout: workout)
        record.scorePoint(for: .us)
        record.endAndSave()
        workout.calls.removeAll()

        record.abandon(workout: workout)

        #expect(workout.calls.isEmpty)
    }

    // MARK: - Recovery

    @Test func aRecentMatchComesBackInProgressOnItsWorkout() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch(), workout: workout)
        let played = Date(timeIntervalSinceReferenceDate: 1_000)
        for (offset, team) in [Team.us, .them, .us].enumerated() {
            record.scorePoint(for: team, at: played + Double(offset))
        }
        workout.calls.removeAll()

        let context = try relaunch()
        MatchRecord.recoverCurrent(in: context, workout: workout, at: played + 2 + 60 * 60)

        let recovered = try #require(try MatchRecord.current(in: context))
        #expect(recovered.state == .inProgress)
        #expect(recovered.match.points.map(\.winner) == [.us, .them, .us])
        #expect(workout.calls == [.keepRunning])
    }

    @Test func aMatchLeftMoreThanSixHoursIsEndedAndSavedAtItsLastPoint() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch(), workout: workout)
        let lastPoint = Date(timeIntervalSinceReferenceDate: 1_000)
        for team in gamesToLove(.us, 1) { record.scorePoint(for: team, at: lastPoint - 60) }
        record.scorePoint(for: .them, at: lastPoint)
        workout.calls.removeAll()

        MatchRecord.recoverCurrent(in: try relaunch(), workout: workout, at: lastPoint + 6 * 60 * 60 + 1)

        let recovered = try #require(try MatchRecord.current(in: relaunch()))
        #expect(recovered.state == .decided)
        #expect(recovered.decidedAt == lastPoint)
        #expect(recovered.match.score.result == .unfinished)
        #expect(recovered.match.points.count == 5)
        #expect(workout.calls.isEmpty)
    }

    @Test func anEmptyMatchLeftMoreThanSixHoursIsAbandoned() throws {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        MatchRecord.start(Rules(), at: startDate, in: try relaunch(), workout: workout)
        workout.calls.removeAll()

        MatchRecord.recoverCurrent(in: try relaunch(), workout: workout, at: startDate + 6 * 60 * 60 + 1)

        #expect(try relaunch().fetch(FetchDescriptor<MatchRecord>()).isEmpty)
        #expect(workout.calls == [.discard])
    }

    @Test func aMatchIsLeftOnlyAfterMoreThanSixHoursWithoutAPoint() throws {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        let record = MatchRecord.start(Rules(), at: startDate, in: try relaunch(), workout: workout)
        let lastPoint = startDate + 5 * 60 * 60
        record.scorePoint(for: .us, at: lastPoint)
        workout.calls.removeAll()

        MatchRecord.recoverCurrent(in: try relaunch(), workout: workout, at: lastPoint + 6 * 60 * 60)

        let recovered = try #require(try MatchRecord.current(in: relaunch()))
        #expect(recovered.state == .inProgress)
        #expect(workout.calls == [.keepRunning])
    }

    @Test func aStaleMatchIsEndedOnceAndItsSummaryNeverRecoversAWorkout() throws {
        let record = MatchRecord.start(Rules(), in: try relaunch(), workout: workout)
        let lastPoint = Date(timeIntervalSinceReferenceDate: 1_000)
        record.scorePoint(for: .us, at: lastPoint)
        MatchRecord.recoverCurrent(in: try relaunch(), workout: workout, at: lastPoint + 7 * 60 * 60)
        workout.calls.removeAll()

        MatchRecord.recoverCurrent(in: try relaunch(), workout: workout, at: lastPoint + 30 * 60 * 60)

        let recovered = try #require(try MatchRecord.current(in: relaunch()))
        #expect(recovered.state == .decided)
        #expect(recovered.decidedAt == lastPoint)
        #expect(workout.calls.isEmpty)
    }

    /// A workout HealthKit recovers after the app died mid-Abandon or mid-Finish has no Match left to
    /// run under, and would otherwise keep the app in front for good.
    @Test func withNoMatchCurrentNoWorkoutIsKeptRunning() throws {
        MatchRecord.start(Rules(), in: try relaunch(), workout: workout).finish(workout: workout)
        workout.calls.removeAll()

        MatchRecord.recoverCurrent(in: try relaunch(), workout: workout)

        #expect(workout.calls == [.discard])
    }
}

/// Records what a Match asked of its workout, in order.
@MainActor
final class WorkoutSpy: MatchWorkout {
    enum Call: Equatable {
        case begin(Date), keepRunning, end(Date), discard
    }

    var calls: [Call] = []

    func begin(at startDate: Date) { calls.append(.begin(startDate)) }
    func keepRunning() { calls.append(.keepRunning) }
    func end(at decidedAt: Date) { calls.append(.end(decidedAt)) }
    func discard() { calls.append(.discard) }
}
