# watchOS platform facts: workout foreground, input affordances, HealthKit, target OS

Research for [issue #2](https://github.com/robmass/punto-de-oro/issues/2). Researched 2026-09-22. The current release is **watchOS 27**, and Apple Developer documentation reflects the watchOS 26/27 SDKs. Each fact gives the watchOS version it applies to. **UNCERTAIN** marks anything not confirmed by a primary source.

---

## Short answers

1. **Foreground behaviour.** Yes. While an `HKWorkoutSession` is active, the app keeps running for the whole session and **reappears when the wrist is raised**. Apple documents no time limit, and the frontmost-app timeout (Return to Clock, normally 2 min, 1 h max) does not apply. On Always On hardware the app stays visible and dimmed with the wrist down, at a reduced update rate. Its **controls stay tappable in Always On**, and a tap both runs the action and wakes the app. The only documented limit is CPU: heavy background CPU use can get the app suspended. (watchOS 8+ for Always On apps; the workout background behaviour has existed since watchOS 3/5.) This **confirms** the map's standing decision.
2. **Input affordances.**
   - **Screen taps** always work during a workout, including on the dimmed Always On screen.
   - **Double Tap** works through `handGestureShortcut(.primaryAction)`:
     - It needs watchOS 11+ and Series 9+, Ultra 2+ or SE 3.
     - The API gives **exactly one** action per screen.
     - It does **not** work with the wrist down or the display inactive, or with Water Lock or Low Power Mode on.
   - **Digital Crown rotation** is available (`digitalCrownRotation`, watchOS 6+). Pressing the Crown is reserved by the system.
   - **Action Button** is Ultra only and needs watchOS 9+ APIs:
     - The first press can start the workout through `StartWorkoutIntent`.
     - Later presses during the session run one "next action" `AppIntent`, which the app can re-donate at any time.
     - Pressing Action and Side together can pause or resume the workout.
     - The user must set Settings > Action Button > Workout > this app.
   - **Water Lock** disables the touch screen. It can only be enabled by the app during a foreground workout, and only the user can unlock it (hold the Crown). It also disables Double Tap.
   - The new watchOS 27 **single tap** gesture has **no third-party API** (only `.primaryAction` exists).
3. **HealthKit.**
   - **No padel activity type exists** in `HKWorkoutActivityType` as of the current SDK. Closest are `.tennis` (watchOS 2+) and `.pickleball` (watchOS 7+). `.paddleSports` means canoe/kayak/SUP and is **not** padel.
   - Setup needs:
     - the HealthKit capability (entitlement)
     - `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`
     - Background Modes → `WKBackgroundModes: workout-processing`
     - authorization to share `HKWorkoutType`
   - **Crash recovery:** on relaunch the system calls `WKApplicationDelegate.handleActiveWorkoutRecovery()` (watchOS 7+). Inside it, call `HKHealthStore.recoverActiveWorkoutSession()` (watchOS 5+; there is an async variant). You then get a new session object and must re-attach the builder's data source and delegates. **HealthKit restores only the workout, not the match score.** The app must persist its own match state.
4. **Target OS and account.**
   - Recommended minimum: **watchOS 26**. This is explained in the recommendations below.
   - **A paid developer account is NOT required to sideload.** A free "Apple Developer" account (Xcode Personal Team) has the HealthKit and Background Modes capabilities. The cost is that apps, devices and profiles **expire every 7 days**, so the app must be rebuilt and reinstalled weekly. There are also limits of 3 devices, 3 apps per device and 10 App IDs. The paid Apple Developer Program is only needed for 1-year profiles, TestFlight and the App Store.

---

## 1. Foreground behaviour with an active workout session

**Workout session = background execution + returns on wrist raise.** Apple's *Running workout sessions* article says:

> "Your app continues to run throughout the entire workout session, even when the user lowers their wrist or interacts with a different app. When the user raises their wrist, your app reappears …"
> "If the user navigates back to the watch face, Apple Watch displays a small icon at the top of the screen, indicating that a workout session is running. Users can tap the icon to navigate back to your app."
> "Your app can alert the user using audio or haptic feedback while running in the background."
> "If your app uses an excessive amount of CPU while in the background, watchOS may suspend it."

Source: <https://developer.apple.com/documentation/healthkit/running-workout-sessions> (section "Run in the background").

**Always On.** From *Designing your app for the Always On state* (watchOS 8+):

- "Apps running a background session, such as a workout session … remain onscreen as long as the session is active." The UI keeps updating at reduced frequency. `TimelineView` cadence drops from `.live` to `.seconds` or `.minutes`, so the app should drop sub-second updates and animation when `scenePhase != .active` or `isLuminanceReduced`.
- "Any controls in the user interface remain interactive … When the user interacts with a control, the system runs the associated action and transitions your app back to the active state." A tap on the dimmed screen therefore scores a point directly, with no wake tap needed first.
- **Frontmost-app timeout (applies to non-workout apps only):** an app without a session stays frontmost "usually two minutes" before it is suspended. The user sets this in Settings > General > Wake Screen > Return to Clock, per app, up to **1 hour max** (watchOS 8+). A workout session makes this irrelevant, but the setup and summary screens *before and after* the session are subject to it.
- Always On hardware: the article says it isn't available on original SE or Series 4 and earlier. **SE 3 does have Always On** ([Apple Newsroom, Sept 2025](https://www.apple.com/newsroom/2025/09/apple-introduces-apple-watch-se-3/)). Every watch that runs watchOS 26 or 27 has Always On **except SE (2nd gen)**, which runs 26 but not 27. On SE 2 the screen turns off with the wrist down, but the session keeps running and the app returns on raise.

Source: <https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state>

**Time limits.** Apple documents no maximum duration for a workout session. The documented constraint is background CPU usage. **UNCERTAIN:** real-world battery cost of a 90-minute match with heart-rate sampling. Workout sessions always sample heart rate at high frequency, which is normal for workout apps but should be measured.

**Starting a session from the Action Button.** If `perform()` does not start a session within 30 s, the system shows an error. "Without a session, the app goes to the background the next time they drop their wrist." ([Action button article](https://developer.apple.com/documentation/appintents/actionbuttonarticle)). This confirms that the session is what keeps the app foregrounded.

## 2. Input affordances

### Screen taps

These always work while the display is on or in Always On, as described in §1. They do not work in Water Lock. **UNCERTAIN:** reliability with sweat or wet fingers. Apple's only statement is that Water Lock exists "to avoid unintended taps on the display when you wear your Apple Watch in water" ([Water Lock support article](https://support.apple.com/en-us/108352)). No Apple doc quantifies touch behaviour when sweaty, so this needs an on-court test.

### Double Tap (`handGestureShortcut`)

- API: `View.handGestureShortcut(_:isEnabled:)` with `HandGestureShortcut.primaryAction`. It is available on **watchOS 11.0+** ([doc](https://developer.apple.com/documentation/swiftui/view/handgestureshortcut(_:isenabled:))). "Performing the control's shortcut while the control is anywhere in the frontmost scene is equivalent to direct interaction with the control." The target is resolved leading-to-trailing in the active scene. It works on any buttonlike control (Button, Toggle) ([watchOS updates, June 2024](https://developer.apple.com/documentation/updates/watchos)).
- **Only one shortcut exists:** `HandGestureShortcut` has only `.primaryAction` in the current SDK ([doc](https://developer.apple.com/documentation/swiftui/handgestureshortcut)). So Double Tap can drive **one** action per screen, for example "point to Us" or "undo", not both.
- **Hardware:** Series 9 or later, Ultra 2 or later, SE 3 ([Apple Support 108413](https://support.apple.com/en-us/108413); [SE 3 newsroom](https://www.apple.com/newsroom/2025/09/apple-introduces-apple-watch-se-3/)).
- **When it does NOT work** (Apple Support [108413](https://support.apple.com/en-us/108413) and [watch user guide, watchOS 27](https://support.apple.com/guide/watch/use-double-tap-for-common-actions-apdabb7b275c/watchos)):
  - "the display is inactive because your wrist is down". **The player must raise the wrist first**, so Always On does not count as awake here.
  - Low Power Mode, Sleep Focus, Theater Mode or **Water Lock** is on
  - the watch is locked or wrist detection is off
  - some accessibility hand-gesture features are on
  - Apple also lists a wrist tattoo as a possible cause of failure
- **watchOS 27 single tap:** a new system gesture (tap once) for selecting Smart Stack widgets ([apple.com/os/watchos](https://www.apple.com/os/watchos/)). **No third-party API was found.** The only `HandGestureShortcut` member is still `.primaryAction`. **Wrist flick** (watchOS 26, same hardware) is also system-only as far as the docs show. **UNCERTAIN:** check the WWDC26 SwiftUI "What's new" notes if these matter.

### Digital Crown

- `digitalCrownRotation(_:)` and its variants are available on **watchOS 6.0+** ([doc](https://developer.apple.com/documentation/swiftui/view/digitalcrownrotation(_:))). Rotation feeds a binding, so it could step a value or drive an undo scrub.
- **Pressing** the Crown is a system action: it goes to the watch face or app list and cannot be overridden. Pressing and holding it exits Water Lock.
- **UNCERTAIN:** whether a rotation made with the wrist down or in Always On reaches the app, or only wakes the screen. This needs a device test.

### Action Button (Apple Watch Ultra only)

From [Responding to the Action button on Apple Watch Ultra](https://developer.apple.com/documentation/appintents/actionbuttonarticle). The APIs are `StartWorkoutIntent`, `PauseWorkoutIntent` and `ResumeWorkoutIntent`, plus `IntentResult.result(actionButtonIntent:)`, all **watchOS 9.0+**:

- **First press:** runs the app's `StartWorkoutIntent`. The user must choose Settings > Action Button > Action: Workout > App: *this app*. The app then appears there with its `suggestedWorkouts`. If the app has never requested HealthKit authorization, the press just launches the app.
- **Subsequent presses during a session:** "Apple Watch Ultra runs the next action when someone presses the Action button while a workout … session is already running." The next action is whatever `AppIntent` was **most recently donated**, and donating a new one replaces it. This allows one scoring action, such as "point to Us", or an undo.
- **Action + Side button together:** pauses or resumes the workout if the app implements `PauseWorkoutIntent` and `ResumeWorkoutIntent`. Otherwise the press is ignored.
- Intents must live in the watch app, **not** an App Intents extension.
- The dive section notes that "while in the water they can't use the touch screen, but the Action button and Digital Crown function normally". That statement is about submersion. **UNCERTAIN** whether the Action Button's next action fires while Water Lock is on during a normal workout. It is plausible but untested.
- Ultra models on watchOS 27: Ultra 2, 3 and 4. The original Ultra stops at watchOS 26.

### Water Lock

- `WKInterfaceDevice.enableWaterLock()` is available on **watchOS 6.1+**. Rules from the [doc](https://developer.apple.com/documentation/watchkit/wkinterfacedevice/enablewaterlock()):
  - it must be called on the main thread
  - it works "only … when the app is running in the foreground during an active workout or location session"
  - it needs a supported device
  - "Water Lock remains active until the user unlocks it. You can't programmatically unlock the watch."
- While it is on, "your Apple Watch doesn't respond to touch on its display". The user unlocks by pressing and holding the Crown ([support 108352](https://support.apple.com/en-us/108352)). It also disables Double Tap.
- Verdict: it is not useful for padel scoring. It only makes sense as a "pocket-proof" mode where scoring runs through the Action Button alone, and that is Ultra only and **UNCERTAIN**.

### Summary table: viable mid-rally?

| Affordance | Min OS | Hardware | Wrist down / Always On | Mid-rally verdict |
|---|---|---|---|---|
| Screen tap (large regions) | any | all | **Works** (tap on dimmed screen runs the action) | **Primary input** |
| Double Tap `.primaryAction` | watchOS 11 | S9+, Ultra 2+, SE 3 | **No**, wrist must be raised | Good secondary input for **one** action (hands-free with a racket in the other hand) |
| Crown rotation | watchOS 6 | all | Unverified | Weak mid-rally (imprecise); fine for undo or adjust between points |
| Action Button next action | watchOS 9 | Ultra only | Physical button; probably works (unverified) | Good for **one** action on Ultra; needs user setup |
| Water Lock | watchOS 6.1 | all (supported) | n/a | Not viable (kills touch and Double Tap) |
| Single tap / wrist flick | watchOS 27 / 26 | S9+ etc. | n/a | **No third-party API** |

## 3. HealthKit

### Activity type

The full `HKWorkoutActivityType` enumeration ([doc](https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype)) contains **no padel case** as of the current SDK, checked 2026-09-22. The racket-sport cases are:

| Case | Since | Apple description |
|---|---|---|
| `.tennis` | watchOS 2 | "playing tennis" |
| `.pickleball` | watchOS 7 | "playing pickleball" |
| `.squash`, `.racquetball`, `.badminton`, `.tableTennis` | watchOS 2 | the respective sports |
| `.paddleSports` | watchOS 2 | "canoeing, kayaking, paddling an outrigger, paddling a stand-up paddle board" (**not padel**) |
| `.other` | watchOS 2 | "a workout that does not match any of the other workout activity types" (Apple's doc adds that apps using it "must explain how your app calculates workout data when sensor information is not available", which is an App Review point) |

For activities without specialised calorimetry, which covers all racket sports, "the system estimates calories based on the data from Apple Watch's sensors" ([Running workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions)). The choice between them therefore mostly affects the **label and icon** in Fitness and Health, not accuracy. **UNCERTAIN:** whether calorimetry differs between `.tennis` and `.pickleball`. Apple does not document per-type formulas.

`HKWorkoutConfiguration.locationType` should be `.indoor` or `.outdoor` according to the court. Padel is often played indoors.

### Permissions, capabilities and Info.plist

- **HealthKit capability** in Signing & Capabilities adds the `com.apple.developer.healthkit` entitlement.
- **`NSHealthShareUsageDescription`** (read) and **`NSHealthUpdateUsageDescription`** (write). Since watchOS 6, authorization happens on the watch itself, so these keys go on the watch app target ([Running workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions), "Set up the app").
- **Background Modes → Workout processing**, which is `WKBackgroundModes` = `workout-processing` ([doc](https://developer.apple.com/documentation/bundleresources/information-property-list/wkbackgroundmodes)). Add **Audio** only if the app plays audio. Haptics during a workout are covered by the workout session itself, per the "Run in the background" list.
- **Types:** share `HKObjectType.workoutType()`. Read is optional. For example, `heartRate` and `activeEnergyBurned` are needed to show live stats. The summary spec only needs duration, so reading can be minimal or skipped.
- With the Action Button, the app must request authorization inside `StartWorkoutIntent.perform()` through a `Task`. The start intent is not called at all if the app has never requested authorization.

### Crash recovery

- If the app crashes during an active session, the system relaunches it and calls **`WKApplicationDelegate.handleActiveWorkoutRecovery()`** (watchOS 7.0+, [doc](https://developer.apple.com/documentation/watchkit/wkapplicationdelegate/handleactiveworkoutrecovery())). In a SwiftUI app, hook it up with `@WKApplicationDelegateAdaptor`.
- In that method, call **`HKHealthStore.recoverActiveWorkoutSession()`** (watchOS 5.0+, with a completion-handler and an `async throws -> HKWorkoutSession?` form; [doc](https://developer.apple.com/documentation/healthkit/hkhealthstore/recoveractiveworkoutsession(completion:))). "HealthKit then attempts to restore the previous workout session, returning either a new session object or an error." "As soon as you receive the session object, you must access its builder and set up your data source and delegates again."
- **This restores the HealthKit session only.** Nothing in the docs says app state such as the match score survives. The app must write match state to disk on every point, for example as a small Codable file in the app container, and reload it at launch. It should rebind that state to the recovered session. **UNCERTAIN:** whether builder metadata added before the crash comes back with the recovered builder. Don't rely on it.
- The docs cover recovery only for **crashes during an active session**. If the user force-quits or the watch reboots, recovery isn't documented, and app-owned persisted state is the only safety net (**UNCERTAIN** for those cases).

## 4. Target OS and developer account

### OS/hardware landscape (Sept 2026)

| watchOS | Released | Hardware |
|---|---|---|
| 27 (current) | Sept 2026 | SE 3, Series 9, 10, 11, 12, Ultra 2, 3, 4 ([apple.com/os/watchos](https://www.apple.com/os/watchos/)) |
| 26 | Sept 2025 | adds Series 6, 7, 8, SE (2nd gen), Ultra (1st gen) ([Apple Newsroom, June 2025](https://www.apple.com/newsroom/2025/06/watchos-26-delivers-more-personalized-ways-to-stay-active-and-connected/)) |
| 11 | Sept 2024 | same hardware floor as 26 (Series 6+, SE 2, Ultra). First version with `handGestureShortcut` |

Every watch that can run watchOS 27 has both Double Tap and Always On. The oldest APIs this app needs are `handGestureShortcut` (watchOS 11) and Always On app behaviour (watchOS 8). The others are older: workout recovery (7), `StartWorkoutIntent` and next action (9), and `.pickleball` (7).

### Sideloading and the developer account

From [Compare memberships](https://developer.apple.com/support/compare-memberships/) and [Supported capabilities (watchOS)](https://developer.apple.com/help/account/reference/supported-capabilities-watchos):

- A free "Apple Developer" account (Personal Team in Xcode) *can* install and test apps on a personal device.
- The capability table has checkmarks for **HealthKit** and **Background modes** in the free "Apple Developer" column. For comparison, HealthKit Estimate Recalibration and Siri do not. App Intents such as the Action Button intents do not need a capability. Note from the same page: "For the watchOS app target, the capabilities available are app groups and background modes, and don't depend on your program membership."
- Personal Team limits:
  - provisioning profiles expire **7 days** after issuance, and the app must be rebuilt and reinstalled
  - up to 3 devices and 10 App IDs, which also expire after 7 days
  - up to 3 apps per device
- The paid Apple Developer Program (annual fee) gives 1-year profiles, TestFlight and App Store distribution. It is needed only for the later App Store path, or to avoid the weekly re-install.
- **UNCERTAIN:** what happens to an installed app when the 7-day profile expires mid-match. The expected behaviour is that the app won't launch after expiry, so re-deploy before match day. Deploying to a watchOS 27 device also requires the matching Xcode (Xcode 27 SDK).

---

## Recommendations for the spec

1. **Minimum watchOS: 26.0.** It covers the same hardware as watchOS 11 (Series 6+, SE 2, Ultra 1) and every API listed above, and gives the current SwiftUI and design language. Choose **watchOS 27** instead only if Rob's own watch is Series 9+, Ultra 2+ or SE 3 and he doesn't care about older watches. That choice guarantees Double Tap and Always On on every supported device but excludes Series 6–8, SE 2 and Ultra 1. *Needs a decision: which watch does Rob wear?*
2. **Viable mid-rally inputs:**
   - **Primary: large screen tap regions**, two halves or two big buttons for "point to team A/B". These are the only input that works on every model, including with the wrist down on the dimmed Always On screen.
   - **Secondary: Double Tap on one action.** Bind `.handGestureShortcut(.primaryAction)` to a single control. The most useful candidate is probably "point to Us" (hands-free while holding the racket). The other candidate is "undo". The binding choice belongs in the interaction/prototype ticket. It needs a raised wrist and Series 9+, Ultra 2+ or SE 3. Degrade gracefully elsewhere: the modifier simply has no effect.
   - **Optional (Ultra only): Action Button.** A `StartWorkoutIntent` starts a match. Donate one next-action intent that mirrors the Double Tap action. Implement Pause/Resume intents so the Action + Side press pauses the match timer.
   - **Crown:** not for scoring. It could serve as a between-points undo or adjust control.
   - **Don't use Water Lock.**
   - Plan an on-court test for sweat/wet touch reliability and Crown behaviour in Always On.
3. **HealthKit activity type: `.tennis`**, with `locationType` set from a setup choice or defaulting to `.indoor`. Rationale:
   - There is no padel type.
   - Tennis is the closest court racket sport and gives a sensible label and icon in Fitness.
   - It avoids the extra App Review explanation required for `.other`.
   - `.paddleSports` is wrong (it means water paddling).

   `.pickleball` is an acceptable alternative if the "paddle" association is preferred. Re-check `HKWorkoutActivityType` each WWDC in case Apple adds padel.
4. **Workout recovery approach:**
   - (a) Persist the full match state (config, score, serve, deuce state, start time) to a local file **after every scoring event**.
   - (b) Implement `handleActiveWorkoutRecovery()` through `@WKApplicationDelegateAdaptor`. Inside it, call `recoverActiveWorkoutSession()`, re-attach the `HKLiveWorkoutDataSource` and delegates, and reload the persisted match into the live-scoring screen.
   - (c) If there is persisted in-progress state but no recoverable session (force-quit, reboot or recovery error), resume the match from disk and start a new workout session. Alternatively, offer "resume / discard". That choice belongs to the lifecycle ticket.
   - (d) Clear persisted state only after `finishWorkout` succeeds and the summary is shown.
5. **Distribution:** a free Personal Team is enough for personal sideloading with HealthKit and workout background mode, at the cost of reinstalling every 7 days. Buy the Developer Program only if the weekly reinstall becomes annoying or when moving toward the App Store.

## Newly surfaced questions (possible tickets)

- **Which Apple Watch does Rob wear?** This settles the watchOS 26 vs 27 choice and whether Double Tap and the Action Button are available to him.
- **What does Double Tap bind to** (point to Us, point to Them, or undo), and does the Action Button mirror it or do something else? This belongs to the on-wrist interaction or prototype ticket.
- **Pause semantics:** should pausing the workout (Action + Side on Ultra, or an on-screen control) pause the match clock, and is pause needed at all?
- **Crash vs force-quit resume flow:** automatically resume the match, or prompt "resume / discard"? Lifecycle ticket.
- **Always On presentation:** what the score screen looks like dimmed (reduced luminance, no animations). This feeds into the screen-flow and accessibility work.
- **On-device test plan:** touch reliability with sweat, Crown rotation in Always On, Action Button with Water Lock, and battery drain over a 90-minute match.
