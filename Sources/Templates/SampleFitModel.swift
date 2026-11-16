import Foundation

/// A pure-arithmetic height model of `DocumentRenderer` for an A4 page. `SampleContent` uses it to trim
/// sample resumes so each one fits the page count its template declares, without rendering anything.
///
/// The numbers mirror the renderer's geometry (column widths, gutters, gaps) and were calibrated
/// against the CI renders: average glyph widths per font come from the exported PDFs, and line height
/// follows `RenderText.paragraphStyle` (size times line spacing times 1.12, or the font's own taller line).
/// It errs on the tall side, so a sample may fall a little short of a full page but should not spill over.
struct SampleFitModel {
    let template: TemplateSpec
    let contentWidth: Double
    let mainWidth: Double
    let sideWidth: Double
    let usableHeight: Double
    /// Width of the sidebar fill band (sidebar layouts only).
    let bandWidth: Double
    private let sideKinds: Set<SectionKind>

    init(template: TemplateSpec) {
        self.template = template
        let pageWidth: Double = 595.28
        let pageHeight: Double = 841.89
        let content: Double = pageWidth - 2 * template.marginSide
        let fraction: Double = min(max(template.sidebarFraction, 0.2), 0.4)
        var side: Double = min(max(content * fraction, 110), 230)
        let edge: Double = max(20, template.marginSide * 0.75)
        var main: Double
        switch template.layout {
        case .sidebarLeft:
            main = pageWidth - template.marginSide - (edge + side + 18 + 24)
        case .sidebarRight:
            main = (pageWidth - edge - side - 18) - 24 - template.marginSide
        case .headerThenTwoColumn:
            main = content - side - 24
        case .singleColumn:
            main = content
            side = 0
        }
        self.contentWidth = content
        self.bandWidth = edge + side + 18
        self.mainWidth = max(120, main)
        self.sideWidth = side
        self.usableHeight = pageHeight - template.marginTop - template.marginBottom
        self.sideKinds = template.layout == .singleColumn ? [] : Set(template.sidebarSections)
    }

    func isInSidebar(_ kind: SectionKind) -> Bool {
        return sideKinds.contains(kind)
    }

    // MARK: Totals

    /// Estimated content height of the main column (header included) and of the sidebar or rail.
    func load(_ sections: [ResumeSection]) -> (main: Double, side: Double) {
        var main: Double = headerHeight()
        if main > 0 {
            main += max(10, template.sectionSpacing * 0.9) - template.sectionSpacing
        }
        var side: Double = 0
        if template.header == .sidebarCard {
            let base: Double = template.baseSize
            // Previews show a portrait silhouette on photo templates, so the photo is always counted.
            var photo: Double = 0
            if template.photo == .sidebarBleed {
                photo = max(0, min(bandWidth * 0.82, 260) - template.marginTop) + 14 + 12
            } else if template.photo == .sidebarTop {
                photo = 92 + 12
            }
            side += photo + 24 * 1.25 + 4 + base * 1.5 + 6 * base * 1.4
        }
        for section in sections {
            if isInSidebar(section.kind) {
                side += sectionHeight(section, width: sideWidth)
            } else {
                main += sectionHeight(section, width: mainWidth)
            }
        }
        return (main, side)
    }

    // MARK: Fonts

    /// Average advance of a lower-case-heavy text glyph as a share of the point size, measured from CI PDFs.
    private static func charWidth(_ font: FontChoice) -> Double {
        switch font {
        case .sfPro: return 0.49
        case .newYork, .iowanOldStyle: return 0.495
        case .helveticaNeue: return 0.452
        case .avenirNext: return 0.50
        case .georgia: return 0.447
        case .palatino: return 0.452
        case .baskerville: return 0.445
        case .hoeflerText: return 0.426
        case .charter: return 0.442
        case .gillSans: return 0.414
        case .optima: return 0.434
        case .cochin: return 0.43
        case .didot: return 0.45
        case .futura: return 0.47
        case .menlo: return 0.602
        }
    }

    /// Fonts whose natural line is taller than the requested leading.
    private static func naturalLineHeight(_ font: FontChoice) -> Double {
        switch font {
        case .avenirNext: return 1.366
        case .futura: return 1.34
        case .helveticaNeue: return 1.22
        case .menlo: return 1.17
        case .sfPro, .newYork, .georgia, .palatino, .baskerville, .hoeflerText, .charter, .iowanOldStyle,
             .gillSans, .optima, .cochin, .didot:
            return 1.0
        }
    }

