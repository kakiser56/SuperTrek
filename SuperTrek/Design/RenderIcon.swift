import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let phosphor = NSColor(red: 0.2, green: 1.0, blue: 0.3, alpha: 1)
let dim = phosphor.withAlphaComponent(0.22)
let amber = NSColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 1)
let alert = NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1)
let cyan = NSColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 1)

// Background with a faint green vignette, like a CRT that is switched on.
NSColor(red: 0.01, green: 0.03, blue: 0.015, alpha: 1).setFill()
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    NSColor(red: 0.05, green: 0.16, blue: 0.07, alpha: 1).cgColor,
    NSColor(red: 0.01, green: 0.03, blue: 0.015, alpha: 1).cgColor,
] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: size / 2, y: size / 2), startRadius: 0,
                       endCenter: CGPoint(x: size / 2, y: size / 2), endRadius: size * 0.75, options: [])

// The 8x8 sector grid.
let cells = 8
let inset: CGFloat = 112
let gridSize = size - inset * 2
let cell = gridSize / CGFloat(cells)
ctx.setStrokeColor(dim.cgColor)
ctx.setLineWidth(3)
for i in 0...cells {
    let p = inset + CGFloat(i) * cell
    ctx.move(to: CGPoint(x: p, y: inset)); ctx.addLine(to: CGPoint(x: p, y: inset + gridSize))
    ctx.move(to: CGPoint(x: inset, y: p)); ctx.addLine(to: CGPoint(x: inset + gridSize, y: p))
}
ctx.strokePath()
ctx.setFillColor(dim.cgColor)
for r in 0..<cells {
    for c in 0..<cells {
        let x = inset + (CGFloat(c) + 0.5) * cell
        let y = inset + (CGFloat(r) + 0.5) * cell
        ctx.fillEllipse(in: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
    }
}

func draw(_ text: String, row: Int, col: Int, color: NSColor, scale: CGFloat = 1, glow: CGFloat = 18, weight: NSFont.Weight = .bold) {
    let font = NSFont.monospacedSystemFont(ofSize: cell * 0.62 * scale, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let str = NSAttributedString(string: text, attributes: attrs)
    let bounds = str.size()
    let x = inset + (CGFloat(col) - 0.5) * cell - bounds.width / 2
    let y = inset + (CGFloat(cells - row) + 0.5) * cell - bounds.height / 2
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: glow, color: color.withAlphaComponent(0.9).cgColor)
    str.draw(at: NSPoint(x: x, y: y))
    str.draw(at: NSPoint(x: x, y: y))
    ctx.restoreGState()
}

draw("*", row: 2, col: 2, color: amber, scale: 1.2)
draw("*", row: 7, col: 7, color: amber, scale: 1.2)
draw(">!<", row: 7, col: 2, color: cyan, scale: 1.05)
draw("+K+", row: 2, col: 7, color: alert, scale: 1.05)

// Torpedo track from the ship toward the enemy.
ctx.setStrokeColor(alert.withAlphaComponent(0.55).cgColor)
ctx.setLineWidth(7)
ctx.setLineDash(phase: 0, lengths: [5, 24])
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: inset + 5.2 * cell + 30, y: inset + 4.2 * cell + 30))
ctx.addLine(to: CGPoint(x: inset + 6.5 * cell - 70, y: inset + 6.5 * cell - 70))
ctx.strokePath()
ctx.setLineDash(phase: 0, lengths: [])

// The ship, large and glowing, centered on the grid.
draw("<*>", row: 5, col: 5, color: phosphor, scale: 4.3, glow: 60, weight: .heavy)

// CRT scanlines.
ctx.setFillColor(NSColor.black.withAlphaComponent(0.10).cgColor)
var y: CGFloat = 0
while y < size {
    ctx.fill(CGRect(x: 0, y: y, width: size, height: 4))
    y += 12
}

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote", CommandLine.arguments[1], rep.pixelsWide, "x", rep.pixelsHigh)
