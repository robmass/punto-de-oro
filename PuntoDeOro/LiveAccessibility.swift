import Foundation

/// How VoiceOver reads one half of the live screen: a single element, its Team and Point score,
/// and how to score for it.
struct SpokenHalf: Equatable {
    var label: String
    var value: String
    var hint: String
}

extension Score {
    /// A half as one element, "Them, 30. Double-tap to score a point for Them.": the Point score as
    /// shown, but Advantage as a word rather than the letters "AD".
    func spokenHalf(_ team: Team) -> SpokenHalf {
        let points = points(team)
        return SpokenHalf(
            label: team.name,
            value: points == "AD" ? "Advantage" : points,
            hint: "Double-tap to score a point for \(team.name)."
        )
    }
}

extension Match {
    /// The strip's status, one label per line: the Deuce rule's name at a Deciding point, else
    /// `Tie-break` or `Super tie-break` while one is played, over `Change ends` until the next Point.
    var stripStatuses: [String] {
        let score = score
        if score.isDecidingPoint { return [rules.deuceRule.name] }
        var statuses = [score.tieBreak?.name].compactMap(\.self)
        if score.isChangeOfEnds { statuses.append("Change ends") }
        return statuses
    }

    /// The whole strip as one element, "Games 4-3. Sets, Us 6-4. Golden point.": Us first
    /// throughout, as on the summary, and only what the strip shows.
    var spokenStrip: String {
        let score = score
        var sentences: [String] = []
        if score.showsCurrentGames {
            sentences.append("Games \(score.games(.us))-\(score.games(.them))")
        }
        if !score.sets.isEmpty {
            let sets = score.sets.map { "\($0.games(.us))-\($0.games(.them))" }
            sentences.append("Sets, Us " + sets.joined(separator: ", "))
        }
        sentences += stripStatuses
        return sentences.map { $0 + "." }.joined(separator: " ")
    }
}
