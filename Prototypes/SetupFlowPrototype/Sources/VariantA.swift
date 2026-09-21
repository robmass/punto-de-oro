// PROTOTYPE — Variant A: Wizard. One screen per choice; tapping a row advances.
// Pro set gets a follow-up step for its decider. Nothing remembered (last choice only ticked).
// Health permission is asked once on first launch, before setup.
import SwiftUI

struct VariantA: View {
    var exit: () -> Void

    enum Step: Hashable { case decider, deuce, serve, review }

    @State private var healthAsked = false
    @State private var path: [Step] = []
    @State private var rules = Rules()
    @State private var started = false

    var body: some View {
        if !healthAsked {
            FakeHealthPermissionView { healthAsked = true }
        } else if started {
            MatchStartedView(rules: rules, variant: "A — Wizard") {
                started = false
                path = []
            }
        } else {
            NavigationStack(path: $path) {
                List(Format.allCases) { f in
                    choiceRow(f.rawValue, f.detail, selected: rules.format == f) {
                        rules.format = f
                        path.append(f == .proSet ? .decider : .deuce)
                    }
                }
                .navigationTitle("Format")
                .toolbar { ExitToolbar(exit: exit) }
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .decider: deciderStep
                    case .deuce: deuceStep
                    case .serve: serveStep
                    case .review: reviewStep
                    }
                }
            }
        }
    }

    private var deciderStep: some View {
        List(ProDecider.allCases) { d in
            choiceRow(d.rawValue, d.detail, selected: rules.proDecider == d) {
                rules.proDecider = d
                path.append(.deuce)
            }
        }
        .navigationTitle("At 8–8")
    }

    private var deuceStep: some View {
        List(DeuceRule.allCases) { d in
            choiceRow(d.rawValue, d.detail, selected: rules.deuce == d) {
                rules.deuce = d
                path.append(.serve)
            }
        }
        .navigationTitle("Deuce")
    }

    private var serveStep: some View {
        VStack(spacing: 8) {
            Text("Who serves first?").font(.footnote)
            ForEach(Team.allCases) { t in
                Button(t.rawValue) {
                    rules.firstServe = t
                    path.append(.review)
                }
                .tint(t.color)
                .frame(maxHeight: .infinity)
            }
        }
        .navigationTitle("Serve")
    }

    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(rules.formatLabel).font(.headline)
                Text(rules.deuce.rawValue)
                Text("\(rules.firstServe.rawValue) serve").foregroundStyle(rules.firstServe.color)
                Button("Start") { started = true }
                    .tint(.green)
                    .padding(.top, 8)
            }
        }
        .navigationTitle("Ready")
    }

    private func choiceRow(_ title: String, _ detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title).font(.headline)
                    Text(detail).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(.green) }
            }
        }
    }
}
