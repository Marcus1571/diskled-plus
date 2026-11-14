import AppKit

/// Four observed LED states: off, reads only, writes only, both.
enum LEDState: Hashable {
    case off
    case readsOnly
    case writesOnly
    case both

    init(readsActive: Bool, writesActive: Bool) {
        switch (readsActive, writesActive) {
        case (false, false): self = .off
        case (true, false):  self = .readsOnly
        case (false, true):  self = .writesOnly
        case (true, true):   self = .both
        }
    }
}

/// Status-bar graphic layouts. All keep the same rule: left/first channel =
/// reads (green), second = writes (red), lit or dark per tick, never smoothed.
///
/// - `bars`: the original — one square split into two vertical rectangles
///   separated by a 1 pt seam (DiskLED's look, carried over).
/// - `dots`: two circles side by side (iStat-Menus style), lower profile.
/// - `dotsLabeled`: the drive label ("SSD" or "HDD", detected — see
///   SystemDriveType) above the two dots, stacked tight against the menu-bar
///   height (text at the top plane, dots at the bottom, like iStat's
///   two-line elements).
/// - `letters`: "RW" where the letters themselves are the LEDs.
/// - `monogram`: the drive label in white with an activity line above and
///   below — top line green (reads), bottom line red (writes).
/// - `barsLabeled`: the drive label to the left of the bars.
enum LEDLayout: String, CaseIterable {
    case bars
    case dots
    case dotsLabeled
    case letters
    case monogram
    case barsLabeled

    var title: String {
        switch self {
        case .bars:        return "Bars (two rectangles)"
        case .dots:        return "Dots (two circles)"
        case .dotsLabeled: return "Dots with drive label stacked"
        case .letters:     return "\"R/W\" letters as LEDs"
        case .monogram:    return "Drive label with blinking lines"
        case .barsLabeled: return "Bars with drive label"
        }
    }

    /// Label font used by the labeled layouts (iStat-style: ~10 pt regular —
    /// thinner than a semibold, matching the neighboring iStat two-line
    /// elements). The label *text* is the detected system-drive medium type
    /// ("SSD" / "HDD"), carried by LEDIconRenderer.labelText — see
    /// SystemDriveType.
    static let labelFont = NSFont.systemFont(ofSize: 10, weight: .regular)

    static func labelWidth(_ label: String, font: NSFont) -> CGFloat {
        ceil((label as NSString).size(withAttributes: [.font: font]).width)
    }

    /// Status-item image size per layout. Labeled layouts are sized from the
    /// measured label text; the status item runs at variable length so each
    /// layout gets its fit. Stacked layouts use 20 pt of the bar height —
    /// text tight at the top plane, LEDs at the very bottom plane (verified
    /// against iStat's BAT/100% element on the real bar).
    func iconSize(label: String) -> NSSize {
        switch self {
        case .bars, .dots, .letters:
            return NSSize(width: 16, height: 16)
        case .dotsLabeled:
            return NSSize(width: Self.labelWidth(label, font: Self.labelFont) + 1, height: 20)
        case .monogram:
            return NSSize(width: Self.labelWidth(label, font: Self.labelFont) + 2, height: 20)
        case .barsLabeled:
            return NSSize(width: Self.labelWidth(label, font: Self.labelFont) + 3 + 14, height: 16)
        }
    }

    init(stored: String) {
        self = LEDLayout(rawValue: stored) ?? .bars
    }
}

/// Draws the status-bar icon for the active layout. No interpolation: a channel
/// is either lit this tick or dark. Contiguous lit ticks under sustained load
/// read as "steadily ON" exactly like DiskLED.
final class LEDIconRenderer {
    static let shared = LEDIconRenderer()

    private let gap: CGFloat = 1            // seam between the two channels

    // Lit colors at full strength; the brightness percentage controls them via alpha,
    // so 60% looks like the same hue dimmed against the menu bar, never color-shifted.
    private let readLitFull  = NSColor(srgbRed: 0.05, green: 1.00, blue: 0.25, alpha: 1)
    private let writeLitFull = NSColor(srgbRed: 1.00, green: 0.15, blue: 0.15, alpha: 1)
    // Off state: a faint, appearance-adaptive tint (labelColor is dark on a light bar,
    // light on a dark one), so the icon is always locatable. Fully clear (0.8.1/0.8.2)
    // made unlabeled layouts invisible while idle — the app looked absent from the bar.
    private let readOff  = NSColor.labelColor.withAlphaComponent(0.15)
    private let writeOff = NSColor.labelColor.withAlphaComponent(0.15)
    // Labels (system label color: white on a dark bar, black on a light one) stay lit at all times so a labeled layout remains
    // findable while the LEDs are off — same role as any other menu-bar text.
    private let labelColor = NSColor.labelColor // dynamic: resolved at draw time against the menu bar's appearance

    /// Text drawn by the labeled layouts: the detected system-drive medium
    /// type ("SSD" / "HDD"), set once at launch by the app delegate (see
    /// SystemDriveTypeDetector). Defaults to "SSD" until detection runs.
    private(set) var labelText = "SSD"

    func setDriveLabel(_ newLabel: String) {
        guard newLabel != labelText else { return }
        labelText = newLabel
        cache.removeAll() // every cached icon was drawn with the old text
    }

    // One image per (layout, state, brightness) triple, all tiny. Brightness is
    // clamped to 10–100 by the callers.
    private var cache: [LEDLayout: [LEDState: [Int: NSImage]]] = [:]

