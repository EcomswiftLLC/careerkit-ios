import UIKit

// MARK: - Links

struct RenderLinkSpan {
    let range: NSRange
    let url: URL
}

/// Finds explicit web and mail links inside free text. Bare words such as "Node.js" are ignored.
final class RenderLinkDetector {
    private let detector: NSDataDetector?

    init() {
        detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }

    func spans(in text: String) -> [RenderLinkSpan] {
        guard let detector = detector, !text.isEmpty else { return [] }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var found: [RenderLinkSpan] = []
        detector.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
            guard let match = match, let url = match.url else { return }
            let piece = ns.substring(with: match.range).lowercased()
            let explicit = piece.contains("://") || piece.hasPrefix("www.") || piece.contains("@")
            guard explicit else { return }
            let scheme = (url.scheme ?? "").lowercased()
            guard scheme == "http" || scheme == "https" || scheme == "mailto" else { return }
            found.append(RenderLinkSpan(range: match.range, url: url))
        }
        return found
    }
}

/// Holds the PDF context for the page currently being drawn so text layouts can add link annotations.
final class RenderCanvas {
    var pdfContext: UIGraphicsPDFRendererContext?
    /// Set by tests to collect where the photo and the header text were drawn (page coordinates, page one).
    var geometry: RenderGeometry?

    func recordPhoto(_ rect: CGRect) {
        geometry?.photoRects.append(rect)
    }

    /// Records the glyph boxes of a header text layout drawn with its top left at `origin`.
    func recordHeaderText(_ layout: RenderTextLayout, at origin: CGPoint) {
        guard let geometry = geometry, let first = layout.lines.first else { return }
        let top: CGFloat = first.fragmentRect.minY
        for line in layout.lines where line.usedRect.width > 0.5 {
            let r = line.usedRect
            geometry.headerTextRects.append(CGRect(x: origin.x + r.minX, y: origin.y + r.minY - top,
                                                   width: r.width, height: r.height))
        }
    }

    func addLink(_ url: URL, rect: CGRect) {
        guard let context = pdfContext, rect.width > 0, rect.height > 0 else { return }
        // Link annotations are stored in PDF page space (origin at the bottom left), while all drawing here
        // uses UIKit space (origin at the top left), so the rectangle has to be flipped.
        let pageHeight = context.pdfContextBounds.height
        let flipped = CGRect(x: rect.minX, y: pageHeight - rect.maxY, width: rect.width, height: rect.height)
        context.setURL(url, for: flipped)
    }
}

// MARK: - Colour helpers

enum RenderColors {
    static func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (r, g, b, a)
        }
        var w: CGFloat = 0
        if color.getWhite(&w, alpha: &a) {
            return (w, w, w, a)
        }
        return (0, 0, 0, 1)
    }

    static func luminance(_ color: UIColor) -> CGFloat {
        let c = components(color)
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    /// Linear blend: t = 0 gives `a`, t = 1 gives `b`.
    static func mix(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        let ca = components(a)
        let cb = components(b)
        let k: CGFloat = min(max(t, 0), 1)
        return UIColor(
            red: ca.r + (cb.r - ca.r) * k,
            green: ca.g + (cb.g - ca.g) * k,
            blue: ca.b + (cb.b - ca.b) * k,
            alpha: ca.a + (cb.a - ca.a) * k
        )
    }

    /// White on dark fills, the given dark colour on light fills.
    static func readable(on fill: UIColor, dark: UIColor) -> UIColor {
        return luminance(fill) < 0.58 ? UIColor.white : dark
    }

    static func sameHex(_ a: String?, _ b: String?) -> Bool {
        guard let a = a, let b = b else { return false }
        let x = a.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        let y = b.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        return x == y
    }
}

// MARK: - Direction

enum RenderTextDirection {
    static func isRightToLeft(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if isRTLScalar(scalar.value) { return true }
            if scalar.properties.isAlphabetic { return false }
        }
        return false
    }

    static func containsRTL(_ text: String) -> Bool {
        for scalar in text.unicodeScalars where isRTLScalar(scalar.value) {
            return true
        }
        return false
    }

    private static func isRTLScalar(_ v: UInt32) -> Bool {
        switch v {
        case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF, 0x10800...0x10FFF, 0x1E800...0x1EFFF:
            return true
        default:
            return false
        }
    }
}

