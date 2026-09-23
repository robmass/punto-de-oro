import SwiftData
import SwiftUI

@main
struct PuntoDeOroApp: App {
    @WKApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let container: ModelContainer

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
        .environment(\.workout, appDelegate.workout)
    }
}
