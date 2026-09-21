// PROTOTYPE — Variant B: Summary list. Every Rule is a row showing its current value, Start is the
// first row, and the last Rules are remembered (in memory), so a replay is a single tap.
// The Pro set decider is its own row that appears only for Pro set. Health is asked at the first Start.
import SwiftUI

struct VariantB: View {
    var exit: () -> Void

    @State private var rules = Rules()
    @State private var healthAsked = false
    @State private var showHealth = false
    @State private var started = false

    var body: some View {
        if started {
            MatchStartedView(rules: rules, variant: "B — Summary list") { started = false }
        } else {
            NavigationStack {
                List {
                    Button {
                        if healthAsked { started = true } else { showHealth = true }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: 12).fill(.green))

                    NavigationLink {
                        picker("Format", Format.allCases, \.format, title: \.rawValue, detail: \.detail)
                    } label: { valueRow("Format", rules.format.short) }

                    if rules.format == .proSet {
                        NavigationLink {
                            picker("At 8–8", ProDecider.allCases, \.proDecider, title: \.rawValue, detail: \.detail)
                        } label: { valueRow("At 8–8", rules.proDecider.rawValue) }
                    }

                    NavigationLink {
                        picker("Deuce", DeuceRule.allCases, \.deuce, title: \.rawValue, detail: \.detail)
                    } label: { valueRow("Deuce", rules.deuce.rawValue) }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Serves first").font(.caption2).foregroundStyle(.secondary)
                        HStack {
                            ForEach(Team.allCases) { t in
                                Button(t.rawValue) { rules.firstServe = t }
                                    .buttonStyle(.bordered)
                                    .tint(rules.firstServe == t ? t.color : .gray)
                            }
                        }
                    }
                }
                .navigationTitle("New match")
                .toolbar { ExitToolbar(exit: exit) }
                .sheet(isPresented: $showHealth) {
                    FakeHealthPermissionView {
                        healthAsked = true
                        showHealth = false
                        started = true
                    }
                }
            }
        }
    }

    private func valueRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
    }

    private func picker<T: Identifiable & Equatable>(
        _ navTitle: String, _ options: [T], _ key: WritableKeyPath<Rules, T>,
        title: KeyPath<T, String>, detail: KeyPath<T, String>
    ) -> some View {
        PickerScreen(navTitle: navTitle, options: options, selected: rules[keyPath: key],
                     title: title, detail: detail) { rules[keyPath: key] = $0 }
    }
}

private struct PickerScreen<T: Identifiable & Equatable>: View {
    let navTitle: String
    let options: [T]
    let selected: T
    let title: KeyPath<T, String>
    let detail: KeyPath<T, String>
    var onPick: (T) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(options) { o in
            Button {
                onPick(o)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(o[keyPath: title]).font(.headline)
                        Text(o[keyPath: detail]).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if o == selected { Image(systemName: "checkmark").foregroundStyle(.green) }
                }
            }
        }
        .navigationTitle(navTitle)
    }
}
