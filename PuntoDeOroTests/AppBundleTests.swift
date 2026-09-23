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
}
