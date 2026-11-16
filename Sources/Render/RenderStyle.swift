import UIKit

/// Colours used by one column. The sidebar flips ink and fill.
struct RenderTheme {
    let ink: UIColor
    let muted: UIColor
    let accent: UIColor
    let rule: UIColor
    /// Text colour on a chip filled with `accent`.
    let chipText: UIColor
    let isSidebar: Bool
}

/// Template values with the user's overrides applied. Pure value type, safe on any thread.
struct RenderStyle {
    let pageSize: CGSize
    let marginTop: CGFloat
    let marginSide: CGFloat
    let marginBottom: CGFloat
    let scale: CGFloat
    /// Line height multiplier (template times user setting).
    let leading: CGFloat
    let headingChoice: FontChoice
    let bodyChoice: FontChoice
    let bodySize: CGFloat
    let smallSize: CGFloat
    let nameSize: CGFloat
    let headingSize: CGFloat
    let uppercaseHeadings: Bool
    let headingKern: CGFloat
    let sectionGap: CGFloat
    let entryGap: CGFloat
    let accent: UIColor
    let ink: UIColor
    let muted: UIColor
    let sidebarFill: UIColor
    let sidebarInk: UIColor
    let headerFill: UIColor
    /// User choice for heading capitals. nil keeps each heading style's own rule.
    var headingCaseOverride: Bool? = nil
    /// User choice for the photo crop. nil keeps the shape each header style uses.
    var photoShape: RenderPhotoShape? = nil
    /// User choice for entry dates. nil keeps "Jan 2024".
    var dateFormat: ResumeDateFormat? = nil

    // MARK: Fonts

    func bodyFont(size: CGFloat? = nil, bold: Bool = false, italic: Bool = false) -> UIFont {
        return RenderFonts.font(bodyChoice, size: size ?? bodySize, bold: bold, italic: italic)
    }

    func headingFont(size: CGFloat? = nil, bold: Bool = true, italic: Bool = false) -> UIFont {
        return RenderFonts.font(headingChoice, size: size ?? headingSize, bold: bold, italic: italic)
    }

    // MARK: Themes

    var mainTheme: RenderTheme {
        return RenderTheme(ink: ink,
                           muted: muted,
                           accent: accent,
                           rule: muted.withAlphaComponent(0.45),
                           chipText: RenderColors.readable(on: accent, dark: ink),
                           isSidebar: false)
    }

    var sidebarTheme: RenderTheme {
        return RenderTheme(ink: sidebarInk,
                           muted: RenderColors.mix(sidebarInk, sidebarFill, 0.22),
                           accent: sidebarInk,
                           rule: sidebarInk.withAlphaComponent(0.35),
                           chipText: sidebarFill,
                           isSidebar: true)
    }

    // MARK: Factories

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> CGFloat {
        return CGFloat(min(max(value, low), high))
    }

    static func make(template: TemplateSpec, overrides: StyleOverrides, pageSize: CGSize) -> RenderStyle {
        let scale: CGFloat = clamp(overrides.fontScale, 0.7, 1.4)
        let leading: CGFloat = clamp(template.lineSpacing, 0.9, 1.6) * clamp(overrides.lineSpacing, 0.8, 1.6)

        var side = CGFloat(template.marginSide)
        var top = CGFloat(template.marginTop)
        var bottom = CGFloat(template.marginBottom)
        if let custom = overrides.marginPoints {
            let value: CGFloat = clamp(custom, 14, 80)
            side = value
            top = value
            bottom = value
        }
        side = min(max(side, 14), (pageSize.width - 240) / 2)
        top = max(top, 18)
        bottom = max(bottom, 18)

        let accentHex: String = overrides.accentHex ?? template.accentHex
        let accent = UIColor(hexString: accentHex)
        let ink = UIColor(hexString: template.textHex)
        let muted = UIColor(hexString: template.mutedHex)
        let accentChanged: Bool = overrides.accentHex != nil

        let sidebarFill: UIColor
        if let hex = template.sidebarFillHex {
            if accentChanged && RenderColors.sameHex(hex, template.accentHex) {
                sidebarFill = accent
            } else {
                sidebarFill = UIColor(hexString: hex)
            }
        } else {
            sidebarFill = RenderColors.mix(UIColor.white, accent, 0.10)
        }
        let sidebarInk: UIColor
        if let hex = template.sidebarTextHex {
            sidebarInk = UIColor(hexString: hex)
        } else {
            sidebarInk = RenderColors.readable(on: sidebarFill, dark: ink)
        }
        let headerFill: UIColor
        if let hex = template.headerFillHex {
            if accentChanged && RenderColors.sameHex(hex, template.accentHex) {
                headerFill = accent
            } else {
                headerFill = UIColor(hexString: hex)
            }
        } else {
            headerFill = accent
        }

        let body: CGFloat = max(6, CGFloat(template.baseSize) * scale)
        var result = RenderStyle(pageSize: pageSize,
                                 marginTop: top,
                                 marginSide: side,
                                 marginBottom: bottom,
                                 scale: scale,
                                 leading: leading,
                                 headingChoice: overrides.headingFont ?? template.headingFont,
                                 bodyChoice: overrides.bodyFont ?? template.bodyFont,
                                 bodySize: body,
                                 smallSize: body * 0.92,
                                 nameSize: max(12, CGFloat(template.nameSize) * scale),
                                 headingSize: max(7, CGFloat(template.headingSize) * scale),
                                 uppercaseHeadings: template.uppercaseHeadings,
                                 headingKern: CGFloat(template.letterSpacingHeadings),
                                 sectionGap: CGFloat(template.sectionSpacing) * scale,
                                 entryGap: CGFloat(template.entrySpacing) * scale,
                                 accent: accent,
                                 ink: ink,
                                 muted: muted,
                                 sidebarFill: sidebarFill,
                                 sidebarInk: sidebarInk,
                                 headerFill: headerFill)
        result.headingCaseOverride = overrides.uppercaseHeadings
        result.photoShape = RenderPhotoShape.from(overrides.photoShape)
        result.dateFormat = overrides.dateFormat
        return result
    }

