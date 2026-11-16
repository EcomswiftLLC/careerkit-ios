import UIKit

struct RenderPlacement {
    let item: RenderFlowItem
    /// Absolute x of the item (column left plus item indent).
    let x: CGFloat
    /// Absolute y of the top of the item.
    let y: CGFloat
    let columnLeft: CGFloat
}

struct RenderColumn {
    let left: CGFloat
    let width: CGFloat
    /// Lowest allowed y for content (page height minus bottom margin).
    let bottom: CGFloat
    /// Where content starts on the first page (below a header, for example).
    let firstTop: CGFloat
    /// Where content starts on every later page.
    let otherTop: CGFloat
}

/// Flows items down a column and onto further pages.
/// Rules: a keep-with-next chain moves together; text splits between lines with at least two lines on each
/// side where possible; nothing is ever dropped (an item taller than a page is split or, as a last resort,
/// placed at the top of a fresh page).
enum RenderPaginator {
    private static let epsilon: CGFloat = 0.01

    static func paginate(_ input: [RenderFlowItem], column: RenderColumn) -> [[RenderPlacement]] {
        var pages: [[RenderPlacement]] = [[]]
        var queue: [RenderFlowItem] = input
        var index: Int = 0
        var pageIndex: Int = 0
        var placed: Int = 0
        var y: CGFloat = column.firstTop

        func topOf(_ page: Int) -> CGFloat {
            return page == 0 ? column.firstTop : column.otherTop
        }
        func startPage() {
            pages.append([])
            pageIndex += 1
            placed = 0
            y = topOf(pageIndex)
        }
        func place(_ item: RenderFlowItem, space: CGFloat) {
            let top: CGFloat = y + space
            pages[pageIndex].append(RenderPlacement(item: item,
                                                    x: column.left + item.xOffset,
                                                    y: top,
                                                    columnLeft: column.left))
            y = top + item.height
            placed += 1
        }

        // A header that already fills the first page pushes the column to page two.
        if !queue.isEmpty && column.firstTop > column.bottom - 36 {
            startPage()
        }

        while index < queue.count {
            let available: CGFloat = column.bottom - y

            // Find the keep-with-next chain that starts here.
            var end: Int = index
            while end < queue.count - 1 && queue[end].keepWithNext {
                end += 1
            }

            var need: CGFloat = 0
            var needFresh: CGFloat = 0
            for i in index...end {
                let gap: CGFloat = queue[i].spaceBefore
                need += queue[i].height + ((placed == 0 && i == index) ? 0 : gap)
                needFresh += queue[i].height + (i == index ? 0 : gap)
            }

            // 1. The whole chain fits.
            if need <= available + epsilon {
                for i in index...end {
                    place(queue[i], space: placed == 0 ? 0 : queue[i].spaceBefore)
                }
                index = end + 1
                continue
            }

            // 2. A chain that ends in a long paragraph only needs the start of that paragraph to fit.
            if end > index, let minLast = queue[end].minSplitHeight {
                var needMin: CGFloat = 0
                for i in index..<end {
                    needMin += queue[i].height + ((placed == 0 && i == index) ? 0 : queue[i].spaceBefore)
                }
                needMin += queue[end].spaceBefore + minLast
                if needMin <= available + epsilon {
                    place(queue[index], space: placed == 0 ? 0 : queue[index].spaceBefore)
                    index += 1
                    continue
                }
            }

            // 3. Move the chain to a fresh page when it fits there whole.
            if end > index {
                let fresh: CGFloat = column.bottom - topOf(pageIndex + 1)
                if placed > 0 && needFresh <= fresh + epsilon {
                    startPage()
                    continue
                }
            }

            // 4. Handle the first item of the chain on its own.
            let item: RenderFlowItem = queue[index]
            let space: CGFloat = placed == 0 ? 0 : item.spaceBefore
            if item.height + space <= available + epsilon {
                place(item, space: space)
                index += 1
                continue
            }
            if let splitter = item.splitBlock,
               let parts = splitter(available - space, placed == 0),
               parts.0.height > 0,
               parts.0.height <= available - space + epsilon {
                let head: RenderFlowItem = parts.0
                let tail: RenderFlowItem = parts.1
                head.xOffset = item.xOffset
                head.spaceBefore = item.spaceBefore
                head.keepWithNext = false
                tail.xOffset = item.xOffset
                tail.spaceBefore = 0
                tail.keepWithNext = item.keepWithNext
                queue[index] = tail
                place(head, space: space)
                startPage()
                continue
            }
            if placed > 0 {
                startPage()
                continue
            }
            // Cannot be split and is taller than a page: place it anyway so nothing is lost.
            place(item, space: 0)
            index += 1
        }

        while pages.count > 1, let last = pages.last, last.isEmpty {
            pages.removeLast()
        }
        return pages
    }
}
