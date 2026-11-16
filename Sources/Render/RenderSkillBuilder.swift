import UIKit

extension RenderSectionBuilder {
    /// Skill groups in one of four styles. Narrow columns fall back to simpler shapes.
    func skillItems(_ groups: [SkillGroup], leadingGap: CGFloat) -> [RenderFlowItem] {
        var items: [RenderFlowItem] = []
        let groupGap: CGFloat = max(2.5, style.bodySize * 0.35)
        let kind: SkillStyle = template.skillStyle

        var labelWidth: CGFloat = 0
        if kind == .groupedLines && !isNarrow {
            var widest: CGFloat = 0
            for group in groups where !group.name.isEmpty {
                widest = max(widest, RenderText.naturalWidth(group.name, bodyStyle(bold: true)))
            }
            labelWidth = min(widest + 14, width * 0.34)
        }

        for (i, group) in groups.enumerated() {
            let before: CGFloat = items.isEmpty ? leadingGap : groupGap
            switch kind {
            case .commaList:
                items.append(inlineGroup(group, separator: ", ", separatorColor: theme.ink, spaceBefore: before))
            case .pipeList:
                items.append(inlineGroup(group, separator: "  |  ", separatorColor: theme.muted, spaceBefore: before))
            case .groupedLines:
                if labelWidth > 0 && !group.name.isEmpty {
                    items.append(alignedGroup(group, labelWidth: labelWidth, spaceBefore: before))
                } else if isNarrow && !group.name.isEmpty {
                    items.append(contentsOf: stackedGroup(group, spaceBefore: before))
                } else {
                    items.append(inlineGroup(group, separator: ", ", separatorColor: theme.ink, spaceBefore: before))
                }
            case .bulletColumns:
                items.append(contentsOf: columnGroup(group, spaceBefore: before, isFirstGroup: i == 0))
            case .pills:
                items.append(contentsOf: pillGroup(group, spaceBefore: before))
            }
        }
        return items
    }

    // MARK: Styles

    /// "Name: a, b, c" as one wrapping paragraph.
    private func inlineGroup(_ group: SkillGroup, separator: String, separatorColor: UIColor, spaceBefore: CGFloat) -> RenderFlowItem {
        var runs: [(String, RenderTextStyle)] = []
        if !group.name.isEmpty {
            runs.append((group.name + ": ", bodyStyle(bold: true)))
        }
        let base: RenderTextStyle = bodyStyle()
        let sepStyle: RenderTextStyle = bodyStyle(color: separatorColor)
        for (i, item) in group.items.enumerated() {
            if i > 0 { runs.append((separator, sepStyle)) }
            runs.append((item, base))
        }
        let layout = ctx.layout(RenderText.runs(runs), width: width)
        return RenderFlowFactory.text(layout: layout, spaceBefore: spaceBefore)
    }

    /// Group name in a fixed label column, the items beside it.
    private func alignedGroup(_ group: SkillGroup, labelWidth: CGFloat, spaceBefore: CGFloat) -> RenderFlowItem {
        let composite = RenderComposite()
        let label = ctx.layout(RenderText.attributed(group.name, bodyStyle(bold: true)), width: labelWidth - 10, links: [])
        let list = group.items.joined(separator: ", ")
        let items = ctx.layout(RenderText.attributed(list, bodyStyle()), width: width - labelWidth)
        composite.addRow([(label, 0), (items, labelWidth)])
        return composite.makeItem(spaceBefore: spaceBefore) ?? RenderFlowItem(height: 0, draw: { _, _ in })
    }

    /// Narrow column: the name on its own line, the items under it.
    private func stackedGroup(_ group: SkillGroup, spaceBefore: CGFloat) -> [RenderFlowItem] {
        let nameLayout = ctx.layout(RenderText.attributed(group.name, bodyStyle(bold: true)), width: width, links: [])
        let nameItem = RenderFlowFactory.text(layout: nameLayout, spaceBefore: spaceBefore, keep: true)
        let list = group.items.joined(separator: ", ")
        let listLayout = ctx.layout(RenderText.attributed(list, bodyStyle()), width: width)
        let listItem = RenderFlowFactory.text(layout: listLayout, spaceBefore: 1)
        return [nameItem, listItem]
    }

