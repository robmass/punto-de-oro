import Foundation
import OSLog
import SwiftData

/// The Match record at the current schema version.
typealias MatchRecord = MatchSchemaV1.MatchRecord

/// The first schema. Finished records are kept for a future history feature, so this version stays
/// frozen: a change to the record is a new schema version with a stage in `MatchMigrationPlan`.
enum MatchSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [MatchRecord.self] }

    /// A Match on disk: its Rules and Point log, saved after every change so the Match survives the
    /// app dying. The domain `Match` is derived from it, never stored alongside it.
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

        /// Only this app writes the record, so a value it cannot read falls back to the default Rules
        /// rather than stranding the Match.
        var rules: Rules {
            Rules(
                format: Format(stored: formatName, decider: proSetDeciderName),
                deuceRule: DeuceRule(rawValue: deuceRuleName) ?? .advantage,
                firstServer: Team(rawValue: firstServerName) ?? .us
            )
        }

        private(set) var state: State {
            get { State(rawValue: stateName) ?? .inProgress }
            set { stateName = newValue.rawValue }
        }

        var match: Match { Match(rules: rules, points: points) }

        /// Starts a new Match under these Rules and saves it, making it the current Match.
        @discardableResult
        static func start(_ rules: Rules, at startDate: Date = .now, in context: ModelContext) -> MatchRecord {
            let record = MatchRecord(rules: rules, startDate: startDate)
            context.insert(record)
            record.save()
            return record
        }

        /// Every record not yet Finished, newest first; the first is the current Match.
        static var currentDescriptor: FetchDescriptor<MatchRecord> {
            let finished = State.finished.rawValue
            return FetchDescriptor(
                predicate: #Predicate { $0.stateName != finished },
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
        }

        /// The single non-Finished record, if any: the Match a launch opens straight into.
        static func current(in context: ModelContext) throws -> MatchRecord? {
            var descriptor = currentDescriptor
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        }

        /// The most recent record, Finished or not: the source of the last Rules, so they need no
        /// separate store.
        static var latestDescriptor: FetchDescriptor<MatchRecord> {
            var descriptor = FetchDescriptor<MatchRecord>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
            descriptor.fetchLimit = 1
            return descriptor
        }

        /// Scores a Point and saves it; the winning Point makes the Match Decided.
        func scorePoint(for team: Team, at timestamp: Date = .now) {
            guard state != .finished else { return }
            var match = match
            match.scorePoint(for: team, at: timestamp)
            guard match.points.count != points.count else { return }
            points = match.points
            if match.score.isDecided {
                state = .decided
                decidedAt = timestamp
            }
            save()
        }

        /// Removes the most recent Point and saves, reopening a Decided Match; returns the toast naming
        /// the Point, or nil when the log is empty or the Match is Finished.
        @discardableResult
        func undo() -> String? {
            guard state != .finished else { return nil }
            var match = match
            guard let toast = match.undo() else { return nil }
            points = match.points
            state = .inProgress
            decidedAt = nil
            save()
            return toast
        }

        /// The players have left the summary: the Match is final and no longer current.
        func finish() {
            state = .finished
            save()
        }

        /// Written straight away rather than left to autosave, so force-quitting loses no Points.
        private func save() {
            do {
                try modelContext?.save()
            } catch {
                Logger.persistence.error("Could not save the Match: \(error)")
            }
        }
    }
}

/// How each schema version migrates to the next; empty while there is only one.
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

private extension Logger {
    static let persistence = Logger(subsystem: "com.robmass.PuntoDeOro", category: "persistence")
}

/// The Format's name on disk; the Pro set's 8–8 decider is stored beside it.
private enum StoredFormat: String {
    case threeSets, twoSetsPlusSuperTieBreak, proSet, infinite
}

private extension Format {
    var stored: (name: String, decider: String?) {
        switch self {
        case .threeSets: (StoredFormat.threeSets.rawValue, nil)
        case .twoSetsPlusSuperTieBreak: (StoredFormat.twoSetsPlusSuperTieBreak.rawValue, nil)
        case .proSet(let decider): (StoredFormat.proSet.rawValue, decider.rawValue)
        case .infinite: (StoredFormat.infinite.rawValue, nil)
        }
    }

    init(stored name: String, decider: String?) {
        switch StoredFormat(rawValue: name) {
        case .threeSets, nil: self = .threeSets
        case .twoSetsPlusSuperTieBreak: self = .twoSetsPlusSuperTieBreak
        case .proSet: self = .proSet(decider: decider.flatMap(TieBreak.init(rawValue:)) ?? .tieBreak)
        case .infinite: self = .infinite
        }
    }
}
