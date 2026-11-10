import AppKit
import os

private let log = Logger(subsystem: "com.diskledplus.app", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // Fidelity target: DiskLED's default polling interval is 30 ms (~33 ticks/s),
    // fast enough that every I/O burst is guaranteed at least one visible blink.
    // See findings.md / KB.md for the reasoning.
    private enum Constants {
        static let tickInterval: TimeInterval = 0.030
        static let defaultBrightnessPercent = 60
        static let brightnessKey = "ledBrightnessPercent"
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let source = DiskActivitySource()
    private let renderer: LEDIconRenderer = .shared
    private var timer: Timer?
    private var lastRenderedState: LEDState?
    private var brightnessMenuItem: NSMenuItem?

    // LED brightness in percent of the lit colors' full strength (10–100). The
    // operator set the default explicitly — never "bump it back up to be visible".
    private var brightnessPercent: Int = Constants.defaultBrightnessPercent

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Constants.brightnessKey: Constants.defaultBrightnessPercent])
        let stored = UserDefaults.standard.integer(forKey: Constants.brightnessKey)
        brightnessPercent = min(max(stored, 10), 100)
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
        statusItem.button?.image = renderer.icon(for: state, brightnessPercent: brightnessPercent)
        statusItem.button?.toolTip = "DiskLED-plus — green: reads, red: writes"
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
        brightnessPercent = percent
        UserDefaults.standard.set(percent, forKey: Constants.brightnessKey)
        for item in brightnessMenuItem?.submenu?.items ?? [] {
            item.state = item.tag == percent ? .on : .off
        }
        render(lastRenderedState ?? .off)
        log.info("LED brightness set to \(percent)% (persisted)")
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "DiskLED-plus"
        alert.informativeText = """
        Instantaneous disk activity in the menu bar.
        Left (green): reads. Right (red): writes.
        Every I/O tick blinks — nothing is smoothed away.

        Inspired by Helge Klein's DiskLED for Windows.
        """
        alert.alertStyle = .informational
        alert.runModal()
    }
}
