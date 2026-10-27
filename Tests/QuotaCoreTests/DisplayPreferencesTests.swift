import XCTest
@testable import QuotaCore

final class DisplayPreferencesTests: XCTestCase {
    private let readout = MenuBarReadout(id: "test", title: "Codex", detail: "Codex · account average", fiveHour: 72, weekly: 84)
    func testSingleWindowDoesNotIncludeSuperscripts() {
        XCTAssertEqual(readout.text(mode: .remaining, window: .fiveHour), "72%")
        XCTAssertEqual(readout.text(mode: .remaining, window: .weekly), "84%")
        XCTAssertEqual(readout.text(mode: .used, window: .fiveHour), "28%")
        XCTAssertEqual(readout.text(mode: .used, window: .weekly), "16%")
    }
    func testBothWindowsUseApprovedCompactLabels() {
        XCTAssertEqual(readout.text(mode: .remaining, window: .both), "⁵ʰ 72% · ʷ 84%")
        XCTAssertEqual(readout.text(mode: .used, window: .both), "⁵ʰ 28% · ʷ 16%")
        XCTAssertEqual(readout.text(mode: .used, window: .both, includeSource: true), "Codex ⁵ʰ 28% · ʷ 16%")
    }
    func testMissingQuotaNeverBecomesOneHundredPercentUsed() {
        let missing = MenuBarReadout(id: "x", title: "x", detail: "x", fiveHour: 0, weekly: nil)
        XCTAssertEqual(missing.text(mode: .used, window: .both), "⁵ʰ 100% · ʷ —")
        XCTAssertEqual(missing.text(mode: .remaining, window: .weekly), "—")
        XCTAssertTrue(missing.tooltip(mode: .used, window: .both).contains("Weekly: unavailable"))
    }
    func testTooltipRetainsMeaningWhenVisibleLabelsAreOmitted() {
        XCTAssertEqual(readout.tooltip(mode: .used, window: .weekly), "Codex · account average · Weekly: 16% used · Next usable reset unavailable")
    }
    func quota(_ id: String, provider: String = "codex", five: Double?, weekly: Double?, disabled: Bool = false) -> AccountQuota {
        var windows: [QuotaWindow] = []
        if let five { windows.append(QuotaWindow(id: "5-hour", label: "5-hour", remaining: five)) }
        if let weekly { windows.append(QuotaWindow(id: "Weekly", label: "Weekly", remaining: weekly)) }
        return AccountQuota(account: Account(id: id, authIndex: id, provider: provider, name: id, email: "\(id)@example.com", disabled: disabled), windows: windows)
    }
    func testSourcesOfferSeparateProviderAveragesAndAccounts() {
        let sources = MenuBarSource.options(from: [quota("a", five: 86, weekly: 92), quota("b", five: 58, weekly: 76), quota("c", provider: "claude", five: 18, weekly: 61), quota("disabled", five: 0, weekly: 0, disabled: true)])
        XCTAssertEqual(sources.filter(\.isProvider).count, 2)
        XCTAssertEqual(sources.filter { !$0.isProvider }.count, 3)
        XCTAssertTrue(sources.contains { $0.id == "provider:codex" && $0.detail == "All 2 accounts" })
        XCTAssertFalse(sources.contains { $0.id == "account:disabled" })
    }
    func testProviderAverageDoesNotMixOtherProvidersFailuresOrReviewQuotas() throws {
        var a = quota("a", five: 86, weekly: 92)
        a.windows.append(QuotaWindow(id: "review", label: "Code review · Weekly", remaining: 0, duration: 604800))
        let quotas = [a, quota("b", five: 58, weekly: 76), quota("missing", five: nil, weekly: nil), quota("c", provider: "claude", five: 0, weekly: 0), quota("disabled", five: 0, weekly: 0, disabled: true)]
        let source = try XCTUnwrap(MenuBarSource.options(from: quotas).first { $0.id == "provider:codex" })
        let value = source.readout(from: quotas, stale: false)
        XCTAssertEqual(value.fiveHour, 72); XCTAssertEqual(value.weekly, 84)
        let individual = try XCTUnwrap(MenuBarSource.options(from: quotas).first { $0.id == "account:b" }).readout(from: quotas, stale: false)
        XCTAssertEqual(individual.fiveHour, 58); XCTAssertEqual(individual.weekly, 76)
    }
    func testPerWindowAveragesUseOnlyAccountsReportingThatWindow() throws {
        let quotas = [quota("a", five: 80, weekly: nil), quota("b", five: 60, weekly: 30)]
        let source = try XCTUnwrap(MenuBarSource.options(from: quotas).first { $0.id == "provider:codex" })
        let value = source.readout(from: quotas, stale: false)
        XCTAssertEqual(value.fiveHour, 70); XCTAssertEqual(value.weekly, 30)
        XCTAssertNil(source.readout(from: quotas, stale: true).weekly)
        XCTAssertNil(source.readout(from: [], stale: false).fiveHour)
    }
    func testWeeklyExhaustionDoesNotReduceReportedFiveHourQuota() throws {
        let quotas = [quota("a", five: 100, weekly: 0), quota("b", five: 80, weekly: 60)]
        let sources = MenuBarSource.options(from: quotas)
        let provider = try XCTUnwrap(sources.first { $0.id == "provider:codex" }).readout(from: quotas, stale: false)
        XCTAssertEqual(provider.fiveHour, 90)
        XCTAssertEqual(provider.weekly, 30)
        XCTAssertTrue(provider.tooltip(mode: .remaining, window: .fiveHour).contains("5-hour: 90% remaining"))
        XCTAssertFalse(provider.tooltip(mode: .remaining, window: .fiveHour).contains("limited by weekly"))
        let a = try XCTUnwrap(sources.first { $0.id == "account:a" }).readout(from: quotas, stale: false)
        XCTAssertEqual(a.fiveHour, 100)
        XCTAssertEqual(a.text(mode: .used, window: .fiveHour), "0%")
    }
    func testFiveHourAndWeeklyAveragesAreIndependent() throws {
        let quotas = [quota("a", five: 100, weekly: 10), quota("b", five: 10, weekly: 100)]
        let source = try XCTUnwrap(MenuBarSource.options(from: quotas).first { $0.isProvider })
        let result = source.readout(from: quotas, stale: false)
        XCTAssertEqual(result.fiveHour, 55)
        XCTAssertEqual(result.weekly, 55)
    }
    func testFullFiveHourWindowStaysFullWhenWeeklyIsLower() throws {
        let quotas = [quota("a", five: 100, weekly: 59)]
        for source in MenuBarSource.options(from: quotas) {
            let result = source.readout(from: quotas, stale: false)
            XCTAssertEqual(result.text(mode: .remaining, window: .both), "⁵ʰ 100% · ʷ 59%")
            XCTAssertEqual(result.text(mode: .used, window: .both), "⁵ʰ 0% · ʷ 41%")
        }
    }
    func testMissingWeeklyKeepsReportedFiveHourAndIgnoresReviewPool() throws {
        var q = quota("a", five: 75, weekly: nil)
        q.windows.append(QuotaWindow(id: "review", label: "Code review · Weekly", remaining: 0))
        let source = try XCTUnwrap(MenuBarSource.options(from: [q]).first)
        let result = source.readout(from: [q], stale: false)
        XCTAssertEqual(result.fiveHour, 75)
    }
    func testWarningThresholdsAndMissingValues() {
        XCTAssertEqual(TrayQuotaSeverity.forRemaining(0), .critical)
        XCTAssertEqual(TrayQuotaSeverity.forRemaining(9.99), .critical)
        XCTAssertEqual(TrayQuotaSeverity.forRemaining(10), .critical)
        XCTAssertEqual(TrayQuotaSeverity.forRemaining(10.01), .warning)
        XCTAssertEqual(TrayQuotaSeverity.forRemaining(25), .warning)
        XCTAssertEqual(TrayQuotaSeverity.forRemaining(25.01), .normal)
        XCTAssertEqual(TrayQuotaSeverity.forRemaining(nil), .normal)
        XCTAssertEqual(TrayQuotaSeverity.forRemaining(.nan), .normal)
    }
    func testEachPercentageHasItsOwnSeverityEvenInUsedMode() {
        let value = MenuBarReadout(id: "x", title: "Claude", detail: "x", fiveHour: 20, weekly: 5)
        let parts = value.parts(mode: .used, window: .both, includeSource: true)
        XCTAssertEqual(parts.map(\.text).joined(), "Claude ⁵ʰ 80% · ʷ 95%")
        XCTAssertEqual(parts.map(\.severity), [.normal, .normal, .warning, .normal, .critical])
        XCTAssertEqual(value.parts(mode: .remaining, window: .weekly).first?.severity, .critical)
    }

}
