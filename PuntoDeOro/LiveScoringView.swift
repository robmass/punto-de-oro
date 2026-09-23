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
    /// Always On. Only the paint changes while dimmed: every frame and tap area stays as it is, so a
    /// tap with the wrist down lands where it did with the wrist up.
    @Environment(\.isLuminanceReduced) private var isDimmed
    /// The US / THEM labels and the strip's chips follow Dynamic Type, capped so a label cannot reach
    /// its score and two stacked chips still fit the strip. Everything else on the screen is pinned
    /// to the geometry: the score is already as large as its half allows.
    @ScaledMetric(relativeTo: .caption2) private var teamLabelSize = LiveGeometry.teamLabelSize
    @ScaledMetric(relativeTo: .caption2) private var chipSize: CGFloat = 11
    private static let maxChipSize: CGFloat = 13

    var body: some View {
        GeometryReader { geometry in
            let halfHeight = (geometry.size.height - LiveGeometry.topBarHeight - LiveGeometry.stripHeight) / 2
            let match = record.match
            let score = match.score
            VStack(spacing: 0) {
                topBar
                half(.them, score: score, height: halfHeight)
                strip(match, score: score)
                half(.us, score: score, height: halfHeight)
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) { toastView }
        // Nothing animates in Always On.
        .transaction { if isDimmed { $0.disablesAnimations = true } }
    }

    private var topBar: some View {
        HStack {
            Button {
                toast = record.undo()
                if toast != nil { Haptic.play([.directionDown]) }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 60, height: LiveGeometry.topBarHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .handGestureShortcut(.primaryAction, isEnabled: isPrimaryActionEnabled)
            .accessibilityLabel("Undo last point")
            Spacer()
        }
        .frame(height: LiveGeometry.topBarHeight)
        .background(.black, ignoresSafeAreaEdges: [])
    }

    /// The score alone is laid out, centred in the half; the Team label is overlaid at the half's
    /// outer edge, away from the strip, so however far it scales it cannot move the score. One
    /// accessibility element, read as its Team and Point score; VoiceOver's double-tap scores.
    private func half(_ team: Team, score: Score, height: CGFloat) -> some View {
        let spoken = score.spokenHalf(team)
        return Text(score.points(team))
            .font(.system(size: LiveGeometry.scoreSize(halfHeight: height), weight: .bold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: team == .them ? .top : .bottom) {
                Text(team.name.uppercased())
                    .font(.system(
                        size: min(teamLabelSize, LiveGeometry.maxTeamLabelSize(halfHeight: height)),
                        weight: .semibold
                    ))
                    .opacity(0.85)
                    .padding(team == .them ? .top : .bottom, LiveGeometry.teamLabelInset)
            }
        .overlay(alignment: .leading) {
            if score.servingTeam == team {
                Circle()
                    .fill(Palette.serveMarker)
                    .frame(width: 10, height: 10)
                    .padding(.leading, 14)
            }
        }
        .frame(height: height)
        .paint(LiveStyle.half(team, isDimmed: isDimmed))
        .contentShape(Rectangle())
        .onTapGesture { scorePoint(for: team) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken.label)
        .accessibilityValue(spoken.value)
        .accessibilityHint(spoken.hint)
        .accessibilityAction { scorePoint(for: team) }
    }

    private func scorePoint(for team: Team) {
        Haptic.play(record.scorePoint(for: team))
    }

    /// The dead band: no gesture, so a tap here does nothing and fires no haptic. Completed Sets read
    /// left to right, then the Games of the Set being played; an Infinite match has only its running
    /// Game count, and a Super tie-break replacing the third Set has no Games to show. At a Deciding
    /// point the whole strip turns gold, the one place the app spends it, and everything on it goes
    /// black to stay legible; dimmed, it is a gold outline with everything on it gold. VoiceOver reads
    /// it as one element carrying the whole state.
    private func strip(_ match: Match, score: Score) -> some View {
        let isDecidingPoint = score.isDecidingPoint
        return HStack(spacing: 10) {
            ForEach(score.sets.indices, id: \.self) { index in
                gamesColumn(score.sets[index].games, isDecidingPoint: isDecidingPoint)
                    .opacity(0.6)
                    .layoutPriority(1)
            }
            if !score.isDecided && !score.isThirdSetSuperTieBreak {
                gamesColumn(score.games, isDecidingPoint: isDecidingPoint)
                    .layoutPriority(1)
            }
            let statuses = match.stripStatuses
            if !statuses.isEmpty {
                VStack(spacing: 0) {
                    ForEach(statuses, id: \.self) { status in
                        Text(status.uppercased())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .font(.system(size: min(chipSize, Self.maxChipSize), weight: .bold))
            }
        }
        .font(.system(size: 15, weight: .semibold).monospacedDigit())
        // The Games never give way: a chip too wide at its size shrinks instead, clear of the edges.
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .frame(height: LiveGeometry.stripHeight)
        .paint(LiveStyle.strip(isDecidingPoint: isDecidingPoint, isDimmed: isDimmed))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(match.spokenStrip)
    }

    private func gamesColumn(_ games: (Team) -> Int, isDecidingPoint: Bool) -> some View {
        VStack(spacing: -2) {
            Text("\(games(.them))")
                .foregroundStyle(LiveStyle.games(.them, isDecidingPoint: isDecidingPoint, isDimmed: isDimmed))
            Text("\(games(.us))")
                .foregroundStyle(LiveStyle.games(.us, isDecidingPoint: isDecidingPoint, isDimmed: isDimmed))
        }
    }

    /// Not while dimmed: its filled capsule would light up the black screen.
    @ViewBuilder
    private var toastView: some View {
        if let toast, !isDimmed {
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

private extension View {
    /// Paints a surface without touching its layout: the fill behind it, the outline drawn inside its
    /// edge and following the display's corners where it meets them.
    func paint(_ style: Paint) -> some View {
        foregroundStyle(style.foreground)
            .background(style.fill, ignoresSafeAreaEdges: [])
            .overlay {
                if let outline = style.outline {
                    ConcentricRectangle()
                        .stroke(outline, lineWidth: 2)
                        .padding(1)
                        .allowsHitTesting(false)
                }
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

#Preview("Always On") {
    LiveScoringView(record: previewRecord(pointsWonBy: [.us, .us, .us, .us, .them]), isPrimaryActionEnabled: true)
        .environment(\.isLuminanceReduced, true)
}

#Preview("Golden point, Always On") {
    LiveScoringView(record: previewRecord(
        Rules(deuceRule: .goldenPoint),
        pointsWonBy: [.us, .us, .us, .them, .them, .them]
    ), isPrimaryActionEnabled: true)
    .environment(\.isLuminanceReduced, true)
}
