import AppKit

// Renders a mockup sheet of candidate DiskLED-plus status-bar layouts.
// Output: PNG at 2x, one row per variant family, each variant shown inside a
// dark menu-bar segment. Run: swift scripts/make-mockups.swift <output.png>

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "screenshots/statusbar-mockups.png"

// MARK: - Shared colors (same hues as LEDIconRenderer)

let readLit  = NSColor(srgbRed: 0.05, green: 1.00, blue: 0.25, alpha: 1)
let writeLit = NSColor(srgbRed: 1.00, green: 0.15, blue: 0.15, alpha: 1)
let readOff  = NSColor(srgbRed: 0.04, green: 0.16, blue: 0.07, alpha: 1)
let writeOff = NSColor(srgbRed: 0.18, green: 0.04, blue: 0.04, alpha: 1)
let barBG    = NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)
let white    = NSColor.white

let barHeight: CGFloat = 24
let scale: CGFloat = 2
let cellWidth: CGFloat = 168
let captionHeight: CGFloat = 34
let margin: CGFloat = 14

// MARK: - Variant drawing (each draws inside the given bar rect, centered)

typealias Variant = (name: String, note: String, draw: (NSRect) -> Void)

func dot(_ rect: NSRect, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func dots(_ bar: NSRect, xOffset: CGFloat = 0) {
    let d: CGFloat = 7, gap: CGFloat = 2
    let total = d * 2 + gap
    let x = bar.midX - total / 2 + xOffset
    let y = bar.midY - d / 2
    dot(NSRect(x: x, y: y, width: d, height: d), color: readLit)
    dot(NSRect(x: x + d + gap, y: y, width: d, height: d), color: writeLit)
}

func label(_ text: String, in bar: NSRect, atX x: CGFloat, color: NSColor = white,
           font: NSFont = NSFont.systemFont(ofSize: 11.5)) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let size = (text as NSString).size(withAttributes: attrs)
    (text as NSString).draw(at: NSPoint(x: x, y: bar.midY - size.height / 2),
                            withAttributes: attrs)
}

func textWidth(_ text: String, font: NSFont = NSFont.systemFont(ofSize: 11.5)) -> CGFloat {
    (text as NSString).size(withAttributes: [.font: font]).width
}

// Two-dot cluster with a label on its left; the pair is centered as a unit.
func labeledDots(_ bar: NSRect, text: String) {
    let d: CGFloat = 7, gap: CGFloat = 2, labelGap: CGFloat = 4
    let dotsWidth = d * 2 + gap
    let total = textWidth(text) + labelGap + dotsWidth
    let x = bar.midX - total / 2
    label(text, in: bar, atX: x)
    let dx = x + textWidth(text) + labelGap
    let y = bar.midY - d / 2
    dot(NSRect(x: dx, y: y, width: d, height: d), color: readLit)
    dot(NSRect(x: dx + d + gap, y: y, width: d, height: d), color: writeLit)
}

// Letters as the LEDs themselves: first letter = reads channel, second = writes.
func letters(_ bar: NSRect, text: String, firstColor: NSColor, secondColor: NSColor,
             font: NSFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: white]
    let total = (text as NSString).size(withAttributes: attrs).width
    var x = bar.midX - total / 2
    for (i, ch) in text.enumerated() {
        let chStr = String(ch)
        let w = (chStr as NSString).size(withAttributes: attrs).width
        let color: NSColor = i == 0 ? firstColor : (i == 1 ? secondColor : white)
        let y = bar.midY - (chStr as NSString).size(withAttributes: attrs).height / 2
        (chStr as NSString).draw(at: NSPoint(x: x, y: y),
                                 withAttributes: [.font: font, .foregroundColor: color])
        x += w
    }
}

// White "SSD" stacked above the dot pair — the shipped .dotsLabeled layout.
func stackedDots(_ bar: NSRect) {
    let font = NSFont.systemFont(ofSize: 9, weight: .semibold)
    let text = "SSD"
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: white]
    let size = (text as NSString).size(withAttributes: attrs)
    let iconRect = NSRect(x: bar.midX - 10, y: bar.midY - 9.5, width: 20, height: 17)
    (text as NSString).draw(
        at: NSPoint(x: iconRect.midX - size.width / 2, y: iconRect.maxY - size.height),
        withAttributes: attrs)
    let d: CGFloat = 5, gap: CGFloat = 1
    let total = d * 2 + gap
    let x = iconRect.midX - total / 2
    dot(NSRect(x: x, y: iconRect.minY, width: d, height: d), color: readLit)
    dot(NSRect(x: x + d + gap, y: iconRect.minY, width: d, height: d), color: writeLit)
}

