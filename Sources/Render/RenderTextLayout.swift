import UIKit

/// A measured block of attributed text. Wraps a TextKit layout so the same geometry is used
/// for measuring, drawing, splitting between pages and link rectangles.
final class RenderTextLayout {
    struct Line {
        let fragmentRect: CGRect
        let usedRect: CGRect
        let glyphRange: NSRange
    }

    let attributed: NSAttributedString
    let width: CGFloat
    let lines: [Line]
    /// Height of all lines, rounded up to a whole point. 0 for empty text.
    let height: CGFloat
    /// Width of the widest line.
    let usedWidth: CGFloat
    let links: [RenderLinkSpan]

    private let storage: NSTextStorage
    private let manager: NSLayoutManager
    private let container: NSTextContainer
    private let canvas: RenderCanvas?

    init(_ attributed: NSAttributedString,
         width: CGFloat,
         canvas: RenderCanvas? = nil,
         links explicitLinks: [RenderLinkSpan]? = nil,
         detector: RenderLinkDetector? = nil) {
        let safeWidth: CGFloat = max(1, width)
        let newStorage = NSTextStorage(attributedString: attributed)
        let newManager = NSLayoutManager()
        let newContainer = NSTextContainer(size: CGSize(width: safeWidth, height: CGFloat.greatestFiniteMagnitude))
        newContainer.lineFragmentPadding = 0
        newContainer.lineBreakMode = .byWordWrapping
        newManager.addTextContainer(newContainer)
        newStorage.addLayoutManager(newManager)
        newManager.ensureLayout(for: newContainer)

        var collected: [Line] = []
        let glyphCount: Int = newManager.numberOfGlyphs
        if glyphCount > 0 {
            newManager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: glyphCount)) { rect, used, _, glyphRange, _ in
                collected.append(Line(fragmentRect: rect, usedRect: used, glyphRange: glyphRange))
            }
        }
        var widest: CGFloat = 0
        for line in collected {
            widest = max(widest, line.usedRect.width)
        }
        var totalHeight: CGFloat = 0
        if let first = collected.first, let last = collected.last {
            totalHeight = ceil(max(0, last.usedRect.maxY - first.fragmentRect.minY))
        }

        let resolvedLinks: [RenderLinkSpan]
        if let explicitLinks = explicitLinks {
            resolvedLinks = explicitLinks
        } else if let detector = detector {
            resolvedLinks = detector.spans(in: attributed.string)
        } else {
            resolvedLinks = []
        }

        self.attributed = attributed
        self.width = safeWidth
        self.lines = collected
        self.height = totalHeight
        self.usedWidth = widest
        self.links = resolvedLinks
        self.storage = newStorage
        self.manager = newManager
        self.container = newContainer
        self.canvas = canvas
    }

    // MARK: Geometry

    /// Distance from the top of the layout to the baseline of the given line.
    func baseline(ofLine index: Int) -> CGFloat {
        guard index >= 0, index < lines.count else { return 0 }
        let line = lines[index]
        let location: CGPoint = manager.location(forGlyphAt: line.glyphRange.location)
        return line.fragmentRect.minY + location.y
    }

    /// Height of a run of whole lines, measured from the top of the first line.
    func partHeight(_ range: Range<Int>) -> CGFloat {
        guard !range.isEmpty, range.lowerBound >= 0, range.upperBound <= lines.count else { return 0 }
        let top: CGFloat = lines[range.lowerBound].fragmentRect.minY
        let bottom: CGFloat = lines[range.upperBound - 1].usedRect.maxY
        return ceil(max(0, bottom - top))
    }

    /// Chooses where to break a run of lines so the head fits in `maxHeight`.
    /// Strict mode keeps at least two lines on both sides (no widows or orphans).
    /// Relaxed mode allows any line boundary. Returns the first line index of the tail.
    func splitIndex(range: Range<Int>, maxHeight: CGFloat, relaxed: Bool) -> Int? {
        let count: Int = range.count
        let minHead: Int = relaxed ? 1 : 2
        let minTail: Int = relaxed ? 1 : 2
        guard count >= minHead + minTail else { return nil }
        var best: Int? = nil
        var k: Int = range.lowerBound + minHead
        while k <= range.upperBound - minTail {
            if partHeight(range.lowerBound..<k) <= maxHeight + 0.01 {
                best = k
            } else {
                break
            }
            k += 1
        }
        return best
    }

    // MARK: Drawing

    /// Draws the given lines (default all) so the top of the first drawn line sits at `origin`.
    func draw(at origin: CGPoint, lines range: Range<Int>? = nil, withLinks: Bool = true) {
        guard !lines.isEmpty else { return }
        let run: Range<Int> = range ?? (0..<lines.count)
        guard !run.isEmpty, run.lowerBound >= 0, run.upperBound <= lines.count else { return }
        let first = lines[run.lowerBound]
        let last = lines[run.upperBound - 1]
        let start: Int = first.glyphRange.location
        let end: Int = last.glyphRange.location + last.glyphRange.length
        let glyphs = NSRange(location: start, length: max(0, end - start))
        let shifted = CGPoint(x: origin.x, y: origin.y - first.fragmentRect.minY)
        manager.drawGlyphs(forGlyphRange: glyphs, at: shifted)

        guard withLinks, let canvas = canvas, !links.isEmpty else { return }
        let minY: CGFloat = first.fragmentRect.minY
        let maxY: CGFloat = last.fragmentRect.maxY
        for span in links {
            let safe = NSIntersectionRange(span.range, NSRange(location: 0, length: attributed.length))
            guard safe.length > 0 else { continue }
            let glyphRange: NSRange = manager.glyphRange(forCharacterRange: safe, actualCharacterRange: nil)
            manager.enumerateEnclosingRects(forGlyphRange: glyphRange,
                                            withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                            in: container) { rect, _ in
                guard rect.midY >= minY, rect.midY <= maxY else { return }
                let placed = CGRect(x: rect.minX + shifted.x,
                                    y: rect.minY + shifted.y,
                                    width: rect.width,
                                    height: rect.height)
                canvas.addLink(span.url, rect: placed.insetBy(dx: -0.5, dy: -1))
            }
        }
    }
}
