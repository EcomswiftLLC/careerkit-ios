import UIKit

/// Builds the flow items for resume sections: headings, text, entries and skills.
final class RenderSectionBuilder {
    let ctx: RenderContext
    let template: TemplateSpec

    init(ctx: RenderContext, template: TemplateSpec) {
        self.ctx = ctx
        self.template = template
    }

    var style: RenderStyle { return ctx.style }
    var theme: RenderTheme { return ctx.theme }
    var width: CGFloat { return ctx.width }
    /// Sidebars and rails are too narrow for two column layouts inside an entry.
    var isNarrow: Bool { return ctx.width < 250 }

    // MARK: Text styles and rhythm

    func bodyStyle(bold: Bool = false, italic: Bool = false, color: UIColor? = nil, size: CGFloat? = nil) -> RenderTextStyle {
        return RenderTextStyle(font: style.bodyFont(size: size, bold: bold, italic: italic),
                               color: color ?? theme.ink,
                               leading: style.leading)
    }

    func metaStyle() -> RenderTextStyle {
        return RenderTextStyle(font: style.bodyFont(size: style.smallSize), color: theme.muted, leading: style.leading)
    }

    var paragraphGap: CGFloat { return max(3, style.bodySize * 0.45) }
    var bulletGap: CGFloat { return max(1.5, style.bodySize * 0.22) }
    var bulletIndent: CGFloat { return max(11, style.bodySize * 1.5) }

    // MARK: Section assembly

    func sectionItems(_ section: ResumeSection) -> [RenderFlowItem] {
        let label: String = RenderContent.label(for: section)
        if effectiveHeadingStyle == .sideLabel {
            return sideLabelSection(section, label: label)
        }
        let body: [RenderFlowItem] = bodyItems(section)
        guard !body.isEmpty else { return [] }
        var items: [RenderFlowItem] = [headingItem(label: label, spaceBefore: style.sectionGap)]
        items.append(contentsOf: body)
        return items
    }

    func bodyItems(_ section: ResumeSection) -> [RenderFlowItem] {
        var items: [RenderFlowItem] = []

        let paragraphs: [String] = RenderContent.paragraphs(section.text)
        for (i, paragraph) in paragraphs.enumerated() {
            let attr = RenderText.attributed(paragraph, bodyStyle())
            let layout = ctx.layout(attr, width: width)
            items.append(RenderFlowFactory.text(layout: layout, spaceBefore: i == 0 ? 0 : paragraphGap))
        }

        for entry in RenderContent.renderableEntries(section) {
            let gap: CGFloat = items.isEmpty ? 0 : style.entryGap
            items.append(contentsOf: entryItems(entry, leadingGap: gap))
        }

        let groups: [SkillGroup] = RenderContent.renderableSkillGroups(section)
        if !groups.isEmpty {
            let gap: CGFloat = items.isEmpty ? 0 : style.entryGap
            items.append(contentsOf: skillItems(groups, leadingGap: gap))
        }
        return items
    }

    // MARK: Headings

    var effectiveHeadingStyle: SectionHeadingStyle {
        if template.headingStyle == .sideLabel && ctx.width < 300 {
            return .uppercaseRule
        }
        return template.headingStyle
    }

    private func headingAttributed(_ label: String, kind: SectionHeadingStyle, sizeScale: CGFloat = 1) -> NSAttributedString {
        // An explicit user choice wins over the capitals a heading style normally uses.
        let upper: Bool = style.headingCaseOverride ?? (kind == .uppercaseRule || kind == .boxedLabel || style.uppercaseHeadings)
        let font: UIFont = style.headingFont(size: style.headingSize * sizeScale, bold: true)
        let kern: CGFloat = (upper || kind == .smallCapsAccent) ? style.headingKern * sizeScale : 0
        let color: UIColor
        switch kind {
        case .uppercaseRule, .smallCapsAccent, .dottedRule, .sideLabel, .centeredRule:
            color = theme.accent
        case .accentBar, .plainBold, .underlineAccent, .leftBorder:
            color = theme.ink
        case .boxedLabel:
            color = theme.chipText
        case .tintedBand:
            color = bandTextColor
        }
        let base = RenderTextStyle(font: font, color: color, leading: 1.0, alignment: .natural, kern: kern)
        if kind == .smallCapsAccent && style.headingCaseOverride != false {
            return RenderText.smallCaps(label, base)
        }
        return RenderText.attributed(upper ? label.uppercased() : label, base)
    }

