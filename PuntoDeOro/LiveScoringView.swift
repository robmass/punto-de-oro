import SwiftUI

/// The "Halves" live scoring screen: tap a half to score a Point for that Team.
struct LiveScoringView: View {
    @State private var match: Match
    @State private var toast: String?

    init(match: Match = Match()) {
        _match = State(initialValue: match)
    }

    /// Pinned on every watch; the halves split the remainder. The top bar is tall enough to
    /// hold the system clock, which sits lowest (bottom at 33.5pt) on the 49mm Ultra.
    private static let topBarHeight: CGFloat = 36
    private static let stripHeight: CGFloat = 34

    var body: some View {
        GeometryReader { geometry in
            let halfHeight = (geometry.size.height - Self.topBarHeight - Self.stripHeight) / 2
            let score = match.score
            VStack(spacing: 0) {
                topBar
                half(.them, score: score, height: halfHeight)
                strip(score)
                half(.us, score: score, height: halfHeight)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) { toastView }
    }

    private var topBar: some View {
        HStack {
            Button {
                toast = match.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 60, height: Self.topBarHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo")
            Spacer()
        }
        .frame(height: Self.topBarHeight)
        .background(.black, ignoresSafeAreaEdges: [])
    }

    private func half(_ team: Team, score: Score, height: CGFloat) -> some View {
        let label = Text(team.name.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .opacity(0.85)
        return VStack(spacing: 0) {
            if team == .them { label }
            Text(score.points(team))
                .font(.system(size: height * 0.7, weight: .bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if team == .us { label }
        }
        .foregroundStyle(team.color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .leading) {
            if score.servingTeam == team {
                Circle()
                    .fill(Palette.serveMarker)
                    .frame(width: 10, height: 10)
                    .padding(.leading, 14)
            }
        }
        .frame(height: height)
        .background(team.halfBackground, ignoresSafeAreaEdges: [])
        .contentShape(Rectangle())
        .onTapGesture { match.scorePoint(for: team) }
    }

    /// The dead band: no gesture, so a tap here does nothing. Completed Sets read left to right,
    /// then the Games of the Set being played; an Infinite match has only its running Game count,
    /// and a Super tie-break replacing the third Set has no Games to show. At a Deciding point the
    /// whole strip turns gold, the one place the app spends it, and everything on it goes black to
    /// stay legible.
    private func strip(_ score: Score) -> some View {
        let isDecidingPoint = score.isDecidingPoint
        return HStack(spacing: 10) {
            ForEach(score.sets.indices, id: \.self) { index in
                gamesColumn(score.sets[index].games, isDecidingPoint: isDecidingPoint)
                    .opacity(0.6)
            }
            if !score.isDecided && !score.isThirdSetSuperTieBreak {
                gamesColumn(score.games, isDecidingPoint: isDecidingPoint)
            }
            if let status = statusLabel(score) {
                Text(status)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .font(.system(size: 15, weight: .semibold).monospacedDigit())
        .frame(maxWidth: .infinity)
        .frame(height: Self.stripHeight)
        .foregroundStyle(isDecidingPoint ? .black : .white)
        .background(isDecidingPoint ? Palette.gold : Palette.strip, ignoresSafeAreaEdges: [])
    }

    private func gamesColumn(_ games: (Team) -> Int, isDecidingPoint: Bool) -> some View {
        VStack(spacing: -2) {
            Text("\(games(.them))").foregroundStyle(isDecidingPoint ? .black : Team.them.color)
            Text("\(games(.us))").foregroundStyle(isDecidingPoint ? .black : Team.us.color)
        }
    }

    /// The Deuce rule's name at a Deciding point, `TIE-BREAK` or `SUPER TIE-BREAK` while one is
    /// played. Once the Match is Decided, a placeholder names the winner until the summary screen
    /// lands.
    private func statusLabel(_ score: Score) -> String? {
        if let winner = score.winner { return "\(winner.name.uppercased()) WIN" }
        if score.isDecidingPoint { return match.rules.deuceRule.name.uppercased() }
        switch score.tieBreak {
        case .tieBreak: return "TIE-BREAK"
        case .superTieBreak: return "SUPER TIE-BREAK"
        case nil: return nil
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 10))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.gray.opacity(0.8), in: Capsule())
                .padding(.bottom, 8)
                .allowsHitTesting(false)
                .task(id: toast) {
                    try? await Task.sleep(for: .seconds(1.1))
                    self.toast = nil
                }
        }
    }
}

private enum Palette {
    /// Reserved for the Deciding point strip; spent nowhere else in the app.
    static let gold = Color(red: 0xFF / 255, green: 0xCC / 255, blue: 0x00 / 255)
    static let serveMarker = Color(red: 0xD4 / 255, green: 0xFF / 255, blue: 0x3A / 255)
    static let strip = Color(white: 0x11 / 255)
}

private extension Team {
    var color: Color {
        switch self {
        case .us: Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
        case .them: Color(red: 0xFF / 255, green: 0x9F / 255, blue: 0x0A / 255)
        }
    }

    var halfBackground: Color {
        switch self {
        case .us: Color(red: 0x0F / 255, green: 0x3D / 255, blue: 0x1C / 255)
        case .them: Color(red: 0x4A / 255, green: 0x2E / 255, blue: 0x05 / 255)
        }
    }
}

#Preview("3 sets") {
    LiveScoringView()
}

#Preview("Golden point") {
    var match = Match(rules: Rules(deuceRule: .goldenPoint))
    for team: Team in [.us, .us, .us, .them, .them, .them] { match.scorePoint(for: team) }
    return LiveScoringView(match: match)
}

#Preview("Super tie-break") {
    let oneSetAll = [Team](repeating: .us, count: 24) + [Team](repeating: .them, count: 24)
    var match = Match(rules: Rules(format: .twoSetsPlusSuperTieBreak))
    for team in oneSetAll + [.us, .them, .us] { match.scorePoint(for: team) }
    return LiveScoringView(match: match)
}

#Preview("Infinite") {
    var match = Match(rules: Rules(format: .infinite))
    for team in [Team](repeating: .them, count: 44) + [.us, .us] { match.scorePoint(for: team) }
    return LiveScoringView(match: match)
}
