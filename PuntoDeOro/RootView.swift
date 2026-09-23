import SwiftData
import SwiftUI

/// The scene root: the single non-Finished Match opens straight into live scoring, score intact;
/// with none on disk, the setup wizard replaces it. Setup is swapped in and out here, never pushed,
/// so no back-swipe can reach it mid-match. Nothing else is restored, so a relaunch always lands on
/// the live page.
struct RootView: View {
    @Query(MatchRecord.currentDescriptor) private var current: [MatchRecord]
    @Query(MatchRecord.latestDescriptor) private var latest: [MatchRecord]

    var body: some View {
        if let record = current.first {
            LiveScoringView(record: record)
        } else {
            SetupWizardView(lastRules: latest.first?.rules)
        }
    }
}