    /// Two column bullet list (one column in narrow areas). Rows are atomic so pages break between rows.
    private func columnGroup(_ group: SkillGroup, spaceBefore: CGFloat, isFirstGroup: Bool) -> [RenderFlowItem] {
        var out: [RenderFlowItem] = []
        let columns: Int = isNarrow ? 1 : 2
        let columnGap: CGFloat = 14
        let cellWidth: CGFloat = (width - CGFloat(columns - 1) * columnGap) / CGFloat(columns)
        let marker: String = template.bullets.glyph.isEmpty ? "\u{2022}" : template.bullets.glyph
        let indent: CGFloat = bulletIndent
        var nextGap: CGFloat = spaceBefore

        if !group.name.isEmpty {
            let nameLayout = ctx.layout(RenderText.attributed(group.name, bodyStyle(bold: true)), width: width, links: [])
            out.append(RenderFlowFactory.text(layout: nameLayout, spaceBefore: spaceBefore, keep: true))
            nextGap = 2.5
        }

        let markerStyle = RenderTextStyle(font: style.bodyFont(bold: true), color: theme.accent, leading: 1.0)
        var index: Int = 0
        var firstRow: Bool = true
        while index < group.items.count {
            let upper: Int = min(index + columns, group.items.count)
            let slice: [String] = Array(group.items[index..<upper])
            var cells: [(RenderTextLayout, CGFloat)] = []
            for (n, text) in slice.enumerated() {
                let x: CGFloat = CGFloat(n) * (cellWidth + columnGap)
                let markerLayout = ctx.layout(RenderText.attributed(marker, markerStyle), width: indent + 20, links: [])
                let textLayout = ctx.layout(RenderText.attributed(text, bodyStyle()), width: max(20, cellWidth - indent))
                cells.append((markerLayout, x))
                cells.append((textLayout, x + indent))
            }
            let composite = RenderComposite()
            composite.addRow(cells)
            if let row = composite.makeItem(spaceBefore: firstRow ? nextGap : bulletGap) {
                out.append(row)
            }
            firstRow = false
            index += columns
        }
        return out
    }

    /// Skills as soft rounded pills that wrap across the column. Each row is one block, so pages break between rows.
    private func pillGroup(_ group: SkillGroup, spaceBefore: CGFloat) -> [RenderFlowItem] {
        var out: [RenderFlowItem] = []
        var nextGap: CGFloat = spaceBefore
        if !group.name.isEmpty {
            let nameLayout = ctx.layout(RenderText.attributed(group.name, bodyStyle(bold: true)), width: width, links: [])
            out.append(RenderFlowFactory.text(layout: nameLayout, spaceBefore: spaceBefore, keep: true))
            nextGap = 3
        }
        let padX: CGFloat = 7
        let padY: CGFloat = 2.5
        let gapX: CGFloat = 5
        let gapY: CGFloat = 5
        let textStyle: RenderTextStyle = bodyStyle(size: style.smallSize)
        let fill: UIColor = pillFill

        struct Pill {
            let layout: RenderTextLayout
            let width: CGFloat
            let height: CGFloat
        }
        var pills: [Pill] = []
        for item in group.items {
            let natural: CGFloat = RenderText.naturalWidth(item, textStyle)
            let textWidth: CGFloat = min(natural + 1, max(20, width - 2 * padX))
            let layout = ctx.layout(RenderText.attributed(item, textStyle), width: textWidth)
            pills.append(Pill(layout: layout, width: textWidth + 2 * padX, height: layout.height + 2 * padY))
        }

        var rows: [[Pill]] = []
        var current: [Pill] = []
        var used: CGFloat = 0
        for pill in pills {
            let needed: CGFloat = current.isEmpty ? pill.width : used + gapX + pill.width
            if !current.isEmpty && needed > width {
                rows.append(current)
                current = [pill]
                used = pill.width
            } else {
                current.append(pill)
                used = needed
            }
        }
        if !current.isEmpty { rows.append(current) }

        for (r, row) in rows.enumerated() {
            var rowHeight: CGFloat = 0
            for pill in row { rowHeight = max(rowHeight, pill.height) }
            let snapshot: [Pill] = row
            let item = RenderFlowItem(height: ceil(rowHeight), spaceBefore: r == 0 ? nextGap : gapY, draw: { origin, _ in
                var x: CGFloat = origin.x
                for pill in snapshot {
                    let rect = CGRect(x: x, y: origin.y, width: pill.width, height: pill.height)
                    RenderDraw.fillRounded(rect, radius: min(pill.height / 2, 9), fill)
                    pill.layout.draw(at: CGPoint(x: x + padX, y: origin.y + padY))
                    x += pill.width + gapX
                }
            })
            out.append(item)
        }
        return out
    }
}
