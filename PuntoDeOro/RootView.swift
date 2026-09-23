import SwiftData
import SwiftUI

/// The scene root: the single non-Finished Match opens straight into live scoring, score intact;
/// with none on disk, the entry point starts one. Nothing else is restored, so a relaunch always
/// lands on the live page.
struct RootView: View {
    @Query(MatchRecord.currentDescriptor) private var current: [MatchRecord]

    var body: some View {
        if let record = current.first {
            LiveScoringView(record: record)
        } else {
            EntryPointView()
        }
    }
}

/// A placeholder until the setup wizard lands: starts a Match under the default Rules.
private struct EntryPointView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        Button("New match") {
            MatchRecord.start(Rules(), in: context)
        }
    }
}
