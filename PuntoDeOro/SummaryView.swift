import SwiftData
import SwiftUI

/// The screen a Match ends on, shown once it is Decided. It runs inside the workout, so Return to
/// Clock does not apply to it. Leaving it is what makes the Match Finished: Done, or ten minutes
/// untouched. Undo or Resume reopens the Match in the same workout instead. There is no Discard.
struct SummaryView: View {
    let record: MatchRecord
    /// Moved by every touch, restarting the countdown to Finished.
    @State private var lastTouched = Date.now
    /// Taken as the summary lands, at the Decided moment, and kept: the saved workout ends there, so
    /// the minutes spent reading the summary are not counted.
    @State private var stats: WorkoutStats?
    @Environment(\.workout) private var workout

    /// How long the summary waits untouched before the Match Finishes on its own.
    static let untouchedTimeout: Duration = .seconds(10 * 60)

    var body: some View {
        let score = record.match.score
        ScrollView {
            VStack(spacing: 6) {
                Text(score.result.title)
                    .font(.title3.weight(.bold))
                Text(score.summary)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .multilineTextAlignment(.center)
                if let duration = record.duration {
                    Text(duration.formatted(.time(pattern: .hourMinuteSecond)))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text((stats ?? workout.stats).line)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("Done") { record.finish(workout: workout) }
                    .padding(.top, 4)
                switch record.summaryReopening {
                case .undo: Button("Undo") { record.undo() }
                case .resume: Button("Resume") { record.resume() }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .tint(.white)
        .onAppear { stats = workout.stats }
        .simultaneousGesture(TapGesture().onEnded { lastTouched = .now })
        .onScrollPhaseChange { _, phase in
            if phase != .idle { lastTouched = .now }
        }
        .task(id: lastTouched) {
            do {
                try await Task.sleep(for: Self.untouchedTimeout)
            } catch {
                return
            }
            record.finish(workout: workout)
        }
    }
}

/// Kept alive for the previews' records, and in memory so previews save nothing to disk.
@MainActor private let previewContainer = try! ModelContainer.matches(
    ModelConfiguration(isStoredInMemoryOnly: true)
)

@MainActor
private func previewRecord(_ rules: Rules = Rules(), pointsWonBy winners: [Team], ended: Bool = false) -> MatchRecord {
    let record = MatchRecord.start(rules, in: previewContainer.mainContext, workout: NoWorkout())
    let start = Date.now - 90 * 60
    for (offset, team) in winners.enumerated() { record.scorePoint(for: team, at: start + Double(offset) * 30) }
    if ended { record.endAndSave() }
    return record
}

/// The Points that win this many Games in a row to love.
private func games(_ team: Team, _ count: Int) -> [Team] { Array(repeating: team, count: 4 * count) }

private let sixFour = games(.us, 5) + games(.them, 4) + games(.us, 1)

#Preview("Won in a tie-break") {
    let sixAll = games(.us, 5) + games(.them, 6) + games(.us, 1)
    let tieBreak = Array(repeating: Team.them, count: 5) + Array(repeating: Team.us, count: 7)
    SummaryView(record: previewRecord(pointsWonBy: sixFour + sixAll + tieBreak))
}

#Preview("Unfinished") {
    SummaryView(record: previewRecord(pointsWonBy: sixFour + games(.them, 3) + [.us, .us, .them], ended: true))
}
