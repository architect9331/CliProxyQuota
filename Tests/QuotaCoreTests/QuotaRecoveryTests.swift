import XCTest
@testable import QuotaCore

final class QuotaRecoveryTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_900_000_000)
    func quota(_ id: String, five: Double, weekly: Double, fiveReset: TimeInterval?, weekReset: TimeInterval?, disabled: Bool = false) -> AccountQuota {
        AccountQuota(account: Account(id: id, authIndex: id, provider: "claude", name: id, email: id, disabled: disabled), windows: [
            QuotaWindow(id: "5h", label: "5-hour", remaining: five, resetsAt: fiveReset.map { now.addingTimeInterval($0) }),
            QuotaWindow(id: "w", label: "Weekly", remaining: weekly, resetsAt: weekReset.map { now.addingTimeInterval($0) })])
    }
    func testWeeklyBlockStillUsesEarlierFiveHourReset() {
        let q = quota("a", five: 100, weekly: 0, fiveReset: 3600, weekReset: 7200)
        XCTAssertEqual(QuotaRecovery.nextReset(in: [q]), now.addingTimeInterval(3600))
    }
    func testBothEmptyUseEarlierOfBothResets() {
        let a = quota("a", five: 0, weekly: 0, fiveReset: 3600, weekReset: 7200)
        let b = quota("b", five: 0, weekly: 0, fiveReset: 7200, weekReset: 3600)
        XCTAssertEqual(QuotaRecovery.nextReset(in: [a]), now.addingTimeInterval(3600))
        XCTAssertEqual(QuotaRecovery.nextReset(in: [b]), now.addingTimeInterval(3600))
    }
    func testEarliestResetAcrossSelectedAccountsWins() {
        let a = quota("a", five: 0, weekly: 0, fiveReset: 3600, weekReset: 21600)
        let b = quota("b", five: 0, weekly: 50, fiveReset: 7200, weekReset: 36000)
        XCTAssertEqual(QuotaRecovery.nextReset(in: [a,b]), now.addingTimeInterval(3600))
    }
    func testRemainingPercentagesDoNotChangeResetSelection() {
        let a = quota("a", five: 8, weekly: 8, fiveReset: 3600, weekReset: 7200)
        XCTAssertEqual(QuotaRecovery.nextReset(in: [a]), now.addingTimeInterval(3600))
        let b = quota("b", five: 8, weekly: 20, fiveReset: 3600, weekReset: 7200)
        XCTAssertEqual(QuotaRecovery.nextReset(in: [b]), now.addingTimeInterval(3600))
    }
    func testMissingResetUsesKnownWindowAndFullWindowsStillCount() {
        XCTAssertEqual(QuotaRecovery.nextReset(in: [quota("a", five: 0, weekly: 0, fiveReset: 3600, weekReset: nil)]), now.addingTimeInterval(3600))
        XCTAssertEqual(QuotaRecovery.nextReset(in: [quota("a", five: 100, weekly: 100, fiveReset: 3600, weekReset: 7200)]), now.addingTimeInterval(3600))
        XCTAssertEqual(QuotaRecovery.nextReset(in: [quota("a", five: 100, weekly: 59, fiveReset: nil, weekReset: 7200)]), now.addingTimeInterval(7200))
        XCTAssertNil(QuotaRecovery.nextReset(in: [quota("a", five: 100, weekly: 59, fiveReset: nil, weekReset: nil)]))
    }
    func testReviewAndMonthlyWindowsDoNotAffectCountdown() {
        var q = quota("a", five: 100, weekly: 59, fiveReset: 3600, weekReset: 7200)
        q.windows += [
            QuotaWindow(id: "review", label: "Code review · Weekly", remaining: 0, resetsAt: now.addingTimeInterval(30)),
            QuotaWindow(id: "monthly", label: "Monthly", remaining: 0, resetsAt: now.addingTimeInterval(60))]
        XCTAssertEqual(QuotaRecovery.nextReset(in: [q]), now.addingTimeInterval(3600))
    }
    func testWeeklyResetWinsWhenItIsSooner() {
        let q = quota("a", five: 100, weekly: 59, fiveReset: 7200, weekReset: 3600)
        XCTAssertEqual(QuotaRecovery.nextReset(in: [q]), now.addingTimeInterval(3600))
    }
    func testDisabledAndFailedAccountsAreIgnored() {
        var failed = quota("a", five: 0, weekly: 80, fiveReset: 60, weekReset: 7200)
        failed.issue = "Unavailable"
        let disabled = quota("b", five: 0, weekly: 80, fiveReset: 30, weekReset: 7200, disabled: true)
        let valid = quota("c", five: 0, weekly: 80, fiveReset: 3600, weekReset: 7200)
        XCTAssertEqual(QuotaRecovery.nextReset(in: [failed,disabled,valid]), now.addingTimeInterval(3600))
    }
    func testReadoutRecoveryIndependentOfVisibleCriticalWindow() {
        let value = MenuBarReadout(id: "a", title: "a", detail: "a", fiveHour: 10, weekly: 30, nextReset: now.addingTimeInterval(8040))
        XCTAssertEqual(value.recoveryText(window: .both, now: now), "↻ 2h 14m")
        XCTAssertEqual(value.recoveryText(window: .weekly, now: now), "↻ 2h 14m")
        XCTAssertEqual(value.recoveryText(window: .fiveHour, now: now.addingTimeInterval(8040)), "↻ due")
        let missing = MenuBarReadout(id: "a", title: "a", detail: "a", fiveHour: 0, weekly: 0)
        XCTAssertEqual(missing.recoveryText(window: .both, now: now), "↻ —")
    }
    func testProviderReadoutUsesSelectedAccountCohort() throws {
        let a = quota("a", five: 100, weekly: 0, fiveReset: 60, weekReset: 7200)
        let source = try XCTUnwrap(MenuBarSource.options(from: [a]).first { $0.isProvider })
        XCTAssertEqual(source.readout(from: [a], stale: false).nextReset, now.addingTimeInterval(60))
        XCTAssertNil(source.readout(from: [a], stale: true).nextReset)
        let other = quota("b", five: 100, weekly: 59, fiveReset: 30, weekReset: 3600)
        let selected = try XCTUnwrap(MenuBarSource.options(from: [a, other]).first { $0.id == "account:a" })
        XCTAssertEqual(selected.readout(from: [a, other], stale: false).nextReset, now.addingTimeInterval(60))
    }
}
