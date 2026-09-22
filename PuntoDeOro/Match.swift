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

    mutating func scorePoint(for team: Team, at timestamp: Date = .now) {
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
    private var gamesWon = Tally()

    fileprivate init(firstServer: Team) {
        self.firstServer = firstServer
    }

    /// Serve alternates every Game.
    var servingTeam: Team {
        gamesWon.total.isMultiple(of: 2) ? firstServer : firstServer.opponent
    }

    func points(_ team: Team) -> String {
        let own = pointsInGame[team], opponent = pointsInGame[team.opponent]
        if own >= 3 && opponent >= 3 { return own > opponent ? "AD" : "40" }
        return ["0", "15", "30", "40"][own]
    }

    func games(_ team: Team) -> Int { gamesWon[team] }

    fileprivate mutating func record(_ winner: Team) {
        pointsInGame[winner] += 1
        if pointsInGame[winner] >= 4 && pointsInGame[winner] - pointsInGame[winner.opponent] >= 2 {
            gamesWon[winner] += 1
            pointsInGame = Tally()
        }
    }
}

/// A count kept for each Team.
private struct Tally {
    private var us = 0, them = 0

    var total: Int { us + them }

    subscript(team: Team) -> Int {
        get { team == .us ? us : them }
        set { if team == .us { us = newValue } else { them = newValue } }
    }
}
