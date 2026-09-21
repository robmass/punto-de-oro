// PROTOTYPE — Variant C: Play again first. Home is a big replay card for the last Rules (seeded so it's
// visible on first run) plus "New rules". New rules are vertical Crown-paged screens: Format has
// Pro set split into two rows (no follow-up step), Deuce is a Crown wheel, and the serve screen is two
// halves — tapping a Team *is* Start. Health is asked at the first Start.
import SwiftUI

struct VariantC: View {
    var exit: () -> Void

    enum Screen { case home, newRules, serve, started }
    enum Page: Hashable { case format, deuce, serve }

    // Seeded "last match" so the replay card shows on first run.
    @State private var lastRules: Rules? = Rules(format: .twoSetsSuperTB, deuce: .golden)
    @State private var draft = Rules()
    @State private var screen: Screen = .home
    @State private var page: Page = .format
    @State private var healthAsked = false
    @State private var showHealth = false

    // Format rows with Pro set split into its two deciders.
    private struct FormatRow: Identifiable {
        let id: String
        let format: Format
        let decider: ProDecider?
        let detail: String
    }
    private let formatRows: [FormatRow] = [
        .init(id: "3", format: .threeSets, decider: nil, detail: Format.threeSets.detail),
        .init(id: "2", format: .twoSetsSuperTB, decider: nil, detail: Format.twoSetsSuperTB.detail),
        .init(id: "p7", format: .proSet, decider: .tieBreak, detail: "To 9, tie-break at 8–8"),
        .init(id: "p10", format: .proSet, decider: .superTieBreak, detail: "To 9, super tie-break at 8–8"),
        .init(id: "i", format: .infinite, decider: nil, detail: Format.infinite.detail),
    ]

    var body: some View {
        switch screen {
        case .home: home
        case .newRules: newRules
        case .serve: NavigationStack { serveSplit.navigationTitle("Who serves?") }
        case .started:
            MatchStartedView(rules: draft, variant: "C — Play again") {
                lastRules = draft
                screen = .home
            }
        }
    }

    private var home: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if let last = lastRules {
                        Button {
                            draft = last
                            screen = .serve
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Play again", systemImage: "arrow.clockwise").font(.headline)
                                Text(last.formatLabel).font(.footnote)
                                Text(last.deuce.rawValue).font(.footnote).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .tint(.green)
                    }
                    Button("New rules") {
                        draft = lastRules ?? Rules()
                        page = .format
                        screen = .newRules
                    }
                }
            }
            .navigationTitle("Punto de Oro")
            .toolbar { ExitToolbar(exit: exit) }
        }
    }

    private var newRules: some View {
        NavigationStack {
            TabView(selection: $page) {
                List(formatRows) { row in
                    Button {
                        draft.format = row.format
                        if let d = row.decider { draft.proDecider = d }
                        withAnimation { page = .deuce }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(row.decider.map { "Pro set · \($0 == .tieBreak ? "TB" : "STB")" } ?? row.format.short)
                                .font(.headline)
                            Text(row.detail).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("1 · Format")
                .tag(Page.format)

                VStack(spacing: 4) {
                    Picker("Deuce", selection: $draft.deuce) {
                        ForEach(DeuceRule.allCases) { d in
                            VStack {
                                Label(d.rawValue, systemImage: d.symbol).font(.headline)
                                Text(d.detail).font(.caption2).foregroundStyle(.secondary)
                            }
                            .tag(d)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    Button("Next") { withAnimation { page = .serve } }
                }
                .navigationTitle("2 · Deuce")
                .tag(Page.deuce)

                serveSplit
                    .navigationTitle("3 · Serve")
                    .tag(Page.serve)
            }
            .tabViewStyle(.verticalPage)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { screen = .home } label: { Image(systemName: "xmark") }
                }
            }
        }
    }

    /// Two halves; tapping a Team starts the match with that Team serving.
    private var serveSplit: some View {
        VStack(spacing: 6) {
            ForEach(Team.allCases) { t in
                Button {
                    draft.firstServe = t
                    if healthAsked { screen = .started } else { showHealth = true }
                } label: {
                    VStack {
                        Image(systemName: "tennisball.fill")
                        Text("\(t.rawValue) serve").font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .tint(t.color)
            }
        }
        .sheet(isPresented: $showHealth) {
            FakeHealthPermissionView {
                healthAsked = true
                showHealth = false
                screen = .started
            }
        }
    }
}
