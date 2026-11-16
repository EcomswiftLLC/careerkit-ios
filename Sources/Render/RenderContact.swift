import UIKit

struct RenderContactItem {
    let text: String
    let url: URL?
}

/// Laid out contact items with positions relative to the block origin.
struct RenderPartsBlock {
    var parts: [RenderPart]
    var height: CGFloat
}

enum RenderContact {
    // MARK: Items

    static func items(for personal: PersonalInfo) -> [RenderContactItem] {
        var out: [RenderContactItem] = []
        let email = RenderContent.trimmed(personal.email)
        if !email.isEmpty {
            out.append(RenderContactItem(text: email, url: mailURL(email)))
        }
        let phone = RenderContent.trimmed(personal.phone)
        if !phone.isEmpty {
            out.append(RenderContactItem(text: phone, url: phoneURL(phone)))
        }
        let place = RenderContent.trimmed(personal.locationLine)
        if !place.isEmpty {
            out.append(RenderContactItem(text: place, url: nil))
        }
        for web in [personal.linkedIn, personal.portfolio, personal.website] {
            let t = RenderContent.trimmed(web)
            if !t.isEmpty {
                out.append(RenderContactItem(text: displayText(forWeb: t), url: webURL(t)))
            }
        }
        return out
    }

    static func items(email: String, phone: String, location: String) -> [RenderContactItem] {
        var p = PersonalInfo()
        p.email = email
        p.phone = phone
        p.city = location
        return items(for: p)
    }

    // MARK: URLs

    static func mailURL(_ email: String) -> URL? {
        let t = RenderContent.trimmed(email)
        guard t.contains("@"), !t.contains(" ") else { return nil }
        return URL(string: "mailto:" + t)
    }

    static func phoneURL(_ phone: String) -> URL? {
        var digits = ""
        for ch in phone {
            if ch.isNumber && ch.isASCII {
                digits.append(ch)
            } else if ch == "+" && digits.isEmpty {
                digits.append(ch)
            }
        }
        guard digits.filter({ $0.isNumber }).count >= 5 else { return nil }
        return URL(string: "tel:" + digits)
    }

