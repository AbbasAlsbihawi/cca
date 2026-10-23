import AppKit

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: make-icon <dir.iconset>\n".utf8))
    exit(2)
}
let dir = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    defer { NSGraphicsContext.restoreGraphicsState() }
    let s = CGFloat(px)
    let box = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    NSColor(srgbRed: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255, alpha: 1).setFill()
    NSBezierPath(roundedRect: box, xRadius: box.width * 0.225, yRadius: box.width * 0.225).fill()
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.36, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "person.2.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let white = NSImage(size: sym.size, flipped: false) { r in
            sym.draw(in: r)
            NSColor.white.setFill()
            r.fill(using: .sourceIn)
            return true
        }
        let w = white.size.width, h = white.size.height
        white.draw(in: NSRect(x: (s - w) / 2, y: (s - h) / 2, width: w, height: h))
    }
    return rep.representation(using: .png, properties: [:])
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)" + (scale == 2 ? "@2x" : "") + ".png"
        guard let png = render(base * scale) else { FileHandle.standardError.write(Data("render failed\n".utf8)); exit(1) }
        try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
    }
}
