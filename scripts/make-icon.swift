// Renders the DiskLED-plus app icon and writes a 1024×1024 PNG.
//
// Usage: swift scripts/make-icon.swift <output-png>
// Design: dark rounded plate, two vertical LED bars — left green (reads),
// right red (writes), both lit. Colors match LEDIconRenderer's lit colors
// (readLit sRGB(0.05,1.00,0.25), writeLit sRGB(1.00,0.15,0.15)).
// Generated at package time; no binary assets live in the repo.

import AppKit
import CoreGraphics
import UniformTypeIdentifiers

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "app-icon.png"

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                    bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!

let W = CGFloat(size)
let faceRect = CGRect(x: 104, y: 104, width: 816, height: 816)
let facePath = CGPath(roundedRect: faceRect, cornerWidth: 184, cornerHeight: 184, transform: nil)

// Face plate with a soft drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 44,
              color: CGColor(colorSpace: space, components: [0, 0, 0, 0.35])!)
ctx.setFillColor(CGColor(colorSpace: space, components: [0.070, 0.067, 0.063, 1.0])!)
ctx.addPath(facePath)
ctx.fillPath()
ctx.restoreGState()

// Subtle sheen on the top of the plate
ctx.saveGState()
ctx.addPath(facePath)
ctx.clip()
let sheenColors = [CGColor(colorSpace: space, components: [1, 1, 1, 0.10])!,
                   CGColor(colorSpace: space, components: [1, 1, 1, 0.0])!] as CFArray
let sheen = CGGradient(colorsSpace: space, colors: sheenColors, locations: [0, 0.5])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: W), end: CGPoint(x: 0, y: 0), options: [.drawsAfterEndLocation])
ctx.restoreGState()

// LED bars, both lit: left green (reads), right red (writes)
func drawBar(rect: CGRect, base: [CGFloat], core: [CGFloat]) {
    ctx.saveGState()
    let outer = CGPath(roundedRect: rect, cornerWidth: 48, cornerHeight: 48, transform: nil)
    let glow = CGColor(colorSpace: space, components: [base[0], base[1], base[2], 0.45])!
    ctx.setShadow(offset: .zero, blur: 26, color: glow)
    ctx.setFillColor(CGColor(colorSpace: space, components: base)!)
    ctx.addPath(outer)
    ctx.fillPath()
    ctx.restoreGState()

    let coreRect = rect.insetBy(dx: 10, dy: 10)
    ctx.saveGState()
    let corePath = CGPath(roundedRect: coreRect, cornerWidth: 42, cornerHeight: 42, transform: nil)
    ctx.setFillColor(CGColor(colorSpace: space, components: core)!)
    ctx.addPath(corePath)
    ctx.fillPath()
    ctx.restoreGState()
}

let barW: CGFloat = 300
let barH: CGFloat = 700
let seam: CGFloat = 34
let barY: CGFloat = (W - barH) / 2
let leftX = 104 + (816 - (barW * 2 + seam)) / 2
let rightX = leftX + barW + seam

// readLit green (base), a brighter core for the lens look; writeLit red likewise
drawBar(rect: CGRect(x: leftX, y: barY, width: barW, height: barH),
        base: [0.05, 1.00, 0.25, 1.0], core: [0.10, 1.00, 0.40, 1.0])
drawBar(rect: CGRect(x: rightX, y: barY, width: barW, height: barH),
        base: [1.00, 0.15, 0.15, 1.0], core: [1.00, 0.30, 0.30, 1.0])

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                           UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outPath)")