    static func webURL(_ text: String) -> URL? {
        let t = RenderContent.trimmed(text)
        guard !t.isEmpty, !t.contains(" ") else { return nil }
        let lower = t.lowercased()
        let full: String = (lower.hasPrefix("http://") || lower.hasPrefix("https://")) ? t : "https://" + t
        if let url = URL(string: full) { return url }
        let allowed: CharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "%:/?#[]@!$&'()*+,;=-._~"))
        if let encoded = full.addingPercentEncoding(withAllowedCharacters: allowed) {
            return URL(string: encoded)
        }
        return nil
    }

    /// "https://www.example.com/in/name/" becomes "example.com/in/name".
    static func displayText(forWeb text: String) -> String {
        var t = RenderContent.trimmed(text)
        let lower = t.lowercased()
        if lower.hasPrefix("https://") {
            t = String(t.dropFirst(8))
        } else if lower.hasPrefix("http://") {
            t = String(t.dropFirst(7))
        }
        if t.lowercased().hasPrefix("www.") {
            t = String(t.dropFirst(4))
        }
        while t.hasSuffix("/") && t.count > 1 {
            t.removeLast()
        }
        return t.isEmpty ? text : t
    }

    // MARK: Layout

    private static func itemLayout(_ item: RenderContactItem,
                                   ctx: RenderContext,
                                   width: CGFloat,
                                   font: UIFont,
                                   color: UIColor,
                                   alignment: NSTextAlignment) -> RenderTextLayout {
        let style = RenderTextStyle(font: font, color: color, leading: 1.0, alignment: alignment)
        let attr = RenderText.attributed(item.text, style)
        var links: [RenderLinkSpan] = []
        if let url = item.url {
            links.append(RenderLinkSpan(range: NSRange(location: 0, length: attr.length), url: url))
        }
        return ctx.layout(attr, width: width, links: links)
    }

    /// Items flow left to right with a separator and wrap onto further rows.
    static func flow(_ items: [RenderContactItem],
                     ctx: RenderContext,
                     width: CGFloat,
                     alignment: NSTextAlignment,
                     font: UIFont,
                     color: UIColor,
                     sepColor: UIColor,
                     separator: String = "  |  ") -> RenderPartsBlock {
        guard !items.isEmpty, width > 10 else { return RenderPartsBlock(parts: [], height: 0) }
        var layouts: [RenderTextLayout] = []
        for item in items {
            layouts.append(itemLayout(item, ctx: ctx, width: width, font: font, color: color, alignment: .natural))
        }
        let sepStyle = RenderTextStyle(font: font, color: sepColor)
        let sepLayout = ctx.layout(RenderText.attributed(separator, sepStyle), width: 400, links: [])
        let sepWidth: CGFloat = ceil(sepLayout.usedWidth)

        var rows: [[Int]] = []
        var current: [Int] = []
        var currentWidth: CGFloat = 0
        for i in layouts.indices {
            let w: CGFloat = ceil(layouts[i].usedWidth)
            let grown: CGFloat = current.isEmpty ? w : currentWidth + sepWidth + w
            if !current.isEmpty && grown > width {
                rows.append(current)
                current = [i]
                currentWidth = w
            } else {
                current.append(i)
                currentWidth = grown
            }
        }
        if !current.isEmpty { rows.append(current) }

        var parts: [RenderPart] = []
        var y: CGFloat = 0
        let rowGap: CGFloat = max(2, font.pointSize * 0.25)
        for row in rows {
            var rowWidth: CGFloat = CGFloat(max(0, row.count - 1)) * sepWidth
            var rowHeight: CGFloat = 0
            for i in row {
                rowWidth += ceil(layouts[i].usedWidth)
                rowHeight = max(rowHeight, layouts[i].height)
            }
            var x: CGFloat = 0
            if alignment == .center {
                x = (width - rowWidth) / 2
            } else if alignment == .right {
                x = width - rowWidth
            }
            x = max(0, x)
            for (n, i) in row.enumerated() {
                parts.append(RenderPart(layout: layouts[i], x: x, y: y))
                x += ceil(layouts[i].usedWidth)
                if n < row.count - 1 {
                    parts.append(RenderPart(layout: sepLayout, x: x, y: y))
                    x += sepWidth
                }
            }
            y += rowHeight + rowGap
        }
        return RenderPartsBlock(parts: parts, height: max(0, y - rowGap))
    }

    /// One item per line.
    static func stack(_ items: [RenderContactItem],
                      ctx: RenderContext,
                      width: CGFloat,
                      alignment: NSTextAlignment,
                      font: UIFont,
                      color: UIColor,
                      gap: CGFloat) -> RenderPartsBlock {
        guard !items.isEmpty, width > 10 else { return RenderPartsBlock(parts: [], height: 0) }
        var parts: [RenderPart] = []
        var y: CGFloat = 0
        for item in items {
            let layout = itemLayout(item, ctx: ctx, width: width, font: font, color: color, alignment: alignment)
            guard layout.height > 0 else { continue }
            var x: CGFloat = 0
            if layout.lines.count == 1 {
                let w: CGFloat = ceil(layout.usedWidth)
                if alignment == .right {
                    x = max(0, width - w)
                } else if alignment == .center {
                    x = max(0, (width - w) / 2)
                }
                // A single line is positioned by x, so draw it left aligned inside its own width.
                let narrow = itemLayout(item, ctx: ctx, width: max(w + 2, 4), font: font, color: color, alignment: .natural)
                parts.append(RenderPart(layout: narrow, x: x, y: y))
                y += narrow.height + gap
            } else {
                parts.append(RenderPart(layout: layout, x: 0, y: y))
                y += layout.height + gap
            }
        }
        return RenderPartsBlock(parts: parts, height: max(0, y - gap))
    }
}
