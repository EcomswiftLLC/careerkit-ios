import UIKit

/// Builds the resume header for each `HeaderStyle`. The result is one block placed at the top of page one.
/// The newer styles live in `RenderHeaderBuilder+Styles.swift`.
final class RenderHeaderBuilder {
    let ctx: RenderContext
    let personal: PersonalInfo
    let photo: UIImage?
    /// Horizontal extent a banner fill may bleed over (page coordinates).
    let bleedLeft: CGFloat
    let bleedRight: CGFloat
    /// Where the template wants the photo. Only the side matters for row headers.
    let placement: PhotoPlacement

    init(ctx: RenderContext, personal: PersonalInfo, photo: UIImage?, bleedLeft: CGFloat, bleedRight: CGFloat,
         placement: PhotoPlacement = .headerRight) {
        self.ctx = ctx
        self.personal = personal
        self.photo = photo
        self.bleedLeft = bleedLeft
        self.bleedRight = bleedRight
        self.placement = placement
    }

    var style: RenderStyle { return ctx.style }
    var theme: RenderTheme { return ctx.theme }

    struct Plan {
        var parts: [RenderPart] = []
        var height: CGFloat = 0
        var decorations: [(CGPoint) -> Void] = []
    }

    /// Where text and photo go in a header row. Without a photo the text gets the full width (no hole).
    struct Slot {
        let textX: CGFloat
        let textWidth: CGFloat
        let photoX: CGFloat
    }

    /// Header photo size: the template size times the user's small, medium or large choice,
    /// never so big that the text beside it gets narrower than 160 pt.
    var photoSize: CGFloat {
        let base: CGFloat = min(76, ctx.width * 0.2) * style.photoScale
        return max(36, min(base, ctx.width - 160 - 18))
    }

    var photoOnLeft: Bool { return placement == .headerLeft }

