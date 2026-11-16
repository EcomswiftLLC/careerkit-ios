import UIKit

/// Renders a cover letter into a PDF with the same engine as the resume. Pure and thread-safe.
enum CoverLetterRenderer {
    static func render(_ letter: CoverLetter, template: CoverLetterTemplateSpec) -> RenderedDocument {
        let composer = RenderLetterComposer(letter: letter, template: template)
        return composer.render()
    }
}

final class RenderLetterComposer {
    private let letter: CoverLetter
    private let template: CoverLetterTemplateSpec
    private let style: RenderStyle
    private let canvas = RenderCanvas()
    private let detector = RenderLinkDetector()

    private struct HeaderPlan {
        var parts: [RenderPart] = []
        var height: CGFloat = 0
        var decorations: [(CGPoint) -> Void] = []
    }

    init(letter: CoverLetter, template: CoverLetterTemplateSpec) {
        self.letter = letter
        self.template = template
        self.style = RenderStyle.make(letter: template, overrides: letter.style, pageSize: letter.pageSize.size)
    }

    func render() -> RenderedDocument {
        let page: CGSize = style.pageSize
        let contentWidth: CGFloat = max(120, page.width - 2 * style.marginSide)
        let theme: RenderTheme = style.mainTheme
        let ctx = RenderContext(style: style, theme: theme, width: contentWidth, canvas: canvas, detector: detector)

        var items: [RenderFlowItem] = []
        if let header = buildHeader(ctx: ctx, pageWidth: page.width) {
            items.append(header)
        }
        items.append(contentsOf: buildBody(ctx: ctx, hasHeader: !items.isEmpty))

        let column = RenderColumn(left: style.marginSide,
                                  width: contentWidth,
                                  bottom: page.height - style.marginBottom,
                                  firstTop: style.marginTop,
                                  otherTop: style.marginTop)
        let pages: [[RenderPlacement]] = RenderPaginator.paginate(items, column: column)
        let pageCount: Int = max(1, pages.count)
        let title: String = RenderContent.trimmed(letter.title)
        let author: String = RenderContent.trimmed(letter.senderName)
        let footerStyle: RenderStyle = style

        let data: Data = RenderPDFWriter.makePDF(pageSize: page, pageCount: pageCount, title: title, author: author, canvas: canvas) { index in
            RenderDraw.fill(CGRect(origin: CGPoint.zero, size: page), UIColor.white)
            guard index < pages.count else { return }
            var lowest: CGFloat = 0
            for placement in pages[index] {
                placement.item.drawBlock(CGPoint(x: placement.x, y: placement.y), placement.columnLeft)
                lowest = max(lowest, placement.y + placement.item.height)
            }
            // Pages 2 and later: small sender name and page number in the bottom margin.
            if let footer = RenderPageFooter.text(name: author, page: index + 1, of: pageCount) {
                RenderPageFooter.draw(footer,
                                      style: footerStyle,
                                      color: theme.muted,
                                      columnLeft: style.marginSide,
                                      columnWidth: contentWidth,
                                      contentBottom: column.bottom,
                                      pageHeight: page.height,
                                      lowestContent: lowest)
            }
        }
        return RenderedDocument(pdfData: data, pageCount: pageCount, pageSize: letter.pageSize)
    }

    // MARK: Body

    private func bodyStyle(bold: Bool = false, color: UIColor? = nil) -> RenderTextStyle {
        return RenderTextStyle(font: style.bodyFont(bold: bold), color: color ?? style.ink, leading: style.leading)
    }

