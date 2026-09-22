import SwiftUI

/// The "Halves" live scoring screen: tap a half to score a Point for that Team.
struct LiveScoringView: View {
    @State private var match = Match()
    @State private var toast: String?

    /// Pinned on every watch; the halves split the remainder.
    private static let topBarHeight: CGFloat = 26
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

    /// The dead band: no gesture, so a tap here does nothing.
    private func strip(_ score: Score) -> some View {
        VStack(spacing: -2) {
            Text("\(score.games(.them))").foregroundStyle(Team.them.color)
            Text("\(score.games(.us))").foregroundStyle(Team.us.color)
        }
        .font(.system(size: 15, weight: .semibold).monospacedDigit())
        .frame(maxWidth: .infinity)
        .frame(height: Self.stripHeight)
        .background(Palette.strip, ignoresSafeAreaEdges: [])
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

#Preview {
    LiveScoringView()
}
