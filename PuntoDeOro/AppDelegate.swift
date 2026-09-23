import WatchKit

/// The app-level events SwiftUI has no hook for. It owns the Health workout, so the one the system
/// recovers after a crash is the same one the scene hands to every Match.
@MainActor
final class AppDelegate: NSObject, WKApplicationDelegate {
    let workout = HealthWorkout()

    /// The app died mid-workout and has been relaunched: take the running workout back.
    func handleActiveWorkoutRecovery() {
        workout.recover()
    }
}
