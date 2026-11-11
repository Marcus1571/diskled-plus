import AppKit

/// Preferences window: layout of the status-bar indicator and LED brightness.
/// A plain AppKit NSWindow with fixed controls — no SwiftUI, matching the rest
/// of the app. Kept alive as a singleton so reopening always shows the current
/// values; every change persists immediately through the AppDelegate's shared
/// accessors.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var layoutPopup: NSPopUpButton?
    private var previewView: NSImageView?
    private var brightnessSlider: NSSlider?
    private var brightnessLabel: NSTextField?
    private var isRefreshingControls = false

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 186),
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

        // Layout picker
        let layoutLabel = NSTextField(labelWithString: "Indicator layout:")
        layoutLabel.frame = NSRect(x: 20, y: 150, width: 120, height: 20)
        contentView.addSubview(layoutLabel)

        let popup = NSPopUpButton(frame: NSRect(x: 140, y: 146, width: 170, height: 24))
        popup.autoenablesItems = false
        for layout in LEDLayout.allCases {
            popup.addItem(withTitle: layout.title)
            popup.lastItem?.representedObject = layout.rawValue
        }
        popup.target = self
        popup.action = #selector(layoutChanged(_:))
        contentView.addSubview(popup)
        layoutPopup = popup

        // Brightness
        let brightnessTitle = NSTextField(labelWithString: "LED brightness:")
        brightnessTitle.frame = NSRect(x: 20, y: 118, width: 120, height: 20)
        contentView.addSubview(brightnessTitle)

        let slider = NSSlider(value: Double(AppDelegate.sharedBrightnessPercent),
                              minValue: 10, maxValue: 100,
                              target: self, action: #selector(brightnessChanged(_:)))
        slider.frame = NSRect(x: 140, y: 114, width: 130, height: 24)
        contentView.addSubview(slider)
        brightnessSlider = slider

        let valueLabel = NSTextField(labelWithString: "\(AppDelegate.sharedBrightnessPercent)%")
        valueLabel.frame = NSRect(x: 274, y: 118, width: 40, height: 20)
        contentView.addSubview(valueLabel)
        brightnessLabel = valueLabel

        // Live preview of the chosen layout, both LEDs lit, scaled 4x.
        let previewBox = NSBox()
        previewBox.boxType = .primary
        previewBox.title = "Preview"
        previewBox.frame = NSRect(x: 20, y: 40, width: 90, height: 66)
        contentView.addSubview(previewBox)
        let preview = NSImageView(frame: NSRect(x: 30, y: 52, width: 70, height: 48))
        preview.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(preview)
        previewView = preview

        let hint = NSTextField(wrappingLabelWithString:
            "Green = reads · Red = writes. Blinking follows every I/O tick and is never smoothed.")
        hint.font = NSFont.systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 122, y: 44, width: 180, height: 50)
        contentView.addSubview(hint)

        refresh()
    }

    /// Re-sync the controls from the live preference values (also called by the
    /// app delegate when the menu's Brightness submenu changes the value).
    func refresh() {
        isRefreshingControls = true
        defer { isRefreshingControls = false }
        let layout = AppDelegate.sharedLayout
        if let index = LEDLayout.allCases.firstIndex(of: layout) {
            layoutPopup?.selectItem(at: index)
        }
        let brightness = AppDelegate.sharedBrightnessPercent
        brightnessSlider?.integerValue = brightness
        brightnessLabel?.stringValue = "\(brightness)%"
        updatePreview()
    }

    private func updatePreview() {
        guard let previewView,
              let raw = layoutPopup?.selectedItem?.representedObject as? String,
              let layout = LEDLayout(rawValue: raw) else { return }
        previewView.image = LEDIconRenderer.shared.icon(for: .both,
                                                        brightnessPercent: AppDelegate.sharedBrightnessPercent,
                                                        layout: layout)
    }

    @objc private func layoutChanged(_ sender: NSPopUpButton) {
        guard !isRefreshingControls,
              let raw = sender.selectedItem?.representedObject as? String,
              let layout = LEDLayout(rawValue: raw) else { return }
        AppDelegate.sharedLayout = layout
        updatePreview()
    }

    @objc private func brightnessChanged(_ sender: NSSlider) {
        guard !isRefreshingControls else { return }
        AppDelegate.sharedBrightnessPercent = sender.integerValue
        brightnessLabel?.stringValue = "\(sender.integerValue)%"
        updatePreview()
    }

    func windowWillClose(_ notification: Notification) {
        // Nothing to persist here — every change is written the moment it is
        // made; closing is purely visual.
    }
}