    private func lineHeight(_ size: Double) -> Double {
        return size * max(template.lineSpacing * 1.12, SampleFitModel.naturalLineHeight(template.bodyFont))
    }

    private func lines(_ text: String, width: Double, size: Double, bold: Bool = false) -> Double {
        guard !text.isEmpty else { return 0 }
        let glyph: Double = size * SampleFitModel.charWidth(template.bodyFont) * (bold ? 1.08 : 1.0)
        let perLine: Double = max(8, floor(width / max(1, glyph)))
        return max(1, ceil(Double(text.count) * 1.06 / perLine))
    }

    // MARK: Header

    /// Header photo edge, as `RenderHeaderBuilder.photoSize` computes it at the default size.
    private var headerPhoto: Double {
        guard template.photo != .none, !template.photo.isSidebar else { return 0 }
        return min(76, contentWidth * 0.2)
    }

    private func headerHeight() -> Double {
        let text: Double = headerTextHeight()
        let photo: Double = headerPhoto
        guard photo > 0 else { return text }
        switch template.header {
        case .centered, .centeredAccent:
            return template.photo == .headerCenter ? text + photo + 12 : max(text, photo)
        case .bannerCentered:
            return text + photo + 4 + 12
        case .banner:
            return max(text, photo + 4 + 18)
        case .tintedCard:
            return max(text, photo + 32)
        case .initialLetter:
            return max(text, photo * 1.1)
        default:
            return max(text, photo + 12)
        }
    }

    private func headerTextHeight() -> Double {
        let name: Double = template.nameSize * 1.25
        let title: Double = template.baseSize * 1.2 * 1.25
        let contact: Double = template.baseSize * 0.92 * 1.35
        switch template.header {
        case .sidebarCard:
            return 0
        case .splitContact:
            return max(name + title + 3, 4 * contact + 4) + 10
        case .monogramBadge:
            let badge: Double = min(max(template.nameSize * 1.75, 46), 64)
            return max(badge, name + title + contact + 10)
        case .leftAligned, .centered:
            return name + title + contact + 12
        case .banner:
            return name + title + contact + 30
        case .ruledMonogram:
            return name + title + contact + 26
        case .accentRuleLeft:
            return name + title + contact + 11
        case .centeredAccent:
            return name + title + contact + 24
        case .doubleRule:
            return name + title + contact + 48
        case .rightAligned:
            return name + title + contact + 24
        case .tintedCard:
            return max(name + title + 3, 4 * contact + 4) + 32
        case .bannerCentered:
            return name + title + contact + 36
        case .initialLetter:
            return max(template.nameSize * 2.5 * 1.25, name + title + contact + 11)
        case .smallCapsCentered:
            return min(template.nameSize, 26) * 1.25 + title + contact + 38
        }
    }

    // MARK: Sections

    private func headingHeight() -> Double {
        let extra: Double
        switch template.headingStyle {
        case .uppercaseRule: extra = 10
        case .smallCapsAccent: extra = 5
        case .accentBar: extra = 13
        case .boxedLabel: extra = 12
        case .plainBold: extra = 5
        case .sideLabel: extra = 0
        case .dottedRule: extra = 6
        case .underlineAccent: extra = 12
        case .centeredRule: extra = 7
        case .leftBorder: extra = 8
        case .tintedBand: extra = 14
        case .fullBar: extra = 17
        case .ruleAbove: extra = 12
        }
        return template.headingSize * 1.25 + extra
    }

