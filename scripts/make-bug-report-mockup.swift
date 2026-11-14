import AppKit

// One-off design sheet for the "Report a Bug" addition (menu + About page).
// Output: screenshots/bug-report-mockups.png at 2x.
// Run: swift scripts/make-bug-report-mockup.swift

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "screenshots/bug-report-mockups.png"

let scale: CGFloat = 2
let margin: CGFloat = 20
let panelGap: CGFloat = 26
let captionHeight: CGFloat = 40

let menuWidth: CGFloat = 250
let aboutWidth: CGFloat = 300

// MARK: - Assets

let appIcon: NSImage? = {
    for p in ["docs/img/app-icon.png", ".build/icon/AppIcon-1024.png"] {
        if let img = NSImage(contentsOfFile: p) { return img }
    }
    return nil
}()
let qr = NSImage(contentsOfFile: "assets/paypal-qr.png")

func sfSymbol(_ name: String, size: CGFloat) -> NSImage? {
    NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: size, weight: .regular))
}

let ladybug = sfSymbol("ladybug.fill", size: 12)

// MARK: - Menu panel (light macOS dropdown look)

let menuFont = NSFont.menuBarFont(ofSize: 0)
let rowHeight: CGFloat = 22
let menuRows: [(text: String, icon: NSImage?, shortcut: String, dim: Bool, highlight: Bool)] = [
    ("DiskLED-plus", nil, "", true, false),
    ("SEP", nil, "", false, false),
    ("Reads    1.2 MB/s", nil, "", true, false),
    ("Writes   84 KB/s", nil, "", true, false),
    ("SEP", nil, "", false, false),
    ("Brightness", nil, "", false, false),
    ("Start at Login", nil, "", false, false),
    ("Check for Updates…", nil, "", false, false),
    ("SEP", nil, "", false, false),
    ("Settings…", nil, "⌘,", false, false),
    ("About DiskLED-plus", nil, "", false, false),
    ("REPORT_ROW_A", nil, "", false, true),   // emoji variant, highlighted
    ("REPORT_ROW_B", nil, "", false, false),  // SF-symbol variant
    ("Quit DiskLED-plus", nil, "⌘Q", false, false),
]

func drawMenu(into rect: NSRect) {
    let bg = NSColor.windowBackgroundColor
    bg.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()

    // Flipped context: y counts from the top edge downward.
    var y = rect.minY + 4
    for row in menuRows {
        if row.text == "SEP" {
            let sep = NSRect(x: rect.minX + 1, y: y + rowHeight / 2 - 0.5,
                             width: rect.width - 2, height: 1)
            NSColor.separatorColor.setFill()
            sep.fill()
            y += rowHeight
            continue
        }
        let rowRect = NSRect(x: rect.minX, y: y, width: rect.width, height: rowHeight)
        y += rowHeight

        if row.highlight {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: rowRect.insetBy(dx: 4, dy: 1), xRadius: 4, yRadius: 4).fill()
        }
        let textColor: NSColor = row.highlight
            ? .white
            : (row.dim ? .disabledControlTextColor : .labelColor)

        let text: String
        var icon: NSImage?
        if row.text == "REPORT_ROW_A" {
            text = "🪲 Report a Bug…"
        } else if row.text == "REPORT_ROW_B" {
            text = "Report a Bug…"
            icon = ladybug
        } else {
            text = row.text
        }

        var x = rowRect.minX + 16
        if let icon {
            let tinted = icon.tinted(with: textColor)
            let s = icon.size
            let iconRect = NSRect(x: x, y: rowRect.midY - s.height / 2, width: s.width, height: s.height)
            tinted.draw(in: iconRect)
            x += s.width + 4
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: menuFont, .foregroundColor: textColor]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(at: NSPoint(x: x, y: rowRect.midY - size.height / 2),
                                withAttributes: attrs)
        if !row.shortcut.isEmpty {
            let sw = (row.shortcut as NSString).size(withAttributes: attrs).width
            (row.shortcut as NSString).draw(
                at: NSPoint(x: rowRect.maxX - 14 - sw, y: rowRect.midY - size.height / 2),
                withAttributes: attrs)
        }
    }
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let result = NSImage(size: size, flipped: false) { _ in
            color.set()
            let rect = NSRect(origin: .zero, size: self.size)
            NSRect(origin: .zero, size: self.size).fill()
            self.draw(in: rect, from: rect, operation: .sourceAtop, fraction: 1)
            return true
        }
        return result
    }
}

// MARK: - About panel (current shipped page + the new bug row)