    func icon(for state: LEDState, brightnessPercent: Int, layout: LEDLayout) -> NSImage {
        let percent = min(max(brightnessPercent, 10), 100)
        if let cached = cache[layout]?[state]?[percent] { return cached }
        let size = layout.iconSize(label: labelText)
        let image = NSImage(size: size, flipped: false) { [self] rect in
            draw(layout: layout, state: state, percent: percent, label: labelText, in: rect)
            return true
        }
        image.isTemplate = false // preserves the LED colors; macOS must not re-tint it
        cache[layout, default: [:]][state, default: [:]][percent] = image
        return image
    }

    // MARK: - Per-layout drawing (origin bottom-left, not flipped)

    private func draw(layout: LEDLayout, state: LEDState, percent: Int, label: String, in rect: NSRect) {
        let readsActive = state == .readsOnly || state == .both
        let writesActive = state == .writesOnly || state == .both
        let readLit = readLitFull.withAlphaComponent(Double(percent) / 100)
        let writeLit = writeLitFull.withAlphaComponent(Double(percent) / 100)

        switch layout {
        case .bars:
            let half = (rect.width - gap) / 2
            (readsActive ? readLit : readOff).setFill()
            NSRect(x: rect.minX, y: rect.minY, width: half, height: rect.height).fill()
            (writesActive ? writeLit : writeOff).setFill()
            NSRect(x: rect.minX + half + gap, y: rect.minY, width: half, height: rect.height).fill()

        case .dots:
            let d = (rect.width - gap) / 2
            let y = (rect.height - d) / 2
            (readsActive ? readLit : readOff).setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.minX, y: y, width: d, height: d)).fill()
            (writesActive ? writeLit : writeOff).setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.minX + d + gap, y: y, width: d, height: d)).fill()

        case .dotsLabeled:
            // Drive label ("SSD"/"HDD") stacked above the dot pair: text tight
            // to the top of the bar height, dots the same size as the
            // standalone dots layout (7.5 pt) at the very bottom — no wasted
            // margin, no shrunken LEDs.
            let font = LEDLayout.labelFont
            let text = label as NSString
            let attrs = textAttributes(font)
            let textSize = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(x: rect.midX - textSize.width / 2,
                                  y: rect.maxY - textSize.height),
                      withAttributes: attrs)
            let d: CGFloat = (16 - gap) / 2
            let total = d * 2 + gap
            let x = rect.midX - total / 2
            (readsActive ? readLit : readOff).setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: 0, width: d, height: d)).fill()
            (writesActive ? writeLit : writeOff).setFill()
            NSBezierPath(ovalIn: NSRect(x: x + d + gap, y: 0, width: d, height: d)).fill()

        case .letters:
            // The letters are the LEDs: "R" is the reads channel, "W" the writes one.
            let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            let r = "R" as NSString
            let w = "W" as NSString
            let attrs = textAttributes(font)
            let rWidth = r.size(withAttributes: attrs).width
            let total = rWidth + w.size(withAttributes: attrs).width
            let x = rect.midX - total / 2
            let y = rect.midY - r.size(withAttributes: attrs).height / 2
            r.draw(at: NSPoint(x: x, y: y),
                   withAttributes: [.font: font,
                                    .foregroundColor: readsActive ? readLit : readOff])
            w.draw(at: NSPoint(x: x + rWidth, y: y),
                   withAttributes: [.font: font,
                                    .foregroundColor: writesActive ? writeLit : writeOff])

        case .monogram:
            // Drive label ("SSD"/"HDD") in white (always lit) with an activity
            // line above and below: top line green on reads, bottom line red
            // on writes, both near-dark when idle. Lines span the text width
            // (over/underline style); the red line sits at the very bottom of
            // the bar height.
            let font = LEDLayout.labelFont
            let text = label as NSString
            let attrs = textAttributes(font)
            let textSize = text.size(withAttributes: attrs)
            let lineWidth: CGFloat = ceil(textSize.width)
            let thickness: CGFloat = 1.5
            let x = rect.midX - lineWidth / 2
            (readsActive ? readLit : readOff).setFill()
            NSRect(x: x, y: rect.maxY - thickness, width: lineWidth, height: thickness).fill()
            text.draw(at: NSPoint(x: rect.midX - textSize.width / 2,
                                  y: rect.midY - textSize.height / 2),
                      withAttributes: attrs)
            (writesActive ? writeLit : writeOff).setFill()
            NSRect(x: x, y: rect.minY, width: lineWidth, height: thickness).fill()

        case .barsLabeled:
            // Drive label ("SSD"/"HDD") left, the two rectangles right
            // (compressed to fit).
            let font = LEDLayout.labelFont
            let text = label as NSString
            let attrs = textAttributes(font)
            let textSize = text.size(withAttributes: attrs)
            let square: CGFloat = 14
            let labelGap: CGFloat = 3
            let total = textSize.width + labelGap + square
            let x = rect.midX - total / 2
            text.draw(at: NSPoint(x: x, y: rect.midY - textSize.height / 2),
                      withAttributes: attrs)
            let sx = x + textSize.width + labelGap
            let sy = rect.midY - square / 2
            let half = (square - gap) / 2
            (readsActive ? readLit : readOff).setFill()
            NSRect(x: sx, y: sy, width: half, height: square).fill()
            (writesActive ? writeLit : writeOff).setFill()
            NSRect(x: sx + half + gap, y: sy, width: half, height: square).fill()
        }
    }

    private func textAttributes(_ font: NSFont) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: labelColor]
    }
}