    static func make(letter: CoverLetterTemplateSpec, overrides: StyleOverrides, pageSize: CGSize) -> RenderStyle {
        let scale: CGFloat = clamp(overrides.fontScale, 0.7, 1.4)
        let leading: CGFloat = clamp(letter.lineSpacing, 0.9, 1.6) * clamp(overrides.lineSpacing, 0.8, 1.6)

        var side = CGFloat(letter.marginSide)
        var top = CGFloat(letter.marginTop)
        var bottom = CGFloat(letter.marginBottom)
        if let custom = overrides.marginPoints {
            let value: CGFloat = clamp(custom, 14, 90)
            side = value
            top = value
            bottom = value
        }
        side = min(max(side, 14), (pageSize.width - 240) / 2)
        top = max(top, 18)
        bottom = max(bottom, 18)

        let accentHex: String = overrides.accentHex ?? letter.accentHex
        let accent = UIColor(hexString: accentHex)
        let ink = UIColor(hexString: TemplateSpec.normalizedHex(overrides.textHex) ?? letter.textHex)
        let muted = UIColor(hexString: letter.mutedHex)
        let headerFill: UIColor
        if let custom = TemplateSpec.normalizedHex(overrides.headerFillHex) {
            headerFill = UIColor(hexString: custom)
        } else if let hex = letter.headerFillHex {
            if overrides.accentHex != nil && RenderColors.sameHex(hex, letter.accentHex) {
                headerFill = accent
            } else {
                headerFill = UIColor(hexString: hex)
            }
        } else {
            headerFill = accent
        }

        let body: CGFloat = max(6, CGFloat(letter.baseSize) * scale)
        let nameFactor: CGFloat = clamp(overrides.nameScale, StyleOverrides.nameScaleRange.lowerBound, StyleOverrides.nameScaleRange.upperBound)
        let paragraphFactor: CGFloat = clamp(overrides.sectionSpacing, StyleOverrides.spacingRange.lowerBound, StyleOverrides.spacingRange.upperBound)
        return RenderStyle(pageSize: pageSize,
                           marginTop: top,
                           marginSide: side,
                           marginBottom: bottom,
                           scale: scale,
                           leading: leading,
                           headingChoice: overrides.headingFont ?? letter.headingFont,
                           bodyChoice: overrides.bodyFont ?? letter.bodyFont,
                           bodySize: body,
                           smallSize: body * 0.92,
                           nameSize: max(12, CGFloat(letter.nameSize) * scale * nameFactor),
                           headingSize: body,
                           uppercaseHeadings: false,
                           headingKern: 0,
                           sectionGap: CGFloat(letter.paragraphSpacing) * scale * paragraphFactor,
                           entryGap: CGFloat(letter.paragraphSpacing) * scale * paragraphFactor,
                           accent: accent,
                           ink: ink,
                           muted: muted,
                           sidebarFill: RenderColors.mix(UIColor.white, accent, 0.10),
                           sidebarInk: ink,
                           headerFill: headerFill)
    }
}

/// Everything a builder needs: resolved style, the column theme, the column width and shared helpers.
struct RenderContext {
    let style: RenderStyle
    let theme: RenderTheme
    let width: CGFloat
    let canvas: RenderCanvas
    let detector: RenderLinkDetector?

    /// Measures text. Pass explicit `links` to control annotations; `[]` turns them off.
    func layout(_ text: NSAttributedString,
                width w: CGFloat,
                links: [RenderLinkSpan]? = nil,
                autoLinks: Bool = true) -> RenderTextLayout {
        let finder: RenderLinkDetector? = (links == nil && autoLinks) ? detector : nil
        return RenderTextLayout(text, width: w, canvas: canvas, links: links, detector: finder)
    }

    func withWidth(_ w: CGFloat) -> RenderContext {
        return RenderContext(style: style, theme: theme, width: w, canvas: canvas, detector: detector)
    }
}
