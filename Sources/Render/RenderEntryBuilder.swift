import UIKit

extension RenderSectionBuilder {
    /// Effective entry layout. Narrow columns cannot hold a date column beside the heading.
    var effectiveEntryLayout: EntryLayout {
        let kind: EntryLayout = template.entryLayout
        if (kind == .dateRight && width < 250) || (kind == .dateGutter && width < 320) {
            return .dateBelow
        }
        return kind
    }

    func entryItems(_ entry: ResumeEntry, leadingGap: CGFloat) -> [RenderFlowItem] {
        let heading: String = RenderContent.trimmed(entry.heading)
        let sub: String = RenderContent.trimmed(entry.subheading)
        let location: String = RenderContent.trimmed(entry.location)
        let extra: String = RenderContent.trimmed(entry.extra)
        let detail: String = RenderContent.trimmed(entry.detail)
        let dates: String = entry.dateRange(locale: Locale.current)
        let bullets: [String] = RenderContent.renderableBullets(entry)

        let kind: EntryLayout = effectiveEntryLayout
        let primary: String = heading.isEmpty ? sub : heading
        let secondary: String = heading.isEmpty ? "" : sub

        let headStyle: RenderTextStyle = bodyStyle(bold: true)
        let subStyle: RenderTextStyle = bodyStyle()
        let meta: RenderTextStyle = metaStyle()

        var bodyX: CGFloat = 0
        let composite = RenderComposite()

        switch kind {
        case .dateRight:
            addTwoColumn(composite, left: primary, leftStyle: headStyle, right: dates, rightStyle: meta,
                         x0: 0, available: width, gapBefore: 0)
            addTwoColumn(composite, left: secondary, leftStyle: subStyle, right: location, rightStyle: meta,
                         x0: 0, available: width, gapBefore: 1.5)

        case .dateBelow:
            if !primary.isEmpty {
                let layout = ctx.layout(RenderText.attributed(primary, headStyle), width: width)
                composite.addLine(layout)
            }
            var runs: [(String, RenderTextStyle)] = []
            appendRun(&runs, secondary, subStyle)
            appendRun(&runs, location, meta)
            appendRun(&runs, dates, meta)
            if !runs.isEmpty {
                composite.addLine(ctx.layout(RenderText.runs(runs), width: width), gapBefore: 1.5)
            }

        case .stacked:
            if !primary.isEmpty {
                composite.addLine(ctx.layout(RenderText.attributed(primary, headStyle), width: width))
            }
            if !secondary.isEmpty {
                composite.addLine(ctx.layout(RenderText.attributed(secondary, subStyle), width: width), gapBefore: 1)
            }
            var runs: [(String, RenderTextStyle)] = []
            appendRun(&runs, dates, meta)
            appendRun(&runs, location, meta)
            if !runs.isEmpty {
                composite.addLine(ctx.layout(RenderText.runs(runs), width: width), gapBefore: 1)
            }

        case .dateGutter:
            let gutter: CGFloat = min(max(width * 0.22, 72), 100)
            bodyX = gutter
            let textWidth: CGFloat = width - gutter
            var dateStyle = meta
            dateStyle.alignment = .natural
            var cells: [(RenderTextLayout, CGFloat)] = []
            if !dates.isEmpty {
                cells.append((ctx.layout(RenderText.attributed(dates, dateStyle), width: gutter - 10, links: []), 0))
            }
            if !primary.isEmpty {
                cells.append((ctx.layout(RenderText.attributed(primary, headStyle), width: textWidth), gutter))
            }
            composite.addRow(cells)
            var runs: [(String, RenderTextStyle)] = []
            appendRun(&runs, secondary, subStyle)
            appendRun(&runs, location, meta)
            if !runs.isEmpty {
                composite.addLine(ctx.layout(RenderText.runs(runs), width: textWidth), x: gutter, gapBefore: 1.5)
            }
        }

        if !extra.isEmpty {
            var extraStyle = RenderTextStyle(font: style.bodyFont(size: style.smallSize, italic: true),
                                             color: theme.muted,
                                             leading: style.leading)
            extraStyle.alignment = .natural
            composite.addLine(ctx.layout(RenderText.attributed(extra, extraStyle), width: width - bodyX), x: bodyX, gapBefore: 1.5)
        }

        let bodyWidth: CGFloat = width - bodyX
        let hasBody: Bool = !detail.isEmpty || !bullets.isEmpty
        var items: [RenderFlowItem] = []

        if let header = composite.makeItem(spaceBefore: leadingGap, keep: hasBody) {
            items.append(header)
        }

        if !detail.isEmpty {
            let layout = ctx.layout(RenderText.attributed(detail, bodyStyle()), width: bodyWidth)
            let item = RenderFlowFactory.text(layout: layout,
                                              spaceBefore: items.isEmpty ? leadingGap : 2.5,
                                              keep: !bullets.isEmpty)
            item.xOffset = bodyX
            items.append(item)
        }

        var bulletItems: [RenderFlowItem] = []
        for (i, text) in bullets.enumerated() {
            let before: CGFloat
            if items.isEmpty && bulletItems.isEmpty {
                before = leadingGap
            } else if i == 0 {
                before = 2.5
            } else {
                before = bulletGap
            }
            let item = bulletItem(text: text, width: bodyWidth, spaceBefore: before)
            item.xOffset = bodyX
            bulletItems.append(item)
        }
        // Do not leave a single bullet alone at the top of the next page.
        if bulletItems.count >= 3 {
            bulletItems[bulletItems.count - 2].keepWithNext = true
        }
        items.append(contentsOf: bulletItems)
        return items
    }

