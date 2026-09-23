import WatchKit

/// What the wrist feels, so the players know what happened without looking. Every new Point fires
/// one, so a tap that fires nothing scored nothing: that silence is the error signal for a tap that
/// lands on the strip.
enum Haptic: Equatable {
    case click, success, notification, retry, directionUp, directionDown

    /// The haptics a new Point fires, from the score before it to the score after. The point clicks
    /// (one for Us, two for Them) give way to `.success` for a Game won, and that to `.notification`
    /// for a Set or the Match won. `.retry` follows at a Deciding point, and `.directionUp` at a
    /// Change of ends.
    static func forPoint(by team: Team, from before: Score, to after: Score) -> [Haptic] {
        var haptics: [Haptic]
        if after.sets.count > before.sets.count {
            haptics = [.notification]
        } else if !after.isGameUnderway {
            haptics = [.success]
        } else {
            haptics = team == .us ? [.click] : [.click, .click]
        }
        if after.isDecidingPoint { haptics.append(.retry) }
        if after.isChangeOfEnds { haptics.append(.directionUp) }
        return haptics
    }

    /// Plays haptics in order, after any still playing, so each one is felt on its own.
    @MainActor
    static func play(_ haptics: [Haptic]) {
        guard !haptics.isEmpty else { return }
        let previous = lastPlayed
        lastPlayed = Task {
            await previous?.value
            for haptic in haptics {
                WKInterfaceDevice.current().play(haptic.type)
                try? await Task.sleep(for: haptic.gap)
            }
        }
    }

    @MainActor private static var lastPlayed: Task<Void, Never>?

    /// How long to wait before the next haptic: a click is short, so a second one follows ~150 ms
    /// later; the longer patterns need more room to stay apart.
    private var gap: Duration { self == .click ? .milliseconds(150) : .milliseconds(450) }

    private var type: WKHapticType {
        switch self {
        case .click: .click
        case .success: .success
        case .notification: .notification
        case .retry: .retry
        case .directionUp: .directionUp
        case .directionDown: .directionDown
        }
    }
}