    func headingItem(label: String, spaceBefore: CGFloat) -> RenderFlowItem {
        let kind: SectionHeadingStyle = effectiveHeadingStyle
        let attr: NSAttributedString = headingAttributed(label, kind: kind)
        let w: CGFloat = width
        let ruleColor: UIColor = theme.rule
        let accent: UIColor = theme.accent
        let size: CGFloat = style.headingSize

        switch kind {
        case .accentBar:
            let layout = ctx.layout(attr, width: w, links: [])
            let barHeight: CGFloat = 2.6
            let labelY: CGFloat = barHeight + 4.5
            return RenderFlowItem(height: ceil(labelY + layout.height + 6), spaceBefore: spaceBefore, keepWithNext: true, draw: { origin, _ in
                RenderDraw.fill(CGRect(x: origin.x, y: origin.y, width: 26, height: barHeight), accent)
                layout.draw(at: CGPoint(x: origin.x, y: origin.y + labelY))
            })

        case .boxedLabel:
            let layout = ctx.layout(attr, width: max(20, w - 14), links: [])
            let chipWidth: CGFloat = min(w, ceil(layout.usedWidth) + 14)
            let chipHeight: CGFloat = layout.height + 5
            return RenderFlowItem(height: ceil(chipHeight + 7), spaceBefore: spaceBefore, keepWithNext: true, draw: { origin, _ in
                RenderDraw.fillRounded(CGRect(x: origin.x, y: origin.y, width: chipWidth, height: chipHeight), radius: 2.5, accent)
                layout.draw(at: CGPoint(x: origin.x + 7, y: origin.y + 2.5))
            })

        case .dottedRule:
            let layout = ctx.layout(attr, width: w, links: [])
            let baseline: CGFloat = layout.baseline(ofLine: 0)
            let startX: CGFloat = ceil(layout.usedWidth) + 8
            return RenderFlowItem(height: ceil(layout.height + 6), spaceBefore: spaceBefore, keepWithNext: true, draw: { origin, _ in
                layout.draw(at: origin)
                if startX < w - 12 {
                    RenderDraw.dotted(from: CGPoint(x: origin.x + startX, y: origin.y + baseline - size * 0.3),
                                      toX: origin.x + w,
                                      color: ruleColor)
                }
            })

        case .plainBold, .smallCapsAccent:
            let layout = ctx.layout(attr, width: w, links: [])
            return RenderFlowItem(height: ceil(layout.height + 5), spaceBefore: spaceBefore, keepWithNext: true, draw: { origin, _ in
                layout.draw(at: origin)
            })

        case .uppercaseRule, .sideLabel:
            let layout = ctx.layout(attr, width: w, links: [])
            let ruleY: CGFloat = layout.height + 3.5
            return RenderFlowItem(height: ceil(ruleY + 0.6 + 6), spaceBefore: spaceBefore, keepWithNext: true, draw: { origin, _ in
                layout.draw(at: origin)
                RenderDraw.fill(CGRect(x: origin.x, y: origin.y + ruleY, width: w, height: 0.6), ruleColor)
            })

        case .underlineAccent:
            let layout = ctx.layout(attr, width: w, links: [])
            let barY: CGFloat = layout.height + 3.5
            let barHeight: CGFloat = 2.2
            let barWidth: CGFloat = min(w, max(22, size * 2.6))
            return RenderFlowItem(height: ceil(barY + barHeight + 6), spaceBefore: spaceBefore, keepWithNext: true, draw: { origin, _ in
                layout.draw(at: origin)
                RenderDraw.fill(CGRect(x: origin.x, y: origin.y + barY, width: barWidth, height: barHeight), accent)
            })

        case .centeredRule:
            let layout = ctx.layout(attr, width: w, links: [])
            let used: CGFloat = ceil(layout.usedWidth)
            let singleLine: Bool = layout.lines.count <= 1
            let labelX: CGFloat = singleLine ? max(0, floor((w - used) / 2)) : 0
            let gap: CGFloat = 10
            let headingFont: UIFont = style.headingFont(size: size, bold: true)
            let ruleY: CGFloat = layout.baseline(ofLine: 0) - headingFont.xHeight * 0.5
            let leftEnd: CGFloat = labelX - gap
            let rightStart: CGFloat = labelX + used + gap
            return RenderFlowItem(height: ceil(layout.height + 7), spaceBefore: spaceBefore, keepWithNext: true, draw: { origin, _ in
                if singleLine && leftEnd > 8 {
                    RenderDraw.fill(CGRect(x: origin.x, y: origin.y + ruleY, width: leftEnd, height: 0.6), ruleColor)
                    RenderDraw.fill(CGRect(x: origin.x + rightStart, y: origin.y + ruleY, width: max(0, w - rightStart), height: 0.6), ruleColor)
                }
                layout.draw(at: CGPoint(x: origin.x + labelX, y: origin.y))
            })

        case .leftBorder:
            let barWidth: CGFloat = 3
            let inset: CGFloat = 9
            let layout = ctx.layout(attr, width: max(20, w - inset), links: [])
            let barHeight: CGFloat = layout.height + 2
            return RenderFlowItem(height: ceil(barHeight + 6), spaceBefore: spaceBefore, keepWithNext: true, draw: { origin, _ in
                RenderDraw.fill(CGRect(x: origin.x, y: origin.y, width: barWidth, height: barHeight), accent)
                layout.draw(at: CGPoint(x: origin.x + inset, y: origin.y + 1))
            })

        case .tintedBand:
            let pad: CGFloat = 6
            let layout = ctx.layout(attr, width: max(20, w - 2 * pad), links: [])
            let bandHeight: CGFloat = layout.height + 7
            let fill: UIColor = bandFill
            return RenderFlowItem(height: ceil(bandHeight + 7), spaceBefore: spaceBefore, keepWithNext: true, draw: { origin, _ in
                RenderDraw.fill(CGRect(x: origin.x, y: origin.y, width: w, height: bandHeight), fill)
                layout.draw(at: CGPoint(x: origin.x + pad, y: origin.y + 3.5))
            })
        }
    }

