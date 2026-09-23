import SwiftData
import SwiftUI

/// The setup wizard: one screen per choice, tap a row to advance. It is only ever the scene root's
/// alternative to live scoring, so its NavigationStack never holds the live page, and Start swaps
/// it out by making the new Match current. Neutral chrome: the gold stays with the Deciding point.
struct SetupWizardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.workout) private var workout
    @State private var wizard: SetupWizard
    /// Set on the first Start, so a second tap before the root swaps cannot start a second Match.
    @State private var isStarting = false

    init(lastRules: Rules?) {
        _wizard = State(initialValue: SetupWizard(lastRules: lastRules))
    }

    var body: some View {
        NavigationStack(path: $wizard.path) {
            formatScreen
                .navigationDestination(for: SetupWizard.Step.self) { step in
                    switch step {
                    case .decider: deciderScreen
                    case .deuce: deuceScreen
                    case .serve: serveScreen
                    case .ready: readyScreen
                    }
                }
        }
        .tint(.white)
    }

    private var formatScreen: some View {
        List {
            if let lastRules = wizard.lastRules {
                Section {
                    ChoiceRow(title: "Play again", subtitle: "\(lastRules.format.fullName) · \(lastRules.deuceRule.name)") {
                        wizard.playAgain()
                    }
                }
            }
            Section {
                ForEach(wizard.formatRows, id: \.name) { format in
                    ChoiceRow(title: format.name, subtitle: format.subtitle, isTicked: wizard.isTicked(format)) {
                        wizard.choose(format)
                    }
                }
            }
        }
        .navigationTitle("Format")
    }

    private var deciderScreen: some View {
        List(TieBreak.allCases, id: \.self) { decider in
            ChoiceRow(
                title: decider.name,
                subtitle: decider.subtitle,
                isTicked: wizard.rules.format.proSetDecider == decider
            ) {
                wizard.choose(decider)
            }
        }
        .navigationTitle("At 8–8")
    }

    private var deuceScreen: some View {
        List(DeuceRule.allCases, id: \.self) { deuceRule in
            ChoiceRow(title: deuceRule.name, subtitle: deuceRule.subtitle, isTicked: wizard.rules.deuceRule == deuceRule) {
                wizard.choose(deuceRule)
            }
        }
        .navigationTitle("Deuce")
    }

    private var serveScreen: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Team.allCases, id: \.self) { team in
                    Button {
                        wizard.choose(firstServer: team)
                    } label: {
                        HStack {
                            Text(team.name)
                            if wizard.rules.firstServer == team { Tick() }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Serve")
    }

    private var readyScreen: some View {
        let rules = wizard.rules
        return ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(rules.format.name).font(.headline)
                if let decider = rules.format.proSetDecider {
                    Text("\(decider.name) at 8–8")
                }
                Text(rules.deuceRule.name)
                Text("\(rules.firstServer.name) serve first")
                Button("Start") {
                    guard !isStarting else { return }
                    isStarting = true
                    MatchRecord.start(rules, in: context, workout: workout)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.black)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Ready")
    }
}

/// A tappable choice: name over a one-line subtitle, ticked when it is the current choice. Text
/// wraps rather than truncates, so accessibility sizes stay readable and the list simply scrolls.
private struct ChoiceRow: View {
    let title: String
    let subtitle: String
    var isTicked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if isTicked { Tick() }
            }
        }
    }
}

/// Marks the current choice on a screen.
private struct Tick: View {
    var body: some View {
        Image(systemName: "checkmark")
            .accessibilityLabel("Selected")
    }
}

private extension Format {
    /// The Format's name, naming a Pro set's 8–8 decider too, as the Play again row replays it.
    var fullName: String {
        guard let decider = proSetDecider else { return name }
        return "\(name), \(decider.name.lowercased())"
    }

    var name: String {
        switch self {
        case .threeSets: "3 sets"
        case .twoSetsPlusSuperTieBreak: "2 sets + super tie-break"
        case .proSet: "Pro set"
        case .infinite: "Infinite"
        }
    }

    var subtitle: String {
        switch self {
        case .threeSets: "Best of 3, full third set"
        case .twoSetsPlusSuperTieBreak: "Super tie-break at 1–1"
        case .proSet: "One set to 9"
        case .infinite: "Count games, stop any time"
        }
    }
}

private extension TieBreak {
    var subtitle: String { self == .tieBreak ? "To 7" : "To 10" }
}

private extension DeuceRule {
    var subtitle: String {
        switch self {
        case .advantage: "Win by two"
        case .goldenPoint: "1st deuce decides"
        case .silverPoint: "2nd deuce decides"
        case .starPoint: "3rd deuce decides"
        }
    }
}

/// In memory, so previews save nothing to disk.
@MainActor private let previewContainer = try! ModelContainer.matches(
    ModelConfiguration(isStoredInMemoryOnly: true)
)

#Preview("First run") {
    SetupWizardView(lastRules: nil)
        .modelContainer(previewContainer)
}

#Preview("Play again") {
    SetupWizardView(lastRules: Rules(format: .proSet(decider: .superTieBreak), deuceRule: .goldenPoint))
        .modelContainer(previewContainer)
}
