import AppKit
import os
import ServiceManagement
import Sparkle

private let log = Logger(subsystem: "com.diskledplus.app", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // Fidelity target: DiskLED's default polling interval is 30 ms (~33 ticks/s),
    // fast enough that every I/O burst is guaranteed at least one visible blink.
    // See findings.md / KB.md for the reasoning.
    private enum Constants {
        static let tickInterval: TimeInterval = 0.030
        static let defaultBrightnessPercent = 60
        static let brightnessKey = "ledBrightnessPercent"
        static let layoutKey = "ledLayout"
        // 0.3.x bare-binary launches stored preferences under the process-name
        // domain ("DiskLEDPlus"); the bundled app uses the bundle identifier
        // domain ("com.diskledplus.app"). Carried over on first bundled launch.
        static let legacyDefaultsSuite = "DiskLEDPlus"
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let source = DiskActivitySource()
    private let renderer: LEDIconRenderer = .shared
    private var timer: Timer?
    private var lastRenderedState: LEDState?
    private var brightnessMenuItem: NSMenuItem?
    private var loginItemMenuItem: NSMenuItem?
    // Sparkle: nil for bare-binary launches (Sparkle can only update a bundled app).
    private var updaterController: SPUStandardUpdaterController?

    // LED brightness in percent of the lit colors' full strength (10–100). The
    // operator set the default explicitly — never "bump it back up to be visible".
    private var brightnessPercent: Int = Constants.defaultBrightnessPercent
    // Graphic layout of the status-bar indicator (bars or dots).
    private var layout: LEDLayout = .bars

    // Cross-object preference surface: the settings window and this app delegate
    // both read/write through these static accessors, which persist immediately
    // and hand the change back to the live app delegate for re-rendering.
    static var sharedLayout: LEDLayout {
        get { LEDLayout(stored: UserDefaults.standard.string(forKey: Constants.layoutKey) ?? "") }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.layoutKey)
            (NSApp.delegate as? AppDelegate)?.applyLayout(newValue)
        }
    }
    static var sharedBrightnessPercent: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: Constants.brightnessKey)
            return min(max(stored, 10), 100)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.brightnessKey)
            (NSApp.delegate as? AppDelegate)?.applyBrightness(newValue)
        }
    }

    // Menu items that mirror live rates (display only; the LED stays the primary output).
    private var readRateItem: NSMenuItem?
    private var writeRateItem: NSMenuItem?

    // Rolling ~1 s window for the menu's B/s readout (the LED itself is never smoothed).
    private var windowStart = Date()
    private var windowReadBytes: UInt64 = 0
    private var windowWriteBytes: UInt64 = 0
    private var windowTicks: UInt = 0
    private var lastWindowReadBytes: UInt64 = 0
    private var lastWindowWriteBytes: UInt64 = 0
    private var lastWindowTicks: UInt = 0

    // Debug tracing (opt-in): launch with DISKLED_DEBUG=1 to log every tick to the
    // unified log with the time since the previous tick and the raw deltas. 33 Hz
    // logging is spammy by design — it exists to verify cadence and burst behavior.
    private let debugTrace = ProcessInfo.processInfo.environment["DISKLED_DEBUG"] == "1"
    private var lastBeatAt: DispatchTime?

    /// True when running from a proper .app bundle (vs. the bare release binary).
    private var isBundled: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// Current start-at-login state according to macOS (only meaningful when bundled).
    private var isStartAtLoginEnabled: Bool {
        guard isBundled else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Migrate the pre-0.4.0 bare-binary brightness setting before register()
        // runs, so the migrated value takes precedence over the registered default.
        if UserDefaults.standard.object(forKey: Constants.brightnessKey) == nil,
           let legacy = UserDefaults(suiteName: Constants.legacyDefaultsSuite),
           let migrated = legacy.object(forKey: Constants.brightnessKey) as? Int {
            UserDefaults.standard.set(migrated, forKey: Constants.brightnessKey)
            log.info("migrated brightness preference from bare-binary defaults domain: \(migrated, privacy: .public)%")
        }
        UserDefaults.standard.register(defaults: [Constants.brightnessKey: Constants.defaultBrightnessPercent])
        brightnessPercent = AppDelegate.sharedBrightnessPercent
        layout = AppDelegate.sharedLayout
        // The labeled layouts carry the system drive's medium type ("SSD"/"HDD").
        // Detect once at launch — a system drive's medium type cannot change
        // while the process runs. Details of the detection land in the unified
        // log (subsystem com.diskledplus.disk, category drive).
        let driveType = SystemDriveTypeDetector.detect()
        renderer.setDriveLabel(driveType.label)
        log.info("system drive medium type resolved, label=\(driveType.label, privacy: .public)")
        // One-shot enablement for scripted installs: --enable-login-item registers
        // the login item without needing a click through the menu first.
        if isBundled, CommandLine.arguments.contains("--enable-login-item") {
            do {
                try SMAppService.mainApp.register()
                log.info("start-at-login register (--enable-login-item) ok, status=\(SMAppService.mainApp.status.rawValue, privacy: .public)")
            } catch {
                log.error("start-at-login register (--enable-login-item) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if isBundled {
            // Sparkle's scheduler comes from Info.plist (check at startup, weekly
            // interval); the first-run permission prompt is Sparkle's standard flow.
            updaterController = SPUStandardUpdaterController(startingUpdater: true,
                                                             updaterDelegate: nil,
                                                             userDriverDelegate: nil)
        }
        buildMenu()
        render(.off)
        let t = Timer(timeInterval: Constants.tickInterval, repeats: true) { [weak self] _ in
            self?.beat()
        }
        t.tolerance = 0 // no coalescing: sub-30 ms jitter is exactly what we are here to keep
        RunLoop.main.add(t, forMode: .common)
        timer = t
        log.info("DiskLED-plus started, tick=\(Constants.tickInterval)s, debugTrace=\(self.debugTrace, privacy: .public)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard let timer else { return }
        timer.invalidate()
        self.timer = nil
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Blink loop

    private func beat() {
        let tick = source.tick()
        if debugTrace {
            let now = DispatchTime.now()
            let dtMs = lastBeatAt.map { Double(now.uptimeNanoseconds &- $0.uptimeNanoseconds) / 1_000_000 } ?? 0
            lastBeatAt = now
            log.debug("tick dt=\(dtMs, format: .fixed(precision: 1))ms read=\(tick.readBytesDelta, privacy: .public)B/\(tick.readOpsDelta, privacy: .public)op write=\(tick.writeBytesDelta, privacy: .public)B/\(tick.writeOpsDelta, privacy: .public)op")
        }

        windowReadBytes &+= tick.readBytesDelta
        windowWriteBytes &+= tick.writeBytesDelta
        windowTicks &+= 1

        let now = Date()
        if now.timeIntervalSince(windowStart) >= 1.0 {
            lastWindowReadBytes = windowReadBytes
            lastWindowWriteBytes = windowWriteBytes
            lastWindowTicks = windowTicks
            windowStart = now
            windowReadBytes = 0
            windowWriteBytes = 0
            windowTicks = 0
        }

        let state = LEDState(
            readsActive: tick.readBytesDelta > 0 || tick.readOpsDelta > 0,
            writesActive: tick.writeBytesDelta > 0 || tick.writeOpsDelta > 0
        )
        if state != lastRenderedState {
            render(state)
        }
    }

    private func render(_ state: LEDState) {
        lastRenderedState = state
        statusItem.button?.image = renderer.icon(for: state, brightnessPercent: brightnessPercent, layout: layout)
        statusItem.button?.toolTip = "DiskLED-plus — green: reads, red: writes"
    }

    // MARK: - Preferences application (from Settings window or menu)

    private func applyLayout(_ newLayout: LEDLayout) {
        layout = newLayout
        statusItem.length = NSStatusItem.variableLength // re-measure for the new image size
        render(lastRenderedState ?? .off)
        log.info("LED layout set to \(newLayout.rawValue, privacy: .public) (persisted)")
    }

    private func applyBrightness(_ percent: Int) {
        let clamped = min(max(percent, 10), 100)
        brightnessPercent = clamped
        for item in brightnessMenuItem?.submenu?.items ?? [] {
            item.state = item.tag == clamped ? .on : .off
        }
        render(lastRenderedState ?? .off)
        log.info("LED brightness set to \(clamped)% (persisted)")
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        let header = NSMenuItem(title: "DiskLED-plus", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let readItem = NSMenuItem(title: "Reads — aggregating…", action: nil, keyEquivalent: "")
        readItem.isEnabled = false
        let writeItem = NSMenuItem(title: "Writes — aggregating…", action: nil, keyEquivalent: "")
        writeItem.isEnabled = false
        menu.addItem(readItem)
        menu.addItem(writeItem)
        readRateItem = readItem
        writeRateItem = writeItem
        menu.addItem(.separator())

        let brightnessMenu = NSMenu()
        brightnessMenu.autoenablesItems = false
        for percent in stride(from: 10, through: 100, by: 10) {
            let item = NSMenuItem(title: "\(percent)%", action: #selector(setBrightness(_:)), keyEquivalent: "")
            item.tag = percent
            item.target = self
            item.state = percent == brightnessPercent ? .on : .off
            brightnessMenu.addItem(item)
        }
        let brightnessItem = NSMenuItem(title: "Brightness", action: nil, keyEquivalent: "")
        brightnessItem.submenu = brightnessMenu
        menu.addItem(brightnessItem)
        brightnessMenuItem = brightnessItem
        menu.addItem(.separator())

        // Start-at-login is only meaningful from a proper .app bundle; from the
        // bare binary the menu voice would silently fail, so it is withheld.
        if isBundled {
            let loginItem = NSMenuItem(title: "Start at Login",
                                       action: #selector(toggleStartAtLogin(_:)),
                                       keyEquivalent: "")
            loginItem.target = self
            loginItem.state = isStartAtLoginEnabled ? .on : .off
            menu.addItem(loginItem)
            loginItemMenuItem = loginItem
            menu.addItem(.separator())

            if let updater = updaterController {
                let checkUpdates = NSMenuItem(title: "Check for Updates…",
                                              action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                                              keyEquivalent: "")
                checkUpdates.target = updater
                menu.addItem(checkUpdates)
            }
        }

        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(showSettings),
                                  keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let about = NSMenuItem(title: "About DiskLED-plus",
                               action: #selector(showAbout),
                               keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit DiskLED-plus",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)

        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        let seconds = max(Double(lastWindowTicks), 1) * Constants.tickInterval
        let readBps = Double(lastWindowReadBytes) / seconds
        let writeBps = Double(lastWindowWriteBytes) / seconds
        readRateItem?.title = "Reads   \(formatter.string(fromByteCount: Int64(readBps.rounded())))/s"
        writeRateItem?.title = "Writes  \(formatter.string(fromByteCount: Int64(writeBps.rounded())))/s"
    }

    // MARK: - Brightness

    @objc private func setBrightness(_ sender: NSMenuItem) {
        let percent = sender.tag
        guard (10...100).contains(percent) else { return }
        AppDelegate.sharedBrightnessPercent = percent
    }

    // MARK: - Start at Login

    @objc private func toggleStartAtLogin(_ sender: NSMenuItem) {
        do {
            if sender.state == .on {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            log.error("start-at-login toggle failed: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = "Could not change Start at Login"
            alert.informativeText = "\(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }
        sender.state = isStartAtLoginEnabled ? .on : .off
        log.info("start-at-login now enabled=\(self.isStartAtLoginEnabled, privacy: .public)")
    }

    // MARK: - Settings window

    @objc private func showSettings() {
        let controller = SettingsWindowController.shared
        controller.refresh()
        controller.showWindow(self)
        controller.window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - About (standard macOS panel)

    /// Standard macOS About panel: app icon, name, version, and a credits block
    /// with the author, the license and the source repository.
    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "DiskLED-plus",
            .credits: Self.aboutCredits(),
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func aboutCredits() -> NSAttributedString {
        let text = NSMutableAttributedString()
        let body = NSFont.systemFont(ofSize: 11)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 6

        func append(_ string: String, font: NSFont = body, color: NSColor = .labelColor,
                    link: URL? = nil) {
            let attributed = NSMutableAttributedString(string: string)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
            ]
            if let link {
                attributes[.link] = link
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            attributed.setAttributes(attributes, range: NSRange(location: 0, length: attributed.length))
            text.append(attributed)
        }

        append("By Marcus1571\n", font: NSFont.boldSystemFont(ofSize: 11))
        append("Disk activity, shown the way hardware used to do it: one LED per channel, "
             + "blinking for every single tick of I/O — 33 times per second, nothing "
             + "averaged, nothing rounded up, nothing smoothed away.\n\n")
        append("Inspired by Helge Klein's DiskLED for Windows — no code or assets "
             + "were copied, just the point.\n\n")
        append("License: MIT — full text in the repository.\n")
        append("github.com/Marcus1571/diskled-plus", color: .linkColor,
               link: URL(string: "https://github.com/Marcus1571/diskled-plus")!)
        append("\n")
        return text
    }
}