// MARK: - Attributed strings

struct RenderTextStyle {
    var font: UIFont
    var color: UIColor
    /// Line height as a multiple of the font size. 1.0 means the font's natural line height.
    var leading: CGFloat = 1.0
    var alignment: NSTextAlignment = .natural
    var kern: CGFloat = 0
}

enum RenderText {
    static func paragraphStyle(_ s: RenderTextStyle, rtl: Bool) -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.alignment = s.alignment
        ps.lineBreakMode = .byWordWrapping
        ps.baseWritingDirection = rtl ? NSWritingDirection.rightToLeft : NSWritingDirection.leftToRight
        let target: CGFloat = s.font.pointSize * s.leading * 1.12
        ps.lineSpacing = max(0, target - s.font.lineHeight)
        ps.hyphenationFactor = 0
        return ps
    }

    static func attributes(_ s: RenderTextStyle, rtl: Bool) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .font: s.font,
            .foregroundColor: s.color,
            .paragraphStyle: paragraphStyle(s, rtl: rtl),
            .ligature: 0
        ]
        if s.kern != 0 {
            attrs[.kern] = s.kern
        }
        return attrs
    }

    static func attributed(_ text: String, _ style: RenderTextStyle) -> NSAttributedString {
        let rtl = RenderTextDirection.isRightToLeft(text)
        return NSAttributedString(string: text, attributes: attributes(style, rtl: rtl))
    }

    /// Several runs in one paragraph. Paragraph metrics come from the first run.
    static func runs(_ parts: [(String, RenderTextStyle)]) -> NSAttributedString {
        guard let first = parts.first else { return NSAttributedString(string: "") }
        let combined: String = parts.map { $0.0 }.joined()
        let rtl = RenderTextDirection.isRightToLeft(combined)
        let shared = paragraphStyle(first.1, rtl: rtl)
        let out = NSMutableAttributedString()
        for (text, style) in parts where !text.isEmpty {
            var attrs = attributes(style, rtl: rtl)
            attrs[.paragraphStyle] = shared
            out.append(NSAttributedString(string: text, attributes: attrs))
        }
        return out
    }

    /// Drawn small caps: a full size capital at the start of each word, smaller capitals after it.
    static func smallCaps(_ text: String, _ style: RenderTextStyle) -> NSAttributedString {
        let rtl = RenderTextDirection.isRightToLeft(text)
        let shared = paragraphStyle(style, rtl: rtl)
        let smallFont: UIFont = style.font.withSize(style.font.pointSize * 0.8)
        var bigAttrs = attributes(style, rtl: rtl)
        bigAttrs[.paragraphStyle] = shared
        var smallAttrs = bigAttrs
        smallAttrs[.font] = smallFont

        let out = NSMutableAttributedString()
        var atWordStart = true
        for ch in text {
            let piece = String(ch)
            if ch.isWhitespace {
                out.append(NSAttributedString(string: piece, attributes: bigAttrs))
                atWordStart = true
            } else if atWordStart {
                out.append(NSAttributedString(string: piece.uppercased(), attributes: bigAttrs))
                atWordStart = false
            } else {
                out.append(NSAttributedString(string: piece.uppercased(), attributes: smallAttrs))
            }
        }
        return out
    }

    /// Natural single line width of a string in the given style.
    static func naturalWidth(_ text: String, _ style: RenderTextStyle) -> CGFloat {
        var left = style
        left.alignment = .natural
        let layout = RenderTextLayout(attributed(text, left), width: 10000)
        return ceil(layout.usedWidth)
    }
}

// MARK: - Simple drawing helpers (UIKit coordinates, current context)

enum RenderDraw {
    static func fill(_ rect: CGRect, _ color: UIColor) {
        guard rect.width > 0, rect.height > 0, let cg = UIGraphicsGetCurrentContext() else { return }
        cg.setFillColor(color.cgColor)
        cg.fill(rect)
    }

