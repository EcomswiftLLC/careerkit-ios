import UIKit

/// One placeable piece of a column. Items are measured once and drawn once, at the position the paginator picks.
final class RenderFlowItem {
    let height: CGFloat
    /// Gap above the item. Ignored when the item is first in its column on a page.
    var spaceBefore: CGFloat
    /// When true the item must share a page with the item after it.
    var keepWithNext: Bool
    /// Horizontal indent inside the column.
    var xOffset: CGFloat
    /// Height needed to start this item on a page when it can be split (two lines), else nil.
    var minSplitHeight: CGFloat?
    /// Called with the top left of the item and the left edge of its column.
    let drawBlock: (CGPoint, CGFloat) -> Void
    /// Splits into a head that fits in the given height and a tail. The Bool asks for relaxed rules.
    let splitBlock: ((CGFloat, Bool) -> (RenderFlowItem, RenderFlowItem)?)?

    init(height: CGFloat,
         spaceBefore: CGFloat = 0,
         keepWithNext: Bool = false,
         xOffset: CGFloat = 0,
         minSplitHeight: CGFloat? = nil,
         draw: @escaping (CGPoint, CGFloat) -> Void,
         split: ((CGFloat, Bool) -> (RenderFlowItem, RenderFlowItem)?)? = nil) {
        self.height = height
        self.spaceBefore = spaceBefore
        self.keepWithNext = keepWithNext
        self.xOffset = xOffset
        self.minSplitHeight = minSplitHeight
        self.drawBlock = draw
        self.splitBlock = split
    }

    /// A copy that also draws `overlay` (for gutter labels). When split, only the head keeps the overlay.
    func withOverlay(_ overlay: @escaping (CGPoint, CGFloat) -> Void) -> RenderFlowItem {
        let base = self
        var wrappedSplit: ((CGFloat, Bool) -> (RenderFlowItem, RenderFlowItem)?)? = nil
        if let original = splitBlock {
            wrappedSplit = { maxHeight, relaxed in
                guard let parts = original(maxHeight, relaxed) else { return nil }
                return (parts.0.withOverlay(overlay), parts.1)
            }
        }
        return RenderFlowItem(height: height,
                              spaceBefore: spaceBefore,
                              keepWithNext: keepWithNext,
                              xOffset: xOffset,
                              minSplitHeight: minSplitHeight,
                              draw: { origin, column in
                                  overlay(origin, column)
                                  base.drawBlock(origin, column)
                              },
                              split: wrappedSplit)
    }
}

/// A glyph (bullet) hung to the side of a text block, aligned to the block's first baseline.
struct RenderHangingGlyph {
    let layout: RenderTextLayout
    let x: CGFloat
}

enum RenderFlowFactory {
    /// A text block that can break between lines. `lines` selects a sub range (used for tails).
    static func text(layout: RenderTextLayout,
                     lines: Range<Int>? = nil,
                     glyph: RenderHangingGlyph? = nil,
                     textX: CGFloat = 0,
                     spaceBefore: CGFloat = 0,
                     keep: Bool = false) -> RenderFlowItem {
        let range: Range<Int> = lines ?? (0..<layout.lines.count)
        let blockHeight: CGFloat = layout.partHeight(range)

        let draw: (CGPoint, CGFloat) -> Void = { origin, _ in
            layout.draw(at: CGPoint(x: origin.x + textX, y: origin.y), lines: range)
            if let glyph = glyph, !range.isEmpty {
                let top: CGFloat = layout.lines[range.lowerBound].fragmentRect.minY
                let textBase: CGFloat = layout.baseline(ofLine: range.lowerBound) - top
                let glyphBase: CGFloat = glyph.layout.baseline(ofLine: 0)
                glyph.layout.draw(at: CGPoint(x: origin.x + glyph.x, y: origin.y + textBase - glyphBase), withLinks: false)
            }
        }

        var splitter: ((CGFloat, Bool) -> (RenderFlowItem, RenderFlowItem)?)? = nil
        var minSplit: CGFloat? = nil
        if range.count >= 2 {
            splitter = { maxHeight, relaxed in
                guard let k = layout.splitIndex(range: range, maxHeight: maxHeight, relaxed: relaxed) else { return nil }
                let head = RenderFlowFactory.text(layout: layout, lines: range.lowerBound..<k, glyph: glyph, textX: textX)
                let tail = RenderFlowFactory.text(layout: layout, lines: k..<range.upperBound, glyph: nil, textX: textX)
                return (head, tail)
            }
        }
        if range.count >= 4 {
            minSplit = layout.partHeight(range.lowerBound..<(range.lowerBound + 2))
        }
        return RenderFlowItem(height: blockHeight,
                              spaceBefore: spaceBefore,
                              keepWithNext: keep,
                              minSplitHeight: minSplit,
                              draw: draw,
                              split: splitter)
    }
}

// MARK: - Composite rows

struct RenderPart {
    let layout: RenderTextLayout
    let x: CGFloat
    let y: CGFloat
}

/// Stacks text layouts into rows with aligned baselines. The result is one atomic block.
final class RenderComposite {
    private(set) var parts: [RenderPart] = []
    private(set) var cursor: CGFloat = 0

    var isEmpty: Bool { return parts.isEmpty }

    func addLine(_ layout: RenderTextLayout, x: CGFloat = 0, gapBefore: CGFloat = 0) {
        guard layout.height > 0 else { return }
        let y: CGFloat = parts.isEmpty ? 0 : cursor + gapBefore
        parts.append(RenderPart(layout: layout, x: x, y: y))
        cursor = y + layout.height
    }

    /// Cells share a baseline. Each cell is (layout, x).
    func addRow(_ cells: [(RenderTextLayout, CGFloat)], gapBefore: CGFloat = 0) {
        let live: [(RenderTextLayout, CGFloat)] = cells.filter { $0.0.height > 0 }
        guard !live.isEmpty else { return }
        var maxBase: CGFloat = 0
        for cell in live {
            maxBase = max(maxBase, cell.0.baseline(ofLine: 0))
        }
        let top: CGFloat = parts.isEmpty ? 0 : cursor + gapBefore
        var bottom: CGFloat = top
        for cell in live {
            let y: CGFloat = top + (maxBase - cell.0.baseline(ofLine: 0))
            parts.append(RenderPart(layout: cell.0, x: cell.1, y: y))
            bottom = max(bottom, y + cell.0.height)
        }
        cursor = bottom
    }

    func makeItem(spaceBefore: CGFloat = 0, keep: Bool = false) -> RenderFlowItem? {
        guard !parts.isEmpty else { return nil }
        let snapshot: [RenderPart] = parts
        return RenderFlowItem(height: ceil(cursor), spaceBefore: spaceBefore, keepWithNext: keep, draw: { origin, _ in
            for part in snapshot {
                part.layout.draw(at: CGPoint(x: origin.x + part.x, y: origin.y + part.y))
            }
        })
    }
}
