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

/// The fixed configuration of a Match.
struct Rules {
    var format: Format = .threeSets
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

/// The shape of a Match.
enum Format: Equatable {
    case threeSets
    /// A Super tie-break replaces the third Set at 1–1.
    case twoSetsPlusSuperTieBreak
    /// One 9-game Set, decided at 8–8 by the tie-break chosen at setup.
    case proSet(decider: TieBreak)
    /// No Sets, only a running count of Games.
    case infinite

    /// The Games that win a Set with a two-game lead, or nil when the Format has no Sets.
    fileprivate var gamesToWinSet: Int? {
        switch self {
        case .threeSets, .twoSetsPlusSuperTieBreak: 6
        case .proSet: 9
        case .infinite: nil
        }
    }

    /// The Games each Team holds when a Set's tie-break is played, or nil when the Format has no Sets.
    fileprivate var tieBreakAt: Int? {
        switch self {
        case .threeSets, .twoSetsPlusSuperTieBreak: 6
        case .proSet: 8
        case .infinite: nil
        }
    }

    /// The tie-break that decides a level Set.
    fileprivate var setTieBreak: TieBreak {
        if case .proSet(let decider) = self { decider } else { .tieBreak }
    }

    /// The Sets that win the Match, or nil when the Format has no Sets.
    fileprivate var setsToWin: Int? {
        switch self {
        case .threeSets, .twoSetsPlusSuperTieBreak: 2
        case .proSet: 1
        case .infinite: nil
        }
    }
}

/// The Game that decides a level Set.
enum TieBreak {
    case tieBreak, superTieBreak

    fileprivate var pointsToWin: Int { self == .tieBreak ? 7 : 10 }
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

extension Match {
    /// The final outcome of a Match.
    enum Result: Equatable {
        case won(Team)
        /// Infinite only: the counts of completed Games are level.
        case draw
        /// A set-based Match that was Ended early.
        case unfinished
    }
}

/// The score derived from a Point log.
struct Score {
    private let rules: Rules
    private var format: Format { rules.format }
    private var pointsInGame = Tally()
    /// Returns to 40–40 in the Game being played.
    private var deucesInGame = 0
    private var gamesInSet = Tally()
    private var gamesPlayed = 0
    /// The completed Sets, in the order they were played.
    private(set) var sets: [SetScore] = []
    /// The Team that won the Sets the Format asks for, once the Match is Decided.
    private(set) var winner: Team?
    /// Whether the last Point sits on a Change of ends: an odd completed Game of the Set, or every
    /// 6 Points of a Tie-break. Counting Games per Set cues a Set ending odd (6–3, 7–6) at its end,
    /// and one ending even (6–4) after the first Game of the next Set.
    private(set) var isChangeOfEnds = false

    var isDecided: Bool { winner != nil }

    /// The Result once the Match is Decided, whether by its winning Point or by the players ending it
    /// here. Infinite counts completed Games only; the unfinished Game is ignored.
    var result: Match.Result {
        if let winner { return .won(winner) }
        guard format == .infinite else { return .unfinished }
        if gamesInSet[.us] == gamesInSet[.them] { return .draw }
        return .won(gamesInSet[.us] > gamesInSet[.them] ? .us : .them)
    }

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

    /// The tie-break being played, if any: a Set level at 6–6 (8–8 in a Pro set) is decided by one,
    /// and in 2 sets + super tie-break a Super tie-break replaces the third Set.
    var tieBreak: TieBreak? {
        if isThirdSetSuperTieBreak { return .superTieBreak }
        guard let tieBreakAt = format.tieBreakAt,
              gamesInSet[.us] == tieBreakAt, gamesInSet[.them] == tieBreakAt else { return nil }
        return format.setTieBreak
    }

    /// Whether a Tie-break or Super tie-break is being played.
    var isTieBreak: Bool { tieBreak != nil }

    /// Whether the Super tie-break standing in for the third Set is being played: it has no Games.
    var isThirdSetSuperTieBreak: Bool {
        format == .twoSetsPlusSuperTieBreak && sets.count == 2 && !isDecided
    }

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

    /// Games in the Set being played, or the running count of an Infinite match.
    func games(_ team: Team) -> Int { gamesInSet[team] }

    fileprivate mutating func record(_ winner: Team) {
        // Whether this Point was played in a tie-break, fixed before the Point changes the score.
        let tieBreak = tieBreak
        let wasDecidingPoint = isDecidingPoint
        pointsInGame[winner] += 1
        guard wasDecidingPoint || pointsInGame.hasWon(winner, reaching: tieBreak?.pointsToWin ?? 4) else {
            if isDeuce { deucesInGame += 1 }
            isChangeOfEnds = tieBreak != nil && pointsInGame.total.isMultiple(of: 6)
            return
        }
        let gamePoints = pointsInGame
        pointsInGame = Tally()
        deucesInGame = 0
        gamesPlayed += 1
        if isThirdSetSuperTieBreak {
            completeSet(SetScore(superTieBreak: gamePoints), wonBy: winner)
            return
        }
        gamesInSet[winner] += 1
        isChangeOfEnds = !gamesInSet.total.isMultiple(of: 2)
        guard let gamesToWinSet = format.gamesToWinSet,
              tieBreak != nil || gamesInSet.hasWon(winner, reaching: gamesToWinSet) else { return }
        completeSet(SetScore(games: gamesInSet), wonBy: winner)
        gamesInSet = Tally()
    }

    private mutating func completeSet(_ set: SetScore, wonBy winner: Team) {
        sets.append(set)
        if sets.count(where: { $0.winner == winner }) == format.setsToWin {
            self.winner = winner
            isChangeOfEnds = false
        }
    }
}

/// The Games each Team won in a completed Set, or the Points of a Super tie-break that replaced it.
struct SetScore {
    fileprivate let games: Tally
    let isSuperTieBreak: Bool

    fileprivate init(games: Tally) {
        self.games = games
        isSuperTieBreak = false
    }

    fileprivate init(superTieBreak points: Tally) {
        games = points
        isSuperTieBreak = true
    }

    /// Games won, or Points won when this was a Super tie-break.
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
