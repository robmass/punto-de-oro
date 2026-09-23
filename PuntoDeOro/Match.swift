import Foundation

/// One of the two sides in a Match. The wearer's Team is always Us.
enum Team {
    case us, them

    var name: String { self == .us ? "Us" : "Them" }

    var opponent: Team { self == .us ? .them : .us }
}

/// One rally, won by exactly one Team.
struct Point {
    let winner: Team
    let timestamp: Date
}

/// The fixed configuration of a Match. Only the 3 sets Format exists so far.
struct Rules {
    var deuceRule: DeuceRule = .advantage
    var firstServer: Team = .us
}

/// How a Game is settled from Deuce.
enum DeuceRule {
    case advantage, goldenPoint, silverPoint, starPoint

    var name: String {
        switch self {
        case .advantage: "Advantage"
        case .goldenPoint: "Golden point"
        case .silverPoint: "Silver point"
        case .starPoint: "Star point"
        }
    }

    /// Which Deuce of a Game is decisive, or nil when play is always won by two.
    fileprivate var decisiveDeuce: Int? {
        switch self {
        case .advantage: nil
        case .goldenPoint: 1
        case .silverPoint: 2
        case .starPoint: 3
        }
    }
}

/// A Match is its Rules plus its Point log; every score is derived by replaying the log.
struct Match {
    let rules: Rules
    private(set) var points: [Point] = []

    init(rules: Rules = Rules()) {
        self.rules = rules
    }

    /// Once the Match is Decided, only Undo changes the Point log.
    mutating func scorePoint(for team: Team, at timestamp: Date = .now) {
        guard !score.isDecided else { return }
        points.append(Point(winner: team, timestamp: timestamp))
    }

    /// Removes the most recent Point and returns the toast naming it, or nil when the log is empty.
    @discardableResult
    mutating func undo() -> String? {
        guard let removed = points.popLast() else { return nil }
        let score = score
        return "Undone · point \(removed.winner.name) · \(score.points(.us))–\(score.points(.them))"
    }

    var score: Score {
        var score = Score(rules: rules)
        for point in points { score.record(point.winner) }
        return score
    }
}

/// The score derived from a Point log.
struct Score {
    private let rules: Rules
    private var pointsInGame = Tally()
    /// Returns to 40–40 in the Game being played.
    private var deucesInGame = 0
    private var gamesInSet = Tally()
    private var gamesPlayed = 0
    /// The completed Sets, in the order they were played.
    private(set) var sets: [SetScore] = []
    /// The Team that won two Sets, once the Match is Decided.
    private(set) var winner: Team?

    var isDecided: Bool { winner != nil }

    fileprivate init(rules: Rules) {
        self.rules = rules
    }

    /// Serve alternates every Game, so the Set after a Tie-break opens with the Team that did not
    /// serve first in it. Inside a Tie-break, the Team due serves one Point, then serve changes
    /// every two.
    var servingTeam: Team {
        let firstServer = rules.firstServer
        let dueToServe = gamesPlayed.isMultiple(of: 2) ? firstServer : firstServer.opponent
        guard isTieBreak else { return dueToServe }
        return ((pointsInGame.total + 1) / 2).isMultiple(of: 2) ? dueToServe : dueToServe.opponent
    }

    /// A Set level at 6–6 is decided by a Tie-break.
    var isTieBreak: Bool { gamesInSet[.us] == 6 && gamesInSet[.them] == 6 }

    /// Whether the next Point wins the Game because the Deuce rule makes this Deuce decisive.
    /// Never under Advantage, and never inside a Tie-break.
    var isDecidingPoint: Bool {
        isDeuce && deucesInGame == rules.deuceRule.decisiveDeuce
    }

    /// 40–40 in a Game; a Tie-break has no Deuce.
    private var isDeuce: Bool {
        !isTieBreak && pointsInGame[.us] >= 3 && pointsInGame[.us] == pointsInGame[.them]
    }

    func points(_ team: Team) -> String {
        if isTieBreak { return "\(pointsInGame[team])" }
        let own = pointsInGame[team], opponent = pointsInGame[team.opponent]
        if own >= 3 && opponent >= 3 { return own > opponent ? "AD" : "40" }
        return ["0", "15", "30", "40"][own]
    }

    /// Games in the Set being played.
    func games(_ team: Team) -> Int { gamesInSet[team] }

    fileprivate mutating func record(_ winner: Team) {
        let wasDecidingPoint = isDecidingPoint
        let pointsToWinGame = isTieBreak ? 7 : 4
        pointsInGame[winner] += 1
        guard wasDecidingPoint || pointsInGame.hasWon(winner, reaching: pointsToWinGame) else {
            if isDeuce { deucesInGame += 1 }
            return
        }
        pointsInGame = Tally()
        deucesInGame = 0
        gamesInSet[winner] += 1
        gamesPlayed += 1
        guard gamesInSet.hasWon(winner, reaching: 6) || gamesInSet[winner] == 7 else { return }
        sets.append(SetScore(games: gamesInSet))
        gamesInSet = Tally()
        if sets.count(where: { $0.winner == winner }) == 2 { self.winner = winner }
    }
}

/// The Games each Team won in a completed Set.
struct SetScore {
    fileprivate let games: Tally

    func games(_ team: Team) -> Int { games[team] }

    var winner: Team { games[.us] > games[.them] ? .us : .them }
}

/// A count kept for each Team.
fileprivate struct Tally {
    private var us = 0, them = 0

    var total: Int { us + them }

    /// Whether this Team has reached the target with a lead of two.
    func hasWon(_ team: Team, reaching target: Int) -> Bool {
        self[team] >= target && self[team] - self[team.opponent] >= 2
    }

    subscript(team: Team) -> Int {
        get { team == .us ? us : them }
        set { if team == .us { us = newValue } else { them = newValue } }
    }
}
