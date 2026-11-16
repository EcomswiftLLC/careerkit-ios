import Foundation

// MARK: - Cover letter template library
//
// Ten free cover letter designs. Each one pairs with a resume template and copies
// that template's fonts, accent and text colours so the two documents look like one set.
// All six header layouts are used at least once.

enum CoverLetterTemplateLibrary {

    /// Exactly 10 templates in browse order.
    static let all: [CoverLetterTemplateSpec] = [
        executive,
        corporate,
        classic,
        minimal,
        elegant,
        grid,
        editorial,
        academic,
        marketing,
        engineer,
    ]

    /// Looks up a cover letter template by id. Returns nil for an unknown id.
    static func spec(id: String) -> CoverLetterTemplateSpec? {
        return byID[id]
    }

    private static let byID: [String: CoverLetterTemplateSpec] = {
        var map: [String: CoverLetterTemplateSpec] = [:]
        for template in all { map[template.id] = template }
        return map
    }()

    /// The cover letter design that matches a resume template, if one exists.
    static func spec(matchingResumeTemplateID resumeTemplateID: String) -> CoverLetterTemplateSpec? {
        return all.first { $0.matchingResumeTemplateID == resumeTemplateID }
    }

    // MARK: Designs

    private static let executive = CoverLetterTemplateSpec(
        id: "ck.letter.executive", name: "Executive",
        tagline: "Large name over a fine rule, with contact details on one line.",
        header: .letterhead, headingFont: .baskerville, bodyFont: .charter,
        baseSize: 11, nameSize: 28, lineSpacing: 1.28,
        accentHex: "#1B2A4A", textHex: "#1A1D24", mutedHex: "#545C68", headerFillHex: nil,
        marginTop: 64, marginSide: 66, marginBottom: 60, paragraphSpacing: 11,
        matchingResumeTemplateID: "ck.professional.executive"
    )

    private static let corporate = CoverLetterTemplateSpec(
        id: "ck.letter.corporate", name: "Corporate",
        tagline: "Sender block at the top left, set in one sans-serif family.",
        header: .leftBlock, headingFont: .helveticaNeue, bodyFont: .helveticaNeue,
        baseSize: 10.5, nameSize: 22, lineSpacing: 1.26,
        accentHex: "#1D4E89", textHex: "#1B1F27", mutedHex: "#545E6B", headerFillHex: nil,
        marginTop: 60, marginSide: 64, marginBottom: 56, paragraphSpacing: 10,
        matchingResumeTemplateID: "ck.professional.corporate"
    )

    private static let classic = CoverLetterTemplateSpec(
        id: "ck.letter.classic", name: "Classic",
        tagline: "Centered name and address block in a traditional serif.",
        header: .centered, headingFont: .palatino, bodyFont: .palatino,
        baseSize: 11, nameSize: 26, lineSpacing: 1.3,
        accentHex: "#6E1F2B", textHex: "#221A1C", mutedHex: "#645A5C", headerFillHex: nil,
        marginTop: 66, marginSide: 70, marginBottom: 62, paragraphSpacing: 12,
        matchingResumeTemplateID: "ck.professional.classic-professional"
    )

    private static let minimal = CoverLetterTemplateSpec(
        id: "ck.letter.minimal", name: "Minimal",
        tagline: "Sender details aligned to the right, with wide margins.",
        header: .rightBlock, headingFont: .futura, bodyFont: .avenirNext,
        baseSize: 10.5, nameSize: 24, lineSpacing: 1.3,
        accentHex: "#155E63", textHex: "#16191C", mutedHex: "#596068", headerFillHex: nil,
        marginTop: 68, marginSide: 72, marginBottom: 64, paragraphSpacing: 12,
        matchingResumeTemplateID: "ck.modern.modern-minimal"
    )

    private static let elegant = CoverLetterTemplateSpec(
        id: "ck.letter.elegant", name: "Elegant",
        tagline: "A thin rosewood rule beside the sender block.",
        header: .sideRule, headingFont: .cochin, bodyFont: .hoeflerText,
        baseSize: 11, nameSize: 26, lineSpacing: 1.3,
        accentHex: "#7B2D45", textHex: "#241C1F", mutedHex: "#62575B", headerFillHex: nil,
        marginTop: 64, marginSide: 68, marginBottom: 60, paragraphSpacing: 11,
        matchingResumeTemplateID: "ck.modern.elegant"
    )

    private static let grid = CoverLetterTemplateSpec(
        id: "ck.letter.grid", name: "Grid",
        tagline: "Prussian blue band across the top with the name in white.",
        header: .banner, headingFont: .sfPro, bodyFont: .charter,
        baseSize: 10.5, nameSize: 26, lineSpacing: 1.27,
        accentHex: "#1F4E79", textHex: "#1A1F26", mutedHex: "#56606C", headerFillHex: "#13355B",
        marginTop: 40, marginSide: 60, marginBottom: 56, paragraphSpacing: 10,
        matchingResumeTemplateID: "ck.modern.professional-grid"
    )

    private static let editorial = CoverLetterTemplateSpec(
        id: "ck.letter.editorial", name: "Editorial",
        tagline: "High-contrast serif name with a hairline and a single contact line.",
        header: .letterhead, headingFont: .didot, bodyFont: .georgia,
        baseSize: 10.5, nameSize: 32, lineSpacing: 1.3,
        accentHex: "#8E1B1B", textHex: "#1F1A1B", mutedHex: "#5F5557", headerFillHex: nil,
        marginTop: 60, marginSide: 64, marginBottom: 58, paragraphSpacing: 11,
        matchingResumeTemplateID: "ck.creative.editorial"
    )

    private static let academic = CoverLetterTemplateSpec(
        id: "ck.letter.academic", name: "Academic",
        tagline: "Left-aligned block set in Charter. Suits longer letters.",
        header: .leftBlock, headingFont: .charter, bodyFont: .charter,
        baseSize: 11, nameSize: 22, lineSpacing: 1.3,
        accentHex: "#5A2E24", textHex: "#1E1B1A", mutedHex: "#5C5652", headerFillHex: nil,
        marginTop: 62, marginSide: 66, marginBottom: 58, paragraphSpacing: 10,
        matchingResumeTemplateID: "ck.academic.academic-cv"
    )

    private static let marketing = CoverLetterTemplateSpec(
        id: "ck.letter.marketing", name: "Marketing",
        tagline: "Indigo band with the name, then a clean letter body.",
        header: .banner, headingFont: .gillSans, bodyFont: .helveticaNeue,
        baseSize: 10.5, nameSize: 28, lineSpacing: 1.27,
        accentHex: "#3A3F8F", textHex: "#1C1E2B", mutedHex: "#575A6B", headerFillHex: "#2B2F6B",
        marginTop: 40, marginSide: 60, marginBottom: 56, paragraphSpacing: 10,
        matchingResumeTemplateID: "ck.creative.marketing-professional"
    )

    private static let engineer = CoverLetterTemplateSpec(
        id: "ck.letter.engineer", name: "Engineer",
        tagline: "Code blue rule beside a monospaced name, kept short and direct.",
        header: .sideRule, headingFont: .menlo, bodyFont: .sfPro,
        baseSize: 10.5, nameSize: 22, lineSpacing: 1.26,
        accentHex: "#2457A6", textHex: "#171B20", mutedHex: "#566069", headerFillHex: nil,
        marginTop: 60, marginSide: 64, marginBottom: 56, paragraphSpacing: 10,
        matchingResumeTemplateID: "ck.technical.software-engineer"
    )
}