    // MARK: Tinted band colours

    /// The paper the column sits on: the sidebar fill in a sidebar, white elsewhere.
    private var columnPaper: UIColor {
        return theme.isSidebar ? style.sidebarFill : UIColor.white
    }

    /// A pale wash of the accent over the column paper.
    var bandFill: UIColor {
        return RenderColors.mix(columnPaper, theme.accent, theme.isSidebar ? 0.14 : 0.09)
    }

    /// Accent text when it keeps 4.5:1 on the band, otherwise the column ink.
    var bandTextColor: UIColor {
        if RenderSectionBuilder.contrast(theme.accent, bandFill) >= 4.5 {
            return theme.accent
        }
        return theme.ink
    }

    /// WCAG contrast ratio between two opaque colours.
    static func contrast(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let la: CGFloat = relativeLuminance(a)
        let lb: CGFloat = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static func relativeLuminance(_ color: UIColor) -> CGFloat {
        let c = RenderColors.components(color)
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    private static func linear(_ channel: CGFloat) -> CGFloat {
        if channel <= 0.03928 { return channel / 12.92 }
        return pow((channel + 0.055) / 1.055, 2.4)
    }

    // MARK: Side labels

    /// Width of the widest single word of a side label, so the gutter never has to break inside a word.
    private func widestWord(of label: String, sizeScale: CGFloat) -> CGFloat {
        var widest: CGFloat = 0
        let words = label.split(whereSeparator: { $0 == " " || $0 == "\n" })
        for word in words {
            let attr: NSAttributedString = headingAttributed(String(word), kind: .sideLabel, sizeScale: sizeScale)
            let probe = RenderTextLayout(attr, width: 10000)
            widest = max(widest, ceil(probe.usedWidth))
        }
        return widest
    }

    /// One gutter for every section of the document: sized to the longest word among the template's
    /// default section titles, so labels wrap only between words and all bodies share one left edge.
    private var sideLabelGutter: CGFloat {
        let kinds: [SectionKind] = template.mainSections + template.sidebarSections
        var widest: CGFloat = 0
        for kind in kinds {
            widest = max(widest, widestWord(of: kind.defaultTitle, sizeScale: 1))
        }
        let floorWidth: CGFloat = max(width * 0.18, 76)
        let ceiling: CGFloat = max(floorWidth, width * 0.32)
        return min(max(widest + 16, floorWidth), ceiling)
    }

    /// Editorial layout: the label sits in a left gutter beside the first block of the section.
    private func sideLabelSection(_ section: ResumeSection, label: String) -> [RenderFlowItem] {
        let gutter: CGFloat = sideLabelGutter
        let labelWidth: CGFloat = max(20, gutter - 14)
        let inner = RenderSectionBuilder(ctx: ctx.withWidth(width - gutter), template: template)
        var body: [RenderFlowItem] = inner.bodyItems(section)
        guard !body.isEmpty else { return [] }
        for item in body {
            item.xOffset += gutter
        }
        body[0].spaceBefore = style.sectionGap

        // A renamed section can hold a word longer than the gutter: shrink that label (not the gutter)
        // until its longest word fits, down to 70 percent.
        var scale: CGFloat = 1
        let longest: CGFloat = widestWord(of: label, sizeScale: 1)
        if longest > labelWidth {
            scale = max(0.7, labelWidth / longest)
        }
        let attr: NSAttributedString = headingAttributed(label, kind: .sideLabel, sizeScale: scale)
        let labelLayout = ctx.layout(attr, width: labelWidth, links: [])
        let labelFont: UIFont = style.headingFont(size: style.headingSize * scale, bold: true)
        let lift: CGFloat = max(0, style.bodyFont(bold: true).ascender - labelFont.ascender)
        let labelBottom: CGFloat = lift + labelLayout.height

        // Keep the label clear of the next section: a tall label holds the following item on its page,
        // and a short body gets a spacer so the label never runs into the next heading.
        if labelBottom > body[0].height && body.count > 1 {
            body[0].keepWithNext = true
        }
        var bodyHeight: CGFloat = 0
        for (i, item) in body.enumerated() {
            bodyHeight += item.height + (i == 0 ? 0 : item.spaceBefore)
        }
        if labelBottom > bodyHeight {
            // Pad the last block (never a separate empty item, which could end up alone on a page).
            let last: RenderFlowItem = body[body.count - 1]
            body[body.count - 1] = RenderFlowItem(height: last.height + ceil(labelBottom - bodyHeight),
                                                  spaceBefore: last.spaceBefore,
                                                  keepWithNext: last.keepWithNext,
                                                  xOffset: last.xOffset,
                                                  draw: last.drawBlock)
        }

        body[0] = body[0].withOverlay { origin, columnLeft in
            labelLayout.draw(at: CGPoint(x: columnLeft, y: origin.y + lift))
        }
        return body
    }
}
