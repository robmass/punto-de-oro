import SwiftData
import SwiftUI

/// The scene root: the single non-Finished Match resumes straight into live scoring, score intact;
/// with none on disk, the entry point starts one. Nothing else is restored, so a relaunch always
/// lands on the live page.
struct RootView: View {
    @Query(MatchRecord.resumableDescriptor) private var resumable: [MatchRecord]

    var body: some View {
        if let record = resumable.first {
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
