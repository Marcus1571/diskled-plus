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

/// Status-bar graphic layouts. All keep the same rule: left = reads (green),
/// right = writes (red), lit or dark per tick, never smoothed.
///
/// - `bars`: the original — one 16×16 pt square split into two vertical
///   rectangles separated by a 1 pt seam (DiskLED's look, carried over).
/// - `dots`: two circles side by side (iStat-Menus style), lower profile and
///   friendlier to a crowded menu bar.
enum LEDLayout: String, CaseIterable {
    case bars
    case dots

    var label: String {
        switch self {
        case .bars: return "Bars (two rectangles)"
        case .dots: return "Dots (two circles)"
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

    private let side: CGFloat = 16          // point size of the icon
    private let gap: CGFloat = 1            // seam between the two channels

    // Lit colors at full strength; the brightness percentage controls them via alpha,
    // so 60% looks like the same hue dimmed against the menu bar, never color-shifted.
    private let readLitFull  = NSColor(srgbRed: 0.05, green: 1.00, blue: 0.25, alpha: 1)
    private let writeLitFull = NSColor(srgbRed: 1.00, green: 0.15, blue: 0.15, alpha: 1)
    // Off state: same shapes, near-dark so the indicator is still locatable. Not affected
    // by the brightness setting — its role is "the light is off", not "light at zero".
    private let readOff  = NSColor(srgbRed: 0.04, green: 0.16, blue: 0.07, alpha: 1)
    private let writeOff = NSColor(srgbRed: 0.18, green: 0.04, blue: 0.04, alpha: 1)

    // One image per (layout, state, brightness) triple; worst case 2 layouts x
    // 4 states x 10 brightness steps, all tiny. Brightness is clamped to 10–100.
    private var cache: [LEDLayout: [LEDState: [Int: NSImage]]] = [:]

    func icon(for state: LEDState, brightnessPercent: Int, layout: LEDLayout) -> NSImage {
        let percent = min(max(brightnessPercent, 10), 100)
        if let cached = cache[layout]?[state]?[percent] { return cached }
        let readsActive = state == .readsOnly || state == .both
        let writesActive = state == .writesOnly || state == .both
        let readColor = readsActive ? readLitFull.withAlphaComponent(Double(percent) / 100) : readOff
        let writeColor = writesActive ? writeLitFull.withAlphaComponent(Double(percent) / 100) : writeOff

        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { [self] rect in
            switch layout {
            case .bars:
                let half = (rect.width - gap) / 2
                readColor.setFill()
                NSRect(x: rect.minX, y: rect.minY, width: half, height: rect.height).fill()
                writeColor.setFill()
                NSRect(x: rect.minX + half + gap, y: rect.minY, width: half, height: rect.height).fill()
            case .dots:
                let diameter = (rect.width - gap) / 2
                let y = (rect.height - diameter) / 2
                readColor.setFill()
                NSBezierPath(ovalIn: NSRect(x: rect.minX, y: y, width: diameter, height: diameter)).fill()
                writeColor.setFill()
                NSBezierPath(ovalIn: NSRect(x: rect.minX + diameter + gap, y: y, width: diameter, height: diameter)).fill()
            }
            return true
        }
        image.isTemplate = false // preserves the LED colors; macOS must not re-tint it
        cache[layout, default: [:]][state, default: [:]][percent] = image
        return image
    }
}
