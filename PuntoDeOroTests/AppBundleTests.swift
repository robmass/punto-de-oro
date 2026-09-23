import Foundation
import Testing
@testable import PuntoDeOro

struct AppBundleTests {
    /// Tests are hosted in the app, so `Bundle.main` is the installed app bundle.
    @Test func displayNameIsPuntoDeOroInFull() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Punto de Oro")
    }

    /// A Match runs as a workout, and nothing else runs in the background: no audio mode.
    @Test func theOnlyBackgroundModeIsWorkoutProcessing() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "WKBackgroundModes") as? [String] == ["workout-processing"])
    }

    /// The watch shows the Health prompt itself, so its reasons belong in the watch app.
    @Test(arguments: ["NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"])
    func healthUsageIsExplained(key: String) {
        let reason = Bundle.main.object(forInfoDictionaryKey: key) as? String
        #expect(reason?.isEmpty == false)
    }

    /// The asset catalogue's icon is the one the Home Screen shows (spec §10).
    @Test func theHomeScreenIconIsTheAppIcon() {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        #expect(primary?["CFBundleIconName"] as? String == "AppIcon")
    }

    /// The launcher complication ships as a WidgetKit extension inside the app (spec §9).
    @Test func theLauncherComplicationShipsInsideTheApp() throws {
        let plugIns = try #require(Bundle.main.builtInPlugInsURL)
        let extensions = try FileManager.default.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil)
            .compactMap(Bundle.init(url:))
        let points = extensions.compactMap {
            ($0.object(forInfoDictionaryKey: "NSExtension") as? [String: Any])?["NSExtensionPointIdentifier"] as? String
        }
        #expect(points == ["com.apple.widgetkit-extension"])
    }
}