    static func fillRounded(_ rect: CGRect, radius: CGFloat, _ color: UIColor) {
        guard rect.width > 0, rect.height > 0 else { return }
        color.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: radius).fill()
    }

    static func stroke(_ rect: CGRect, _ color: UIColor, width: CGFloat) {
        guard rect.width > 0, rect.height > 0, let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.stroke(rect)
        cg.restoreGState()
    }

    static func fillCircle(center: CGPoint, radius: CGFloat, _ color: UIColor) {
        guard radius > 0, let cg = UIGraphicsGetCurrentContext() else { return }
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
    }

    static func dotted(from start: CGPoint, toX endX: CGFloat, color: UIColor, width: CGFloat = 0.9) {
        guard endX > start.x, let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.setLineCap(.round)
        cg.setLineDash(phase: 0, lengths: [0.01, 3.2])
        cg.move(to: start)
        cg.addLine(to: CGPoint(x: endX, y: start.y))
        cg.strokePath()
        cg.restoreGState()
    }
}

/// Where things were drawn, for layout tests. Filled only when `RenderCanvas.geometry` is set.
final class RenderGeometry {
    var photoRects: [CGRect] = []
    var headerTextRects: [CGRect] = []
}

enum RenderPhotoShape {
    case circle
    case rounded
    case square

    static func from(_ shape: PhotoShape?) -> RenderPhotoShape? {
        guard let shape else { return nil }
        switch shape {
        case .circle: return .circle
        case .rounded: return .rounded
        case .square: return .square
        }
    }
}

enum RenderPhoto {
    /// The photo only appears when the template supports it, the user has not turned it off and the data decodes.
    static func image(for resume: Resume, template: TemplateSpec) -> UIImage? {
        guard template.photo != .none, resume.style.showPhoto,
              let data = resume.personal.photoData, !data.isEmpty else { return nil }
        return UIImage(data: data)
    }

    /// Aspect fill crop into a circle or rounded square, with an optional thin ring in `ring`.
    static func draw(_ image: UIImage, in rect: CGRect, shape: RenderPhotoShape, ring: UIColor? = nil) {
        guard rect.width > 0, rect.height > 0,
              image.size.width > 0, image.size.height > 0,
              let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        let path: UIBezierPath
        switch shape {
        case .circle:
            path = UIBezierPath(ovalIn: rect)
        case .rounded:
            path = UIBezierPath(roundedRect: rect, cornerRadius: rect.width * 0.12)
        case .square:
            path = UIBezierPath(rect: rect)
        }
        path.addClip()
        let scale: CGFloat = max(rect.width / image.size.width, rect.height / image.size.height)
        let w: CGFloat = image.size.width * scale
        let h: CGFloat = image.size.height * scale
        image.draw(in: CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
        cg.restoreGState()
        if let ring = ring {
            let lineWidth: CGFloat = max(1, rect.width * 0.018)
            let inset: CGRect = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let border: UIBezierPath
            switch shape {
            case .circle: border = UIBezierPath(ovalIn: inset)
            case .rounded: border = UIBezierPath(roundedRect: inset, cornerRadius: inset.width * 0.12)
            case .square: border = UIBezierPath(rect: inset)
            }
            border.lineWidth = lineWidth
            ring.setStroke()
            border.stroke()
        }
    }
}

// MARK: - PDF writer

enum RenderPDFWriter {
    /// Creates a PDF with `pageCount` pages of equal size. `drawPage` is called once per page after the page began.
    static func makePDF(pageSize: CGSize,
                        pageCount: Int,
                        title: String,
                        author: String,
                        canvas: RenderCanvas,
                        drawPage: (Int) -> Void) -> Data {
        let bounds = CGRect(origin: CGPoint.zero, size: pageSize)
        let format = UIGraphicsPDFRendererFormat()
        var info: [String: Any] = [kCGPDFContextCreator as String: "CareerKit"]
        if !title.isEmpty { info[kCGPDFContextTitle as String] = title }
        if !author.isEmpty { info[kCGPDFContextAuthor as String] = author }
        format.documentInfo = info
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        return renderer.pdfData { context in
            canvas.pdfContext = context
            let total: Int = max(1, pageCount)
            for page in 0..<total {
                context.beginPage()
                drawPage(page)
            }
            canvas.pdfContext = nil
        }
    }
}
