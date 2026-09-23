import Foundation
import HealthKit
import OSLog
import SwiftUI

/// The Apple Health workout a Match runs as. With a workout session active the app stays in front on
/// the wrist for the whole Match, reappears on a wrist raise and is exempt from Return to Clock. There
/// is no pause: the workout runs from Start until the Match is Finished or Abandoned.
@MainActor
protocol MatchWorkout: AnyObject {
    /// Asks the players for Health access, from setup only: Start never asks, and nothing asks
    /// while a Match is underway. Once they have answered, it asks nothing more.
    func askForAccess()
    /// Whether Health may save the workout, as last answered.
    var healthAccess: HealthAccess { get }
    /// Starts the workout as the Match starts.
    func begin(at startDate: Date)
    /// Keeps a workout running under the current Match: the one HealthKit recovered after a crash,
    /// or, when it was lost (a reboot), a fresh one from now.
    func keepRunning()
    /// Ends and saves the workout at Finished, backdated to the Decided moment so the time spent
    /// reading the summary is not counted as play.
    func end(at decidedAt: Date)
    /// Throws the workout away with an Abandoned Match, writing nothing to Health.
    func discard()
    /// What the running workout has measured so far, for the summary.
    var stats: WorkoutStats { get }
}

/// Whether Health may save a Match's workout. Without it, a Match still runs, only without a workout.
enum HealthAccess: Equatable {
    /// Never answered: the sheet asks again the next time setup appears.
    case undetermined
    case allowed
    case denied

    init(_ status: HKAuthorizationStatus) {
        switch status {
        case .sharingAuthorized: self = .allowed
        case .sharingDenied: self = .denied
        default: self = .undetermined
        }
    }

    /// The Ready screen's one quiet line, only once the players have said no.
    var readyNotice: String? {
        self == .denied ? "Health off · no workout. The app may return to the clock." : nil
    }
}

/// What a Match's workout has measured: active energy and average heart rate, each nil until the
/// sensors report it.
struct WorkoutStats: Equatable {
    /// Kilocalories.
    var activeEnergy: Double?
    /// Beats per minute.
    var averageHeartRate: Double?

    /// The summary's one stats line.
    var line: String {
        "\(Self.rounded(activeEnergy)) kcal · \(Self.rounded(averageHeartRate)) bpm avg"
    }

    private static func rounded(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()))" } ?? "–"
    }
}

/// A Match's workout, run as an `HKWorkoutSession` with a live builder. One Match makes one Health entry.
@MainActor
final class HealthWorkout: NSObject, MatchWorkout {
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    /// Each change waits for the one before, so a Discard made while the workout is still starting
    /// cannot overtake the Start it follows.
    private var lastChange: Task<Void, Never>?
    /// Whether a Match wants the workout running, as last said; unknown after a launch until the
    /// current Match has been recovered.
    private var isWanted: Bool?
    /// Each ending session's wait, resumed once it reaches `.ended`.
    private var sessionsEnding: [ObjectIdentifier: CheckedContinuation<Void, Never>] = [:]

    /// Asked each time setup appears, never at Start, so no sheet stands between the players and
    /// the first point; once they have answered, HealthKit asks nothing more.
    private static let typesToShare: Set<HKSampleType> = [
        .workoutType(),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
    ]
    private static let typesToRead: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
    ]

    /// Not one of the changes: a sheet left unanswered must not hold up the Start that follows it.
    func askForAccess() {
        Task { [store] in
            do {
                try await store.requestAuthorization(toShare: Self.typesToShare, read: Self.typesToRead)
            } catch {
                Logger.workout.error("Could not ask for Health access: \(error)")
            }
        }
    }

    var healthAccess: HealthAccess {
        HealthAccess(store.authorizationStatus(for: .workoutType()))
    }

    func begin(at startDate: Date) {
        change { [self] in
            isWanted = true
            // A workout left running would make a second Health entry, so it goes first.
            await discardSession()
            try await startSession(at: startDate)
        }
    }

    func keepRunning() {
        change { [self] in
            isWanted = true
            guard session == nil else { return }
            // Asked here too, not only in `recover()`: whichever runs first after a crash takes the
            // recovered workout, so a fresh one never starts in its place.
            if let recovered = await recoveredSession() {
                attach(recovered)
            } else {
                // Starting now, not at the Match's start: a fresh workout cannot claim the time the
                // lost one covered.
                try await startSession(at: .now)
            }
        }
    }

    /// Takes back the session HealthKit kept running when the app crashed mid-Match. HealthKit hands
    /// back a new session object and restores only the workout; the score comes back from the Match
    /// record.
    func recover() {
        change { [self] in
            guard session == nil, let recovered = await recoveredSession() else { return }
            attach(recovered)
            // The app died between a Match leaving and its workout doing so: nothing is left for the
            // workout to run under.
            if isWanted == false { await discardSession() }
        }
    }

    func end(at decidedAt: Date) {
        change { [self] in
            isWanted = false
            guard let (session, builder) = takeSession() else { return }
            await endSession(session)
            try await builder.endCollection(at: decidedAt)
            try await builder.finishWorkout()
        }
    }

    func discard() {
        change { [self] in
            isWanted = false
            await discardSession()
        }
    }

    var stats: WorkoutStats {
        WorkoutStats(
            activeEnergy: builder?.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()),
            averageHeartRate: builder?.statistics(for: HKQuantityType(.heartRate))?
                .averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
        )
    }

    private func startSession(at startDate: Date) async throws {
        let configuration = HKWorkoutConfiguration()
        // There is no padel type in `HKWorkoutActivityType`; `.paddleSports` is canoe, kayak and
        // SUP, so padel is logged as its closest racket sport. Calorimetry is sensor-estimated for
        // every racket sport, so this only sets the label and icon in Fitness and Health. Re-check
        // the enumeration each WWDC in case Apple adds padel.
        configuration.activityType = .tennis
        configuration.locationType = .indoor
        let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        let builder = attach(session)
        session.startActivity(with: startDate)
        do {
            try await builder.beginCollection(at: startDate)
        } catch {
            takeSession()
            await endSession(session)
            throw error
        }
    }

    /// The session HealthKit kept running through a crash, if any.
    private func recoveredSession() async -> HKWorkoutSession? {
        do {
            return try await store.recoverActiveWorkoutSession()
        } catch {
            Logger.workout.error("Could not recover the workout: \(error)")
            return nil
        }
    }

    /// Makes a session the running one, with its builder collecting live from the watch's sensors.
    @discardableResult
    private func attach(_ session: HKWorkoutSession) -> HKLiveWorkoutBuilder {
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: store,
            workoutConfiguration: session.workoutConfiguration
        )
        session.delegate = self
        self.session = session
        self.builder = builder
        return builder
    }

    private func discardSession() async {
        guard let (session, builder) = takeSession() else { return }
        await endSession(session)
        builder.discardWorkout()
    }

    /// The running session and its builder, handed over once so a Match ends its workout only once.
    @discardableResult
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

    func askForAccess() {}
    var healthAccess: HealthAccess { .allowed }
    func begin(at startDate: Date) {}
    func keepRunning() {}
    func end(at decidedAt: Date) {}
    func discard() {}
    var stats: WorkoutStats { WorkoutStats() }
}

extension EnvironmentValues {
    /// The workout the current Match runs as; the app injects the Health one.
    @Entry var workout: any MatchWorkout = NoWorkout()
}

private extension Logger {
    static let workout = Logger(subsystem: "com.robmass.PuntoDeOro", category: "workout")
}
