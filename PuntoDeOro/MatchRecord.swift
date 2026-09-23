import Foundation
import SwiftData

/// A Match on disk: its Rules and Point log, saved after every change so the Match survives the
/// app dying. The domain `Match` is derived from it, never stored alongside it.
///
/// Finished records are kept but never displayed; they are there for a future history feature,
/// so the schema is versioned (`MatchSchemaV1`) and changes to it need a migration stage.
@Model
final class MatchRecord {
    /// Where a Match is in its lifecycle.
    enum State: String {
        case inProgress, decided, finished
    }

    // Stored as primitives so the schema stays plain to migrate and to query.
    private var formatName: String
    private var proSetDeciderName: String?
    private var deuceRuleName: String
    private var firstServerName: String
    private var stateName: String
    private(set) var points: [Point] = []
    private(set) var startDate: Date
    /// When the winning Point was played, while the Match is Decided.
    private(set) var decidedAt: Date?

    private init(rules: Rules, startDate: Date) {
        (formatName, proSetDeciderName) = rules.format.stored
        deuceRuleName = rules.deuceRule.rawValue
        firstServerName = rules.firstServer.rawValue
        stateName = State.inProgress.rawValue
        self.startDate = startDate
    }

    var rules: Rules {
        Rules(
            format: Format(stored: formatName, decider: proSetDeciderName),
            deuceRule: DeuceRule(rawValue: deuceRuleName) ?? .advantage,
            firstServer: Team(rawValue: firstServerName) ?? .us
        )
    }

    var state: State { State(rawValue: stateName) ?? .inProgress }

    var match: Match { Match(rules: rules, points: points) }

    /// Starts a new Match under these Rules and saves it, making it the Match to resume.
    @discardableResult
    static func start(_ rules: Rules, at startDate: Date = .now, in context: ModelContext) -> MatchRecord {
        let record = MatchRecord(rules: rules, startDate: startDate)
        context.insert(record)
        record.save()
        return record
    }

    /// Every record not yet Finished, newest first; the first is the Match to resume.
    static var resumableDescriptor: FetchDescriptor<MatchRecord> {
        let finished = State.finished.rawValue
        return FetchDescriptor(
            predicate: #Predicate { $0.stateName != finished },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
    }

    /// The single non-Finished record, if any.
    static func resumable(in context: ModelContext) throws -> MatchRecord? {
        var descriptor = resumableDescriptor
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Scores a Point and saves it; the winning Point makes the Match Decided.
    func scorePoint(for team: Team, at timestamp: Date = .now) {
        var match = match
        match.scorePoint(for: team, at: timestamp)
        guard match.points.count != points.count else { return }
        points = match.points
        if match.score.isDecided {
            stateName = State.decided.rawValue
            decidedAt = timestamp
        }
        save()
    }

    /// Removes the most recent Point and saves, reopening a Decided Match; returns the toast naming
    /// the Point, or nil when the log is empty.
    @discardableResult
    func undo() -> String? {
        var match = match
        guard let toast = match.undo() else { return nil }
        points = match.points
        stateName = State.inProgress.rawValue
        decidedAt = nil
        save()
        return toast
    }

    /// The players have left the summary: the Match is final and no longer resumed.
    func finish() {
        stateName = State.finished.rawValue
        save()
    }

    /// Written straight away rather than left to autosave, so force-quitting loses no Points.
    private func save() {
        try? modelContext?.save()
    }
}

enum MatchSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [MatchRecord.self] }
}

enum MatchMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [MatchSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

extension ModelContainer {
    /// The container holding every Match record, migrated to the current schema.
    static func matches(_ configuration: ModelConfiguration = ModelConfiguration()) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: MatchSchemaV1.self),
            migrationPlan: MatchMigrationPlan.self,
            configurations: configuration
        )
    }
}

private extension Format {
    /// The Format's stored name, and the Pro set's 8–8 decider.
    var stored: (name: String, decider: String?) {
        switch self {
        case .threeSets: ("threeSets", nil)
        case .twoSetsPlusSuperTieBreak: ("twoSetsPlusSuperTieBreak", nil)
        case .proSet(let decider): ("proSet", decider.rawValue)
        case .infinite: ("infinite", nil)
        }
    }

    init(stored name: String, decider: String?) {
        switch name {
        case "twoSetsPlusSuperTieBreak": self = .twoSetsPlusSuperTieBreak
        case "proSet": self = .proSet(decider: decider.flatMap(TieBreak.init(rawValue:)) ?? .tieBreak)
        case "infinite": self = .infinite
        default: self = .threeSets
        }
    }
}
