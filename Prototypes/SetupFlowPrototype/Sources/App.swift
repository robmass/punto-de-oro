// PROTOTYPE — throwaway. Setup flow design: three structurally different setup flows,
// picked from a variant list at launch (the watch stand-in for a ?variant= switcher).
//   A — Wizard: one screen per choice, tap advances; Health asked on first launch.
//   B — Summary list: all Rules on one screen with Start on top, last Rules remembered; Health asked at first Start.
//   C — Play again: replay card up front; new Rules on Crown-paged screens, choosing the serving team starts the match.
import SwiftUI

@main
struct SetupFlowPrototypeApp: App {
    var body: some Scene {
        WindowGroup { VariantPicker() }
    }
}

struct VariantPicker: View {
    @State private var variant: String?

    var body: some View {
        switch variant {
        case "A": VariantA(exit: { variant = nil })
        case "B": VariantB(exit: { variant = nil })
        case "C": VariantC(exit: { variant = nil })
        default:
            NavigationStack {
                List {
                    Section("PROTOTYPE") {
                        row("A", "Wizard")
                        row("B", "Summary list")
                        row("C", "Play again + pager")
                    }
                }
                .navigationTitle("Setup variants")
            }
        }
    }

    private func row(_ key: String, _ name: String) -> some View {
        Button { variant = key } label: {
            VStack(alignment: .leading) {
                Text("\(key) — \(name)").font(.headline)
            }
        }
    }
}

/// Top-left "exit to variant list" button, visibly not part of the design.
struct ExitToolbar: ToolbarContent {
    var exit: () -> Void
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: exit) { Image(systemName: "square.grid.2x2") }
                .tint(.purple)
        }
    }
}
