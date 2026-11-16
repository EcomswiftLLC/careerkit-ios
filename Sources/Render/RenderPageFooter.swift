import UIKit

/// A small "Name · 2 / 3" line on pages 2 and later of a multi-page resume or letter, so loose printed pages can be
/// matched up. Template independent and always on for multi-page documents (there is no setting). One-page documents
/// and page 1 never get it. It is real, selectable text drawn in the bottom margin, centred under the main column,
/// in the column's muted colour, and it is skipped on a page where content reaches into the margin.
enum RenderPageFooter {
    /// Footer text for a 1-based page number, or nil when the page gets no footer.
    static func text(name: String, page: Int, of total: Int) -> String? {
        guard total > 1, page >= 2, page <= total else { return nil }
        let cleaned: String = RenderContent.trimmed(name)
        let counter: String = "\(page) / \(total)"
        if cleaned.isEmpty { return counter }
        return "\(cleaned)  \u{00B7}  \(counter)"
    }

    static func fontSize(for style: RenderStyle) -> CGFloat {
        return min(9, max(7, style.smallSize * 0.85))
    }

    /// Where the footer line sits: inside the bottom margin, below `contentBottom`, above the page edge.
    static func frame(columnLeft: CGFloat,
                      columnWidth: CGFloat,
                      contentBottom: CGFloat,
                      pageHeight: CGFloat,
                      lineHeight: CGFloat) -> CGRect {
        let margin: CGFloat = max(0, pageHeight - contentBottom)
        let centred: CGFloat = contentBottom + max(4, (margin - lineHeight) / 2)
        let top: CGFloat = max(contentBottom + 2, min(centred, pageHeight - lineHeight - 2))
        return CGRect(x: columnLeft, y: top, width: max(1, columnWidth), height: lineHeight)
    }

    /// Draws the footer into the current PDF page. `lowestContent` is the bottom of the lowest block on the page;
    /// when it reaches the footer line (an oversized block placed anyway), the footer is left out.
    static func draw(_ text: String,
                     style: RenderStyle,
                     color: UIColor,
                     columnLeft: CGFloat,
                     columnWidth: CGFloat,
                     contentBottom: CGFloat,
                     pageHeight: CGFloat,
                     lowestContent: CGFloat) {
        let textStyle = RenderTextStyle(font: style.bodyFont(size: fontSize(for: style)),
                                        color: color,
                                        leading: 1.0,
                                        alignment: .center,
                                        kern: 0.2)
        let layout = RenderTextLayout(RenderText.attributed(text, textStyle), width: max(1, columnWidth))
        guard layout.height > 0 else { return }
        let rect: CGRect = frame(columnLeft: columnLeft,
                                 columnWidth: columnWidth,
                                 contentBottom: contentBottom,
                                 pageHeight: pageHeight,
                                 lineHeight: layout.height)
        guard lowestContent < rect.minY - 1, rect.maxY <= pageHeight else { return }
        layout.draw(at: rect.origin, withLinks: false)
    }

    /// Page text without the footer, for blank-page checks. Whitespace is dropped because PDF extraction spacing
    /// varies; the result is only meant for an emptiness test.
    static func removingFooter(_ footer: String, from pageText: String) -> String {
        let compactFooter: String = footer.filter { !$0.isWhitespace }
        var compactPage: String = pageText.filter { !$0.isWhitespace }
        guard !compactFooter.isEmpty, let range = compactPage.range(of: compactFooter, options: .backwards) else {
            return compactPage
        }
        compactPage.removeSubrange(range)
        return compactPage
    }
}
