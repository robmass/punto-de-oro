import SwiftData
import SwiftUI

@main
struct PuntoDeOroApp: App {
    private let container: ModelContainer
    private let workout = HealthWorkout()

    init() {
        do {
            container = try .matches()
        } catch {
            fatalError("Could not open the Match store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        .environment(\.workout, workout)
    }
}
