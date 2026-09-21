# Punto de Oro

A padel score tracker for Apple Watch. This glossary fixes the language for matches, their rules, and how the score is derived.

## Language

### Match and its rules

**Match**:
One game of padel between two Teams, defined entirely by its Rules and its Point log.
_Avoid_: Game (a Game is a unit inside a Set), session

**Rules**:
The fixed configuration of a Match, chosen at setup: Format, Deuce rule, and first-serving Team.
_Avoid_: Settings, config

**Format**:
The shape of a Match: **3 sets** (best of three 6-game Sets, full third Set), **2 sets + super tie-break** (a Super tie-break replaces the third Set at 1–1), **Pro set** (one 9-game Set, with a Tie-break or Super tie-break at 8–8), or **Infinite**.
_Avoid_: Games per set, mode, match type

**Point log**:
The ordered list of Points played so far in a Match; the only thing that changes during play. Every score shown is derived from it.
_Avoid_: History, events

**Point**:
One rally, won by exactly one Team; the single entry in the Point log.
_Avoid_: Rally (when meaning the scoring unit)

**Undo**:
Removing the most recent Point from the Point log. Unlimited, back to an empty log.
_Avoid_: Correction, revert

### Scoring

**Team**:
One of the two sides in a Match. Serve and Points belong to Teams, never to individual players.
_Avoid_: Pair, side, player

**Set**:
A unit of a Match won by the first Team to 6 Games (9 in a Pro set) with a two-game lead, or by winning its Tie-break.
_Avoid_: Round

**Game**:
A unit of a Set, scored 0/15/30/40, won under the Match's Deuce rule; a Tie-break is also a Game.
_Avoid_: Point (a Point is a unit inside a Game)

**Deuce**:
40–40 within a Game. Each return to 40–40 in the same Game counts as a further Deuce (first, second, third).
_Avoid_: Tie, 40-all

**Advantage**:
The state after a Team wins the Point following a Deuce, when the Deuce rule still allows play to continue; winning the next Point wins the Game.
_Avoid_: Ad

**Deuce rule**:
How a Game is settled from Deuce, chosen at setup: **Advantage** (win by two, unlimited), **Golden point** (first Deuce is decisive), **Silver point** (one Advantage, second Deuce is decisive), or **Star point** (two Advantages, third Deuce is decisive).
_Avoid_: Deuce mode, no-ad

**Deciding point**:
A Point played at a Deuce that the Deuce rule makes decisive: whoever wins it wins the Game. Never occurs under Advantage or inside a Tie-break.
_Avoid_: Sudden death, killer point

**Serving team**:
The Team serving the current Point; it alternates each Game, and in a Tie-break after the first Point and then every two Points. The other Team is the **Receiving team**.
_Avoid_: Server (implies an individual player)

**Tie-break**:
The Game that decides a Set level at 6–6 (or 8–8 in a pro set), scored 0, 1, 2… to 7, won by two. The deuce rule never applies inside it; the Set is recorded as 7–6 (or 9–8).
_Avoid_: Tiebreaker, sudden death

**Super tie-break**:
A Tie-break played to 10 instead of 7, still won by two. It either replaces the third Set (2 sets + super tie-break) or decides a Pro set at 8–8.
_Avoid_: Match tie-break, champions tie-break, long tie-break

**Infinite match**:
A Match with no Sets, only a running count of Games, which ends only when the players choose to end it.
_Avoid_: Timed match, open match

**Decided**:
A Match whose winning Point has been played, or an Infinite match the players have stopped; it still shows its summary and can be reopened by Undo.
_Avoid_: Over, done

**Finished**:
A Decided Match whose summary the players have left; final, and no longer affected by Undo.
_Avoid_: Closed, archived, saved

**Result**:
The final outcome of a Match: the winning Team, or a Draw. In an Infinite match it counts completed Games only; the unfinished Game is ignored.
_Avoid_: Outcome, final score

**Draw**:
A Result with no winner, possible only in an Infinite match when the counts of completed Games are level.
_Avoid_: Tie (clashes with Tie-break)
