// Renders Packaging/AppIcon.icns, plus a 1024px AppIcon.png, from the mark in
// Sources/Odo/OdoMark.swift.
// Run with `make icon`; the .icns is committed, so builds don't need this.
//
//   swiftc Scripts/AppIcon/main.swift Sources/Odo/OdoMark.swift -o .build/appicon
//   .build/appicon <output.icns> [preview-dir]

import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// The full-size icon on Apple's macOS grid: an 824pt rounded square on a
/// 1024 canvas, leaving room for the shadow
func renderIcon(pixels: Int) -> CGImage {
    let s = CGFloat(pixels) / 1024
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: s, y: s)

    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(shape)
    ctx.setFillColor(color(0x0B0B0B))
    ctx.fillPath()
    ctx.restoreGState()

    // Tile: near-black, lighter at the top
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let fill = CGGradient(colorsSpace: nil, colors: [color(0x1C1C1C), color(0x0B0B0B)] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(fill, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // Hairline highlight round the edge
    ctx.addPath(shape)
    ctx.setStrokeColor(color(0xFFFFFF, 0.08))
    ctx.setLineWidth(4)
    ctx.strokePath()
    ctx.restoreGState()

    // The mark
    let markBounds = CGRect(x: 512 - 290, y: 512 - 290, width: 580, height: 580)
    OdoMark.draw(in: ctx, bounds: markBounds, lineWidth: 78,
                 track: color(0xFFFFFF, 0.14), lap: color(0xDCFF50),
                 startLine: color(0xFFFFFF, 0.9))

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: appicon <output.icns> [preview-dir]")
    exit(1)
}
let output = URL(fileURLWithPath: args[1])
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    writePNG(renderIcon(pixels: base), to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    writePNG(renderIcon(pixels: base * 2), to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { exit(iconutil.terminationStatus) }
print("Wrote \(output.path)")

// A full-size PNG beside it, for the README, website and anywhere else
let png = output.deletingPathExtension().appendingPathExtension("png")
writePNG(renderIcon(pixels: 1024), to: png)
print("Wrote \(png.path)")

// Previews: the icon, and the menu bar image on light and dark bars at 2x
if args.count >= 3 {
    let dir = URL(fileURLWithPath: args[2])
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    writePNG(renderIcon(pixels: 512), to: dir.appendingPathComponent("icon-512.png"))
    writePNG(renderIcon(pixels: 64), to: dir.appendingPathComponent("icon-32@2x.png"))

    for (name, bar, ink) in [("menubar-light", 0xE8E8E6, 0x000000), ("menubar-dark", 0x2B2B2B, 0xFFFFFF)] as [(String, UInt32, UInt32)] {
        let scale: CGFloat = 2, w = 140, h = 24
        let ctx = CGContext(data: nil, width: w * 2, height: h * 2, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: scale, y: scale)
        ctx.setFillColor(color(bar))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let height: CGFloat = 13
        let bounds = CGRect(x: 8, y: (CGFloat(h) - height) / 2,
                            width: (height * OdoMark.aspect).rounded(.up) + 1, height: height)
        OdoMark.draw(in: ctx, bounds: bounds, lineWidth: height * 0.16,
                     track: color(ink, 0.3), lap: color(ink))
        let text = NSAttributedString(string: "● 3,369.7 / 5,200.0 mi", attributes: [
            .font: NSFont.menuBarFont(ofSize: 0), .foregroundColor: NSColor(cgColor: color(ink))!])
        let line = CTLineCreateWithAttributedString(text)
        ctx.textPosition = CGPoint(x: bounds.maxX + 5, y: 7.5)
        CTLineDraw(line, ctx)
        writePNG(ctx.makeImage()!, to: dir.appendingPathComponent("\(name).png"))
    }
    print("Previews in \(dir.path)")
}
