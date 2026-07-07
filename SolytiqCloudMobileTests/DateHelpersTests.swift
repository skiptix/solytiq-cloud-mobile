import Testing
import Foundation
@testable import SolytiqCloudMobile

struct DateHelpersTests {
    @Test func friendlyLabelsToday() {
        let today = SCDate.todayISO()
        #expect(SCDate.friendly(today)?.label == "Today")
        #expect(SCDate.friendly(today)?.overdue == false)
    }

    @Test func friendlyLabelsOverdue() {
        let yesterday = SCDate.iso(SCDate.addDays(-1))
        let result = SCDate.friendly(yesterday)
        #expect(result?.label == "Overdue")
        #expect(result?.overdue == true)
    }

    @Test func friendlyLabelsNil() {
        #expect(SCDate.friendly(nil) == nil)
    }

    @Test func to12hFormatsMorningAndAfternoon() {
        #expect(SCDate.to12h("09:30") == "9:30 AM")
        #expect(SCDate.to12h("14:05") == "2:05 PM")
        #expect(SCDate.to12h("00:00") == "12:00 AM")
    }

    @Test func isoRoundTrips() {
        let date = SCDate.date(fromISO: "2026-07-04")
        #expect(date != nil)
        #expect(SCDate.iso(date!) == "2026-07-04")
    }
}