    // MARK: Pieces

    private func appendRun(_ runs: inout [(String, RenderTextStyle)], _ text: String, _ textStyle: RenderTextStyle) {
        guard !text.isEmpty else { return }
        if !runs.isEmpty {
            runs.append(("  \u{00B7}  ", metaStyle()))
        }
        runs.append((text, textStyle))
    }

    /// Left text plus right aligned text on one baseline. The left side wraps; the right side keeps its width.
    private func addTwoColumn(_ composite: RenderComposite,
                              left: String,
                              leftStyle: RenderTextStyle,
                              right: String,
                              rightStyle: RenderTextStyle,
                              x0: CGFloat,
                              available: CGFloat,
                              gapBefore: CGFloat) {
        if left.isEmpty && right.isEmpty { return }
        if right.isEmpty {
            composite.addLine(ctx.layout(RenderText.attributed(left, leftStyle), width: available), x: x0, gapBefore: gapBefore)
            return
        }
        let natural: CGFloat = RenderText.naturalWidth(right, rightStyle)
        let rightWidth: CGFloat = min(natural + 1, available * 0.46)
        var aligned = rightStyle
        aligned.alignment = .right
        let rightLayout = ctx.layout(RenderText.attributed(right, aligned), width: rightWidth, links: [])
        let rightX: CGFloat = x0 + available - rightWidth
        if left.isEmpty {
            composite.addLine(rightLayout, x: rightX, gapBefore: gapBefore)
            return
        }
        let leftWidth: CGFloat = max(40, available - rightWidth - 12)
        let leftLayout = ctx.layout(RenderText.attributed(left, leftStyle), width: leftWidth)
        composite.addRow([(leftLayout, x0), (rightLayout, rightX)], gapBefore: gapBefore)
    }

    /// A bullet with a hanging indent: the marker sits in a gutter and wrapped lines align with the first line.
    func bulletItem(text: String, width w: CGFloat, spaceBefore: CGFloat) -> RenderFlowItem {
        let rtl: Bool = RenderTextDirection.isRightToLeft(text)
        let glyphText: String = template.bullets.glyph
        let indent: CGFloat = glyphText.isEmpty ? 0 : bulletIndent
        let layout = ctx.layout(RenderText.attributed(text, bodyStyle()), width: max(20, w - indent))
        var hanging: RenderHangingGlyph? = nil
        if !glyphText.isEmpty {
            let glyphStyle = RenderTextStyle(font: style.bodyFont(bold: true), color: theme.accent, leading: 1.0)
            let glyphLayout = ctx.layout(RenderText.attributed(glyphText, glyphStyle), width: indent + 20, links: [])
            hanging = RenderHangingGlyph(layout: glyphLayout, x: rtl ? max(0, w - indent) : 0)
        }
        return RenderFlowFactory.text(layout: layout,
                                      glyph: hanging,
                                      textX: rtl ? 0 : indent,
                                      spaceBefore: spaceBefore)
    }
}
