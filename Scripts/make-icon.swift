import AppKit

let output = CommandLine.arguments[1]
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else { fatalError("No graphics context") }
context.setAllowsAntialiasing(true)
let bounds = CGRect(x: 0, y: 0, width: size, height: size)
let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 30, dy: 30), xRadius: 220, yRadius: 220)
let colors = [NSColor(calibratedRed: 0.10, green: 0.48, blue: 0.94, alpha: 1).cgColor,
              NSColor(calibratedRed: 0.20, green: 0.25, blue: 0.76, alpha: 1).cgColor] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
context.saveGState()
background.addClip()
context.drawLinearGradient(gradient, start: CGPoint(x: 70, y: 950), end: CGPoint(x: 950, y: 40), options: [])
context.restoreGState()

func rounded(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

// Three clean storage bays, with a status light on each one.
for y: CGFloat in [590, 420, 250] {
    rounded(CGRect(x: 180, y: y, width: 520, height: 118), radius: 34,
            color: NSColor(calibratedWhite: 1, alpha: 0.96))
    rounded(CGRect(x: 235, y: y + 42, width: 270, height: 18), radius: 9,
            color: NSColor(calibratedRed: 0.16, green: 0.27, blue: 0.53, alpha: 0.72))
    rounded(CGRect(x: 235, y: y + 17, width: 165, height: 12), radius: 6,
            color: NSColor(calibratedRed: 0.48, green: 0.55, blue: 0.71, alpha: 0.65))
    NSColor(calibratedRed: 0.20, green: 0.80, blue: 0.63, alpha: 1).setFill()
    NSBezierPath(ovalIn: CGRect(x: 625, y: y + 40, width: 34, height: 34)).fill()
}

// Magnifier marks the app as an inspector.
let lens = CGRect(x: 540, y: 120, width: 265, height: 265)
NSColor(calibratedRed: 0.08, green: 0.20, blue: 0.48, alpha: 0.28).setStroke()
let shadowRing = NSBezierPath(ovalIn: lens.insetBy(dx: 6, dy: 6))
shadowRing.lineWidth = 36
shadowRing.stroke()
NSColor.white.setStroke()
let ring = NSBezierPath(ovalIn: lens.insetBy(dx: 18, dy: 18))
ring.lineWidth = 36
ring.stroke()
let handle = NSBezierPath()
handle.move(to: CGPoint(x: 753, y: 165))
handle.line(to: CGPoint(x: 884, y: 34))
handle.lineCapStyle = .round
handle.lineWidth = 48
NSColor.white.setStroke()
handle.stroke()

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
