@testable import PuntoDeOro

/// The Points that win this many Games in a row to love.
func gamesToLove(_ team: Team, _ count: Int) -> [Team] {
    Array(repeating: team, count: 4 * count)
}

/// The Points that bring the first Set level at 6–6, with Us due to serve the Tie-break.
let sixAll = gamesToLove(.us, 5) + gamesToLove(.them, 6) + gamesToLove(.us, 1)

extension Score {
    /// The completed Sets as [Us, Them] Games.
    var setScores: [[Int]] { sets.map { [$0.games(.us), $0.games(.them)] } }
}

extension Match {
    /// A Match under these Rules whose Point log holds these Points, played in order.
    init(rules: Rules = Rules(), pointsWonBy winners: [Team]) {
        self.init(rules: rules)
        for team in winners { scorePoint(for: team) }
    }
}