    func sectionHeight(_ section: ResumeSection, width: Double) -> Double {
        let base: Double = template.baseSize
        let line: Double = lineHeight(base)
        let sideLabel: Bool = template.headingStyle == .sideLabel && width >= 300
        let inner: Double = sideLabel ? width - max(width * 0.18, 110) : width
        var h: Double = 0

        if !section.text.isEmpty {
            h += lines(section.text, width: inner, size: base) * line
        }
        for entry in section.entries {
            h += (h > 0 ? template.entrySpacing : 0) + entryHeight(entry, width: inner)
        }
        if !section.skillGroups.isEmpty {
            let groupGap: Double = max(2.5, base * 0.35)
            if h > 0 { h += template.entrySpacing }
            for (i, group) in section.skillGroups.enumerated() {
                let list: String = group.items.joined(separator: ", ")
                let named: Bool = !group.name.isEmpty
                let groupHeight: Double
                if template.skillStyle == .pills {
                    groupHeight = pillHeight(group, width: inner)
                } else if template.skillStyle == .bulletColumns && inner >= 250 {
                    let rows: Double = ceil(Double(group.items.count) / 2)
                    groupHeight = (named ? line + 1.5 : 0) + rows * line + max(0, rows - 1) * 2
                } else if template.skillStyle == .groupedLines && inner >= 250 && named {
                    groupHeight = lines(list, width: inner * 0.72, size: base) * line
                } else if template.skillStyle == .groupedLines && inner < 250 && named {
                    groupHeight = line + 1 + lines(list, width: inner, size: base) * line
                } else {
                    groupHeight = lines((named ? group.name + ": " : "") + list, width: inner, size: base) * line
                }
                h += (i > 0 ? groupGap : 0) + groupHeight
            }
        }
        if sideLabel {
            return template.sectionSpacing + h
        }
        return template.sectionSpacing + headingHeight() + h
    }

    private func entryHeight(_ entry: ResumeEntry, width: Double) -> Double {
        let base: Double = template.baseSize
        let line: Double = lineHeight(base)
        let small: Double = lineHeight(base * 0.92)
        var layout: EntryLayout = template.entryLayout
        if layout == .dateRight && width < 250 { layout = .dateBelow }
        if layout == .dateGutter && width < 320 { layout = .dateBelow }
        if layout == .timeline && width < 300 { layout = .dateBelow }

        let head: String = entry.heading.isEmpty ? entry.subheading : entry.heading
        let sub: String = entry.heading.isEmpty ? "" : entry.subheading
        var bodyWidth: Double = width
        var h: Double
        switch layout {
        case .dateRight:
            h = lines(head, width: width * 0.7, size: base, bold: true) * line
            h += (!sub.isEmpty || !entry.location.isEmpty) ? line + 1.5 : 0
        case .dateBelow:
            let meta: String = [sub, entry.location, "Jan 2020 - Dec 2024"].filter { !$0.isEmpty }.joined(separator: " · ")
            h = lines(head, width: width, size: base, bold: true) * line
            h += lines(meta, width: width, size: base * 0.95) * small + 1.5
        case .stacked:
            h = lines(head, width: width, size: base, bold: true) * line
            h += (sub.isEmpty ? 0 : line + 1) + small + 1
        case .dateGutter:
            let gutter: Double = min(max(width * 0.22, 72), 100)
            bodyWidth = width - gutter
            h = lines(head, width: bodyWidth, size: base, bold: true) * line
            h += (!sub.isEmpty || !entry.location.isEmpty) ? line + 1.5 : 0
        case .timeline:
            let gutter: Double = min(max(width * 0.21, 84), 108)
            bodyWidth = width - gutter - 4
            // The date can wrap to two lines in the gutter.
            h = max(lines(head, width: bodyWidth, size: base, bold: true) * line, 2 * small)
            h += (!sub.isEmpty || !entry.location.isEmpty) ? line + 1.5 : 0
        }
        if !entry.extra.isEmpty {
            h += lines(entry.extra, width: bodyWidth, size: base * 0.92) * small + 1.5
        }
        if !entry.detail.isEmpty {
            h += 2.5 + lines(entry.detail, width: bodyWidth, size: base) * line
        }
        let indent: Double = template.bullets == .none ? 0 : max(11, base * 1.5)
        let bulletGap: Double = max(1.5, base * 0.22)
        for (i, bullet) in entry.bullets.enumerated() {
            h += (i == 0 ? 2.5 : bulletGap) + lines(bullet, width: bodyWidth - indent, size: base) * line
        }
        return h
    }

    /// Rows of skill pills, each pill padded 7 pt either side with 5 pt gaps.
    private func pillHeight(_ group: SkillGroup, width: Double) -> Double {
        let small: Double = template.baseSize * 0.92
        let glyph: Double = small * SampleFitModel.charWidth(template.bodyFont)
        var total: Double = 0
        for item in group.items {
            total += Double(item.count) * glyph + 14 + 5
        }
        let rows: Double = max(1, ceil(total * 1.12 / max(60, width)))
        let rowHeight: Double = lineHeight(small) + 5
        let label: Double = group.name.isEmpty ? 0 : lineHeight(template.baseSize) + 3
        return label + rows * rowHeight + (rows - 1) * 5
    }
}