// "SSD" with an activity line above (reads) and below (writes) — the shipped
// .monogram layout.
func monogramLines(_ bar: NSRect) {
    let font = NSFont.systemFont(ofSize: 9, weight: .semibold)
    let text = "SSD"
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: white]
    let size = (text as NSString).size(withAttributes: attrs)
    let iconRect = NSRect(x: bar.midX - 10, y: bar.midY - 9.5, width: 20, height: 17)
    let lineWidth = ceil(size.width), thickness: CGFloat = 1.5
    let x = iconRect.midX - lineWidth / 2
    readLit.setFill()
    NSRect(x: x, y: iconRect.maxY - thickness, width: lineWidth, height: thickness).fill()
    (text as NSString).draw(
        at: NSPoint(x: iconRect.midX - size.width / 2, y: iconRect.midY - size.height / 2),
        withAttributes: attrs)
    writeLit.setFill()
    NSRect(x: x, y: iconRect.minY, width: lineWidth, height: thickness).fill()
}

// The current bars design plus a white label.
func labeledBars(_ bar: NSRect, text: String) {
    let sq: CGFloat = 16, seam: CGFloat = 1, labelGap: CGFloat = 4
    let total = textWidth(text) + labelGap + sq
    let x = bar.midX - total / 2
    label(text, in: bar, atX: x)
    let sx = x + textWidth(text) + labelGap
    let sy = bar.midY - sq / 2
    let half = (sq - seam) / 2
    readLit.setFill()
    NSRect(x: sx, y: sy, width: half, height: sq).fill()
    writeLit.setFill()
    NSRect(x: sx + half + seam, y: sy, width: half, height: sq).fill()
}

// Full "io" text where each letter is a channel (reads lights the i, writes the o).
func ioLetters(_ bar: NSRect) {
    letters(bar, text: "io", firstColor: readLit, secondColor: writeLit)
}

let variants: [Variant] = [
    ("Bars", "the original, default", { bar in labeledBars(bar, text: "") }),
    ("Dots", "iStat-style", { bar in dots(bar) }),
    ("Dots + \"SSD\" stacked", "label above the dots", { bar in stackedDots(bar) }),
    ("\"R/W\" letters", "the letters ARE the LEDs",
     { bar in letters(bar, text: "RW", firstColor: readLit, secondColor: writeLit) }),
    ("\"SSD\" blinking lines", "top line reads, bottom writes", { bar in monogramLines(bar) }),
    ("Bars + \"SSD\"", "label to the left", { bar in labeledBars(bar, text: "SSD") }),
]

// MARK: - Sheet layout: 3 columns x 2 rows

let cols = 3, rows = 2
let cellHeight = barHeight + captionHeight
let sheetW = margin * 2 + CGFloat(cols) * cellWidth
let sheetH = margin * 2 + CGFloat(rows) * cellHeight
let image = NSImage(size: NSSize(width: sheetW, height: sheetH), flipped: true) { _ in
    NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: sheetW, height: sheetH).fill()

    for (i, variant) in variants.enumerated() {
        let col = i % cols, row = i / cols
        let cellX = margin + CGFloat(col) * cellWidth
        let cellY = margin + CGFloat(row) * cellHeight
        let barRect = NSRect(x: cellX, y: cellY, width: cellWidth - 8, height: barHeight)
        barBG.setFill()
        NSBezierPath(roundedRect: barRect, xRadius: 5, yRadius: 5).fill()
        variant.draw(barRect)

        // caption
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: white]
        let nameSize = (variant.name as NSString).size(withAttributes: nameAttrs)
        (variant.name as NSString).draw(
            at: NSPoint(x: barRect.midX - nameSize.width / 2, y: cellY + barHeight + 5),
            withAttributes: nameAttrs)
        let noteAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.5), .foregroundColor: NSColor(white: 0.75, alpha: 1)]
        let noteSize = (variant.note as NSString).size(withAttributes: noteAttrs)
        (variant.note as NSString).draw(
            at: NSPoint(x: barRect.midX - noteSize.width / 2, y: cellY + barHeight + 19),
            withAttributes: noteAttrs)
    }
    return true
}

// MARK: - Write PNG at 2x

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else {
    fputs("mockups: could not rasterize\n", stderr)
    exit(1)
}
rep.size = NSSize(width: sheetW * scale, height: sheetH * scale)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("mockups: could not encode PNG\n", stderr)
    exit(1)
}
let url = URL(fileURLWithPath: outPath)
try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
try! png.write(to: url)
print("mockups written: \(url.path)")
