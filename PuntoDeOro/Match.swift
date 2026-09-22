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

/// The fixed configuration of a Match. Only 3 sets under Advantage exists so far.
struct Rules {
    var firstServer: Team = .us
}

/// A Match is its Rules plus its Point log; every score is derived by replaying the log.
struct Match {
    let rules = Rules()
    private(set) var points: [Point] = []

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
        var score = Score(firstServer: rules.firstServer)
        for point in points { score.record(point.winner) }
        return score
    }
}

/// The score derived from a Point log.
struct Score {
    private let firstServer: Team
    private var pointsInGame = Tally()
    private var gamesInSet = Tally()
    private var gamesPlayed = 0
    /// The completed Sets, in the order they were played.
    private(set) var sets: [SetScore] = []
    /// The Team that won two Sets, once the Match is Decided.
    private(set) var winner: Team?

    var isDecided: Bool { winner != nil }

    fileprivate init(firstServer: Team) {
        self.firstServer = firstServer
    }

    /// Serve alternates every Game, so the Set after a Tie-break opens with the Team that did not
    /// serve first in it. Inside a Tie-break, the Team due serves one Point, then serve changes
    /// every two.
    var servingTeam: Team {
        let dueToServe = gamesPlayed.isMultiple(of: 2) ? firstServer : firstServer.opponent
        guard isTieBreak else { return dueToServe }
        return ((pointsInGame.total + 1) / 2).isMultiple(of: 2) ? dueToServe : dueToServe.opponent
    }

    /// A Set level at 6–6 is decided by a Tie-break.
    var isTieBreak: Bool { gamesInSet[.us] == 6 && gamesInSet[.them] == 6 }

    func points(_ team: Team) -> String {
        if isTieBreak { return "\(pointsInGame[team])" }
        let own = pointsInGame[team], opponent = pointsInGame[team.opponent]
        if own >= 3 && opponent >= 3 { return own > opponent ? "AD" : "40" }
        return ["0", "15", "30", "40"][own]
    }

    /// Games in the Set being played.
    func games(_ team: Team) -> Int { gamesInSet[team] }

    fileprivate mutating func record(_ winner: Team) {
        let pointsToWinGame = isTieBreak ? 7 : 4
        pointsInGame[winner] += 1
        guard pointsInGame.hasWon(winner, reaching: pointsToWinGame) else { return }
        pointsInGame = Tally()
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