    func slot(width w: CGFloat, size: CGFloat, gap: CGFloat = 18, symmetric: Bool = false) -> Slot {
        guard photo != nil else { return Slot(textX: 0, textWidth: w, photoX: 0) }
        let reserve: CGFloat = size + gap
        if symmetric {
            return Slot(textX: reserve, textWidth: max(80, w - 2 * reserve), photoX: photoOnLeft ? 0 : w - size)
        }
        if photoOnLeft {
            return Slot(textX: reserve, textWidth: max(80, w - reserve), photoX: 0)
        }
        return Slot(textX: 0, textWidth: max(80, w - reserve), photoX: w - size)
    }

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
        case .monogramBadge:
            plan = planMonogram()
        case .accentRuleLeft:
            plan = planAccentRule()
        case .centeredAccent:
            plan = planCenteredAccent()
        case .doubleRule:
            plan = planDoubleRule()
        case .rightAligned:
            plan = planRightAligned()
        case .tintedCard:
            plan = planTintedCard()
        case .bannerCentered:
            plan = planBannerCentered()
        case .initialLetter:
            plan = planInitialLetter()
        case .smallCapsCentered:
            plan = planSmallCapsCentered()
        }
        return makeItem(plan)
    }

    private func makeItem(_ plan: Plan) -> RenderFlowItem? {
        guard plan.height > 0 else { return nil }
        let parts: [RenderPart] = plan.parts
        let decorations: [(CGPoint) -> Void] = plan.decorations
        let canvas: RenderCanvas = ctx.canvas
        return RenderFlowItem(height: ceil(plan.height), draw: { origin, _ in
            for decoration in decorations {
                decoration(origin)
            }
            for part in parts {
                let point = CGPoint(x: origin.x + part.x, y: origin.y + part.y)
                part.layout.draw(at: point)
                canvas.recordHeaderText(part.layout, at: point)
            }
        })
    }

    // MARK: Pieces

    func nameLayout(width: CGFloat, color: UIColor, alignment: NSTextAlignment, size: CGFloat? = nil, kern: CGFloat = 0,
                    bold: Bool = true, uppercase: Bool = false) -> RenderTextLayout? {
        let raw: String = RenderContent.trimmed(personal.fullName)
        guard !raw.isEmpty else { return nil }
        let name: String = uppercase ? raw.uppercased() : raw
        let font: UIFont = style.headingFont(size: size ?? style.nameSize, bold: bold)
        let textStyle = RenderTextStyle(font: font, color: color, leading: 1.0, alignment: alignment, kern: kern)
        return ctx.layout(RenderText.attributed(name, textStyle), width: width, links: [])
    }

    func titleLayout(width: CGFloat, color: UIColor, alignment: NSTextAlignment, smallCaps: Bool = false) -> RenderTextLayout? {
        let title: String = RenderContent.trimmed(personal.professionalTitle)
        guard !title.isEmpty else { return nil }
        let font: UIFont = smallCaps
            ? style.headingFont(size: style.bodySize * 1.05, bold: true)
            : style.bodyFont(size: style.bodySize * 1.2)
        let textStyle = RenderTextStyle(font: font, color: color, leading: 1.0, alignment: alignment, kern: smallCaps ? 1.2 : 0)
        let attr: NSAttributedString = smallCaps ? RenderText.smallCaps(title, textStyle) : RenderText.attributed(title, textStyle)
        return ctx.layout(attr, width: width, links: [])
    }

    func contactFlow(width: CGFloat, alignment: NSTextAlignment, color: UIColor? = nil, sepColor: UIColor? = nil) -> RenderPartsBlock? {
        let items = RenderContact.items(for: personal)
        guard !items.isEmpty else { return nil }
        let block = RenderContact.flow(items, ctx: ctx, width: width, alignment: alignment,
                                       font: style.bodyFont(size: style.smallSize), color: color ?? theme.muted,
                                       sepColor: sepColor ?? theme.rule)
        return block.height > 0 ? block : nil
    }

    func append(_ block: RenderPartsBlock, to plan: inout Plan, x: CGFloat, y: CGFloat) {
        for part in block.parts {
            plan.parts.append(RenderPart(layout: part.layout, x: part.x + x, y: part.y + y))
        }
    }

    func addPhoto(to plan: inout Plan, x: CGFloat, y: CGFloat, size: CGFloat, shape: RenderPhotoShape, ring: UIColor? = nil) {
        guard let image = photo else { return }
        let resolved: RenderPhotoShape = style.photoShape ?? shape
        let ringColor: UIColor? = style.photoRing ? (ring ?? theme.accent) : nil
        let canvas: RenderCanvas = ctx.canvas
        plan.decorations.append { origin in
            let rect = CGRect(x: origin.x + x, y: origin.y + y, width: size, height: size)
            RenderPhoto.draw(image, in: rect, shape: resolved, ring: ringColor)
            canvas.recordPhoto(rect)
        }
        plan.height = max(plan.height, y + size)
    }

    // MARK: Left aligned and centered

    private func planAligned(centered: Bool) -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let size: CGFloat = photoSize
        let photoOnTop: Bool = centered && placement == .headerCenter && photo != nil
        let s: Slot = photoOnTop ? Slot(textX: 0, textWidth: w, photoX: floor((w - size) / 2))
                                 : slot(width: w, size: size, symmetric: centered)
        let alignment: NSTextAlignment = centered ? .center : .natural
        var y: CGFloat = 0
        if photoOnTop {
            addPhoto(to: &plan, x: s.photoX, y: 0, size: size, shape: .circle)
            y = size + 12
        }

        if let name = nameLayout(width: s.textWidth, color: theme.ink, alignment: alignment) {
            plan.parts.append(RenderPart(layout: name, x: s.textX, y: y))
            y += name.height
        }
        if let title = titleLayout(width: s.textWidth, color: theme.accent, alignment: alignment) {
            y += y > 0 ? 3 : 0
            plan.parts.append(RenderPart(layout: title, x: s.textX, y: y))
            y += title.height
        }
        if let block = contactFlow(width: s.textWidth, alignment: alignment) {
            y += y > 0 ? 9 : 0
            append(block, to: &plan, x: s.textX, y: y)
            y += block.height
        }
        plan.height = max(plan.height, y)
        if !photoOnTop {
            addPhoto(to: &plan, x: s.photoX, y: 0, size: size, shape: centered ? .circle : .rounded)
        }
        return plan
    }

    // MARK: Banner

    private func planBanner() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let fill: UIColor = style.headerFill
        let foreground: UIColor = RenderColors.readable(on: fill, dark: style.ink)
        let bannerPhoto: CGFloat = photoSize + 4
        let s: Slot = slot(width: w, size: bannerPhoto)
        var y: CGFloat = 0

        if let name = nameLayout(width: s.textWidth, color: foreground, alignment: .natural) {
            plan.parts.append(RenderPart(layout: name, x: s.textX, y: 0))
            y = name.height
        }
        if let title = titleLayout(width: s.textWidth, color: foreground.withAlphaComponent(0.92), alignment: .natural) {
            y += y > 0 ? 3 : 0
            plan.parts.append(RenderPart(layout: title, x: s.textX, y: y))
            y += title.height
        }
        if let block = contactFlow(width: s.textWidth, alignment: .natural,
                                   color: foreground.withAlphaComponent(0.92), sepColor: foreground.withAlphaComponent(0.5)) {
            y += y > 0 ? 9 : 0
            append(block, to: &plan, x: s.textX, y: y)
            y += block.height
        }
        addPhoto(to: &plan, x: s.photoX, y: 0, size: bannerPhoto, shape: .circle, ring: foreground)
        let content: CGFloat = max(y, photo == nil ? 0 : bannerPhoto)
        guard content > 0 else { return plan }
        let total: CGFloat = content + 18
        plan.height = total
        addBandFill(to: &plan, fill: fill, total: total)
        return plan
    }

    /// Full-bleed band from the page top to `total` below the header origin.
    func addBandFill(to plan: inout Plan, fill: UIColor, total: CGFloat) {
        let left: CGFloat = bleedLeft
        let right: CGFloat = bleedRight
        plan.decorations.insert({ origin in
            RenderDraw.fill(CGRect(x: left, y: 0, width: max(0, right - left), height: origin.y + total), fill)
        }, at: 0)
    }

    // MARK: Split contact

    /// Name and title on the left, contact lines stacked on the right, photo in its slot. Shared with the tinted card.
    func splitContent(width w: CGFloat, contactColor: UIColor) -> Plan {
        var plan = Plan()
        let size: CGFloat = photoSize
        let s: Slot = slot(width: w, size: size, gap: 16)
        let contactWidth: CGFloat = min(s.textWidth * 0.42, 230)
        let contactX: CGFloat = s.textX + s.textWidth - contactWidth
        let leftWidth: CGFloat = max(80, s.textWidth - contactWidth - 18)
        var leftY: CGFloat = 0

        if let name = nameLayout(width: leftWidth, color: theme.ink, alignment: .natural) {
            plan.parts.append(RenderPart(layout: name, x: s.textX, y: 0))
            leftY = name.height
        }
        if let title = titleLayout(width: leftWidth, color: theme.accent, alignment: .natural) {
            leftY += leftY > 0 ? 3 : 0
            plan.parts.append(RenderPart(layout: title, x: s.textX, y: leftY))
            leftY += title.height
        }
        let items = RenderContact.items(for: personal)
        var rightY: CGFloat = 0
        if !items.isEmpty {
            let block = RenderContact.stack(items, ctx: ctx, width: contactWidth, alignment: .right,
                                            font: style.bodyFont(size: style.smallSize), color: contactColor, gap: 2.5)
            append(block, to: &plan, x: contactX, y: 4)
            rightY = block.height + 4
        }
        plan.height = max(leftY, rightY)
        addPhoto(to: &plan, x: s.photoX, y: 0, size: size, shape: .rounded)
        return plan
    }

    private func planSplit() -> Plan {
        let w: CGFloat = ctx.width
        var plan = splitContent(width: w, contactColor: theme.muted)
        let content: CGFloat = plan.height
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
        let size: CGFloat = photoSize
        let s: Slot = slot(width: w, size: size)
        var y: CGFloat = 0

        if let name = nameLayout(width: s.textWidth, color: theme.ink, alignment: .natural, kern: 0.6) {
            plan.parts.append(RenderPart(layout: name, x: s.textX, y: 0))
            y = name.height
        }
        if y > 0 {
            let ruleY: CGFloat = y + 7
            let accent: UIColor = theme.accent
            let ruleX: CGFloat = s.textX
            let ruleWidth: CGFloat = s.textWidth
            plan.decorations.append { origin in
                RenderDraw.fill(CGRect(x: origin.x + ruleX, y: origin.y + ruleY, width: ruleWidth, height: 2.2), accent)
            }
            y = ruleY + 2.2
        }
        if let title = titleLayout(width: s.textWidth, color: theme.accent, alignment: .natural, smallCaps: true) {
            y += y > 0 ? 8 : 0
            plan.parts.append(RenderPart(layout: title, x: s.textX, y: y))
            y += title.height
        }
        if let block = contactFlow(width: s.textWidth, alignment: .natural) {
            y += y > 0 ? 7 : 0
            append(block, to: &plan, x: s.textX, y: y)
            y += block.height
        }
        plan.height = y
        addPhoto(to: &plan, x: s.photoX, y: 0, size: size, shape: .rounded)
        return plan
    }

    // MARK: Monogram badge

    /// First letters of the first and last word of the name, at most two.
    var initials: String {
        let words = RenderContent.trimmed(personal.fullName).split(whereSeparator: { $0 == " " })
        guard let firstWord = words.first, let firstLetter = firstWord.first else { return "" }
        var out: String = String(firstLetter)
        if words.count > 1, let lastWord = words.last, let lastLetter = lastWord.first {
            out.append(lastLetter)
        }
        return out.uppercased()
    }

    /// Initials in an accent disc (the photo takes the disc's place when there is one), with name,
    /// title and contact set beside it and centered on the disc.
    private func planMonogram() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let badge: CGFloat = photo == nil ? min(max(style.nameSize * 1.75, 46), 64)
                                          : min(max(style.nameSize * 1.75, 46), 64) * style.photoScale
        let accent: UIColor = theme.accent
        let mark: String = initials

        var markLayout: RenderTextLayout? = nil
        var markFont: UIFont? = nil
        if photo == nil && !mark.isEmpty {
            let font: UIFont = style.headingFont(size: badge * 0.36, bold: true)
            let markColor: UIColor = RenderColors.readable(on: accent, dark: theme.ink)
            let markStyle = RenderTextStyle(font: font, color: markColor, leading: 1.0, alignment: .center, kern: 0)
            markLayout = ctx.layout(RenderText.attributed(mark, markStyle), width: badge, links: [])
            markFont = font
        }
        let hasBadge: Bool = photo != nil || markLayout != nil
        let textX: CGFloat = hasBadge ? badge + 16 : 0
        let textWidth: CGFloat = max(80, w - textX)

        var parts: [RenderPart] = []
        var y: CGFloat = 0
        if let name = nameLayout(width: textWidth, color: theme.ink, alignment: .natural) {
            parts.append(RenderPart(layout: name, x: textX, y: 0))
            y = name.height
        }
        if let title = titleLayout(width: textWidth, color: theme.accent, alignment: .natural) {
            y += y > 0 ? 3 : 0
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

        let shift: CGFloat = hasBadge ? max(0, floor((badge - y) / 2)) : 0
        for part in parts {
            plan.parts.append(RenderPart(layout: part.layout, x: part.x, y: part.y + shift))
        }
        plan.height = max(y + shift, hasBadge ? badge : 0)

        if photo != nil {
            addPhoto(to: &plan, x: 0, y: 0, size: badge, shape: .circle)
        } else if let layout = markLayout, let font = markFont {
            let markY: CGFloat = floor(badge / 2 - (layout.baseline(ofLine: 0) - font.capHeight / 2))
            plan.decorations.append { origin in
                RenderDraw.fillRounded(CGRect(x: origin.x, y: origin.y, width: badge, height: badge), radius: badge / 2, accent)
                layout.draw(at: CGPoint(x: origin.x, y: origin.y + markY), withLinks: false)
            }
        }
        return plan
    }

    // MARK: Accent rule left

    /// A thick accent bar runs down the left of the name, title and contact block.
    private func planAccentRule() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let barWidth: CGFloat = 4
        let inset: CGFloat = 16
        let size: CGFloat = photoSize
        let s: Slot = slot(width: w, size: size)
        let textX: CGFloat = s.textX + inset
        let textWidth: CGFloat = max(80, s.textWidth - inset)
        var y: CGFloat = 0

        if let name = nameLayout(width: textWidth, color: theme.ink, alignment: .natural) {
            plan.parts.append(RenderPart(layout: name, x: textX, y: 0))
            y = name.height
        }
        if let title = titleLayout(width: textWidth, color: theme.accent, alignment: .natural) {
            y += y > 0 ? 3 : 0
            plan.parts.append(RenderPart(layout: title, x: textX, y: y))
            y += title.height
        }
        if let block = contactFlow(width: textWidth, alignment: .natural) {
            y += y > 0 ? 8 : 0
            append(block, to: &plan, x: textX, y: y)
            y += block.height
        }
        plan.height = y
        if y > 0 {
            let accent: UIColor = theme.accent
            let barHeight: CGFloat = y
            let barX: CGFloat = s.textX
            plan.decorations.append { origin in
                RenderDraw.fill(CGRect(x: origin.x + barX, y: origin.y, width: barWidth, height: barHeight), accent)
            }
        }
        addPhoto(to: &plan, x: s.photoX, y: 0, size: size, shape: .rounded)
        return plan
    }

    // MARK: Centered accent

    /// Centered regular-weight name in the accent colour, a short rule, then a small caps title.
    private func planCenteredAccent() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let size: CGFloat = photoSize
        let photoOnTop: Bool = placement == .headerCenter && photo != nil
        let s: Slot = photoOnTop ? Slot(textX: 0, textWidth: w, photoX: floor((w - size) / 2))
                                 : slot(width: w, size: size, symmetric: true)
        var y: CGFloat = 0
        if photoOnTop {
            addPhoto(to: &plan, x: s.photoX, y: 0, size: size, shape: .circle)
            y = size + 12
        }

        if let name = nameLayout(width: s.textWidth, color: theme.accent, alignment: .center, kern: 0.5, bold: false) {
            plan.parts.append(RenderPart(layout: name, x: s.textX, y: y))
            y += name.height
        }
        if y > 0 {
            let ruleWidth: CGFloat = 36
            let ruleY: CGFloat = y + 7
            let ruleX: CGFloat = floor((w - ruleWidth) / 2)
            let accent: UIColor = theme.accent
            plan.decorations.append { origin in
                RenderDraw.fill(CGRect(x: origin.x + ruleX, y: origin.y + ruleY, width: ruleWidth, height: 1), accent)
            }
            y = ruleY + 1
        }
        if let title = titleLayout(width: s.textWidth, color: theme.ink, alignment: .center, smallCaps: true) {
            y += y > 0 ? 8 : 0
            plan.parts.append(RenderPart(layout: title, x: s.textX, y: y))
            y += title.height
        }
        if let block = contactFlow(width: s.textWidth, alignment: .center) {
            y += y > 0 ? 7 : 0
            append(block, to: &plan, x: s.textX, y: y)
            y += block.height
        }
        plan.height = max(plan.height, y)
        if !photoOnTop {
            addPhoto(to: &plan, x: s.photoX, y: 0, size: size, shape: .circle)
        }
        return plan
    }

    // MARK: Double rule

    /// A hairline above a regular-weight name, and a thick-and-thin rule closing the header.
    private func planDoubleRule() -> Plan {
        var plan = Plan()
        let w: CGFloat = ctx.width
        let accent: UIColor = theme.accent
        let size: CGFloat = photoSize
        let s: Slot = slot(width: w, size: size)
        let topRule: CGFloat = 0.8
        let top: CGFloat = topRule + 12
        var y: CGFloat = top

        if let name = nameLayout(width: s.textWidth, color: theme.ink, alignment: .natural, kern: 0.4, bold: false) {
            plan.parts.append(RenderPart(layout: name, x: s.textX, y: y))
            y += name.height
        }
        if let title = titleLayout(width: s.textWidth, color: theme.accent, alignment: .natural, smallCaps: true) {
            y += 5
            plan.parts.append(RenderPart(layout: title, x: s.textX, y: y))
            y += title.height
        }
        if let block = contactFlow(width: s.textWidth, alignment: .natural) {
            y += 7
            append(block, to: &plan, x: s.textX, y: y)
            y += block.height
        }
        guard y > top || photo != nil else { return plan }
        addPhoto(to: &plan, x: s.photoX, y: top, size: size, shape: .rounded)
        y = max(y, plan.height)

        let thickY: CGFloat = y + 10
        let thinY: CGFloat = thickY + 2.2 + 2
        plan.decorations.append { origin in
            RenderDraw.fill(CGRect(x: origin.x, y: origin.y, width: w, height: topRule), accent)
            RenderDraw.fill(CGRect(x: origin.x, y: origin.y + thickY, width: w, height: 2.2), accent)
            RenderDraw.fill(CGRect(x: origin.x, y: origin.y + thinY, width: w, height: 0.6), accent)
        }
        plan.height = thinY + 0.6
        return plan
    }
}
