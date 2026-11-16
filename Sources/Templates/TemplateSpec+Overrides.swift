import Foundation

/// Applies the user's structural and colour overrides to a template. This is the single place where
/// `StyleOverrides` changes a `TemplateSpec`; `DocumentRenderer` calls it once per render, so the live
/// preview and the exported PDF always agree.
///
/// Fonts, accent colour, text size, line spacing, margins, photo shape and date format stay in
/// `RenderStyle.make`, which reads them straight from the overrides.
extension TemplateSpec {
    /// Header styles the style panel offers. `sidebarCard` belongs to the sidebar templates only.
    static let offeredHeaderStyles: [HeaderStyle] = [.leftAligned, .centered, .splitContact, .ruledMonogram, .banner,
                                                     .monogramBadge, .accentRuleLeft, .centeredAccent, .doubleRule]
    static let offeredHeadingStyles: [SectionHeadingStyle] = [.uppercaseRule, .smallCapsAccent, .accentBar, .boxedLabel, .plainBold, .dottedRule, .sideLabel,
                                                              .underlineAccent, .centeredRule, .leftBorder, .tintedBand]
    static let offeredEntryLayouts: [EntryLayout] = [.dateRight, .dateBelow, .dateGutter, .stacked]
    static let offeredBullets: [BulletStyle] = [.disc, .dash, .square, .chevron, .none]
    static let offeredSkillStyles: [SkillStyle] = [.commaList, .pipeList, .groupedLines, .bulletColumns]

    /// True for layouts with a tinted full height sidebar.
    var hasSidebarColumn: Bool {
        return layout == .sidebarLeft || layout == .sidebarRight
    }

    /// Whether a header style can be used with this template without losing content or breaking layout.
    func supportsHeader(_ style: HeaderStyle) -> Bool {
        switch style {
        case .sidebarCard: return hasSidebarColumn
        case .banner: return !hasSidebarColumn
        default: return true
        }
    }

    /// The editorial side label needs the full page width.
    func supportsHeading(_ style: SectionHeadingStyle) -> Bool {
        if style == .sideLabel { return layout == .singleColumn }
        return true
    }

    /// Returns "#RRGGBB" for valid input ("#rrggbb" or "rrggbb"), otherwise nil.
    static func normalizedHex(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let cleaned: String = raw.trimmingCharacters(in: CharacterSet(charactersIn: "# \n\t")).uppercased()
        guard cleaned.count == 6 else { return nil }
        let allowed: Set<Character> = Set("0123456789ABCDEF")
        guard cleaned.allSatisfy({ allowed.contains($0) }) else { return nil }
        return "#" + cleaned
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        guard value.isFinite else { return 1.0 }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// The effective template for these overrides. Call it once on the template from the library,
    /// not on a spec that was already adjusted (spacing and name size are multipliers).
    func applying(_ o: StyleOverrides) -> TemplateSpec {
        // Sidebar side.
        var newLayout: PageLayout = layout
        if hasSidebarColumn, let side = o.sidebarPosition {
            newLayout = side == .left ? .sidebarLeft : .sidebarRight
        }

        // Header. Invalid combinations keep the template header.
        var newHeader: HeaderStyle = header
        if let wanted = o.headerStyle, supportsHeader(wanted) {
            newHeader = wanted
        }
        // A photo that lived in the sidebar card moves to the header when the card is replaced.
        var newPhoto: PhotoPlacement = photo
        if photo == .sidebarTop && newHeader != .sidebarCard {
            newPhoto = .headerRight
        }

        var newHeading: SectionHeadingStyle = headingStyle
        if let wanted = o.headingStyle, supportsHeading(wanted) {
            newHeading = wanted
        }

        // Colours. Bad hex values are ignored.
        let newText: String = TemplateSpec.normalizedHex(o.textHex) ?? textHex
        var newSidebarFill: String? = sidebarFillHex
        var newSidebarText: String? = sidebarTextHex
        if hasSidebarColumn, let fill = TemplateSpec.normalizedHex(o.sidebarFillHex) {
            newSidebarFill = fill
            // Let the renderer pick readable text for the new fill.
            newSidebarText = nil
        }
        let newHeaderFill: String? = TemplateSpec.normalizedHex(o.headerFillHex) ?? headerFillHex

        let sectionFactor: Double = TemplateSpec.clamp(o.sectionSpacing, StyleOverrides.spacingRange)
        let entryFactor: Double = TemplateSpec.clamp(o.entrySpacing, StyleOverrides.spacingRange)
        let nameFactor: Double = TemplateSpec.clamp(o.nameScale, StyleOverrides.nameScaleRange)

        return TemplateSpec(
            id: id,
            name: name,
            category: category,
            tagline: tagline,
            industries: industries,
            levels: levels,
            designStyle: designStyle,
            isATSFriendly: isATSFriendly,
            typicalPages: typicalPages,
            layout: newLayout,
            sidebarFraction: sidebarFraction,
            header: newHeader,
            headingStyle: newHeading,
            entryLayout: o.entryLayout ?? entryLayout,
            bullets: o.bullets ?? bullets,
            skillStyle: o.skillStyle ?? skillStyle,
            photo: newPhoto,
            headingFont: headingFont,
            bodyFont: bodyFont,
            baseSize: baseSize,
            nameSize: nameSize * nameFactor,
            headingSize: headingSize,
            lineSpacing: lineSpacing,
            uppercaseHeadings: o.uppercaseHeadings ?? uppercaseHeadings,
            letterSpacingHeadings: letterSpacingHeadings,
            accentHex: accentHex,
            textHex: newText,
            mutedHex: mutedHex,
            sidebarFillHex: newSidebarFill,
            sidebarTextHex: newSidebarText,
            headerFillHex: newHeaderFill,
            marginTop: marginTop,
            marginSide: marginSide,
            marginBottom: marginBottom,
            sectionSpacing: sectionSpacing * sectionFactor,
            entrySpacing: entrySpacing * entryFactor,
            mainSections: mainSections,
            sidebarSections: sidebarSections
        )
    }
}
