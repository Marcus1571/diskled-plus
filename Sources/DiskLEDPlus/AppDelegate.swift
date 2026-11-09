import AppKit
import os

private let log = Logger(subsystem: "com.diskledplus.app", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // Fidelity target: DiskLED's default polling interval is 30 ms (~33 ticks/s),
    // fast enough that every I/O burst is guaranteed at least one visible blink.
    // See findings.md / KB.md for the reasoning.
    private enum Constants {
        static let tickInterval: TimeInterval = 0.030
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let source = DiskActivitySource()
    private let renderer: LEDIconRenderer = .shared
    private var timer: Timer?
    private var lastRenderedState: LEDState?

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        render(.off)
        let t = Timer(timeInterval: Constants.tickInterval, repeats: true) { [weak self] _ in
            self?.beat()
        }
        t.tolerance = 0 // no coalescing: sub-30 ms jitter is exactly what we are here to keep
        RunLoop.main.add(t, forMode: .common)
        timer = t
        log.info("DiskLED-plus started, tick=\(Constants.tickInterval)s")
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
        statusItem.button?.image = renderer.icon(for: state)
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
