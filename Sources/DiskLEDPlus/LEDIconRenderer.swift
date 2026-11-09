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

/// Draws the status-bar icon: a square split into two vertical rectangles.
///   left  — bright green, blinks on reads
///   right — red, blinks on writes
/// No interpolation: a side is either lit this tick or dark. Contiguous lit ticks
/// under sustained load read as "steadily ON" exactly like DiskLED.
final class LEDIconRenderer {
    static let shared = LEDIconRenderer()

    private let side: CGFloat = 16          // point size of the square
    private let gap: CGFloat = 1            // seam between the two rectangles

    // Lit colors.
    private let readLit  = NSColor(srgbRed: 0.05, green: 1.00, blue: 0.25, alpha: 1)
    private let writeLit = NSColor(srgbRed: 1.00, green: 0.15, blue: 0.15, alpha: 1)
    // Off state: same shapes, near-dark so the square is still locatable.
    private let readOff  = NSColor(srgbRed: 0.04, green: 0.16, blue: 0.07, alpha: 1)
    private let writeOff = NSColor(srgbRed: 0.18, green: 0.04, blue: 0.04, alpha: 1)

    private var cache: [LEDState: NSImage] = [:]

    func icon(for state: LEDState) -> NSImage {
        if let cached = cache[state] { return cached }
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { [self] rect in
            let half = (rect.width - gap) / 2
            let leftRect  = NSRect(x: rect.minX, y: rect.minY, width: half, height: rect.height)
            let rightRect = NSRect(x: rect.minX + half + gap, y: rect.minY, width: half, height: rect.height)

            let readsActive = state == .readsOnly || state == .both
            let writesActive = state == .writesOnly || state == .both

            (readsActive ? readLit : readOff).setFill()
            leftRect.fill()
            (writesActive ? writeLit : writeOff).setFill()
            rightRect.fill()
            return true
        }
        image.isTemplate = false // preserves the LED colors; macOS must not re-tint it
        cache[state] = image
        return image
    }
}
