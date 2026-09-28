import AppKit

let W = 1280
let H = 640
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
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
let graySub = NSColor(calibratedRed: 168/255, green: 175/255, blue: 184/255, alpha: 1.0)

bg.setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

// ---- wheel emblem, right side ----
let wheelCenter = NSPoint(x: 960, y: 328)
let ringRadius: CGFloat = 212
let spokeInner: CGFloat = 144
let strokeW: CGFloat = 14
let nubRadius: CGFloat = 17
let innerCircleRadius: CGFloat = 150

if let glow = NSGradient(colors: [gold.withAlphaComponent(0.22), bg.withAlphaComponent(0.0)]) {
    glow.draw(fromCenter: wheelCenter, radius: 0, toCenter: wheelCenter, radius: 270, options: [])
}

let ring = NSBezierPath(ovalIn: NSRect(x: wheelCenter.x - ringRadius, y: wheelCenter.y - ringRadius,
                                       width: ringRadius * 2, height: ringRadius * 2))
ring.lineWidth = strokeW
gold.setStroke()
ring.stroke()

for i in 0..<8 {
    let angle = CGFloat(i) * (.pi / 4)
    let dx = cos(angle), dy = sin(angle)
    let p1 = NSPoint(x: wheelCenter.x + dx * spokeInner, y: wheelCenter.y + dy * spokeInner)
    let p2 = NSPoint(x: wheelCenter.x + dx * ringRadius, y: wheelCenter.y + dy * ringRadius)

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

let innerCircle = NSBezierPath(ovalIn: NSRect(x: wheelCenter.x - innerCircleRadius, y: wheelCenter.y - innerCircleRadius,
                                              width: innerCircleRadius * 2, height: innerCircleRadius * 2))
centerDark.setFill()
innerCircle.fill()

if let symbol = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: innerCircleRadius * 1.15, weight: .semibold)
    let configured = symbol.withSymbolConfiguration(config) ?? symbol
    let glyphSize = configured.size
    let origin = NSPoint(x: wheelCenter.x - glyphSize.width / 2, y: wheelCenter.y - glyphSize.height / 2)

    let tinted = NSImage(size: glyphSize)
    tinted.lockFocus()
    configured.draw(in: NSRect(origin: .zero, size: glyphSize))
    cream.set()
    NSRect(origin: .zero, size: glyphSize).fill(using: .sourceAtop)
    tinted.unlockFocus()

    tinted.draw(in: NSRect(origin: origin, size: glyphSize))
}

// ---- text, left side ----
func draw(_ text: String, x: CGFloat, y: CGFloat, font: NSFont, color: NSColor, tracking: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .kern: tracking
    ]
    NSAttributedString(string: text, attributes: attrs).draw(at: NSPoint(x: x, y: y))
}

let eyebrowFont = NSFont.monospacedSystemFont(ofSize: 20, weight: .bold)
draw("AFTER THE CLOUD SHUT DOWN", x: 110, y: 390, font: eyebrowFont, color: gold, tracking: 2.5)

let titleFont = NSFont.monospacedSystemFont(ofSize: 68, weight: .bold)
draw("Control it", x: 108, y: 300, font: titleFont, color: cream)
draw("yourself.", x: 108, y: 222, font: titleFont, color: cream)

// divider line
gold.withAlphaComponent(0.6).setFill()
NSRect(x: 112, y: 196, width: 200, height: 3).fill()

let subFont = NSFont.systemFont(ofSize: 22, weight: .regular)
draw("Local UPnP control for Wemo smart switches", x: 112, y: 148, font: subFont, color: graySub)
draw("macOS + iOS — no cloud account needed", x: 112, y: 116, font: subFont, color: graySub)

let urlFont = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
draw("github.com/pxwang/wemo-sos", x: 112, y: 76, font: urlFont, color: graySub.withAlphaComponent(0.85))

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encode failed")
}
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "social-preview.png"
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath) at \(rep.pixelsWide)x\(rep.pixelsHigh)")
