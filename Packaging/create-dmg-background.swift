import AppKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 800
let height = 500
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create the DMG background bitmap.")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

let title = "Install Stash"
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
    .foregroundColor: NSColor(calibratedWhite: 0.13, alpha: 1)
]
let titleSize = title.size(withAttributes: titleAttributes)
title.draw(
    at: NSPoint(x: (CGFloat(width) - titleSize.width) / 2, y: 430),
    withAttributes: titleAttributes
)

let subtitle = "Drag Stash to Applications to install"
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 16),
    .foregroundColor: NSColor(calibratedWhite: 0.38, alpha: 1)
]
let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
subtitle.draw(
    at: NSPoint(x: (CGFloat(width) - subtitleSize.width) / 2, y: 395),
    withAttributes: subtitleAttributes
)

let arrow = NSBezierPath()
arrow.lineWidth = 7
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 300, y: 235))
arrow.line(to: NSPoint(x: 500, y: 235))
arrow.move(to: NSPoint(x: 478, y: 257))
arrow.line(to: NSPoint(x: 500, y: 235))
arrow.line(to: NSPoint(x: 478, y: 213))
NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.96, alpha: 0.9).setStroke()
arrow.stroke()

let footer = "After installing, open Stash from Applications."
let footerAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13),
    .foregroundColor: NSColor(calibratedWhite: 0.42, alpha: 1)
]
let footerSize = footer.size(withAttributes: footerAttributes)
footer.draw(
    at: NSPoint(x: (CGFloat(width) - footerSize.width) / 2, y: 34),
    withAttributes: footerAttributes
)

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode the DMG background as PNG.")
}
try png.write(to: outputURL)
