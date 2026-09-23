import HealthKit
import Testing
@testable import PuntoDeOro

struct HealthAccessTests {
    /// Only a refusal is worth a line on Ready. Left unanswered, the sheet asks again the next time
    /// setup appears, so nothing is said yet.
    @Test func deniedSharingIsTheOnlyAccessTheReadyScreenMentions() {
        #expect(HealthAccess(.sharingDenied).readyNotice == "Health off · no workout. The app may return to the clock.")
        #expect(HealthAccess(.sharingAuthorized).readyNotice == nil)
        #expect(HealthAccess(.notDetermined).readyNotice == nil)
    }
}