    private func buildBody(ctx: RenderContext, hasHeader: Bool) -> [RenderFlowItem] {
        var out: [RenderFlowItem] = []
        let width: CGFloat = ctx.width
        let paragraphGap: CGFloat = max(6, style.sectionGap)
        let blockGap: CGFloat = max(18, style.sectionGap * 1.8)

        // Date, written in the document language ("16. November 2026", "2026年11月16日").
        let language: ResumeLanguage = style.language
        let explicitLanguage: Bool = style.languageChoice != nil
        let dateText: String = DocumentStrings.letterDate(letter.date, language: language)
        if !dateText.isEmpty {
            let layout = ctx.layout(RenderText.attributed(dateText, bodyStyle(color: style.muted)), width: width, links: [])
            out.append(RenderFlowFactory.text(layout: layout, spaceBefore: hasHeader ? blockGap : 0))
        }

        // Recipient block.
        var recipientLines: [String] = []
        for value in [letter.recipientName, letter.recipientTitle, letter.companyName, letter.companyAddress] {
            let t = RenderContent.trimmed(value)
            if !t.isEmpty { recipientLines.append(t) }
        }
        if !recipientLines.isEmpty {
            let layout = ctx.layout(RenderText.attributed(recipientLines.joined(separator: "\n"), bodyStyle()), width: width)
            out.append(RenderFlowFactory.text(layout: layout, spaceBefore: out.isEmpty ? 0 : paragraphGap * 1.6))
        }

        // Greeting.
        let greeting: String = RenderContent.trimmed(letter.effectiveGreeting(language: language, explicit: explicitLanguage))
        if !greeting.isEmpty {
            let layout = ctx.layout(RenderText.attributed(greeting, bodyStyle()), width: width)
            out.append(RenderFlowFactory.text(layout: layout, spaceBefore: out.isEmpty ? 0 : paragraphGap * 1.8, keep: true))
        }

        // Paragraphs.
        var lastParagraph: RenderFlowItem? = nil
        for paragraph in letter.bodyParagraphs {
            let layout = ctx.layout(RenderText.attributed(paragraph, bodyStyle()), width: width)
            let item = RenderFlowFactory.text(layout: layout, spaceBefore: paragraphGap)
            out.append(item)
            lastParagraph = item
        }

        // Closing.
        let signOff: String = RenderContent.trimmed(letter.effectiveSignOff(language: language, explicit: explicitLanguage))
        let signature: String = RenderContent.trimmed(letter.senderName)
        if !signOff.isEmpty || !signature.isEmpty {
            var closing: [RenderFlowItem] = []
            if !signOff.isEmpty {
                let layout = ctx.layout(RenderText.attributed(signOff, bodyStyle()), width: width)
                closing.append(RenderFlowFactory.text(layout: layout, spaceBefore: paragraphGap * 1.4, keep: !signature.isEmpty))
            }
            if !signature.isEmpty {
                let nameStyle = RenderTextStyle(font: style.headingFont(size: style.bodySize * 1.1, bold: true),
                                                color: style.ink, leading: style.leading)
                let layout = ctx.layout(RenderText.attributed(signature, nameStyle), width: width, links: [])
                let gap: CGFloat = signOff.isEmpty ? paragraphGap * 1.4 : style.bodySize * 2.6
                closing.append(RenderFlowFactory.text(layout: layout, spaceBefore: gap))
            }
            if let last = lastParagraph {
                last.keepWithNext = true
            }
            out.append(contentsOf: closing)
        }
        return out
    }

    // MARK: Header

    private func headerLayouts(ctx: RenderContext, width: CGFloat, color: UIColor, alignment: NSTextAlignment, titleColor: UIColor) -> (name: RenderTextLayout?, title: RenderTextLayout?) {
        let name: String = RenderContent.trimmed(letter.senderName)
        let title: String = RenderContent.trimmed(letter.senderTitle)
        var nameLayout: RenderTextLayout? = nil
        var titleLayout: RenderTextLayout? = nil
        if !name.isEmpty {
            let font = style.headingFont(size: style.nameSize, bold: true)
            let textStyle = RenderTextStyle(font: font, color: color, leading: 1.0, alignment: alignment)
            nameLayout = ctx.layout(RenderText.attributed(name, textStyle), width: width, links: [])
        }
        if !title.isEmpty {
            let textStyle = RenderTextStyle(font: style.bodyFont(size: style.bodySize * 1.05), color: titleColor, leading: 1.0, alignment: alignment)
            titleLayout = ctx.layout(RenderText.attributed(title, textStyle), width: width, links: [])
        }
        return (nameLayout, titleLayout)
    }

