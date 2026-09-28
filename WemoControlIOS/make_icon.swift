import AppKit

let size: CGFloat = 1024
let canvas = NSImage(size: NSSize(width: size, height: size))
canvas.lockFocus()

let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.16, green: 0.52, blue: 0.98, alpha: 1.0),
    NSColor(calibratedRed: 0.04, green: 0.22, blue: 0.62, alpha: 1.0)
])
gradient?.draw(in: bgRect, angle: -90)

if let symbol = NSImage(systemSymbolName: "bolt.house.fill", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: size * 0.52, weight: .semibold)
    let configured = (symbol.withSymbolConfiguration(config) ?? symbol)
    let glyphSize = configured.size
    let origin = NSPoint(x: (size - glyphSize.width) / 2, y: (size - glyphSize.height) / 2 + size * 0.02)
    let glyphRect = NSRect(origin: origin, size: glyphSize)

    let tinted = NSImage(size: glyphSize)
    tinted.lockFocus()
    configured.draw(in: NSRect(origin: .zero, size: glyphSize))
    NSColor.white.set()
    NSRect(origin: .zero, size: glyphSize).fill(using: .sourceAtop)
    tinted.unlockFocus()

    tinted.draw(in: glyphRect)
}

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render icon")
}
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! pngData.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
