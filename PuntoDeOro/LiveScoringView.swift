import SwiftData
import SwiftUI

/// The "Halves" live scoring screen: tap a half to score a Point for that Team. Every Point and
/// Undo goes through the record, which saves it.
struct LiveScoringView: View {
    let record: MatchRecord
    /// Double Tap is Undo only while the live page is selected: the shortcut resolves leading to
    /// trailing, and the controls page is leading.
    let isPrimaryActionEnabled: Bool
    @State private var toast: String?

    /// Pinned on every watch; the halves split the remainder. The top bar is tall enough to
    /// hold the system clock, which sits lowest (bottom at 33.5pt) on the 49mm Ultra.
    private static let topBarHeight: CGFloat = 36
    private static let stripHeight: CGFloat = 34

    var body: some View {
        GeometryReader { geometry in
            let halfHeight = (geometry.size.height - Self.topBarHeight - Self.stripHeight) / 2
            let match = record.match
            let score = match.score
            VStack(spacing: 0) {
                topBar
                half(.them, score: score, height: halfHeight)
                strip(match, score: score, showsResult: record.state == .decided)
                half(.us, score: score, height: halfHeight)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) { toastView }
    }

    private var topBar: some View {
        HStack {
            Button {
                toast = record.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 60, height: Self.topBarHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .handGestureShortcut(.primaryAction, isEnabled: isPrimaryActionEnabled)
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
        .onTapGesture { record.scorePoint(for: team) }
    }

    /// The dead band: no gesture, so a tap here does nothing. Completed Sets read left to right,
    /// then the Games of the Set being played; an Infinite match has only its running Game count,
    /// and a Super tie-break replacing the third Set has no Games to show. At a Deciding point the
    /// whole strip turns gold, the one place the app spends it, and everything on it goes black to
    /// stay legible.
    private func strip(_ match: Match, score: Score, showsResult: Bool) -> some View {
        let isDecidingPoint = score.isDecidingPoint
        return HStack(spacing: 10) {
            ForEach(score.sets.indices, id: \.self) { index in
                gamesColumn(score.sets[index].games, isDecidingPoint: isDecidingPoint)
                    .opacity(0.6)
            }
            if !score.isDecided && !score.isThirdSetSuperTieBreak {
                gamesColumn(score.games, isDecidingPoint: isDecidingPoint)
            }
            let statuses = statusLabels(match, score: score, showsResult: showsResult)
            if !statuses.isEmpty {
                VStack(spacing: 0) {
                    ForEach(statuses, id: \.self) { status in
                        Text(status)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .font(.system(size: 11, weight: .bold))
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

    /// The strip's status, one label per line: the Deuce rule's name at a Deciding point, else
    /// `TIE-BREAK` or `SUPER TIE-BREAK` while one is played, stacked over `CHANGE ENDS` until the
    /// next Point. Once the record is Decided, including a Match Ended early and saved, whose score
    /// is not, a placeholder names its Result until the summary screen lands.
    private func statusLabels(_ match: Match, score: Score, showsResult: Bool) -> [String] {
        if showsResult {
            switch score.result {
            case .won(let winner): return ["\(winner.name.uppercased()) WIN"]
            case .draw: return ["DRAW"]
            case .unfinished: return ["UNFINISHED"]
            }
        }
        if score.isDecidingPoint { return [match.rules.deuceRule.name.uppercased()] }
        var labels: [String] = []
        switch score.tieBreak {
        case .tieBreak: labels.append("TIE-BREAK")
        case .superTieBreak: labels.append("SUPER TIE-BREAK")
        case nil: break
        }
        if score.isChangeOfEnds { labels.append("CHANGE ENDS") }
        return labels
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

/// Kept alive for the previews' records, and in memory so previews save nothing to disk.
@MainActor private let previewContainer = try! ModelContainer.matches(
    ModelConfiguration(isStoredInMemoryOnly: true)
)

@MainActor
private func previewRecord(_ rules: Rules = Rules(), pointsWonBy winners: [Team] = []) -> MatchRecord {
    let record = MatchRecord.start(rules, in: previewContainer.mainContext, workout: NoWorkout())
    for team in winners { record.scorePoint(for: team) }
    return record
}

#Preview("3 sets") {
    LiveScoringView(record: previewRecord(), isPrimaryActionEnabled: true)
}

#Preview("Golden point") {
    LiveScoringView(record: previewRecord(
        Rules(deuceRule: .goldenPoint),
        pointsWonBy: [.us, .us, .us, .them, .them, .them]
    ), isPrimaryActionEnabled: true)
}

#Preview("Super tie-break") {
    let oneSetAll = [Team](repeating: .us, count: 24) + [Team](repeating: .them, count: 24)
    LiveScoringView(record: previewRecord(
        Rules(format: .twoSetsPlusSuperTieBreak),
        pointsWonBy: oneSetAll + [.us, .them, .us]
    ), isPrimaryActionEnabled: true)
}

#Preview("Infinite") {
    LiveScoringView(record: previewRecord(
        Rules(format: .infinite),
        pointsWonBy: [Team](repeating: .them, count: 44) + [.us, .us]
    ), isPrimaryActionEnabled: true)
}

#Preview("Change ends in a super tie-break") {
    let oneSetAll = [Team](repeating: .us, count: 24) + [Team](repeating: .them, count: 24)
    LiveScoringView(record: previewRecord(
        Rules(format: .twoSetsPlusSuperTieBreak),
        pointsWonBy: oneSetAll + [.us, .them, .us, .them, .us, .them]
    ), isPrimaryActionEnabled: true)
}
