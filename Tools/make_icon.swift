import AppKit

// Renders the PhotoMapApp icon: a map-tile squircle with roads, water and a
// park, two scattered photo thumbnails, and a location pin holding a camera.

let canvas: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon_1024.png"

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
let gctx = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current = gctx
let ctx = gctx!.cgContext

// MARK: Squircle base with drop shadow

let squircleRect = NSRect(x: 100, y: 116, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: squircleRect, xRadius: 186, yRadius: 186)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: NSColor.black.withAlphaComponent(0.35).cgColor)
color(0xEDEAE2).setFill()
squircle.fill()
ctx.restoreGState()

// MARK: Map details, clipped to the squircle

ctx.saveGState()
squircle.addClip()

// Water — a river sweeping across the lower-left corner
let water = NSBezierPath()
water.move(to: NSPoint(x: 100, y: 620))
water.curve(to: NSPoint(x: 560, y: 116), controlPoint1: NSPoint(x: 330, y: 560), controlPoint2: NSPoint(x: 470, y: 330))
water.line(to: NSPoint(x: 100, y: 116))
water.close()
color(0x9CCDE8).setFill()
water.fill()

// Shoreline
let shore = NSBezierPath()
shore.move(to: NSPoint(x: 100, y: 620))
shore.curve(to: NSPoint(x: 560, y: 116), controlPoint1: NSPoint(x: 330, y: 560), controlPoint2: NSPoint(x: 470, y: 330))
shore.lineWidth = 10
color(0x7FB8DA).setStroke()
shore.stroke()

// Park — soft green patch upper right
let park = NSBezierPath(ovalIn: NSRect(x: 610, y: 640, width: 400, height: 320))
color(0xB9DFAE).setFill()
park.fill()

// Streets: casing then fill, on a slightly rotated grid
func street(from a: NSPoint, to b: NSPoint, width: CGFloat, casing: NSColor, fill: NSColor) {
    let path = NSBezierPath()
    path.move(to: a)
    path.line(to: b)
    path.lineCapStyle = .butt
    path.lineWidth = width + 10
    casing.setStroke()
    path.stroke()
    path.lineWidth = width
    fill.setStroke()
    path.stroke()
}

ctx.saveGState()
ctx.translateBy(x: 512, y: 512)
ctx.rotate(by: -6 * .pi / 180)
ctx.translateBy(x: -512, y: -512)

let roadCasing = color(0xD8D4C8)
let roadFill = NSColor.white
street(from: NSPoint(x: 0, y: 356), to: NSPoint(x: 1024, y: 356), width: 30, casing: roadCasing, fill: roadFill)
street(from: NSPoint(x: 0, y: 724), to: NSPoint(x: 1024, y: 724), width: 30, casing: roadCasing, fill: roadFill)
street(from: NSPoint(x: 316, y: 0), to: NSPoint(x: 316, y: 1024), width: 30, casing: roadCasing, fill: roadFill)
street(from: NSPoint(x: 724, y: 0), to: NSPoint(x: 724, y: 1024), width: 30, casing: roadCasing, fill: roadFill)
ctx.restoreGState()

// Highway — a diagonal avenue
street(
    from: NSPoint(x: 60, y: 780), to: NSPoint(x: 964, y: 260),
    width: 40, casing: color(0xDFB556), fill: color(0xF8D577)
)

// MARK: Photo thumbnails pinned to the map

func polaroid(center: NSPoint, size: CGFloat, rotation: CGFloat, top: NSColor, bottom: NSColor) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: rotation * .pi / 180)
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: NSColor.black.withAlphaComponent(0.30).cgColor)

    let frameRect = NSRect(x: -size / 2, y: -size / 2, width: size, height: size)
    let frame = NSBezierPath(roundedRect: frameRect, xRadius: 12, yRadius: 12)
    NSColor.white.setFill()
    frame.fill()

    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    let inset = size * 0.09
    let innerRect = frameRect.insetBy(dx: inset, dy: inset).offsetBy(dx: 0, dy: inset * 0.6)
    let inner = NSBezierPath(roundedRect: innerRect, xRadius: 6, yRadius: 6)
    NSGradient(starting: top, ending: bottom)!.draw(in: inner, angle: -90)
    ctx.restoreGState()
}

polaroid(center: NSPoint(x: 285, y: 745), size: 170, rotation: -10,
         top: color(0x8ECBEF), bottom: color(0x4E9ED8))
polaroid(center: NSPoint(x: 785, y: 355), size: 170, rotation: 9,
         top: color(0xFAC46B), bottom: color(0xEE7E52))

ctx.restoreGState() // squircle clip

// MARK: Location pin

let headCenter = NSPoint(x: 512, y: 596)
let headRadius: CGFloat = 238
let tip = NSPoint(x: 512, y: 200)

let pin = NSBezierPath()
pin.move(to: tip)
pin.curve(
    to: NSPoint(x: headCenter.x - headRadius, y: headCenter.y),
    controlPoint1: NSPoint(x: 512 - headRadius * 0.42, y: 300),
    controlPoint2: NSPoint(x: headCenter.x - headRadius, y: headCenter.y - headRadius * 0.72)
)
pin.appendArc(withCenter: headCenter, radius: headRadius, startAngle: 180, endAngle: 0, clockwise: true)
pin.curve(
    to: tip,
    controlPoint1: NSPoint(x: headCenter.x + headRadius, y: headCenter.y - headRadius * 0.72),
    controlPoint2: NSPoint(x: 512 + headRadius * 0.42, y: 300)
)
pin.close()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.38).cgColor)
color(0xDE3125).setFill()
pin.fill()
ctx.restoreGState()
NSGradient(starting: color(0xFF6B52), ending: color(0xDE3125))!.draw(in: pin, angle: -90)

// MARK: Camera badge inside the pin head

let badgeCenter = NSPoint(x: 512, y: 612)
let badgeRadius: CGFloat = 168
let badge = NSBezierPath(ovalIn: NSRect(
    x: badgeCenter.x - badgeRadius, y: badgeCenter.y - badgeRadius,
    width: badgeRadius * 2, height: badgeRadius * 2
))
NSColor.white.setFill()
badge.fill()

let symbolConfig = NSImage.SymbolConfiguration(pointSize: 200, weight: .medium)
guard let camera = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) else {
    fatalError("camera.fill symbol unavailable")
}
let cameraTint = color(0x333A44)
let tinted = NSImage(size: camera.size, flipped: false) { rect in
    camera.draw(in: rect)
    cameraTint.set()
    rect.fill(using: .sourceAtop)
    return true
}

let targetWidth: CGFloat = 218
let aspect = camera.size.height / camera.size.width
let targetRect = NSRect(
    x: badgeCenter.x - targetWidth / 2,
    y: badgeCenter.y - targetWidth * aspect / 2,
    width: targetWidth,
    height: targetWidth * aspect
)
tinted.draw(in: targetRect)

// MARK: Write PNG

gctx!.flushGraphics()
guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG encoding failed")
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
