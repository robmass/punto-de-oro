import Foundation
import Testing
import WidgetKit

/// The launcher complication (spec §9, §10). Its sources are compiled into this target as well as
/// the widget extension, since an extension can't be imported.
struct LauncherTests {
    @Test func offersOnlyTheCircularAndCornerSlots() {
        #expect(Launcher.families == [.accessoryCircular, .accessoryCorner])
    }

    /// Declaring `accessoryRectangular` would put the app in the Smart Stack.
    @Test func staysOutOfTheSmartStack() {
        #expect(!Launcher.families.contains(.accessoryRectangular))
    }

    /// The glyph carries no data, so one entry lasts forever and WidgetKit never asks again.
    @Test func theTimelineIsOneEntryNeverReloaded() {
        let timeline = LauncherProvider.timeline
        #expect(timeline.entries.count == 1)
        #expect(timeline.policy == .never)
    }
}
