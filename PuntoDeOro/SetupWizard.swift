/// Choosing the Rules for a new Match, one choice per screen: Format → At 8–8 (Pro set only) →
/// Deuce → Serve → Ready. Each choice advances; Play again skips straight to Serve with the last
/// Rules. The Format screen is the root, so the path holds only the screens pushed after it.
struct SetupWizard {
    enum Step: Hashable {
        case decider, deuce, serve, ready
    }

    /// The Rules of the most recent Match, or nil on a first run, when there is nothing to replay.
    let lastRules: Rules?
    /// The choices so far, seeded with the last Rules so each screen ticks what was played before.
    private(set) var rules: Rules
    var path: [Step] = []

    init(lastRules: Rules?) {
        self.lastRules = lastRules
        rules = lastRules ?? Rules()
    }

    /// The four Formats; the Pro set row carries the decider already chosen, so it stays one row.
    var formatRows: [Format] {
        [.threeSets, .twoSetsPlusSuperTieBreak, .proSet(decider: rules.format.proSetDecider ?? .tieBreak), .infinite]
    }

    func isTicked(_ format: Format) -> Bool { rules.format == format }

    mutating func playAgain() {
        guard let lastRules else { return }
        rules = lastRules
        path = [.serve]
    }

    mutating func choose(_ format: Format) {
        rules.format = format
        path.append(format.proSetDecider == nil ? .deuce : .decider)
    }

    mutating func choose(_ decider: TieBreak) {
        rules.format = .proSet(decider: decider)
        path.append(.deuce)
    }

    mutating func choose(_ deuceRule: DeuceRule) {
        rules.deuceRule = deuceRule
        path.append(.serve)
    }

    mutating func choose(firstServer: Team) {
        rules.firstServer = firstServer
        path.append(.ready)
    }
}