func drawAbout(into rect: NSRect) {
    let bg = NSColor.windowBackgroundColor
    bg.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()

    func label(_ text: String, _ size: CGFloat, _ weight: NSFont.Weight = .regular,
               _ color: NSColor = .labelColor, _ centerX: CGFloat, _ y: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
        ]
        let s = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(
            at: NSPoint(x: centerX - s.width / 2, y: y),
            withAttributes: attrs)
        return s.height
    }

    let cx = rect.midX
    var y = rect.minY + 20

    if let appIcon {
        let side: CGFloat = 78
        appIcon.draw(in: NSRect(x: cx - side / 2, y: y, width: side, height: side),
                     from: .zero, operation: .sourceOver, fraction: 1)
        y += side + 8
    }
    y += label("DiskLED-plus", 22, .bold, .labelColor, cx, y) + 8
    y += label("Version 0.9.0 (build 900)", 11, .regular, .secondaryLabelColor, cx, y) + 12

    // divider
    NSColor.separatorColor.setFill()
    NSRect(x: cx - 120, y: y - 1, width: 240, height: 1).fill()
    y += 14

    if let qr {
        let side: CGFloat = 76
        qr.draw(in: NSRect(x: cx - side / 2, y: y, width: side, height: side),
                from: .zero, operation: .sourceOver, fraction: 1)
        y += side + 6
    }
    y += label("Support DiskLED-plus", 13, .semibold, .labelColor, cx, y) + 5
    y += label("paypal.me/marcodalmoro", 11, .regular, .linkColor, cx, y) + 5
    y += label("Point your phone's camera at the code — or click the link.", 10,
               .regular, .secondaryLabelColor, cx, y) + 14

    NSColor.separatorColor.setFill()
    NSRect(x: cx - 120, y: y - 1, width: 240, height: 1).fill()
    y += 14

    y += label("© 2026 Marcus1571", 13, .regular, .labelColor, cx, y) + 6
    y += label("MIT", 11, .regular, .secondaryLabelColor, cx, y) + 6
    y += label("github.com/Marcus1571/diskled-plus", 13, .regular, .linkColor, cx, y) + 10

    // NEW: the bug-report line, styled like a compact sibling of the support block.
    y += label("🪲 Report a Bug", 13, .semibold, .labelColor, cx, y) + 5
    y += label("github.com/Marcus1571/diskled-plus/issues", 11, .regular, .linkColor, cx, y) + 10

    let tagline = "Disk activity, shown the way hardware used to do it: one LED per " +
        "channel, blinking for every single tick of I/O — 33 times per second, " +
        "nothing averaged, nothing rounded up, nothing smoothed away."
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 10.5),
        .foregroundColor: NSColor.secondaryLabelColor,
        .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .center; p.lineSpacing = 1; return p }(),
    ]
    let tagWidth: CGFloat = 252
    let tagSize = (tagline as NSString).boundingRect(
        with: NSSize(width: tagWidth, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin], attributes: attrs)
    (tagline as NSString).draw(
        with: NSRect(x: cx - tagWidth / 2, y: y, width: tagWidth, height: tagSize.height),
        options: [.usesLineFragmentOrigin], attributes: attrs)
}

// MARK: - Sheet assembly

let menuHeight: CGFloat = CGFloat(menuRows.count) * rowHeight + 8
let aboutHeight: CGFloat = 530
let panelTop: CGFloat = 60
let sheetW = margin * 2 + menuWidth + aboutWidth + panelGap
let sheetH = margin * 2 + panelTop + max(menuHeight, aboutHeight) + captionHeight

let image = NSImage(size: NSSize(width: sheetW, height: sheetH), flipped: true) { _ in
    NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: sheetW, height: sheetH).fill()

    let menuRect = NSRect(x: margin, y: margin + panelTop, width: menuWidth, height: menuHeight)
    drawMenu(into: menuRect)
    let aboutRect = NSRect(x: margin + menuWidth + panelGap, y: margin + panelTop,
                           width: aboutWidth, height: aboutHeight)
    drawAbout(into: aboutRect)

    func caption(_ text: String, _ sub: String, _ x: CGFloat, _ w: CGFloat) {
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.white]
        let s = (text as NSString).size(withAttributes: nameAttrs)
        (text as NSString).draw(at: NSPoint(x: x + w / 2 - s.width / 2, y: margin + 8),
                                withAttributes: nameAttrs)
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor(calibratedWhite: 0.75, alpha: 1)]
        let ss = (sub as NSString).size(withAttributes: subAttrs)
        (sub as NSString).draw(at: NSPoint(x: x + w / 2 - ss.width / 2, y: margin + 28),
                               withAttributes: subAttrs)
    }
    caption("Menu — two icon options", "🪲 emoji (highlighted) · SF Symbol ladybug", margin, menuWidth)
    caption("About page", "new section under the repo link", margin + menuWidth + panelGap, aboutWidth)
    return true
}

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else {
    fputs("mockup: could not rasterize\n", stderr)
    exit(1)
}
rep.size = NSSize(width: sheetW * scale, height: sheetH * scale)
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("mockup: could not encode PNG\n", stderr)
    exit(1)
}
let url = URL(fileURLWithPath: outPath)
try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
try! png.write(to: url)
print("mockup written: \(url.path)")
