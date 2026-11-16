import UIKit

/// Builds the resume header for each `HeaderStyle`. The result is one block placed at the top of page one.
final class RenderHeaderBuilder {
    let ctx: RenderContext
    let personal: PersonalInfo
    let photo: UIImage?
    /// Horizontal extent a banner fill may bleed over (page coordinates).
    let bleedLeft: CGFloat
    let bleedRight: CGFloat

    init(ctx: RenderContext, personal: PersonalInfo, photo: UIImage?, bleedLeft: CGFloat, bleedRight: CGFloat) {
        self.ctx = ctx
        self.personal = personal
        self.photo = photo
        self.bleedLeft = bleedLeft
        self.bleedRight = bleedRight
    }

    private var style: RenderStyle { return ctx.style }
    private var theme: RenderTheme { return ctx.theme }

    private struct Plan {
        var parts: [RenderPart] = []
        var height: CGFloat = 0
        var decorations: [(CGPoint) -> Void] = []
    }

    private var photoSize: CGFloat { return min(76, ctx.width * 0.2) }

    // MARK: Entry point

    func build(_ kind: HeaderStyle) -> RenderFlowItem? {
        let plan: Plan
        switch kind {
        case .leftAligned, .sidebarCard:
            plan = planAligned(centered: false)
        case .centered:
            plan = planAligned(centered: true)
        case .banner:
            plan = planBanner()
        case .splitContact:
            plan = planSplit()
        case .ruledMonogram:
            plan = planRuled()
        }
        return makeItem(plan)
    }

    private func makeItem(_ plan: Plan) -> RenderFlowItem? {
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

    // MARK: Pieces

    private func nameLayout(width: CGFloat, color: UIColor, alignment: NSTextAlignment, size: CGFloat? = nil, kern: CGFloat = 0) -> RenderTextLayout? {
        let name: String = RenderContent.trimmed(personal.fullName)
        guard !name.isEmpty else { return nil }
        let font: UIFont = style.headingFont(size: size ?? style.nameSize, bold: true)
        let textStyle = RenderTextStyle(font: font, color: color, leading: 1.0, alignment: alignment, kern: kern)
        return ctx.layout(RenderText.attributed(name, textStyle), width: width, links: [])
    }

    private func titleLayout(width: CGFloat, color: UIColor, alignment: NSTextAlignment, smallCaps: Bool = false) -> RenderTextLayout? {
        let title: String = RenderContent.trimmed(personal.professionalTitle)
        guard !title.isEmpty else { return nil }
        let font: UIFont = smallCaps
            ? style.headingFont(size: style.bodySize * 1.05, bold: true)
            : style.bodyFont(size: style.bodySize * 1.2)
        let textStyle = RenderTextStyle(font: font, color: color, leading: 1.0, alignment: alignment, kern: smallCaps ? 1.2 : 0)
        let attr: NSAttributedString = smallCaps ? RenderText.smallCaps(title, textStyle) : RenderText.attributed(title, textStyle)
        return ctx.layout(attr, width: width, links: [])
    }

    private func append(_ block: RenderPartsBlock, to plan: inout Plan, x: CGFloat, y: CGFloat) {
        for part in block.parts {
            plan.parts.append(RenderPart(layout: part.layout, x: part.x + x, y: part.y + y))
        }
    }

    private func addPhoto(to plan: inout Plan, x: CGFloat, y: CGFloat, size: CGFloat, shape: RenderPhotoShape) {
        guard let image = photo else { return }
        plan.decorations.append { origin in
            RenderPhoto.draw(image, in: CGRect(x: origin.x + x, y: origin.y + y, width: size, height: size), shape: shape)
        }
        plan.height = max(plan.height, y + size)
    }

    // MARK: Left aligned and centered

    private func planAligned(centered: Bool) -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let reserve: CGFloat = photo == nil ? 0 : photoSize + 18
        let textWidth: CGFloat = centered ? w - 2 * reserve : w - reserve
        let originX: CGFloat = centered ? reserve : 0
        let alignment: NSTextAlignment = centered ? .center : .natural
        var y: CGFloat = 0

        if let name = nameLayout(width: textWidth, color: theme.ink, alignment: alignment) {
            plan.parts.append(RenderPart(layout: name, x: originX, y: 0))
            y = name.height
        }
        if let title = titleLayout(width: textWidth, color: theme.accent, alignment: alignment) {
            y += y > 0 ? 3 : 0
            plan.parts.append(RenderPart(layout: title, x: originX, y: y))
            y += title.height
        }
        let items = RenderContact.items(for: personal)
        if !items.isEmpty {
            let block = RenderContact.flow(items, ctx: ctx, width: textWidth, alignment: alignment,
                                           font: style.bodyFont(size: style.smallSize), color: theme.muted,
                                           sepColor: theme.rule)
            y += y > 0 ? 9 : 0
            append(block, to: &plan, x: originX, y: y)
            y += block.height
        }
        plan.height = y
        addPhoto(to: &plan, x: w - photoSize, y: 0, size: photoSize, shape: centered ? .circle : .rounded)
        return plan
    }

