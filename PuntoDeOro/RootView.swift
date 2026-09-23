import SwiftData
import SwiftUI

/// The scene root: the single non-Finished Match opens straight into live scoring, score intact;
/// with none on disk, the setup wizard replaces it. Setup is swapped in and out here, never pushed,
/// so no back-swipe can reach it mid-match. Nothing else is restored, so a relaunch always lands on
/// the live page. Each time the app comes to the front, launch included, the current Match is
/// recovered: back on a workout, or ended if it was left.
struct RootView: View {
    @Query(MatchRecord.currentDescriptor) private var current: [MatchRecord]
    @Query(MatchRecord.latestDescriptor) private var latest: [MatchRecord]
    @Environment(\.modelContext) private var context
    @Environment(\.workout) private var workout
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let record = current.first {
                MatchPagesView(record: record)
            } else {
                SetupWizardView(lastRules: latest.first?.rules)
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { MatchRecord.recoverCurrent(in: context, workout: workout) }
        }
    }
}
