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
/// - `dotsLabeled`: a white "SSD" above the two dots, stacked tight against
///   the menu-bar height (text at the top plane, dots at the bottom, like
///   iStat's two-line elements).
/// - `letters`: "RW" where the letters themselves are the LEDs.
/// - `monogram`: "SSD" in white with an activity line above and below —
///   top line green (reads), bottom line red (writes).
/// - `barsLabeled`: white "SSD" label to the left of the bars.
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
        case .dotsLabeled: return "Dots with \"SSD\" stacked"
        case .letters:     return "\"R/W\" letters as LEDs"
        case .monogram:    return "\"SSD\" with blinking lines"
        case .barsLabeled: return "Bars with \"SSD\" label"
        }
    }

    /// Label font and text used by the labeled layouts ("SSD", iStat-style
    /// two-line density: ~9 pt semibold, tight against the bar height).
    static let labelFont = NSFont.systemFont(ofSize: 9, weight: .semibold)
    static let labelText = "SSD"

    static func labelWidth(_ font: NSFont) -> CGFloat {
        ceil((labelText as NSString).size(withAttributes: [.font: font]).width)
    }

    /// Status-item image size per layout. Labeled layouts are sized from the
    /// measured label text; the status item runs at variable length so each
    /// layout gets its fit. Stacked layouts use the full bar height (17 pt)
    /// so no vertical space is wasted.
    var iconSize: NSSize {
        switch self {
        case .bars, .dots, .letters:
            return NSSize(width: 16, height: 16)
        case .dotsLabeled:
            return NSSize(width: Self.labelWidth(Self.labelFont) + 1, height: 17)
        case .monogram:
            return NSSize(width: Self.labelWidth(Self.labelFont) + 2, height: 17)
        case .barsLabeled:
            return NSSize(width: Self.labelWidth(Self.labelFont) + 3 + 14, height: 16)
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
    // Off state: same shapes, near-dark so the indicator is still locatable. Not affected
    // by the brightness setting — its role is "the light is off", not "light at zero".
    private let readOff  = NSColor(srgbRed: 0.04, green: 0.16, blue: 0.07, alpha: 1)
    private let writeOff = NSColor(srgbRed: 0.18, green: 0.04, blue: 0.04, alpha: 1)
    // White "SSD" labels stay lit at all times so a labeled layout remains
    // findable while the LEDs are off — same role as any other menu-bar text.
    private let labelColor = NSColor.white

    // One image per (layout, state, brightness) triple, all tiny. Brightness is
    // clamped to 10–100 by the callers.
    private var cache: [LEDLayout: [LEDState: [Int: NSImage]]] = [:]

    func icon(for state: LEDState, brightnessPercent: Int, layout: LEDLayout) -> NSImage {
        let percent = min(max(brightnessPercent, 10), 100)
        if let cached = cache[layout]?[state]?[percent] { return cached }
        let size = layout.iconSize
        let image = NSImage(size: size, flipped: false) { [self] rect in
            draw(layout: layout, state: state, percent: percent, in: rect)
            return true
        }
        image.isTemplate = false // preserves the LED colors; macOS must not re-tint it
        cache[layout, default: [:]][state, default: [:]][percent] = image
        return image
    }

    // MARK: - Per-layout drawing (origin bottom-left, not flipped)

    private func draw(layout: LEDLayout, state: LEDState, percent: Int, in rect: NSRect) {
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
            // White "SSD" stacked above the dot pair: text tight to the top of
            // the bar height, dots at the very bottom — no wasted margin.
            let font = LEDLayout.labelFont
            let text = LEDLayout.labelText as NSString
            let attrs = textAttributes(font)
            let textSize = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(x: rect.midX - textSize.width / 2,
                                  y: rect.maxY - textSize.height),
                      withAttributes: attrs)
            let d: CGFloat = 5
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
            // "SSD" in white (always lit) with an activity line above and below:
            // top line green on reads, bottom line red on writes, both near-dark
            // when idle. Lines span the text width, like over/underlines.
            let font = LEDLayout.labelFont
            let text = LEDLayout.labelText as NSString
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
            // White "SSD" left, the two rectangles right (compressed to fit).
            let font = LEDLayout.labelFont
            let text = LEDLayout.labelText as NSString
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