    // MARK: Banner

    private func planBanner() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let fill: UIColor = style.headerFill
        let foreground: UIColor = RenderColors.readable(on: fill, dark: style.ink)
        let bannerPhoto: CGFloat = photoSize + 4
        let reserve: CGFloat = photo == nil ? 0 : bannerPhoto + 18
        let textWidth: CGFloat = w - reserve
        var y: CGFloat = 0

        if let name = nameLayout(width: textWidth, color: foreground, alignment: .natural) {
            plan.parts.append(RenderPart(layout: name, x: 0, y: 0))
            y = name.height
        }
        if let title = titleLayout(width: textWidth, color: foreground.withAlphaComponent(0.92), alignment: .natural) {
            y += y > 0 ? 3 : 0
            plan.parts.append(RenderPart(layout: title, x: 0, y: y))
            y += title.height
        }
        let items = RenderContact.items(for: personal)
        if !items.isEmpty {
            let block = RenderContact.flow(items, ctx: ctx, width: textWidth, alignment: .natural,
                                           font: style.bodyFont(size: style.smallSize),
                                           color: foreground.withAlphaComponent(0.92),
                                           sepColor: foreground.withAlphaComponent(0.5))
            y += y > 0 ? 9 : 0
            append(block, to: &plan, x: 0, y: y)
            y += block.height
        }
        addPhoto(to: &plan, x: w - bannerPhoto, y: 0, size: bannerPhoto, shape: .circle)
        let content: CGFloat = max(y, photo == nil ? 0 : bannerPhoto)
        guard content > 0 else { return plan }
        let total: CGFloat = content + 18
        plan.height = total

