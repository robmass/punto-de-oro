import SwiftUI
import WidgetKit

/// The launcher complication (spec §9): the court glyph and nothing else. It carries no data, so it
/// has one entry that never reloads, and no `WidgetCenter.reloadTimelines` call exists anywhere.
///
/// Tapping it is a plain app launch, with no `widgetURL`: the app's normal launch routing lands an
/// in-progress Match on the live page, and otherwise opens setup on Format.
struct Launcher: Widget {
    /// No `accessoryRectangular`: declaring it would put the app in the Smart Stack.
    nonisolated static let families: [WidgetFamily] = [.accessoryCircular, .accessoryCorner]

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Launcher", provider: LauncherProvider()) { _ in
            // The corner slot shows the same glyph with an empty text label: no `widgetLabel`.
            CourtGlyph()
                .containerBackground(for: .widget) {}
        }
        .configurationDisplayName("Punto de Oro")
        .description("Opens Punto de Oro.")
        .supportedFamilies(Self.families)
    }
}

struct LauncherEntry: TimelineEntry {
    let date: Date
}

struct LauncherProvider: TimelineProvider {
    static var timeline: Timeline<LauncherEntry> {
        Timeline(entries: [LauncherEntry(date: .distantPast)], policy: .never)
    }

    func placeholder(in context: Context) -> LauncherEntry {
        LauncherEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (LauncherEntry) -> Void) {
        completion(LauncherEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LauncherEntry>) -> Void) {
        completion(Self.timeline)
    }
}
