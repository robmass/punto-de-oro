// PROTOTYPE — throwaway. Just enough of the Rules model to drive the setup-flow variants.
import SwiftUI

enum Format: String, CaseIterable, Identifiable {
    case threeSets = "3 sets"
    case twoSetsSuperTB = "2 sets + super tie-break"
    case proSet = "Pro set"
    case infinite = "Infinite"
    var id: Self { self }

    var short: String {
        switch self {
        case .threeSets: "3 sets"
        case .twoSetsSuperTB: "2 sets + STB"
        case .proSet: "Pro set"
        case .infinite: "Infinite"
        }
    }
    var detail: String {
        switch self {
        case .threeSets: "Best of 3, full third set"
        case .twoSetsSuperTB: "Super tie-break at 1–1"
        case .proSet: "One set to 9"
        case .infinite: "Count games, stop any time"
        }
    }
}

enum ProDecider: String, CaseIterable, Identifiable {
    case tieBreak = "Tie-break"
    case superTieBreak = "Super tie-break"
    var id: Self { self }
    var detail: String { self == .tieBreak ? "At 8–8, to 7" : "At 8–8, to 10" }
}

enum DeuceRule: String, CaseIterable, Identifiable {
    case advantage = "Advantage"
    case golden = "Golden point"
    case silver = "Silver point"
    case star = "Star point"
    var id: Self { self }

    var detail: String {
        switch self {
        case .advantage: "Win by two"
        case .golden: "1st deuce decides"
        case .silver: "2nd deuce decides"
        case .star: "3rd deuce decides"
        }
    }
    var symbol: String {
        switch self {
        case .advantage: "infinity"
        case .golden: "1.circle.fill"
        case .silver: "2.circle.fill"
        case .star: "3.circle.fill"
        }
    }
}

// Team labels are still fog on the map — "Us / Them" is a placeholder.
enum Team: String, CaseIterable, Identifiable {
    case us = "Us"
    case them = "Them"
    var id: Self { self }
    var color: Color { self == .us ? .blue : .orange }
}

struct Rules: Equatable {
    var format: Format = .twoSetsSuperTB
    var proDecider: ProDecider = .tieBreak
    var deuce: DeuceRule = .golden
    var firstServe: Team = .us

    var formatLabel: String {
        format == .proSet ? "Pro set · \(proDecider.rawValue)" : format.rawValue
    }
}

/// Stub for the end of setup: shows the full Rules so each variant's output is visible.
struct MatchStartedView: View {
    let rules: Rules
    let variant: String
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Match started").font(.headline).foregroundStyle(.green)
                Text("(workout would start here)").font(.caption2).foregroundStyle(.secondary)
                Divider()
                LabeledContent("Format", value: rules.formatLabel)
                LabeledContent("Deuce", value: rules.deuce.rawValue)
                LabeledContent("Serves", value: rules.firstServe.rawValue)
                Button("Back to setup", action: onBack).padding(.top, 6)
                Text("Variant \(variant)").font(.caption2).foregroundStyle(.secondary)
            }
            .font(.footnote)
        }
    }
}

/// Stub for the HealthKit authorization sheet — no real HealthKit in the prototype.
struct FakeHealthPermissionView: View {
    var onAllow: () -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "heart.fill").font(.title2).foregroundStyle(.pink)
                Text("Save matches as workouts in Health?").font(.headline).multilineTextAlignment(.center)
                Text("(stub for the system Health permission sheet)")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Allow", action: onAllow).tint(.pink)
            }
        }
    }
}