        let left: CGFloat = bleedLeft
        let right: CGFloat = bleedRight
        plan.decorations.insert({ origin in
            RenderDraw.fill(CGRect(x: left, y: 0, width: max(0, right - left), height: origin.y + total), fill)
        }, at: 0)
        return plan
    }

    // MARK: Split contact

    private func planSplit() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let photoReserve: CGFloat = photo == nil ? 0 : photoSize + 16
        let contactWidth: CGFloat = min(w * 0.40, 230)
        let contactX: CGFloat = w - photoReserve - contactWidth
        let leftWidth: CGFloat = max(80, contactX - 18)
        var leftY: CGFloat = 0

        if let name = nameLayout(width: leftWidth, color: theme.ink, alignment: .natural) {
            plan.parts.append(RenderPart(layout: name, x: 0, y: 0))
            leftY = name.height
        }
        if let title = titleLayout(width: leftWidth, color: theme.accent, alignment: .natural) {
            leftY += leftY > 0 ? 3 : 0
            plan.parts.append(RenderPart(layout: title, x: 0, y: leftY))
            leftY += title.height
        }
        let items = RenderContact.items(for: personal)
        var rightY: CGFloat = 0
        if !items.isEmpty {
            let block = RenderContact.stack(items, ctx: ctx, width: contactWidth, alignment: .right,
                                            font: style.bodyFont(size: style.smallSize), color: theme.muted, gap: 2.5)
            append(block, to: &plan, x: contactX, y: 4)
            rightY = block.height + 4
        }
        var content: CGFloat = max(leftY, rightY)
        addPhoto(to: &plan, x: w - photoSize, y: 0, size: photoSize, shape: .rounded)
        content = max(content, photo == nil ? 0 : photoSize)
        guard content > 0 else { return plan }
        let ruleY: CGFloat = content + 9
        let ruleColor: UIColor = theme.rule
        plan.decorations.append { origin in
            RenderDraw.fill(CGRect(x: origin.x, y: origin.y + ruleY, width: w, height: 0.6), ruleColor)
        }
        plan.height = ruleY + 0.6
        return plan
    }

    // MARK: Ruled monogram

    private func planRuled() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let reserve: CGFloat = photo == nil ? 0 : photoSize + 18
        let textWidth: CGFloat = w - reserve
        var y: CGFloat = 0

        if let name = nameLayout(width: textWidth, color: theme.ink, alignment: .natural, kern: 0.6) {
            plan.parts.append(RenderPart(layout: name, x: 0, y: 0))
            y = name.height
        }
        if y > 0 {
            let ruleY: CGFloat = y + 7
            let accent: UIColor = theme.accent
            plan.decorations.append { origin in
                RenderDraw.fill(CGRect(x: origin.x, y: origin.y + ruleY, width: w, height: 2.2), accent)
            }
            y = ruleY + 2.2
        }
        if let title = titleLayout(width: textWidth, color: theme.accent, alignment: .natural, smallCaps: true) {
            y += y > 0 ? 8 : 0
            plan.parts.append(RenderPart(layout: title, x: 0, y: y))
            y += title.height
        }
        let items = RenderContact.items(for: personal)
        if !items.isEmpty {
            let block = RenderContact.flow(items, ctx: ctx, width: textWidth, alignment: .natural,
                                           font: style.bodyFont(size: style.smallSize), color: theme.muted,
                                           sepColor: theme.rule)
            y += y > 0 ? 7 : 0
            append(block, to: &plan, x: 0, y: y)
            y += block.height
        }
        plan.height = y
        addPhoto(to: &plan, x: w - photoSize, y: 0, size: photoSize, shape: .rounded)
        return plan
    }

    // MARK: Sidebar card

    /// Photo, name, title and stacked contact lines for the top of a sidebar.
    /// `contactHeading` is an optional heading item for the contact block.
    func buildSidebarCard(contactHeading: RenderFlowItem?) -> [RenderFlowItem] {
        var items: [RenderFlowItem] = []
        let w: CGFloat = ctx.width

        if let image = photo {
            let size: CGFloat = min(w, 92)
            items.append(RenderFlowItem(height: ceil(size), keepWithNext: true, draw: { origin, _ in
                RenderPhoto.draw(image, in: CGRect(x: origin.x, y: origin.y, width: size, height: size), shape: .circle)
            }))
        }

        let nameSize: CGFloat = min(style.nameSize, 24 * style.scale)
        if let name = nameLayout(width: w, color: theme.ink, alignment: .natural, size: nameSize) {
            items.append(RenderFlowFactory.text(layout: name, spaceBefore: items.isEmpty ? 0 : 12, keep: true))
        }
        if let title = titleLayout(width: w, color: theme.ink.withAlphaComponent(0.9), alignment: .natural) {
            items.append(RenderFlowFactory.text(layout: title, spaceBefore: items.isEmpty ? 0 : 4, keep: true))
        }

        let contacts = RenderContact.items(for: personal)
        if !contacts.isEmpty {
            if let heading = contactHeading {
                heading.spaceBefore = style.sectionGap
                items.append(heading)
            }
            let font: UIFont = style.bodyFont(size: style.smallSize)
            for (i, contact) in contacts.enumerated() {
                let block = RenderContact.stack([contact], ctx: ctx, width: w, alignment: .natural,
                                                font: font, color: theme.ink, gap: 0)
                let composite = RenderComposite()
                for part in block.parts {
                    composite.addLine(part.layout, x: part.x, gapBefore: 0)
                }
                if let item = composite.makeItem(spaceBefore: i == 0 ? (contactHeading == nil ? 12 : 0) : 4) {
                    items.append(item)
                }
            }
        }
        return items
    }
}
