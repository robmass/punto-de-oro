import Foundation
import HealthKit
import OSLog
import SwiftUI

/// The Apple Health workout a Match runs as. With a workout session active the app stays in front on
/// the wrist for the whole Match, reappears on a wrist raise and is exempt from Return to Clock. There
/// is no pause: the workout runs from Start until the Match is Finished or Abandoned.
@MainActor
protocol MatchWorkout: AnyObject {
    /// Starts the workout as the Match starts.
    func begin(at startDate: Date)
    /// Ends and saves the workout at Finished, backdated to the Decided moment so the time spent
    /// reading the summary is not counted as play.
    func end(at decidedAt: Date)
    /// Throws the workout away with an Abandoned Match, writing nothing to Health.
    func discard()
}

/// A Match's workout, run as an `HKWorkoutSession` with a live builder. One Match makes one Health entry.
@MainActor
final class HealthWorkout: NSObject, MatchWorkout {
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    /// Each change waits for the one before, so a Discard made while authorization is still being
    /// asked cannot overtake the Start it follows.
    private var lastChange: Task<Void, Never>?
    /// Each ending session's wait, resumed once it reaches `.ended`.
    private var sessionsEnding: [ObjectIdentifier: CheckedContinuation<Void, Never>] = [:]

    /// Asked on every Start, so the first ask arrives with a visible reason, never at launch; once
    /// the players have answered, HealthKit asks nothing more.
    private static let typesToShare: Set<HKSampleType> = [
        .workoutType(),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
    ]
    private static let typesToRead: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
    ]

    func begin(at startDate: Date) {
        change { [self] in
            // A workout left running would make a second Health entry, so it goes first.
            if let (session, builder) = takeSession() {
                await endSession(session)
                builder.discardWorkout()
            }
            try await store.requestAuthorization(toShare: Self.typesToShare, read: Self.typesToRead)
            let configuration = HKWorkoutConfiguration()
            // There is no padel type in `HKWorkoutActivityType`; `.paddleSports` is canoe, kayak and
            // SUP, so padel is logged as its closest racket sport. Calorimetry is sensor-estimated for
            // every racket sport, so this only sets the label and icon in Fitness and Health. Re-check
            // the enumeration each WWDC in case Apple adds padel.
            configuration.activityType = .tennis
            configuration.locationType = .indoor
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.delegate = self
            session.startActivity(with: startDate)
            do {
                try await builder.beginCollection(at: startDate)
            } catch {
                await endSession(session)
                throw error
            }
            self.session = session
            self.builder = builder
        }
    }

    func end(at decidedAt: Date) {
        change { [self] in
            guard let (session, builder) = takeSession() else { return }
            await endSession(session)
            try await builder.endCollection(at: decidedAt)
            try await builder.finishWorkout()
        }
    }

    func discard() {
        change { [self] in
            guard let (session, builder) = takeSession() else { return }
            await endSession(session)
            builder.discardWorkout()
        }
    }

    /// The running session and its builder, handed over once so a Match ends its workout only once.
    private func takeSession() -> (HKWorkoutSession, HKLiveWorkoutBuilder)? {
        defer { (session, builder) = (nil, nil) }
        guard let session, let builder else { return nil }
        return (session, builder)
    }

    /// Ends the session and waits for it to reach `.ended`, the point from which its builder may be
    /// ended. The wait is bounded, so a session that never reports back cannot stall every later change.
    private func endSession(_ session: HKWorkoutSession) async {
        guard session.state != .ended else { return }
        let id = ObjectIdentifier(session)
        await withCheckedContinuation { continuation in
            sessionsEnding[id] = continuation
            session.end()
            Task {
                try? await Task.sleep(for: .seconds(5))
                sessionEnded(id)
            }
        }
    }

    private func change(_ body: @escaping @MainActor () async throws -> Void) {
        let previous = lastChange
        lastChange = Task {
            await previous?.value
            do {
                try await body()
            } catch {
                Logger.workout.error("Could not change the workout: \(error)")
            }
        }
    }

    private func sessionEnded(_ id: ObjectIdentifier) {
        sessionsEnding.removeValue(forKey: id)?.resume()
    }
}

extension HealthWorkout: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended else { return }
        let id = ObjectIdentifier(workoutSession)
        Task { @MainActor in sessionEnded(id) }
    }

    /// A failed session never reaches `.ended`, so a wait for it ends here instead.
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Logger.workout.error("The workout session failed: \(error)")
        let id = ObjectIdentifier(workoutSession)
        Task { @MainActor in sessionEnded(id) }
    }
}

/// A workout that does nothing, for previews.
@MainActor
final class NoWorkout: MatchWorkout {
    nonisolated init() {}

    func begin(at startDate: Date) {}
    func end(at decidedAt: Date) {}
    func discard() {}
}

extension EnvironmentValues {
    /// The workout the current Match runs as; the app injects the Health one.
    @Entry var workout: any MatchWorkout = NoWorkout()
}

private extension Logger {
    static let workout = Logger(subsystem: "com.robmass.PuntoDeOro", category: "workout")
}
