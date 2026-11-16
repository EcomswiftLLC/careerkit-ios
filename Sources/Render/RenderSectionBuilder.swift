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

    private func headingAttributed(_ label: String, kind: SectionHeadingStyle) -> NSAttributedString {
        let upper: Bool = kind == .uppercaseRule || kind == .boxedLabel || style.uppercaseHeadings
        let font: UIFont = style.headingFont(size: style.headingSize, bold: true)
        let kern: CGFloat = (upper || kind == .smallCapsAccent) ? style.headingKern : 0
        let color: UIColor
        switch kind {
        case .uppercaseRule, .smallCapsAccent, .dottedRule, .sideLabel:
            color = theme.accent
        case .accentBar, .plainBold:
            color = theme.ink
        case .boxedLabel:
            color = theme.chipText
        }
        let base = RenderTextStyle(font: font, color: color, leading: 1.0, alignment: .natural, kern: kern)
        if kind == .smallCapsAccent {
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
        }
    }

    /// Editorial layout: the label sits in a left gutter beside the first block of the section.
    private func sideLabelSection(_ section: ResumeSection, label: String) -> [RenderFlowItem] {
        let gutter: CGFloat = min(max(width * 0.2, 80), 112)
        let inner = RenderSectionBuilder(ctx: ctx.withWidth(width - gutter), template: template)
        var body: [RenderFlowItem] = inner.bodyItems(section)
        guard !body.isEmpty else { return [] }
        for item in body {
            item.xOffset += gutter
        }
        body[0].spaceBefore = style.sectionGap

        let attr: NSAttributedString = headingAttributed(label, kind: .sideLabel)
        let labelLayout = ctx.layout(attr, width: max(20, gutter - 14), links: [])
        let labelFont: UIFont = style.headingFont(size: style.headingSize, bold: true)
        let lift: CGFloat = max(0, style.bodyFont(bold: true).ascender - labelFont.ascender)
        body[0] = body[0].withOverlay { origin, columnLeft in
            labelLayout.draw(at: CGPoint(x: columnLeft, y: origin.y + lift))
        }
        return body
    }
}
