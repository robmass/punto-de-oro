# Punto de Oro — build-ready spec

A padel score-tracking app for Apple Watch, native SwiftUI, watch-only.

This document is the hand-off. Every decision in it was locked by a ticket on the
[Wayfinder map](https://github.com/robmass/punto-de-oro/issues/1); nothing here is new.
Where a decision has a primary source richer than this summary — a prototype, a research
file, the glossary — it is linked, and the source wins on detail.

The domain language is fixed by [`CONTEXT.md`](../CONTEXT.md) and used here exactly as
defined there: **Match**, **Rules**, **Point log**, **Format**, **Deuce rule**, **Decided**,
**Finished**, and the rest.

---

## 1. What the app is

One screen to score a padel match on the wrist, mid-rally, without looking. A match runs as
an Apple Health workout, is undoable without limit, and ends on a summary screen. There is no
history, no phone app, and no account.

**Hard requirement:** the fewest taps possible, usable mid-rally with the wrist down. Every
layout and input decision below is downstream of that.

**Audience:** personal sideload first. Nothing in this spec rules out a later App Store
release, but nothing in it is done *for* one.

---

## 2. Platform and project setup

| | |
|---|---|
| Target | watchOS app, **watch-only** (no iOS companion target) |
| Minimum OS | **watchOS 26** |
| UI | SwiftUI |
| Persistence | SwiftData |
| Dev device | Apple Watch Series 9, 45mm, watchOS 27 |
| Team | `PYTG8F6332` — free Personal Team is sufficient; builds re-sign every 7 days |
| Bundle display name | `Punto de Oro` (in full — see §10) |

watchOS 26 supports Series 6+, SE 2 and Ultra 1+. The floor is set by the OS, not by case
size: every device that runs watchOS 26 is supported.

### Capabilities and Info.plist

- **HealthKit** capability on the watch app target.
- `NSHealthShareUsageDescription` — read justification.
- `NSHealthUpdateUsageDescription` — write justification.
- `WKBackgroundModes` = `workout-processing`.
- Authorization to share `HKWorkoutType`. Since watchOS 6 the prompt is shown on the watch
  itself, so these keys belong on the watch app target.
- **Audio background mode is not needed** — the app plays no audio; haptics during a workout
  are covered by the workout session.

### Sideloading

Developer Mode on the watch appears only once the paired iPhone is cabled to the Mac with its
own Developer Mode on, and the watch must be on the same Wi-Fi (the watch's "Mirror iPhone"
airplane setting off). Install with:

```
xcrun devicectl device install app --device <udid> <path/to/.app>
```

*Source: [watchOS platform facts](https://github.com/robmass/punto-de-oro/issues/2) ·
[research findings](https://github.com/robmass/punto-de-oro/blob/research/watchos-platform-facts/research/watchos-platform-facts.md)*

---

## 3. Domain model

### The core shape

> **A Match is its Rules plus its Point log. Everything else is derived by replaying the log.**

Nothing about the score is stored. Points won, games, sets, the serving team, the deuce count,
the deciding-point flag, the change-of-ends cue and the match's end are all computed from the
ordered list of Points. This is what makes unlimited undo a one-line operation and makes
persistence cheap enough to do after every point.

```
Match
  Rules
    format:      .threeSets | .twoSetsPlusSuperTieBreak | .proSet(decider:) | .infinite
    deuceRule:   .advantage | .goldenPoint | .silverPoint | .starPoint
    firstServer: .us | .them
  points:        [Point]        // each: winning Team + timestamp
```

A **Point** is one rally, won by exactly one Team. Teams are **Us** and **Them** — the wearer's
team is always Us. Serve, points and everything else belong to Teams, never to individual
players.

### Formats

| Format | Shape |
|---|---|
| **3 sets** | Best of three 6-game Sets. Tie-break to 7 at 6–6. Full third Set. |
| **2 sets + super tie-break** | As above, but at 1–1 in Sets a **Super tie-break** (to 10) replaces the third Set. Recorded e.g. `6–4 3–6 [10–7]`. |
| **Pro set** | One 9-game Set. At 8–8, a **Tie-break** or a **Super tie-break** — a sub-choice made at setup. Recorded 9–8 either way. |
| **Infinite** | No Sets. A running count of Games until the players stop. |

A Set is won by the first Team to 6 Games (9 in a Pro set) with a two-game lead, or by winning
its tie-break.

### Games and the Deuce rule

A Game is scored 0 / 15 / 30 / 40. **Deuce** is 40–40; each return to 40–40 in the same Game is
a further Deuce (first, second, third). The deuce count **resets every Game**.

| Deuce rule | Behaviour |
|---|---|
| **Advantage** | Win by two, unlimited. No deciding point ever. |
| **Golden point** | The **1st** Deuce is decisive. |
| **Silver point** | One Advantage; the **2nd** Deuce is decisive. |
| **Star point** | Two Advantages; the **3rd** Deuce is decisive (FIP). |

A **Deciding point** is a Point at a Deuce that the Deuce rule makes decisive: whoever wins it
wins the Game. It is flagged on screen and by haptic (§6). It **never** occurs under Advantage
and **never** inside a tie-break.

### Tie-breaks (FIP 2026)

- Points count 0, 1, 2, … First to **7** (**10** for a Super tie-break), **win by 2**, no upper
  limit.
- The Deuce rule never applies inside a tie-break.
- **Serve:** the Team due to serve serves 1 point, then serve changes every 2 points.
- The next Set is served first by the Team that did **not** serve first in the tie-break.
- A normal Set won in a tie-break is recorded **7–6**; a Pro set, **9–8**.

### Serve

Tracked **per Team**. The first-serving Team is chosen at setup; serve alternates every Game,
and follows the tie-break pattern above inside one. Individual-player serve tracking is out of
scope.

### Change of ends

Signalled by the app, not left to the players.

- **When:** after every **odd completed Game of a Set** (1st, 3rd, 5th…), and every **6 Points**
  of a Tie-break or Super tie-break.
- Games count **per Set**, which reproduces FIP exactly with no special cases: a Set ending on
  an odd total (7–6, 6–3) cues at the Set end; one ending even (6–4) cues after the first Game
  of the next Set.
- **Infinite** uses the same rule over its running Game count.
- **The halves never swap.** Us stays the bottom half for the whole Match. The halves mean
  "my team" / "the other team", not a physical side — swapping would move a blind tap target.
- **Derived like everything else:** the cue is shown whenever the Point log sits exactly on a
  changeover boundary. Undoing back to a boundary re-shows it with **no haptic replay** (haptics
  fire only on new Points). A crash mid-changeover restores it correctly. No extra persisted
  state.

### Undo

Removes the most recent Point from the log. **Unlimited**, back to an empty log, and across
Game, Set and tie-break boundaries. Serve, deuce count and the deciding-point flag rewind
correctly for free, because they were never stored.

### Match end and Result

- In set-based Formats, the Point that wins the Match makes it **Decided**.
- An **Infinite** Match is Decided when the players stop it.
- **Decided** → the summary shows, and the Match can be reopened (Undo, or Resume).
- Leaving the summary makes the Match **Finished**: final, workout saved, Undo no longer
  possible.

| Result | When |
|---|---|
| **Winning Team** | The Match was played out; in Infinite, one Team has more completed Games. |
| **Draw** | Infinite only, completed Games level. |
| **Unfinished** | A set-based Match ended early and saved. Score shown exactly as it stood. |

Infinite counts **completed Games only** — the unfinished Game is shown but does not count.

*Source: [Scoring rules and domain language](https://github.com/robmass/punto-de-oro/issues/3) ·
[Changing ends](https://github.com/robmass/punto-de-oro/issues/8) · [`CONTEXT.md`](../CONTEXT.md)*

---

## 4. App structure and flow

```
                    ┌──────────────┐
   launch  ────────▶│ Setup wizard │   (no non-Finished match on disk)
                    └──────┬───────┘
                           │  Start  → replaces the scene root
                           ▼
              ┌────────────────────────────┐
              │  Root TabView (2 pages,    │
              │  horizontal paging)        │
              │                            │
              │  ◀ page 1: Controls        │
              │    page 2: Live scoring ▶  │  ← selected page
              └─────────────┬──────────────┘
                            │  Decided
                            ▼
                     ┌─────────────┐   Done  → Finished → Setup wizard
                     │   Summary   │   Undo / Resume → back to live
                     └─────────────┘

   launch with a non-Finished match on disk ────▶ Root TabView, live page
```

**Setup is replaced, never pushed.** The TabView must be the scene root. If setup were pushed
onto a `NavigationStack`, the system back-swipe would own the left edge and a mid-match
swipe-right would drop the player into the setup wizard.

---

## 5. Setup wizard

One screen per choice, tap a row to advance. Neutral chrome — system white/graphite, no gold.

| # | Screen | Content |
|---|---|---|
| 1 | **Format** | 4 rows, each with a one-line subtitle: 3 sets / 2 sets + super tie-break / Pro set / Infinite. When previous Rules exist, a **Play again** row sits *above* them showing the last Format and Deuce rule. |
| 2 | **At 8–8** | **Pro set only.** Tie-break (to 7) / Super tie-break (to 10). The Format list stays four rows — this is a follow-up step, not two Format rows. |
| 3 | **Deuce** | 4 rows, name + subtitle: Advantage "Win by two" · Golden point "1st deuce decides" · Silver point "2nd deuce decides" · Star point "3rd deuce decides". |
| 4 | **Serve** | Two full-width buttons: **Us** / **Them**. |
| 5 | **Ready** | Summary of the chosen Rules, and **Start**. |

**Taps to start:** 5 for a fresh match, 6 for a Pro set, **2 to replay the last Rules**
(Play again → Serve → … — Play again jumps straight to the Serve screen).

**Remembering.** The last Rules used are the Rules of the most recent SwiftData record — no
separate store. The current choice is ticked on each screen. **On a first run with no records,
the Format screen shows its four rows and no Play again row.**

**Health permission is requested on the first Start**, never at launch. The ask then arrives
with a visible reason (a workout is about to begin), and the app opens straight into setup
rather than into a permission sheet.

**Dynamic Type:** honoured in full, including accessibility sizes. One choice per screen, so
the list simply scrolls.

**Return to Clock applies here** (system default, 2 min) — setup runs outside the workout
session.

*Source: [Setup flow design](https://github.com/robmass/punto-de-oro/issues/4) ·
prototype on [`prototype/setup-flow`](https://github.com/robmass/punto-de-oro/tree/prototype/setup-flow/Prototypes/SetupFlowPrototype)*

---

## 6. Live scoring screen — the "Halves" layout

The trailing page of the root TabView, and the screen the player stares at for ninety minutes.

**Primary source:** [`prototype/live-scoring/index.html`](https://github.com/robmass/punto-de-oro/blob/wayfinder/live-scoring/prototype/live-scoring/index.html)
(`bun prototype/live-scoring/index.html`, open `?variant=A`).

### Layout

```
┌─────────────────────────────┐
│ ↶                     10:24 │  top bar, 26pt, black
├─────────────────────────────┤
│                             │
│          THEM               │  top half — Them
│  ●        30                │  ● = serve marker
│                             │
├─────────────────────────────┤
│      4-3   6-4   TIE-BREAK  │  middle strip, 34pt — dead zone
├─────────────────────────────┤
│                             │
│           40                │  bottom half — Us
│           US                │
│                             │
└─────────────────────────────┘
```

- **Top bar (26pt, black).** Undo `↶` on the left (`topBarLeading`), clock on the right. It sits
  *outside* both halves, so it reads as undo for the whole match rather than for one team.
- **Top half = Them. Bottom half = Us.** As if looking across the net. Each half shows the Team
  label, its point score (0/15/30/40/AD, or tie-break numbers) and a ball marker when that Team
  is serving.
- **Middle strip (34pt).** Games (Them above, Us below, matching the halves), completed Set
  scores, and `TIE-BREAK` / `SUPER TIE-BREAK` when one is being played. **Infinite:** running
  Game count only.
- **Deciding point:** the strip turns **solid gold** and shows the rule's name — `GOLDEN POINT`,
  `SILVER POINT` or `STAR POINT`.
- **Change of ends:** the strip shows `CHANGE ENDS` in **white on the ordinary dark strip — not
  gold** (§10: gold is reserved). It clears on the next Point.

The deciding-point and change-of-ends states can never collide: a change of ends only happens
between Games, the gold strip only during one, and the Deuce rule never applies inside a
tie-break.

### Geometry across watch sizes

**Governing principle:** *mid-rally blind targets stay maximal and pinned; everything eyes-on
may scale, shrink, or sit under the hit-target minimum.*

The top bar (26pt) and middle strip (34pt) **keep their point heights on every watch** — they
carry identical content everywhere and neither is a scoring target, so scaling them buys
nothing and costs strip legibility at 40mm. **The two halves split the remainder.**

| Case | Screen (pt) | Half height | Models |
|---|---|---|---|
| 40mm | 162×197 | 68pt | Series 6, SE 2 — **design floor** |
| 41mm | 176×215 | 77pt | Series 7/8/9 |
| 42mm | 187×223 | 81pt | Series 10/11/12 |
| 44mm | 184×224 | 82pt | Series 6, SE 2 |
| 45mm | 198×242 | 91pt | Series 7/8/9 — **dev device** |
| 46mm | 208×248 | 94pt | Series 10/11/12 |
| 49mm | 205×251 | 95pt | Ultra 1–4 |

- **The score digit scales with its half, at ~70% of half height** — ~48pt at 40mm, ~66pt at
  49mm. The largest element on screen is always as large as that screen allows.
  *(Build note: the prototype rendered 56pt at 45mm, where the 70% rule gives ~64pt. Follow the
  rule and check it by eye on the 45mm device — this is the one numeric inconsistency left in
  the map.)*
- Nothing is letterboxed. There is no fixed-geometry fallback.
- 45mm is the only size tested on hardware; the rest in the simulator.

### Input

| Input | Bound to |
|---|---|
| **Tap a half** | Point to that Team. The primary input; works on every model and while dimmed. |
| **Top-bar ↶** | Undo. Every model. **No confirmation.** |
| **Double Tap** | Undo — with `.handGestureShortcut(.primaryAction, isEnabled: page == .live)` |
| Digital Crown | Not bound. |
| Action Button (Ultra) | Not bound. |

**Double Tap is Undo, not a point.** A tap already scores, and binding Double Tap to one team's
point would make that team easier to score for. It needs a raised wrist, gives one action only,
and is off in Water Lock and Low Power Mode — so it is strictly an extra, never the only route.

**Undo is never confirmed.** It is unlimited, and a mistaken undo is repaired by tapping the
point again. It shows a toast naming what it removed:

```
Undone · point Them · 30–15
```

### Hit targets

- **The halves are never the problem.** At the 40mm floor each is 162×68pt, far above the
  44×44pt minimum, and full-width at every size by construction.
- **The middle strip is a dead zone.** A tap on it does nothing. This works *because* every
  scored point fires a haptic — so a tap that lands on the strip produces **silence, and silence
  is the error signal**. The cost of an ambiguous tap is one repeat; routing it to the nearest
  half would cost an undo plus a re-tap, and could put a point on the wrong team unnoticed. The
  dead band is exactly the visible 34pt — no invisible buffer, so nothing dead is undrawn.
- **The undo button widens sideways to ~60×26pt and stays inside the top bar.** It never extends
  into a half. Under-height is accepted: undo is a deliberate, eyes-on, between-points action.
  Giving it a full 44pt would consume 26% of the Them half at 40mm and turn a top-left tap aimed
  at Them into an undo.
- **The general rule:** any control that is not mid-rally may sit under the minimum, provided it
  lives in the top bar and takes no area from a half.

### Haptics

| Event | Haptic |
|---|---|
| Point for **Us** | 1 × `.click` |
| Point for **Them** | 2 × `.click` (~150 ms apart) |
| Game won | `.success` (replaces the point clicks) |
| Set / Match won | `.notification` |
| Deciding point reached | `.retry` (after the point haptic) |
| Change of ends | `.directionUp` (after the game haptic; alongside the point haptic inside a tie-break) |
| Undo | `.directionDown` |

Haptics fire only on **new** Points — never on undo replay.

### Always On (dimmed)

- **Identical layout, identical tap areas**, so a tap with the wrist down lands where it did with
  the wrist up. The pinned score geometry above is what makes this guarantee hold — nothing
  reflows between active and dimmed.
- Filled backgrounds become outlines on black; team colour survives in text and outlines.
  Points, games and sets stay legible.
- The deciding-point strip becomes a **gold outline with gold text**; the rule's name stays
  readable.
- Nothing animates.
- Controls stay tappable while dimmed: a tap runs the action *and* wakes the app.

*Source: [Live scoring screen and point input](https://github.com/robmass/punto-de-oro/issues/5) ·
[Sizing and accessibility](https://github.com/robmass/punto-de-oro/issues/10) ·
[Changing ends](https://github.com/robmass/punto-de-oro/issues/8)*

---

## 7. The controls page and End match

The **leading** page of the root TabView. Swipe right from the live screen to reach it, left to
return. This is the Workout app's own controls-page idiom.

| | |
|---|---|
| **Page 1 (leading)** | Controls — one large centred **End match** button |
| **Page 2 (trailing)** | Live scoring, exactly as §6 |

### The page

- **One control only:** a large centred **End match** button, far above 44pt.
- **No top bar** — no undo, no app-drawn clock. The system clock keeps its corner.
- **Nothing else.** No Water Lock (it kills touch *and* Double Tap, disabling scoring). No New
  match (the summary already offers it). No live stats.
- Neutral chrome. Gold stays reserved.

### Why a mid-rally tap cannot reach it

1. **It needs a drag, not a tap.** Paging requires horizontal travel past a threshold; a blind
   jab at a half cannot produce one.
2. **It takes zero area from either half.** The control is on a different page, so the halves
   keep every pixel at every size.
3. **The page can never lie in wait** — see auto-return.

### Auto-return — a dimmed screen is always the live page

**Whenever the display dims or goes inactive** (wrist down, or the idle timeout after a raise),
page selection snaps back to the live page.

Chosen over an idle timer because it is self-completing — the display always dims eventually, so
the controls page cannot survive into any state where a blind tap could land on it — and because
it never yanks the page away while the player is looking at it, deciding.

**End match is therefore not reachable while dimmed.** The player raises the wrist first. The
Always On guarantee from §6 is untouched: the dimmed screen is the Halves layout, always.

### Page indicator

Transient: dots fade in while the page moves under the thumb and fade out at rest, so the live
screen is clean at rest and in Always On, while the gesture still reveals its own affordance the
first time a thumb brushes sideways.

**Spec condition: the index must overlay, never participate in layout.** If it would shift the
halves even by a point, hide it instead. Nothing may move under a blind tap.

### Double Tap guard — required, not a preference

`handGestureShortcut(.primaryAction)` resolves **leading-to-trailing in the active scene**, and
the controls page is *leading* of the live page. Left alone, SwiftUI could resolve Double Tap to
**End match** instead of Undo.

- The **Undo** button carries `.handGestureShortcut(.primaryAction, isEnabled: page == .live)`.
- The **End match** button **never** carries the shortcut.
- On the controls page, Double Tap has no target and does nothing.

### What End match opens

A native SwiftUI **`confirmationDialog`**:

| | |
|---|---|
| Title | **End match?** |
| **Save** | → **Decided**. Set-based Formats get Result **Unfinished**; Infinite gets its normal Result. Workout kept. |
| **Discard** | → **Abandoned**. `discardWorkout()`, no summary, back to setup. Styled `.destructive`. |
| **Cancel** | → returns to the **live page**, not the controls page — keeping "a dimmed screen is always the live page" true. |

- **An empty Point log abandons silently, with no prompt.**
- Crown-scrollable at 40mm; honours Dynamic Type in full, including accessibility sizes — the
  prompt is eyes-on, never mid-rally.
- The `.destructive` red on Discard is **the only red in the app**, carrying the system's
  destructive role.

*Source: [End match control placement](https://github.com/robmass/punto-de-oro/issues/12) ·
[Match lifecycle and persistence](https://github.com/robmass/punto-de-oro/issues/6)*

---

## 8. Lifecycle, workout session and persistence

### No pause

There is none. The workout and the match clock run continuously from the first Point to Decided.

### Workout session

- Every Match runs as an `HKWorkoutSession`. This is what keeps the app in front on the wrist for
  the whole match: with an active session the app runs for the session's duration and reappears
  on a wrist raise, with **no documented time limit**, and Return to Clock does not apply. The
  only documented limit is background CPU use.
- `HKWorkoutActivityType.tennis` — **there is no padel type** in `HKWorkoutActivityType`.
  `.pickleball` is the acceptable alternative; `.paddleSports` is canoe/kayak/SUP and is wrong.
  Calorimetry is sensor-estimated for all racket sports, so the choice affects the label and icon
  in Fitness and Health, not accuracy. Re-check the enumeration each WWDC in case Apple adds
  padel.
- `HKWorkoutConfiguration.locationType = .indoor`. The research recommended "a setup choice or
  `.indoor`"; the setup wizard has no such step (§5), so `.indoor` is fixed.
- **The session ends and saves at Finished**, with the workout's end date **backdated to the
  Decided moment** — so the minutes spent reading the summary are not counted as play.
- **One Match = one Health entry.**

### Summary screen

Shown when the Match becomes Decided. It runs **inside** the workout session, so Return to Clock
does not apply to it.

**Content:**

- **Result header** — winning Team / **Draw** / **Unfinished**.
- **Per-set columns with tie-break detail** — `6–4 3–6 7–6⁽⁵⁾`; a super tie-break as `10–8`.
- **Unfinished** adds the current set's games and the current game's points:
  `6–4 3–4 (30–15)`.
- **Infinite** shows the completed-games count only: `14–11`.
- **Duration** — first Point → Decided.
- **One stats line** — active kcal + average HR.

**Exits:**

| Exit | Effect |
|---|---|
| **Undo** | After a winning Point — removes it and reopens the Match in the same workout. |
| **Resume** | After an Infinite stop or an End-early Save — reopens the Match in the same workout. |
| **Done** | → **Finished**. Workout saved. |
| *(untouched 10 min)* | **Auto-Finishes.** |

There is **no Discard on the summary**.

### Crash and relaunch

- **Auto-resume**, straight to the live page. No "resume / discard" prompt.
- Implement `WKApplicationDelegate.handleActiveWorkoutRecovery()` via
  `@WKApplicationDelegateAdaptor`. Inside it call `HKHealthStore.recoverActiveWorkoutSession()`,
  then **re-attach the `HKLiveWorkoutDataSource`, the builder and the delegates** — HealthKit
  returns a new session object and restores *only* the workout, never the score.
- **The match state is the app's own responsibility**, which is why it is persisted after every
  Point.
- **Workout lost but match saved** (e.g. a reboot) → resume the match and start a **fresh**
  workout.
- **Last Point more than 6 h old** → auto **End match → Save** (Result Unfinished; discard if the
  log is empty) and show the summary once.
- Page selection is **not** persisted; resume always lands on the live page.

### Persistence — SwiftData

A single `Match` model:

| Field | Notes |
|---|---|
| `rules` | Format (with the Pro set 8–8 decider), Deuce rule, first-serving Team |
| `points` | The Point log — winning Team + timestamp per Point |
| `startDate` | |
| `state` | in progress / Decided / Finished |
| `decidedAt` | |

- **Saved after every Point, Undo, End and Resume.** Cheap, because the log is all there is.
- **The match to resume is the single non-Finished record.**
- **Finished records are kept but never displayed.** The data is there for a future history
  feature — mind schema migrations. The most recent record is also what drives the **Play again**
  row (§5).

*Source: [Match lifecycle and persistence](https://github.com/robmass/punto-de-oro/issues/6) ·
[watchOS platform facts](https://github.com/robmass/punto-de-oro/issues/2)*

---

## 9. Complication

**v1 ships exactly one off-app surface: a launcher complication.**

| | |
|---|---|
| **Job** | Launcher only — carries no data |
| **Families** | `accessoryCircular`, `accessoryCorner` |
| **Configuration** | `StaticConfiguration`, single entry, never reloaded |
| **Tap** | Plain app launch — no deep link |
| **Render** | The court glyph (§10), `currentColor` / `.widgetAccentable` |

- **No timeline anywhere in the app.** The widget carries no data, so there are no
  `WidgetCenter.reloadTimelines` calls and the WidgetKit refresh budget never applies.
- **Tap routing is the app's normal launch behaviour** (§4): an in-progress match lands on the
  live page, otherwise setup opens on the Format screen. A deep link straight to **Play again**
  was rejected — it would start a workout session and a Health write off a single stray tap on
  the watch face, to save one tap.
- `accessoryCorner` uses the same glyph with an **empty text label**.

**What is deliberately absent, and why:**

- **Live Activity** — impossible, not declined. ActivityKit does not exist on watchOS; the watch
  only *mirrors* Live Activities started by a paired iPhone app, and there is no iPhone app.
- **Smart Stack** — out, by not declaring `accessoryRectangular`.
- **A live score off-app** — out. The workout session already pins the app in front and Always On
  keeps it readable with the wrist down, so a score complication would only duplicate the screen
  already being looked at.

*Source: [Glanceable surfaces](https://github.com/robmass/punto-de-oro/issues/9)*

---

## 10. Visual identity

### App icon — a padel court seen from above

**Primary source:** [`prototype/app-icon/index.html`](https://github.com/robmass/punto-de-oro/blob/wayfinder/app-icon/prototype/app-icon/index.html)
(`?variant=B`) · shipping artwork
[`renders/bthin.svg`](https://github.com/robmass/punto-de-oro/blob/wayfinder/app-icon/prototype/app-icon/renders/bthin.svg)

On a 100×100 canvas (percentages of icon width):

| Element | Spec |
|---|---|
| Ground | `#0B2A5C` full bleed — the circular watch mask crops it invisibly |
| Court | `#1F6FEB`, `x=22 y=14 w=56 h=72`, corner radius 3 |
| Glass box | `#EAF2FF` stroke **3**, around the court rect |
| Net | `#EAF2FF` stroke **3.5**, `y=50`, full court width |
| Service lines | `#EAF2FF` stroke **2**, at `y=28` and `y=72` |
| Centre service line | `#EAF2FF` stroke **2**, `x=50`, from `y=28` to `y=72` |
| Ball | `#FFCC00`, `r=7`, centred `(64, 62)` — on the near court, between the net and the service line |
| Asset | One flat 1024×1024 source. Nothing depends on layering or parallax. |

**Ships at these stroke weights, centre service line included.** A thickened redraw was tested
and **rejected**: a 2-unit stroke on a 100-unit canvas at a 44pt icon is ~1.8 *physical* pixels
on a 2× display, not sub-pixel, so it renders cleanly — and dropping the centre line removed the
icon's only vertical structure, leaving a striped ladder rather than a court. A middle weight was
indistinguishable from the original. Verified by rasterising all three at ~48px and ~88px and
inspecting pixel-by-pixel:
[`prototype/app-icon/renders/`](https://github.com/robmass/punto-de-oro/tree/wayfinder/app-icon/prototype/app-icon/renders).

The icon collapses around 28px — but so does every variant equally. That is why the complication
carries a separate drawing, not a scaled icon.

### Complication glyph — a separate drawing

**Not an export of the icon.** Box + net line + ball, monochrome:

- Service lines and the centre line **dropped entirely**.
- Strokes at **~7% of the canvas**.
- The ball sits **well clear of the net line** — otherwise the two merge at ~24pt.
- Drawn in `currentColor` / `.widgetAccentable` so the system paints it: white on monochrome
  faces, the face tint on tinted ones. **Gold is never relied on off-app** — it does not survive
  a tinted face, which is why the ball is a solid mass rather than a colour.

Accepted cost: stripped of colour this is three elements in a small circular slot, and it will
never be as instant as a single dot. It was chosen so the complication and the Home Screen icon
read as the same app rather than two.

### Palette — gold is reserved

| Token | Value | Used for |
|---|---|---|
| **Gold** | `#FFCC00` | **Only two places in the whole app:** the ball in the icon, and the deciding-point strip. |
| Us | `#30D158` | Us team colour (half background `#0F3D1C`) |
| Them | `#FF9F0A` | Them team colour (half background `#4A2E05`) |
| Serve marker | `#D4FF3A` | The ball marker on the serving Team's half |
| Chrome | system white / graphite | Setup selections, Start, undo glyph, End match |
| Destructive red | system | Discard in the End match dialog — **the only red in the app** |

- **The reason gold is reserved is the live screen, not taste.** The deciding point is the one
  moment the app must shout while the wearer is mid-rally and barely looking. A colour that also
  paints Start buttons cannot do that.
- **The court's blue is not an app accent.** Blue lives on the Home Screen only and never appears
  inside the app. The app already spends green, orange and chartreuse; a fourth hue earns nothing
  on screens that are two rows and a button.
- **`CHANGE ENDS` is white, not gold** — the `.directionUp` haptic carries its urgency.

### Name

**`Punto de Oro`, in full, allowed to truncate.** On smaller watches the grid label clips to
`Punto de O…`, which costs nothing — the icon identifies the app and the label only confirms it.
Shortening to `Punto` or `PdO` would strip the app's one statement of what it is from the device,
to fix a cosmetic clip.

### Asset production

Producing the 1024pt source, the complication symbol and the Xcode asset catalogue is **build
work**, carried by this hand-off. The one constraint that travels with it: **the complication
glyph is a separate drawing from the icon, not an export of it.**

*Source: [App icon and visual identity](https://github.com/robmass/punto-de-oro/issues/11)*

---

## 11. Accessibility

**Supported, labelled and navigable — not optimised for mid-rally use**, and the spec says so
plainly. With VoiceOver on, watchOS makes scoring a two-gesture action (tap to speak, double-tap
to activate), which the "fewest taps" requirement cannot override.

| Element | Reads as |
|---|---|
| Top bar ↶ | "Undo last point, button" |
| Top half | "Them, 30. Double-tap to score a point for Them." |
| Middle strip | "Games 4-3. Sets, Us 6-4. Golden point." — one element, the whole state |
| Bottom half | "Us, 40. Double-tap to score a point for Us." |
| End match button | "End match, button" |

- **Each half is a single accessibility element** (label + value), not a container of labels.
- **No custom rotor actions**, and **no automatic announcement** on each point, game or set — what
  is worth speaking across a ninety-minute match is a design problem of its own, and is out of
  scope.
- The End match `confirmationDialog` is system-provided and labelled by default.

**Dynamic Type:**

| Screen | Element | Behaviour |
|---|---|---|
| Setup wizard | everything | Honours Dynamic Type in full, including accessibility sizes. |
| End match dialog | everything | Honours Dynamic Type in full. |
| Live | score, games, sets, tie-break score | **Pinned** to §6 geometry. Already maximal — Large Text could only clip them or resize the halves mid-match, and the halves must not move under a blind tap. |
| Live | US / THEM labels, strip chips (`TIE-BREAK`, `GOLDEN POINT`) | Scale with Dynamic Type, capped so they cannot push into the score or truncate the chip. |

**Bold Text** is honoured everywhere. It changes weight only and never reflows.

*Source: [Sizing and accessibility](https://github.com/robmass/punto-de-oro/issues/10)*

---

## 12. Out of scope

Ruled out of this effort deliberately. Each would be a fresh effort, not a resumption.

| Out | Why |
|---|---|
| **iPhone companion app (React Native)** | The destination is watch-only. watchOS UI cannot be React Native. Possibly a later effort. |
| **App Store distribution** — privacy manifest, screenshots, localisation, first-run hints | Personal use first. The controls-page swipe has no permanent affordance, which is fine for a sideload and would need a first-run hint only if the app ever ships. |
| **Match history and stats** | Summary screen only. Finished records are stored but never displayed; history belongs with a future phone companion. |
| **Scoring a match you are not playing in** | Labels are fixed **Us / Them** — the wearer's team. |
| **Individual-player serve tracking** | Team-level only, to keep setup simple. |
| **On-court validation** | See §13 — it cannot run before a build exists, so it sits past this spec. |

---

## 13. To verify on court (post-build)

None of these can be settled before a build exists, so none of them gate this spec. Each is a
decision above that is *assumed* rather than proven, with what to do if it fails.

| Check | If it fails |
|---|---|
| Touch reliability with sweaty fingers | The whole input model rests on screen taps; there is no fallback. |
| **1 click (Us) vs 2 clicks (Them)** distinguishable mid-rally | The point haptics need a different vocabulary — this is the least proven decision in §6. |
| Change-of-ends `.directionUp` distinguishable from the game `.success` | Re-pick the cue haptic, or space the two further apart. |
| Mis-taps near the middle strip | The 34pt dead zone reduces boundary mis-taps but does not prove they are gone. Widen or narrow the band. |
| A vigorous rally producing enough horizontal travel to page accidentally to the controls page | Raise the paging threshold, or gate paging on a raised wrist. |
| The dim-triggered auto-return firing while the player is mid-decision with the wrist angled down | Add a short grace period before the snap-back. |
| Digital Crown rotation with the wrist down in Always On | Nothing is bound to the Crown, so this only matters if input is ever revisited. |
| Battery drain over a 90-minute match | Reduce the Always On update rate, or the persistence frequency. |
| Action Button behaviour with Water Lock on (Ultra) | Nothing is bound to it; Water Lock is already excluded. |

---

## 14. Decision provenance

Every section traces to a closed ticket on the
[Wayfinder map](https://github.com/robmass/punto-de-oro/issues/1).

| Ticket | Covers |
|---|---|
| [#2 watchOS platform facts](https://github.com/robmass/punto-de-oro/issues/2) | §2, §8 — foreground behaviour, inputs, HealthKit, target OS |
| [#3 Scoring rules and domain language](https://github.com/robmass/punto-de-oro/issues/3) | §3 — the whole domain model |
| [#4 Setup flow design](https://github.com/robmass/punto-de-oro/issues/4) | §5 |
| [#5 Live scoring screen and point input](https://github.com/robmass/punto-de-oro/issues/5) | §6 — layout, input, haptics, Always On |
| [#6 Match lifecycle and persistence](https://github.com/robmass/punto-de-oro/issues/6) | §8 |
| [#8 Changing ends](https://github.com/robmass/punto-de-oro/issues/8) | §3, §6 |
| [#9 Glanceable surfaces](https://github.com/robmass/punto-de-oro/issues/9) | §9 |
| [#10 Sizing and accessibility](https://github.com/robmass/punto-de-oro/issues/10) | §6 geometry, §11 |
| [#11 App icon and visual identity](https://github.com/robmass/punto-de-oro/issues/11) | §10 |
| [#12 End match control placement](https://github.com/robmass/punto-de-oro/issues/12) | §7 |
| [#7 Assemble the build-ready spec](https://github.com/robmass/punto-de-oro/issues/7) | This document |

**Prototypes and research** (throwaway branches, kept as primary sources):

- [`prototype/setup-flow`](https://github.com/robmass/punto-de-oro/tree/prototype/setup-flow/Prototypes/SetupFlowPrototype) — the setup wizard, on-watch
- [`wayfinder/live-scoring`](https://github.com/robmass/punto-de-oro/blob/wayfinder/live-scoring/prototype/live-scoring/index.html) — the Halves layout
- [`wayfinder/app-icon`](https://github.com/robmass/punto-de-oro/blob/wayfinder/app-icon/prototype/app-icon/index.html) — the icon, plus the stroke-weight renders
- [`research/watchos-platform-facts`](https://github.com/robmass/punto-de-oro/blob/research/watchos-platform-facts/research/watchos-platform-facts.md) — the platform findings