    private func buildHeader(ctx: RenderContext, pageWidth: CGFloat) -> RenderFlowItem? {
        let w: CGFloat = ctx.width
        let contacts: [RenderContactItem] = RenderContact.items(email: letter.senderEmail,
                                                                phone: letter.senderPhone,
                                                                location: letter.senderLocation)
        let smallFont: UIFont = style.bodyFont(size: style.smallSize)
        var plan = HeaderPlan()
        var y: CGFloat = 0

        func addBlock(_ block: RenderPartsBlock, x: CGFloat, y offsetY: CGFloat) {
            for part in block.parts {
                plan.parts.append(RenderPart(layout: part.layout, x: part.x + x, y: part.y + offsetY))
            }
        }

        switch template.header {
        case .leftBlock, .rightBlock:
            let alignment: NSTextAlignment = template.header == .rightBlock ? .right : .natural
            let layouts = headerLayouts(ctx: ctx, width: w, color: style.ink, alignment: alignment, titleColor: style.accent)
            if let name = layouts.name {
                plan.parts.append(RenderPart(layout: name, x: 0, y: 0))
                y = name.height
            }
            if let title = layouts.title {
                y += y > 0 ? 3 : 0
                plan.parts.append(RenderPart(layout: title, x: 0, y: y))
                y += title.height
            }
            if !contacts.isEmpty {
                let block = RenderContact.stack(contacts, ctx: ctx, width: w, alignment: alignment,
                                                font: smallFont, color: style.muted, gap: 1.5)
                y += y > 0 ? 7 : 0
                addBlock(block, x: 0, y: y)
                y += block.height
            }
            plan.height = y

        case .centered:
            let layouts = headerLayouts(ctx: ctx, width: w, color: style.ink, alignment: .center, titleColor: style.accent)
            if let name = layouts.name {
                plan.parts.append(RenderPart(layout: name, x: 0, y: 0))
                y = name.height
            }
            if let title = layouts.title {
                y += y > 0 ? 3 : 0
                plan.parts.append(RenderPart(layout: title, x: 0, y: y))
                y += title.height
            }
            if !contacts.isEmpty {
                let block = RenderContact.flow(contacts, ctx: ctx, width: w, alignment: .center, font: smallFont,
                                               color: style.muted, sepColor: style.muted.withAlphaComponent(0.6),
                                               separator: "  \u{00B7}  ")
                y += y > 0 ? 7 : 0
                addBlock(block, x: 0, y: y)
                y += block.height
            }
            plan.height = y

        case .banner:
            let fill: UIColor = style.headerFill
            let foreground: UIColor = RenderColors.readable(on: fill, dark: style.ink)
            let layouts = headerLayouts(ctx: ctx, width: w, color: foreground, alignment: .natural, titleColor: foreground.withAlphaComponent(0.92))
            if let name = layouts.name {
                plan.parts.append(RenderPart(layout: name, x: 0, y: 0))
                y = name.height
            }
            if let title = layouts.title {
                y += y > 0 ? 3 : 0
                plan.parts.append(RenderPart(layout: title, x: 0, y: y))
                y += title.height
            }
            if !contacts.isEmpty {
                let block = RenderContact.flow(contacts, ctx: ctx, width: w, alignment: .natural, font: smallFont,
                                               color: foreground.withAlphaComponent(0.92),
                                               sepColor: foreground.withAlphaComponent(0.5))
                y += y > 0 ? 8 : 0
                addBlock(block, x: 0, y: y)
                y += block.height
            }
            guard y > 0 else { return nil }
            let total: CGFloat = y + 16
            plan.height = total
            plan.decorations.append { origin in
                RenderDraw.fill(CGRect(x: 0, y: 0, width: pageWidth, height: origin.y + total), fill)
            }

        case .sideRule:
            let inset: CGFloat = 14
            let layouts = headerLayouts(ctx: ctx, width: w - inset, color: style.ink, alignment: .natural, titleColor: style.accent)
            if let name = layouts.name {
                plan.parts.append(RenderPart(layout: name, x: inset, y: 0))
                y = name.height
            }
            if let title = layouts.title {
                y += y > 0 ? 3 : 0
                plan.parts.append(RenderPart(layout: title, x: inset, y: y))
                y += title.height
            }
            if !contacts.isEmpty {
                let block = RenderContact.stack(contacts, ctx: ctx, width: w - inset, alignment: .natural,
                                                font: smallFont, color: style.muted, gap: 1.5)
                y += y > 0 ? 7 : 0
                addBlock(block, x: inset, y: y)
                y += block.height
            }
            guard y > 0 else { return nil }
            let barHeight: CGFloat = y
            let accent: UIColor = style.accent
            plan.decorations.append { origin in
                RenderDraw.fill(CGRect(x: origin.x, y: origin.y, width: 2.5, height: barHeight), accent)
            }
            plan.height = y

        case .letterhead:
            let layouts = headerLayouts(ctx: ctx, width: w, color: style.ink, alignment: .natural, titleColor: style.accent)
            if let name = layouts.name {
                plan.parts.append(RenderPart(layout: name, x: 0, y: 0))
                y = name.height
            }
            if let title = layouts.title {
                y += y > 0 ? 3 : 0
                plan.parts.append(RenderPart(layout: title, x: 0, y: y))
                y += title.height
            }
            if y > 0 {
                let ruleY: CGFloat = y + 7
                let accent: UIColor = style.accent
                plan.decorations.append { origin in
                    RenderDraw.fill(CGRect(x: origin.x, y: origin.y + ruleY, width: w, height: 0.8), accent)
                }
                y = ruleY + 0.8
            }
            if !contacts.isEmpty {
                let block = RenderContact.flow(contacts, ctx: ctx, width: w, alignment: .natural, font: smallFont,
                                               color: style.muted, sepColor: style.muted.withAlphaComponent(0.6),
                                               separator: "  \u{00B7}  ")
                y += y > 0 ? 8 : 0
                addBlock(block, x: 0, y: y)
                y += block.height
            }
            plan.height = y
        }

        guard plan.height > 0 else { return nil }
        let parts: [RenderPart] = plan.parts
        let decorations: [(CGPoint) -> Void] = plan.decorations
        return RenderFlowItem(height: ceil(plan.height), draw: { origin, _ in
            for decoration in decorations {
                decoration(origin)
            }
            for part in parts {
                part.layout.draw(at: CGPoint(x: origin.x + part.x, y: origin.y + part.y))
            }
        })
    }
}
