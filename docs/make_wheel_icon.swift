import AppKit

let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

let bg = NSColor(calibratedRed: 18/255, green: 24/255, blue: 31/255, alpha: 1.0)
let centerDark = NSColor(calibratedRed: 10/255, green: 13/255, blue: 17/255, alpha: 1.0)
let gold = NSColor(calibratedRed: 200/255, green: 155/255, blue: 60/255, alpha: 1.0)
let cream = NSColor(calibratedRed: 237/255, green: 230/255, blue: 214/255, alpha: 1.0)

let full = NSRect(x: 0, y: 0, width: size, height: size)
bg.setFill()
full.fill()

// subtle radial gold glow behind the wheel
if let glow = NSGradient(colors: [gold.withAlphaComponent(0.22), bg.withAlphaComponent(0.0)]) {
    glow.draw(fromCenter: NSPoint(x: size/2, y: size/2), radius: 0,
              toCenter: NSPoint(x: size/2, y: size/2), radius: CGFloat(size) * 0.42,
              options: [])
}

let center = NSPoint(x: size/2, y: size/2)
let ringRadius: CGFloat = CGFloat(size) * 0.332
let spokeInner: CGFloat = CGFloat(size) * 0.225
let strokeW: CGFloat = CGFloat(size) * 0.0215
let nubRadius: CGFloat = CGFloat(size) * 0.026
let innerCircleRadius: CGFloat = CGFloat(size) * 0.235

// outer ring
let ring = NSBezierPath(ovalIn: NSRect(x: center.x - ringRadius, y: center.y - ringRadius,
                                       width: ringRadius * 2, height: ringRadius * 2))
ring.lineWidth = strokeW
gold.setStroke()
ring.stroke()

// spokes + nubs
for i in 0..<8 {
    let angle = CGFloat(i) * (.pi / 4)
    let dx = cos(angle), dy = sin(angle)
    let p1 = NSPoint(x: center.x + dx * spokeInner, y: center.y + dy * spokeInner)
    let p2 = NSPoint(x: center.x + dx * ringRadius, y: center.y + dy * ringRadius)

    let spoke = NSBezierPath()
    spoke.lineWidth = strokeW
    spoke.lineCapStyle = .round
    spoke.move(to: p1)
    spoke.line(to: p2)
    gold.setStroke()
    spoke.stroke()

    let nub = NSBezierPath(ovalIn: NSRect(x: p2.x - nubRadius, y: p2.y - nubRadius,
                                          width: nubRadius * 2, height: nubRadius * 2))
    gold.setFill()
    nub.fill()
}

// center circle (covers spoke inner ends cleanly)
let innerCircle = NSBezierPath(ovalIn: NSRect(x: center.x - innerCircleRadius, y: center.y - innerCircleRadius,
                                              width: innerCircleRadius * 2, height: innerCircleRadius * 2))
centerDark.setFill()
innerCircle.fill()

// glyph: bolt, tinted cream, centered in the inner circle
if let symbol = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: innerCircleRadius * 1.15, weight: .semibold)
    let configured = symbol.withSymbolConfiguration(config) ?? symbol
    let glyphSize = configured.size
    let origin = NSPoint(x: center.x - glyphSize.width / 2, y: center.y - glyphSize.height / 2)

    let tinted = NSImage(size: glyphSize)
    tinted.lockFocus()
    configured.draw(in: NSRect(origin: .zero, size: glyphSize))
    cream.set()
    NSRect(origin: .zero, size: glyphSize).fill(using: .sourceAtop)
    tinted.unlockFocus()

    tinted.draw(in: NSRect(origin: origin, size: glyphSize))
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode failed")
}
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "wheel_icon.png"
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath) at \(rep.pixelsWide)x\(rep.pixelsHigh)")
