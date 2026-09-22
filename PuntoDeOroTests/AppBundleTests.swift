import Foundation
import Testing
@testable import PuntoDeOro

struct AppBundleTests {
    /// Tests are hosted in the app, so `Bundle.main` is the installed app bundle.
    @Test func displayNameIsPuntoDeOroInFull() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Punto de Oro")
    }
}
