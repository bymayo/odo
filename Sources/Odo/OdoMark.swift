import AppKit

/// Odo's mark: a running track, with a lap's worth of progress drawn round it
/// from the start line at the bottom. One shape for the menu bar, the popover
/// and the app icon (Scripts/AppIcon renders that one from this file).
enum OdoMark {
    /// How far round the lap the bold segment runs
    static let progress: CGFloat = 0.68
    /// Track width / height
    static let aspect: CGFloat = 1.55

    /// The track's centre line, fitted inside `bounds` with room for the stroke.
    /// Y-up coordinates; starts at the bottom centre and runs right first.
    static func trackPath(in bounds: CGRect, lineWidth: CGFloat) -> CGPath {
        let inner = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        var w = inner.width, h = inner.width / aspect
        if h > inner.height { h = inner.height; w = h * aspect }
        let rect = CGRect(x: inner.midX - w / 2, y: inner.midY - h / 2, width: w, height: h)
        let r = h / 2

        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.midY), radius: r,
                    startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.midY), radius: r,
                    startAngle: .pi / 2, endAngle: 3 * .pi / 2, clockwise: false)
        path.closeSubpath()
        return path
    }

    /// Length of the centre line, for dashing the progress segment
    static func perimeter(in bounds: CGRect, lineWidth: CGFloat) -> CGFloat {
        let box = trackPath(in: bounds, lineWidth: lineWidth).boundingBoxOfPath
        let r = box.height / 2
        return 2 * (box.width - 2 * r) + 2 * .pi * r
    }

    /// Draws the mark into a Core Graphics context (y-up)
    static func draw(in ctx: CGContext, bounds: CGRect, lineWidth: CGFloat,
                     track: CGColor, lap: CGColor, startLine: CGColor? = nil) {
        let path = trackPath(in: bounds, lineWidth: lineWidth)
        let length = perimeter(in: bounds, lineWidth: lineWidth)

        ctx.saveGState()
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        ctx.addPath(path)
        ctx.setStrokeColor(track)
        ctx.strokePath()

        ctx.addPath(path)
        ctx.setStrokeColor(lap)
        ctx.setLineDash(phase: 0, lengths: [length * progress, length])
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        if let startLine {
            let box = path.boundingBoxOfPath
            ctx.setStrokeColor(startLine)
            ctx.setLineWidth(lineWidth * 0.32)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: box.midX - lineWidth * 0.9, y: box.minY - lineWidth * 0.85))
            ctx.addLine(to: CGPoint(x: box.midX - lineWidth * 0.9, y: box.minY + lineWidth * 0.85))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    /// Menu bar image: a template, so macOS tints it for light, dark and
    /// highlighted menu bars. The track is faint and the lap solid.
    static func menuBarImage(height: CGFloat = 13) -> NSImage {
        let size = NSSize(width: (height * aspect).rounded(.up) + 1, height: height)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(in: ctx, bounds: rect, lineWidth: height * 0.16,
                 track: NSColor.black.withAlphaComponent(0.3).cgColor,
                 lap: NSColor.black.cgColor)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Odo"
        return image
    }
}
