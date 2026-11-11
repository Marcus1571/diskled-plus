import AppKit

/// Preferences window: layout of the status-bar indicator and LED brightness.
/// A plain AppKit NSWindow with fixed controls — no SwiftUI, matching the rest
/// of the app. Kept alive by AppDelegate (not a singleton) so reopening the
/// window always shows the current values.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var layoutButton: NSButton?
    private var dotsButton: NSButton?
    private var brightnessSlider: NSSlider?
    private var brightnessLabel: NSTextField?
    private var isRefreshingControls = false

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = "DiskLED-plus Settings"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.delegate = self
        buildContent()
        window.center()
    }

    private func buildContent() {
        guard let window, let contentView = window.contentView else { return }

        // Layout
        let layoutLabel = NSTextField(labelWithString: "Indicator layout:")
        layoutLabel.frame = NSRect(x: 20, y: 108, width: 120, height: 20)
        contentView.addSubview(layoutLabel)

        let barsButton = NSButton(radioButtonWithTitle: LEDLayout.bars.label,
                                  target: self, action: #selector(layoutChanged(_:)))
        barsButton.tag = 0
        barsButton.frame = NSRect(x: 140, y: 128, width: 150, height: 20)
        contentView.addSubview(barsButton)
        layoutButton = barsButton

        let dots = NSButton(radioButtonWithTitle: LEDLayout.dots.label,
                            target: self, action: #selector(layoutChanged(_:)))
        dots.tag = 1
        dots.frame = NSRect(x: 140, y: 106, width: 150, height: 20)
        contentView.addSubview(dots)
        dotsButton = dots

        // Brightness
        let brightnessTitle = NSTextField(labelWithString: "LED brightness:")
        brightnessTitle.frame = NSRect(x: 20, y: 70, width: 120, height: 20)
        contentView.addSubview(brightnessTitle)

        let slider = NSSlider(value: Double(AppDelegate.sharedBrightnessPercent),
                              minValue: 10, maxValue: 100,
                              target: self, action: #selector(brightnessChanged(_:)))
        slider.frame = NSRect(x: 140, y: 66, width: 130, height: 24)
        contentView.addSubview(slider)
        brightnessSlider = slider

        let valueLabel = NSTextField(labelWithString: "\(AppDelegate.sharedBrightnessPercent)%")
        valueLabel.frame = NSRect(x: 274, y: 70, width: 40, height: 20)
        contentView.addSubview(valueLabel)
        brightnessLabel = valueLabel

        let hint = NSTextField(labelWithString: "Green = reads · Red = writes · blinking is never smoothed")
        hint.font = NSFont.systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 20, y: 20, width: 280, height: 16)
        contentView.addSubview(hint)

        refresh()
    }

    /// Re-sync the controls from the live preference values (also called by the
    /// app delegate when the menu's Brightness submenu changes the value).
    func refresh() {
        isRefreshingControls = true
        defer { isRefreshingControls = false }
        let layout = AppDelegate.sharedLayout
        layoutButton?.state = layout == .bars ? .on : .off
        dotsButton?.state = layout == .dots ? .on : .off
        let brightness = AppDelegate.sharedBrightnessPercent
        brightnessSlider?.integerValue = brightness
        brightnessLabel?.stringValue = "\(brightness)%"
    }

    @objc private func layoutChanged(_ sender: NSButton) {
        guard !isRefreshingControls else { return }
        let layout: LEDLayout = sender.tag == 1 ? .dots : .bars
        AppDelegate.sharedLayout = layout
        refresh() // keeps the other radio button's state consistent
    }

    @objc private func brightnessChanged(_ sender: NSSlider) {
        guard !isRefreshingControls else { return }
        AppDelegate.sharedBrightnessPercent = sender.integerValue
        brightnessLabel?.stringValue = "\(sender.integerValue)%"
    }

    func windowWillClose(_ notification: Notification) {
        // Nothing to persist here — every change is written the moment it is
        // made; closing is purely visual.
    }
}
