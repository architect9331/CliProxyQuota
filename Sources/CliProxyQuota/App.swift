import AppKit
import SwiftUI
import QuotaCore

@main struct CliProxyQuotaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var items: [NSStatusItem] = []
    private weak var anchorButton: NSStatusBarButton?
    private var popover: NSPopover!
    private var store: QuotaStore!
    private var statusTimer: Timer?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--verify-layout") {
            Task { @MainActor in
                do { try await Screenshots.verifyLayout() }
                catch { fputs("Layout verification failed: \(error)\n", stderr); exit(1) }
                NSApp.terminate(nil)
            }
            return
        }
        if let index = arguments.firstIndex(of: "--screenshots"), arguments.count > index + 1 {
            Task { @MainActor in
                do { try await Screenshots.write(to: URL(fileURLWithPath: arguments[index + 1], isDirectory: true)) }
                catch { fputs("Screenshot rendering failed: \(error)\n", stderr); exit(1) }
                NSApp.terminate(nil)
            }
            return
        }
        store = QuotaStore(demo: arguments.contains("--demo"))
        popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        let controller = NSHostingController(rootView: QuotaPopover(store: store))
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller
        NotificationCenter.default.addObserver(self, selector: #selector(updateScreenLimit),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        store.onChange = { [weak self] in self?.updateStatus() }
        updateStatus()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateStatus() }
        }
        store.start()
        if !store.configured && !store.demo { togglePopover() }
        if arguments.contains("--show") { togglePopover() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard popover != nil else { return false }
        if !popover.isShown { togglePopover() }
        return false
    }
    private func updateStatus() {
        let readouts = store.menuReadouts
        let count = max(1, readouts.count)
        while items.count > count { NSStatusBar.system.removeStatusItem(items.removeLast()) }
        while items.count < count {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self; item.button?.action = #selector(togglePopover(_:))
            items.append(item)
        }
        for (index, item) in items.enumerated() {
            guard let button = item.button else { continue }
            button.image = QuotaBotIcon.menuBar
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            if index < readouts.count {
                let readout = readouts[index]
                button.attributedTitle = MenuBarAppearance.title(for: readout, mode: store.percentageMode, window: store.menuBarWindow, includeSource: readouts.count > 1, coloredWarnings: store.trayColorWarnings, showResetCountdown: store.trayResetCountdown)
                let resetText = store.trayResetCountdown ? readout.recoveryText(window: store.menuBarWindow).map { " · " + $0 } ?? "" : ""
                button.setAccessibilityLabel(readout.text(mode: store.percentageMode, window: store.menuBarWindow, includeSource: readouts.count > 1) + resetText)
                button.toolTip = (store.demo ? "Demo · " : "") + readout.tooltip(mode: store.percentageMode, window: store.menuBarWindow)
            } else { button.attributedTitle = NSAttributedString(string: ""); button.setAccessibilityLabel("CliProxy Quota"); button.toolTip = "CliProxy Quota · click for accounts and Settings" }
        }
    }
    @objc private func togglePopover(_ sender: NSStatusBarButton? = nil) {
        if popover.isShown { popover.performClose(nil) }
        else if let button = sender ?? items.first?.button {
            anchorButton = button
            updateScreenLimit()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    @objc private func updateScreenLimit() {
        let screen = anchorButton?.window?.screen ?? items.first?.button?.window?.screen ?? NSScreen.main
        store.maximumPopoverHeight = (screen?.visibleFrame.height ?? 800) - 24
    }

}

/// Render the actual native views with synthetic data, without capturing the user's desktop.
@MainActor enum Screenshots {
    static func write(to directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try writeTrayPreview(to: directory)
        for (name, tab, settings, dark) in [
            ("overview", "All accounts", false, false),
            ("accounts", "Per account", false, false),
            ("settings", "All accounts", true, false),
            ("settings-connection", "All accounts", true, false),
            ("settings-general", "All accounts", true, false),
            ("settings-general-dark", "All accounts", true, true),
            ("overview-dark", "All accounts", false, true),
            ("overview-forecast-off", "All accounts", false, false),
            ("settings-forecast-off", "All accounts", true, false),
            ("overview-used", "All accounts", false, false),
            ("accounts-used", "Per account", false, false)
        ] {
            let store = QuotaStore(demo: true)
            store.selectedView = tab; store.showSettings = settings
            store.maximumPopoverHeight = 1200
            if name == "settings-connection" { store.settingsTab = "Connection" }
            if name.hasPrefix("settings-general") { store.settingsTab = "General" }
            if name == "settings" { store.settingsTab = "Tray Display" }
            if name.hasSuffix("used") { store.percentageMode = .used }
            if name.hasSuffix("forecast-off") { store.forecastEnabled = false }
            let controller = NSHostingController(rootView: QuotaPopover(store: store,
                expandedInitially: tab == "Per account" ? ["demo-codex-1"] : [])
                .environment(\.colorScheme, dark ? .dark : .light))
            if dark { store.appearance = .dark }
            let window = await prepare(controller, dark: dark)
            guard let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds) else {
                throw CocoaError(.fileWriteUnknown)
            }
            controller.view.cacheDisplay(in: controller.view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: directory.appendingPathComponent("\(name).png"))
            window.orderOut(nil)
        }
    }
    private static func writeTrayPreview(to directory: URL) throws {
        let image = NSImage(size: NSSize(width: 420, height: 100))
        image.lockFocus()
        NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance {
            NSColor.windowBackgroundColor.setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: 420, height: 100)).fill()
            let sample = MenuBarReadout(id: "preview", title: "Claude", detail: "Sample data", fiveHour: 8, weekly: 23, nextReset: Date().addingTimeInterval(8040))
            for (mode, y) in [(PercentageMode.remaining, CGFloat(63)), (.used, CGFloat(23))] {
                (mode.title as NSString).draw(at: NSPoint(x: 20, y: y), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
                QuotaBotIcon.menuBar.draw(in: NSRect(x: 130, y: y - 1, width: 18, height: 18))
                MenuBarAppearance.title(for: sample, mode: mode, window: .both)
                    .draw(at: NSPoint(x: 155, y: y))
            }
        }
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: directory.appendingPathComponent("tray-badges.png"))
    }
    private static func prepare<V: View>(_ controller: NSHostingController<V>, dark: Bool = false) async -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 600),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentViewController = controller
        controller.view.frame = NSRect(x: 0, y: 0, width: 420, height: 600)
        window.orderFrontRegardless()
        await settle(controller, window: window)
        return window
    }
    private static func settle<V: View>(_ controller: NSHostingController<V>, window: NSWindow) async {
        // Let content and chrome measurements settle, including after account expansion or tab changes.
        for _ in 0..<5 {
            controller.view.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(80))
            let height = controller.view.fittingSize.height
            window.setContentSize(NSSize(width: 420, height: max(1, height)))
            controller.view.frame = NSRect(x: 0, y: 0, width: 420, height: max(1, height))
        }
        controller.view.layoutSubtreeIfNeeded()
    }
    static func verifyLayout() async throws {
        try ProviderArtwork.verifyAssets()
        func check(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "PopoverLayout", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        let coloredReadout = MenuBarReadout(id: "colors", title: "Claude", detail: "Preview", fiveHour: 20, weekly: 5)
        let coloredTitle = MenuBarAppearance.title(for: coloredReadout, mode: .used, window: .both, includeSource: true)
        func badges(_ title: NSAttributedString) -> [[NSAttributedString.Key: Any]] {
            var result: [[NSAttributedString.Key: Any]] = []
            title.enumerateAttributes(in: NSRange(location: 0, length: title.length)) { attributes, _, _ in
                if attributes[.attachment] != nil { result.append(attributes) }
            }
            return result
        }
        let coloredBadges = badges(coloredTitle)
        try check(coloredBadges.count == 2, "Both windows must have independent rounded badges")
        try check(coloredBadges[0][MenuBarAppearance.badgeText] as? String == "⁵ʰ 80%" &&
            coloredBadges[0][MenuBarAppearance.badgeBackground] as? NSColor == MenuBarAppearance.warningBackground,
            "Five-hour label and used percentage must render in a yellow badge")
        try check(coloredBadges[1][MenuBarAppearance.badgeText] as? String == "ʷ 95%" &&
            coloredBadges[1][MenuBarAppearance.badgeBackground] as? NSColor == MenuBarAppearance.criticalBackground,
            "Weekly label and used percentage must render in a red badge")
        try check(coloredBadges.allSatisfy { ($0[.attachment] as? NSTextAttachment)?.image?.isValid == true },
            "Rounded badge images must be valid")
        let plainTitle = MenuBarAppearance.title(for: coloredReadout, mode: .used, window: .both, includeSource: true, coloredWarnings: false, showResetCountdown: false)
        try check(badges(plainTitle).isEmpty && plainTitle.string == " " + coloredReadout.text(mode: .used, window: .both, includeSource: true),
            "Disabling color styling must restore plain tray labels and percentages")
        let independentCountdown = MenuBarAppearance.title(for: coloredReadout, mode: .used, window: .both, coloredWarnings: false)
        try check(badges(independentCountdown).isEmpty && independentCountdown.string.contains("↻"),
            "Reset countdown must remain visible with color warnings disabled")
        let hiddenCountdown = MenuBarAppearance.title(for: coloredReadout, mode: .used, window: .both, showResetCountdown: false)
        try check(badges(hiddenCountdown).count == 2 && !hiddenCountdown.string.contains("↻"),
            "Hiding the countdown must preserve color warnings")
        for background in [MenuBarAppearance.warningBackground, MenuBarAppearance.criticalBackground] {
            let c = background.usingColorSpace(.sRGB)!
            func linear(_ value: CGFloat) -> CGFloat { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
            let luminance = 0.2126 * linear(c.redComponent) + 0.7152 * linear(c.greenComponent) + 0.0722 * linear(c.blueComponent)
            try check(1.05 / (luminance + 0.05) >= 4.5, "White badge text must have at least 4.5:1 contrast")
        }
        let boundaryBadge = MenuBarAppearance.title(for: MenuBarReadout(id: "boundary", title: "x", detail: "x", fiveHour: 10, weekly: nil), mode: .remaining, window: .fiveHour)
        try check(badges(boundaryBadge).first?[MenuBarAppearance.badgeBackground] as? NSColor == MenuBarAppearance.criticalBackground,
            "Exactly ten percent remaining must have a red background")
        let normalTitle = MenuBarAppearance.title(for: MenuBarReadout(id: "normal", title: "x", detail: "x", fiveHour: 80, weekly: nil), mode: .remaining, window: .both)
        try check(normalTitle.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor == .labelColor,
            "Healthy and unavailable tray readings must retain the standard text color")
        print("Verified rounded tray badges, plain-text fallback, labels, and text contrast")
        for tab in ["All accounts", "Per account"] {
            let store = QuotaStore(demo: true)
            store.maximumPopoverHeight = 1200
            store.selectedView = tab
            let controller = NSHostingController(rootView: QuotaPopover(store: store,
                expandedInitially: Set(store.quotas.map(\.id))))
            let window = await prepare(controller)
            func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
            let resetLabels = descendants(controller.view).compactMap { $0 as? NSTextField }
                .filter { $0.toolTip?.hasPrefix("Resets on ") == true }
            let expectedLabels = tab == "All accounts" ? store.pools.count : store.quotas.reduce(0) { $0 + $1.windows.count }
            try check(resetLabels.count == expectedLabels, "Every reset countdown needs an independent native tooltip")
            try check(resetLabels.allSatisfy { $0.bounds.width > 0 && $0.bounds.height > 0 }, "Tooltip hover regions must have visible bounds")
            let natural = controller.view.fittingSize.height
            try check(natural > 500 && natural < 1200, "\(tab) must fit full expanded content on a tall display: \(natural)")
            store.maximumPopoverHeight = 500
            await settle(controller, window: window)
            let capped = controller.view.fittingSize.height
            try check(abs(capped - 500) < 2, "\(tab) must scroll at the screen boundary: \(capped)")
            store.maximumPopoverHeight = 1200
            await settle(controller, window: window)
            let restored = controller.view.fittingSize.height
            try check(abs(restored - natural) < 2, "\(tab) must grow back when more screen space is available")
            // Changing tabs must remeasure the chrome as well as the list.
            store.selectedView = tab == "All accounts" ? "Per account" : "All accounts"
            await settle(controller, window: window)
            let switched = controller.view.fittingSize.height
            try check(switched > 500 && switched < 1200, "Tab switch must retain natural content sizing")
            print("\(tab): full \(Int(natural))pt; capped \(Int(capped))pt; restored \(Int(restored))pt; tab switch \(Int(switched))pt")
            store.showSettings = true
            for settingsTab in ["General", "Connection", "Tray Display"] {
                store.settingsTab = settingsTab
                store.maximumPopoverHeight = 1200
                await settle(controller, window: window)
                let settingsHeight = controller.view.fittingSize.height
                try check(settingsHeight > 200 && settingsHeight < 650, "Settings tab must fit its content")
                store.maximumPopoverHeight = 200
                await settle(controller, window: window)
                try check(abs(controller.view.fittingSize.height - 200) < 2, "Settings must scroll at the screen boundary")
                print("Settings \(settingsTab): full \(Int(settingsHeight))pt; capped 200pt")
            }
            window.orderOut(nil)
        }
        let store = QuotaStore(demo: true)
        let codex = ProviderForecast.observations(for: "Codex", quotas: store.quotas, endpoint: store.endpoint)!
        try check(codex.first(where: { $0.key == ProviderForecast.digest([store.endpoint, "Codex", "5-hour"]) })?.remaining == 120,
            "Forecast must sum both Codex account allowances")
        try check(store.forecast(for: "Codex").isWarning, "Combined recent Codex pace should warn")
        try check(store.forecast(for: "Claude") == .inTime, "Claude allowance should reset in time")
        var failed = store.quotas
        failed[0].issue = "Unavailable"
        try check(ProviderForecast.observations(for: "Codex", quotas: failed, endpoint: store.endpoint) == nil,
            "Partial provider coverage must not produce a pooled forecast")
        let firstKey = codex[0].key
        try check(!ProviderForecast.observations(for: "Codex", quotas: store.quotas, endpoint: "https://other.example")!.contains(where: { $0.key == firstKey }),
            "Forecast history must be isolated by instance")
        store.forecastLookback = .oneTwenty
        try check(store.forecast(for: "Codex") == .inTime, "Longer averaging should smooth the recent burst")
        store.forecastEnabled = false
        try check(!store.forecastEnabled, "Forecast preference must switch off immediately")
        print("Verified provider sums, incomplete coverage, instance isolation, and configurable forecasts")
        let coordinator = SourceCoordinator()
        coordinator.onToggle = store.toggleSource
        func menu() -> NSMenu {
            SourceMenuButton(summary: "Sources", sources: store.sourceOptions,
                selectedIDs: store.resolvedSourceIDs, onToggle: store.toggleSource).menu(coordinator: coordinator)
        }
        func sourceItem(_ id: String) throws -> NSMenuItem {
            guard let item = menu().items.first(where: { $0.representedObject as? String == id }) else {
                throw NSError(domain: "SourceMenu", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing menu item"])
            }
            return item
        }
        try check(try sourceItem("provider:codex").state == .on, "Default source should be checked")
        coordinator.toggle(try sourceItem("provider:claude"))
        try check(store.menuReadouts.count == 2, "Checkbox selection should create two readouts")
        try check(try sourceItem("provider:claude").state == .on, "New source should be checked")
        store.percentageMode = .used
        store.menuBarWindow = .weekly
        try check(store.menuReadouts.first?.text(mode: store.percentageMode, window: store.menuBarWindow) == "16%", "Global used/weekly preferences should update immediately")
        coordinator.toggle(try sourceItem("provider:codex"))
        coordinator.toggle(try sourceItem("provider:claude"))
        try check(store.menuReadouts.isEmpty, "Unchecking all sources must preserve icon-only mode")
        print("Verified native Source checkbox states, multi-source selection, immediate display changes, and icon-only mode")
    }
}
