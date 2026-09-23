import Foundation

extension Match.Result {
    /// The summary's header.
    var title: String {
        switch self {
        case .won(let winner): "\(winner.name) win"
        case .draw: "Draw"
        case .unfinished: "Unfinished"
        }
    }
}

extension Score {
    /// The score as the summary shows it, Us first: a column per Set, a tie-break's loser's Points
    /// raised (`6–4 3–6 7–6⁽⁵⁾`), a Super tie-break as its Points (`10–8`). A Match Ended early adds
    /// the Set and Game as they stood (`6–4 3–4 (30–15)`); an Infinite match shows its completed
    /// Games only (`14–11`).
    var summary: String {
        if isInfinite { return pair(games(.us), games(.them)) }
        var columns = sets.map(column)
        if !isDecided {
            if !isThirdSetSuperTieBreak { columns.append(pair(games(.us), games(.them))) }
            if isGameUnderway { columns.append("(\(pair(points(.us), points(.them))))") }
        }
        return columns.joined(separator: " ")
    }

    private func column(_ set: SetScore) -> String {
        let games = pair(set.games(.us), set.games(.them))
        guard let loserPoints = set.tieBreakPoints(set.winner.opponent) else { return games }
        return games + "⁽\(loserPoints.superscript)⁾"
    }

    private func pair(_ us: some CustomStringConvertible, _ them: some CustomStringConvertible) -> String {
        "\(us)–\(them)"
    }
}

private extension Int {
    var superscript: String {
        let digits = Array("⁰¹²³⁴⁵⁶⁷⁸⁹")
        return String(String(self).compactMap { $0.wholeNumberValue.map { digits[$0] } })
    }
}
