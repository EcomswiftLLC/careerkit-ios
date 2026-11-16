import UIKit

/// Header styles added in the distinctness pass, and the sidebar card.
extension RenderHeaderBuilder {

    // MARK: Right aligned

    /// Name, a short accent rule, title and contact set flush right. The photo sits in its slot (left by default).
    func planRightAligned() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let size: CGFloat = photoSize
        let s: Slot = slot(width: w, size: size)
        var y: CGFloat = 0

        if let name = nameLayout(width: s.textWidth, color: theme.ink, alignment: .right, kern: 0.3) {
            plan.parts.append(RenderPart(layout: name, x: s.textX, y: 0))
            y = name.height
        }
        if y > 0 {
            let ruleWidth: CGFloat = 44
            let ruleY: CGFloat = y + 6
            let ruleX: CGFloat = s.textX + s.textWidth - ruleWidth
            let accent: UIColor = theme.accent
            plan.decorations.append { origin in
                RenderDraw.fill(CGRect(x: origin.x + ruleX, y: origin.y + ruleY, width: ruleWidth, height: 2), accent)
            }
            y = ruleY + 2
        }
        if let title = titleLayout(width: s.textWidth, color: theme.accent, alignment: .right) {
            y += y > 0 ? 7 : 0
            plan.parts.append(RenderPart(layout: title, x: s.textX, y: y))
            y += title.height
        }
        if let block = contactFlow(width: s.textWidth, alignment: .right) {
            y += y > 0 ? 7 : 0
            append(block, to: &plan, x: s.textX, y: y)
            y += block.height
        }
        plan.height = y
        addPhoto(to: &plan, x: s.photoX, y: 0, size: size, shape: .circle)
        return plan
    }

    // MARK: Tinted card

    /// The split header (name left, contact stacked right) inside a pale accent panel with rounded corners.
    func planTintedCard() -> Plan {
        let w: CGFloat = ctx.width
        let pad: CGFloat = 16
        let inner: Plan = splitContent(width: max(120, w - 2 * pad), contactColor: theme.ink)
        guard inner.height > 0 else { return inner }
        var plan = Plan()
        for part in inner.parts {
            plan.parts.append(RenderPart(layout: part.layout, x: part.x + pad, y: part.y + pad))
        }
        let cardHeight: CGFloat = inner.height + 2 * pad
        let fill: UIColor = RenderColors.mix(style.paper, theme.accent, 0.08)
        let edge: UIColor = theme.accent
        plan.decorations.append { origin in
            RenderDraw.fillRounded(CGRect(x: origin.x, y: origin.y, width: w, height: cardHeight), radius: 6, fill)
            RenderDraw.fill(CGRect(x: origin.x + 10, y: origin.y + cardHeight - 2, width: max(0, w - 20), height: 2), edge)
        }
        for decoration in inner.decorations {
            plan.decorations.append { origin in
                decoration(CGPoint(x: origin.x + pad, y: origin.y + pad))
            }
        }
        plan.height = cardHeight
        return plan
    }

    // MARK: Centered band

    /// A full-bleed band with the photo (when there is one) centered above a centered name, title and contact line.
    func planBannerCentered() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let fill: UIColor = style.headerFill
        let foreground: UIColor = RenderColors.readable(on: fill, dark: style.ink)
        let size: CGFloat = photoSize + 4
        var y: CGFloat = 0
        if photo != nil {
            addPhoto(to: &plan, x: floor((w - size) / 2), y: 0, size: size, shape: .circle, ring: foreground)
            y = size + 12
        }
        let textWidth: CGFloat = max(80, w - 40)
        let textX: CGFloat = 20
        if let name = nameLayout(width: textWidth, color: foreground, alignment: .center, kern: 0.6) {
            plan.parts.append(RenderPart(layout: name, x: textX, y: y))
            y += name.height
        }
        if let title = titleLayout(width: textWidth, color: foreground.withAlphaComponent(0.92), alignment: .center, smallCaps: true) {
            y += 5
            plan.parts.append(RenderPart(layout: title, x: textX, y: y))
            y += title.height
        }
        if let block = contactFlow(width: textWidth, alignment: .center,
                                   color: foreground.withAlphaComponent(0.92), sepColor: foreground.withAlphaComponent(0.5)) {
            y += 9
            append(block, to: &plan, x: textX, y: y)
            y += block.height
        }
        guard y > 0 else { return plan }
        let total: CGFloat = y + 20
        plan.height = total
        addBandFill(to: &plan, fill: fill, total: total)
        return plan
    }

    // MARK: Initial letter

    /// A tall accent initial like a drop cap, with name, title and contact beside it.
    /// With a photo, the photo takes the initial's place, so there is never an empty slot.
    func planInitialLetter() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let letter: String = String(initials.prefix(1))
        var markLayout: RenderTextLayout? = nil
        var markWidth: CGFloat = 0
        if photo == nil && !letter.isEmpty {
            let font: UIFont = style.headingFont(size: style.nameSize * 2.5, bold: false)
            let markStyle = RenderTextStyle(font: font, color: theme.accent, leading: 1.0, alignment: .natural, kern: 0)
            let layout = ctx.layout(RenderText.attributed(letter, markStyle), width: style.nameSize * 3, links: [])
            markLayout = layout
            markWidth = ceil(layout.usedWidth)
        }
        let size: CGFloat = photoSize * 1.1
        let leadWidth: CGFloat = photo != nil ? size : markWidth
        let textX: CGFloat = leadWidth > 0 ? leadWidth + 18 : 0
        let textWidth: CGFloat = max(80, w - textX)

        var parts: [RenderPart] = []
        var y: CGFloat = 0
        if let name = nameLayout(width: textWidth, color: theme.ink, alignment: .natural) {
            parts.append(RenderPart(layout: name, x: textX, y: 0))
            y = name.height
        }
        if let title = titleLayout(width: textWidth, color: theme.accent, alignment: .natural, smallCaps: true) {
            y += y > 0 ? 4 : 0
            parts.append(RenderPart(layout: title, x: textX, y: y))
            y += title.height
        }
        if let block = contactFlow(width: textWidth, alignment: .natural) {
            y += y > 0 ? 7 : 0
            for part in block.parts {
                parts.append(RenderPart(layout: part.layout, x: part.x + textX, y: part.y + y))
            }
            y += block.height
        }
        let leadHeight: CGFloat = photo != nil ? size : (markLayout?.height ?? 0)
        let shift: CGFloat = max(0, floor((leadHeight - y) / 2))
        for part in parts {
            plan.parts.append(RenderPart(layout: part.layout, x: part.x, y: part.y + shift))
        }
        plan.height = max(y + shift, leadHeight)

        if photo != nil {
            addPhoto(to: &plan, x: 0, y: 0, size: size, shape: .rounded)
        } else if let layout = markLayout, leadWidth > 0 {
            let ruleColor: UIColor = theme.rule
            let ruleX: CGFloat = leadWidth + 8
            let ruleHeight: CGFloat = plan.height
            plan.decorations.append { origin in
                layout.draw(at: origin, withLinks: false)
                RenderDraw.fill(CGRect(x: origin.x + ruleX, y: origin.y + 4, width: 0.6, height: max(0, ruleHeight - 8)), ruleColor)
            }
        }
        return plan
    }

    // MARK: Small caps centered

    /// A modest, widely tracked capital name centered between two full-width hairlines.
    func planSmallCapsCentered() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let size: CGFloat = photoSize
        let s: Slot = slot(width: w, size: size, symmetric: true)
        let accent: UIColor = theme.accent
        let top: CGFloat = 0.6 + 12
        var y: CGFloat = top
        let nameSize: CGFloat = min(style.nameSize, 26 * style.scale)
        if let name = nameLayout(width: s.textWidth, color: theme.ink, alignment: .center, size: nameSize,
                                 kern: 2.0, bold: false, uppercase: true) {
            plan.parts.append(RenderPart(layout: name, x: s.textX, y: y))
            y += name.height
        }
        if let title = titleLayout(width: s.textWidth, color: accent, alignment: .center) {
            y += 4
            plan.parts.append(RenderPart(layout: title, x: s.textX, y: y))
            y += title.height
        }
        if let block = contactFlow(width: s.textWidth, alignment: .center) {
            y += 7
            append(block, to: &plan, x: s.textX, y: y)
            y += block.height
        }
        guard y > top || photo != nil else { return plan }
        addPhoto(to: &plan, x: s.photoX, y: top, size: size, shape: .circle)
        y = max(y, plan.height) + 12
        let bottomRule: CGFloat = y
        plan.decorations.append { origin in
            RenderDraw.fill(CGRect(x: origin.x, y: origin.y, width: w, height: 0.6), accent)
            RenderDraw.fill(CGRect(x: origin.x, y: origin.y + bottomRule, width: w, height: 0.6), accent)
        }
        plan.height = bottomRule + 0.6
        return plan
    }

    // MARK: Sidebar card

    /// Photo, name, title and stacked contact lines for the top of a sidebar.
    /// `contactHeading` is an optional heading item for the contact block. `band` is the sidebar fill in page
    /// coordinates and `columnTop` the y where the sidebar column starts; with `bleed` the photo runs across the
    /// whole band from the page top.
    func buildSidebarCard(contactHeading: RenderFlowItem?, band: CGRect? = nil, columnTop: CGFloat = 0, bleed: Bool = false) -> [RenderFlowItem] {
        var items: [RenderFlowItem] = []
        let w: CGFloat = ctx.width
        let canvas: RenderCanvas = ctx.canvas
        let ringColor: UIColor? = style.photoRing ? theme.ink : nil

        if let image = photo {
            let userShape: RenderPhotoShape? = style.photoShape
            if bleed, let band = band, userShape == nil || userShape == .square {
                let photoHeight: CGFloat = min(band.width * 0.82 * style.photoScale, 260)
                let itemHeight: CGFloat = max(0, photoHeight - columnTop) + 14
                items.append(RenderFlowItem(height: ceil(itemHeight), keepWithNext: true, draw: { _, _ in
                    let rect = CGRect(x: band.minX, y: 0, width: band.width, height: photoHeight)
                    RenderPhoto.draw(image, in: rect, shape: .square, ring: nil)
                    canvas.recordPhoto(rect)
                }))
            } else {
                let size: CGFloat = min(w, 92 * style.photoScale)
                let cardShape: RenderPhotoShape = userShape ?? .circle
                items.append(RenderFlowItem(height: ceil(size), keepWithNext: true, draw: { origin, _ in
                    let rect = CGRect(x: origin.x, y: origin.y, width: size, height: size)
                    RenderPhoto.draw(image, in: rect, shape: cardShape, ring: ringColor)
                    canvas.recordPhoto(rect)
                }))
            }
        }

        let nameSize: CGFloat = min(style.nameSize, 24 * style.scale)
        if let name = nameLayout(width: w, color: theme.ink, alignment: .natural, size: nameSize) {
            items.append(recorded(RenderFlowFactory.text(layout: name, spaceBefore: items.isEmpty ? 0 : 12, keep: true), layout: name))
        }
        if let title = titleLayout(width: w, color: theme.ink.withAlphaComponent(0.9), alignment: .natural) {
            items.append(recorded(RenderFlowFactory.text(layout: title, spaceBefore: items.isEmpty ? 0 : 4, keep: true), layout: title))
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

    /// Records the text box of a sidebar card line when it is drawn (tests only).
    private func recorded(_ item: RenderFlowItem, layout: RenderTextLayout) -> RenderFlowItem {
        let canvas: RenderCanvas = ctx.canvas
        return item.withOverlay { origin, _ in
            canvas.recordHeaderText(layout, at: origin)
        }
    }
}
