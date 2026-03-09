import Cocoa

/// Programmatically generates a green "M" app icon using Core Graphics.
struct MGreenAppIcon {
    static let size = CGSize(width: 1024, height: 1024)

    /// Generate the green "M" icon as an NSImage.
    static func makeImage() -> NSImage? {
        let size = Self.size
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let rect = CGRect(origin: .zero, size: size)
        let iconRect = rect.insetBy(dx: 100, dy: 100)

        // -- Rounded rectangle background (macOS icon shape) --
        let cornerRadius: CGFloat = 224 // ~22% of 1024, matches macOS icon spec
        let bgPath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(bgPath)
        context.clip()

        // -- Green gradient background --
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let darkGreen = CGColor(red: 0x1B / 255.0, green: 0x5E / 255.0, blue: 0x20 / 255.0, alpha: 1.0) // #1B5E20
        let brightGreen = CGColor(red: 0x4C / 255.0, green: 0xAF / 255.0, blue: 0x50 / 255.0, alpha: 1.0) // #4CAF50
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [darkGreen, brightGreen] as CFArray, locations: [0.0, 1.0]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width / 2, y: 0),
                end: CGPoint(x: size.width / 2, y: size.height),
                options: []
            )
        }

        // -- Subtle inner glow / shine overlay --
        drawShineOverlay(in: context, rect: iconRect)

        // -- Letter "M" with shadow --
        drawLetterM(in: context, rect: iconRect)

        guard let cgImage = context.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: size)
    }

    /// Draw a subtle radial shine in the upper portion for polish.
    private static func drawShineOverlay(in context: CGContext, rect: CGRect) {
        context.saveGState()
        defer { context.restoreGState() }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let shineCenter = CGPoint(x: rect.midX, y: rect.maxY * 0.72)
        let shineRadius = rect.width * 0.6
        let clear = CGColor(red: 1, green: 1, blue: 1, alpha: 0)
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 0.12)

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [white, clear] as CFArray, locations: [0.0, 1.0]) {
            context.setBlendMode(.screen)
            context.drawRadialGradient(
                gradient,
                startCenter: shineCenter, startRadius: 0,
                endCenter: shineCenter, endRadius: shineRadius,
                options: []
            )
        }
    }

    /// Draw the bold white "M" with a drop shadow.
    private static func drawLetterM(in context: CGContext, rect: CGRect) {
        context.saveGState()
        defer { context.restoreGState() }

        // Shadow for depth
        let shadowColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: shadowColor)

        // Use Core Text to draw the letter
        let fontSize: CGFloat = 480
        let font = CTFontCreateWithName("SF Pro Display Heavy" as CFString, fontSize, nil)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let attrString = NSAttributedString(string: "M", attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)

        // Measure the text to center it
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

        let x = rect.midX - bounds.width / 2 - bounds.origin.x
        let y = rect.midY - bounds.height / 2 - bounds.origin.y

        // Flip coordinate system for Core Text
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }
}

