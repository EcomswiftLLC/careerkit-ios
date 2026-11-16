import Foundation

// MARK: - Resume template library
//
// Thirty free resume templates. Every template is plain data (`TemplateSpec`);
// the renderer decides how to draw it. Each one has its own identity: a type pairing,
// an accent from a restrained palette (navy, cobalt, pine, claret, gold, copper, teal,
// plum, rosewood, steel, tobacco, mulberry, indigo, sienna, olive, crimson, mahogany,
// violet, emerald, amber, petrol), a header treatment and a section heading treatment.
//
// ATS friendly means: one column, no photo, no sidebar, no banner, monogram or chip headings,
// no side labels, no date gutter, no skill columns, and the default section names.
// Colours: text on white is at least 7:1, muted and accent text at least 4.5:1,
// sidebar text on its fill at least 4.5:1, banner fill is dark enough for white text.

enum TemplateLibrary {

    /// Default for new documents. Single column, no photo, no sidebar.
    static let defaultTemplateID: String = "ck.professional.executive"

    /// Exactly 30 templates in browse order (category, then position inside the category).
    static let all: [TemplateSpec] = [
        executive,
        corporate,
        modernProfessional,
        classicProfessional,
        businessElite,
        seniorManagement,
        modernMinimal,
        contemporary,
        elegant,
        cleanLines,
        modernClassic,
        professionalGrid,
        creativeDesigner,
        marketingProfessional,
        visualPortfolio,
        creativeMinimal,
        editorial,
        academicCv,
        researcher,
        universityGraduate,
        scientificCv,
        freshGraduate,
        studentResume,
        internshipResume,
        firstJob,
        softwareEngineer,
        itProfessional,
        dataAnalyst,
        productManager,
        projectManager,
    ]

    /// Looks up a template by id. Returns nil for an unknown id.
    static func spec(id: String) -> TemplateSpec? {
        return byID[id]
    }

    private static let byID: [String: TemplateSpec] = {
        var map: [String: TemplateSpec] = [:]
        for template in all { map[template.id] = template }
        return map
    }()

    /// Templates in one category, in browse order.
    static func templates(in category: TemplateCategory) -> [TemplateSpec] {
        return all.filter { $0.category == category }
    }

    // MARK: Professional

    private static let executive = TemplateSpec(
        id: "ck.professional.executive", name: "Executive", category: .professional,
        tagline: "Baskerville name between a hairline and an Oxford rule. Centered section titles.",
        industries: [.business, .general], levels: [.senior, .executive], designStyle: .classic,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .doubleRule, headingStyle: .centeredRule,
        entryLayout: .dateRight, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .baskerville, bodyFont: .charter, baseSize: 10.5, nameSize: 36, headingSize: 10.5,
        lineSpacing: 1.18, uppercaseHeadings: true, letterSpacingHeadings: 1.8,
        accentHex: "#1B2A4A", textHex: "#1A1D24", mutedHex: "#545C68",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 46, marginSide: 56, marginBottom: 44, sectionSpacing: 16, entrySpacing: 9,
        mainSections: [.summary, .experience, .education, .skills, .memberships, .awards],
        sidebarSections: []
    )

    private static let corporate = TemplateSpec(
        id: "ck.professional.corporate", name: "Corporate", category: .professional,
        tagline: "Tight Helvetica with cobalt bars beside mixed-case section titles.",
        industries: [.business, .general], levels: [.mid, .senior], designStyle: .compact,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .splitContact, headingStyle: .leftBorder,
        entryLayout: .dateBelow, bullets: .square, skillStyle: .groupedLines, photo: .none,
        headingFont: .helveticaNeue, bodyFont: .helveticaNeue, baseSize: 10, nameSize: 32, headingSize: 11.5,
        lineSpacing: 1.15, uppercaseHeadings: false, letterSpacingHeadings: 0.2,
        accentHex: "#1D4E89", textHex: "#1B1F27", mutedHex: "#545E6B",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 44, marginSide: 48, marginBottom: 42, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .skills, .certifications],
        sidebarSections: []
    )

    private static let modernProfessional = TemplateSpec(
        id: "ck.professional.modern-professional", name: "Modern Professional", category: .professional,
        tagline: "Pine bar beside the name, Charter text and a skills rail on the right.",
        industries: [.business, .technology, .general], levels: [.mid], designStyle: .minimal,
        isATSFriendly: false, typicalPages: 1,
        layout: .headerThenTwoColumn, sidebarFraction: 0.3, header: .accentRuleLeft, headingStyle: .underlineAccent,
        entryLayout: .dateRight, bullets: .chevron, skillStyle: .groupedLines, photo: .none,
        headingFont: .avenirNext, bodyFont: .charter, baseSize: 10, nameSize: 30, headingSize: 10.5,
        lineSpacing: 1.15, uppercaseHeadings: true, letterSpacingHeadings: 1.3,
        accentHex: "#1E4D3A", textHex: "#1C221F", mutedHex: "#55605A",
        sidebarFillHex: "#EEF3F0", sidebarTextHex: "#1C221F", headerFillHex: nil,
        marginTop: 40, marginSide: 42, marginBottom: 38, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education],
        sidebarSections: [.skills, .certifications, .languages]
    )

    private static let classicProfessional = TemplateSpec(
        id: "ck.professional.classic-professional", name: "Classic Professional", category: .professional,
        tagline: "Claret Palatino name over a short rule, with dotted leaders after each title.",
        industries: [.general, .business, .healthcare], levels: [.mid, .senior], designStyle: .classic,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .centeredAccent, headingStyle: .dottedRule,
        entryLayout: .dateRight, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .palatino, bodyFont: .palatino, baseSize: 10.5, nameSize: 32, headingSize: 11,
        lineSpacing: 1.18, uppercaseHeadings: true, letterSpacingHeadings: 1.2,
        accentHex: "#6E1F2B", textHex: "#221A1C", mutedHex: "#645A5C",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 48, marginSide: 54, marginBottom: 44, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .skills, .awards],
        sidebarSections: []
    )

    private static let businessElite = TemplateSpec(
        id: "ck.professional.business-elite", name: "Business Elite", category: .professional,
        tagline: "Midnight navy sidebar, Didot name and gold underlines on each section.",
        industries: [.business], levels: [.senior, .executive], designStyle: .bold,
        isATSFriendly: false, typicalPages: 2,
        layout: .sidebarLeft, sidebarFraction: 0.33, header: .sidebarCard, headingStyle: .underlineAccent,
        entryLayout: .dateBelow, bullets: .dash, skillStyle: .groupedLines, photo: .sidebarTop,
        headingFont: .didot, bodyFont: .avenirNext, baseSize: 10, nameSize: 26, headingSize: 11,
        lineSpacing: 1.16, uppercaseHeadings: true, letterSpacingHeadings: 1.6,
        accentHex: "#7D6224", textHex: "#1F2328", mutedHex: "#5B6068",
        sidebarFillHex: "#14213D", sidebarTextHex: "#F3F0E8", headerFillHex: nil,
        marginTop: 36, marginSide: 36, marginBottom: 36, sectionSpacing: 15, entrySpacing: 9,
        mainSections: [.summary, .experience, .education, .awards],
        sidebarSections: [.skills, .languages, .certifications]
    )

    private static let seniorManagement = TemplateSpec(
        id: "ck.professional.senior-management", name: "Senior Management", category: .professional,
        tagline: "Copper-tinted section bands, Gill Sans titles over Baskerville text.",
        industries: [.general, .business, .healthcare], levels: [.senior, .executive], designStyle: .classic,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .centered, headingStyle: .tintedBand,
        entryLayout: .stacked, bullets: .dash, skillStyle: .commaList, photo: .none,
        headingFont: .gillSans, bodyFont: .baskerville, baseSize: 10, nameSize: 32, headingSize: 11,
        lineSpacing: 1.16, uppercaseHeadings: true, letterSpacingHeadings: 1.4,
        accentHex: "#8A4B2A", textHex: "#232629", mutedHex: "#585D63",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 46, marginSide: 50, marginBottom: 44, sectionSpacing: 15, entrySpacing: 9,
        mainSections: [.summary, .experience, .education, .skills, .certifications, .memberships],
        sidebarSections: []
    )

    // MARK: Modern

    private static let modernMinimal = TemplateSpec(
        id: "ck.modern.modern-minimal", name: "Modern Minimal", category: .modern,
        tagline: "Oversized Futura name, teal small caps titles and wide white margins.",
        industries: [.general, .technology, .creative], levels: [.entry, .mid], designStyle: .minimal,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .leftAligned, headingStyle: .smallCapsAccent,
        entryLayout: .dateRight, bullets: .dash, skillStyle: .pipeList, photo: .none,
        headingFont: .futura, bodyFont: .avenirNext, baseSize: 10, nameSize: 36, headingSize: 11.5,
        lineSpacing: 1.14, uppercaseHeadings: false, letterSpacingHeadings: 1,
        accentHex: "#155E63", textHex: "#16191C", mutedHex: "#596068",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 50, marginSide: 56, marginBottom: 46, sectionSpacing: 16, entrySpacing: 9,
        mainSections: [.summary, .experience, .projects, .education, .skills],
        sidebarSections: []
    )

    private static let contemporary = TemplateSpec(
        id: "ck.modern.contemporary", name: "Contemporary", category: .modern,
        tagline: "Lavender sidebar with the photo, and plum tinted bands on each section.",
        industries: [.technology, .creative, .general], levels: [.mid], designStyle: .bold,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarRight, sidebarFraction: 0.32, header: .sidebarCard, headingStyle: .tintedBand,
        entryLayout: .dateRight, bullets: .chevron, skillStyle: .groupedLines, photo: .sidebarTop,
        headingFont: .optima, bodyFont: .avenirNext, baseSize: 10, nameSize: 26, headingSize: 10.5,
        lineSpacing: 1.14, uppercaseHeadings: true, letterSpacingHeadings: 1.2,
        accentHex: "#5A2A5E", textHex: "#221C24", mutedHex: "#5E5563",
        sidebarFillHex: "#EFEAF2", sidebarTextHex: "#2A1F2D", headerFillHex: nil,
        marginTop: 38, marginSide: 38, marginBottom: 36, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .projects],
        sidebarSections: [.skills, .languages, .certifications]
    )

    private static let elegant = TemplateSpec(
        id: "ck.modern.elegant", name: "Elegant", category: .modern,
        tagline: "Cochin name centered over rosewood titles set between hairlines.",
        industries: [.general, .education, .healthcare], levels: [.mid, .senior], designStyle: .classic,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .centered, headingStyle: .centeredRule,
        entryLayout: .dateBelow, bullets: .dash, skillStyle: .commaList, photo: .none,
        headingFont: .cochin, bodyFont: .hoeflerText, baseSize: 10.5, nameSize: 34, headingSize: 10.5,
        lineSpacing: 1.15, uppercaseHeadings: true, letterSpacingHeadings: 2,
        accentHex: "#7B2D45", textHex: "#241C1F", mutedHex: "#62575B",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 48, marginSide: 54, marginBottom: 44, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .skills, .certifications, .volunteer],
        sidebarSections: []
    )

    private static let cleanLines = TemplateSpec(
        id: "ck.modern.clean-lines", name: "Clean Lines", category: .modern,
        tagline: "Steel blue hairlines, Helvetica titles and contact details stacked right.",
        industries: [.technology, .general, .business], levels: [.entry, .mid], designStyle: .compact,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .splitContact, headingStyle: .uppercaseRule,
        entryLayout: .dateRight, bullets: .square, skillStyle: .groupedLines, photo: .none,
        headingFont: .helveticaNeue, bodyFont: .sfPro, baseSize: 10, nameSize: 30, headingSize: 10.5,
        lineSpacing: 1.14, uppercaseHeadings: true, letterSpacingHeadings: 1.2,
        accentHex: "#2F4F6F", textHex: "#1B2227", mutedHex: "#57646D",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 42, marginSide: 46, marginBottom: 40, sectionSpacing: 13, entrySpacing: 7.5,
        mainSections: [.summary, .experience, .education, .skills, .projects, .certifications],
        sidebarSections: []
    )

    private static let modernClassic = TemplateSpec(
        id: "ck.modern.modern-classic", name: "Modern Classic", category: .modern,
        tagline: "Georgia name on a heavy tobacco rule, Gill Sans text and a side rail.",
        industries: [.education, .healthcare, .general], levels: [.mid, .senior], designStyle: .classic,
        isATSFriendly: false, typicalPages: 2,
        layout: .headerThenTwoColumn, sidebarFraction: 0.29, header: .ruledMonogram, headingStyle: .smallCapsAccent,
        entryLayout: .dateBelow, bullets: .disc, skillStyle: .groupedLines, photo: .none,
        headingFont: .georgia, bodyFont: .gillSans, baseSize: 10.5, nameSize: 30, headingSize: 11.5,
        lineSpacing: 1.16, uppercaseHeadings: false, letterSpacingHeadings: 0.6,
        accentHex: "#6A4A1F", textHex: "#211E1A", mutedHex: "#5C5650",
        sidebarFillHex: "#F4F0E6", sidebarTextHex: "#2A2620", headerFillHex: nil,
        marginTop: 42, marginSide: 44, marginBottom: 40, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .awards],
        sidebarSections: [.skills, .certifications, .languages]
    )

    private static let professionalGrid = TemplateSpec(
        id: "ck.modern.professional-grid", name: "Professional Grid", category: .modern,
        tagline: "Prussian blue band with the photo, boxed labels and a skills rail.",
        industries: [.business, .general], levels: [.mid, .senior], designStyle: .bold,
        isATSFriendly: false, typicalPages: 2,
        layout: .headerThenTwoColumn, sidebarFraction: 0.31, header: .banner, headingStyle: .boxedLabel,
        entryLayout: .dateRight, bullets: .square, skillStyle: .groupedLines, photo: .headerRight,
        headingFont: .sfPro, bodyFont: .charter, baseSize: 9.5, nameSize: 30, headingSize: 10,
        lineSpacing: 1.14, uppercaseHeadings: true, letterSpacingHeadings: 1.2,
        accentHex: "#1F4E79", textHex: "#1A1F26", mutedHex: "#56606C",
        sidebarFillHex: "#EEF1F6", sidebarTextHex: "#1A1F26", headerFillHex: "#13355B",
        marginTop: 34, marginSide: 38, marginBottom: 34, sectionSpacing: 12, entrySpacing: 7,
        mainSections: [.summary, .experience, .education, .awards],
        sidebarSections: [.skills, .certifications, .languages]
    )

    // MARK: Creative

    private static let creativeDesigner = TemplateSpec(
        id: "ck.creative.creative-designer", name: "Creative Designer", category: .creative,
        tagline: "Aubergine sidebar with a portrait, Futura titles and mulberry accent bars.",
        industries: [.creative, .technology], levels: [.entry, .mid], designStyle: .bold,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarLeft, sidebarFraction: 0.34, header: .sidebarCard, headingStyle: .accentBar,
        entryLayout: .stacked, bullets: .square, skillStyle: .groupedLines, photo: .sidebarTop,
        headingFont: .futura, bodyFont: .helveticaNeue, baseSize: 9.5, nameSize: 26, headingSize: 10.5,
        lineSpacing: 1.15, uppercaseHeadings: true, letterSpacingHeadings: 1.6,
        accentHex: "#7C2D55", textHex: "#22181F", mutedHex: "#645660",
        sidebarFillHex: "#2B1E33", sidebarTextHex: "#F4EEF5", headerFillHex: nil,
        marginTop: 36, marginSide: 36, marginBottom: 34, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .projects],
        sidebarSections: [.skills, .languages, .awards]
    )

    private static let marketingProfessional = TemplateSpec(
        id: "ck.creative.marketing-professional", name: "Marketing Professional", category: .creative,
        tagline: "Indigo band with the photo, boxed section labels and two-column skills.",
        industries: [.creative, .business], levels: [.mid, .senior], designStyle: .bold,
        isATSFriendly: false, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .banner, headingStyle: .boxedLabel,
        entryLayout: .dateRight, bullets: .disc, skillStyle: .bulletColumns, photo: .headerRight,
        headingFont: .gillSans, bodyFont: .helveticaNeue, baseSize: 9.5, nameSize: 30, headingSize: 10.5,
        lineSpacing: 1.14, uppercaseHeadings: true, letterSpacingHeadings: 1.3,
        accentHex: "#3A3F8F", textHex: "#1C1E2B", mutedHex: "#575A6B",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: "#2B2F6B",
        marginTop: 34, marginSide: 42, marginBottom: 34, sectionSpacing: 12, entrySpacing: 7,
        mainSections: [.summary, .experience, .education, .skills, .certifications, .awards],
        sidebarSections: []
    )

    private static let visualPortfolio = TemplateSpec(
        id: "ck.creative.visual-portfolio", name: "Visual Portfolio", category: .creative,
        tagline: "Projects first, a greige sidebar with the photo and sienna dotted leaders.",
        industries: [.creative], levels: [.entry, .mid], designStyle: .editorial,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarRight, sidebarFraction: 0.33, header: .sidebarCard, headingStyle: .dottedRule,
        entryLayout: .dateBelow, bullets: .dash, skillStyle: .groupedLines, photo: .sidebarTop,
        headingFont: .cochin, bodyFont: .optima, baseSize: 10, nameSize: 26, headingSize: 11.5,
        lineSpacing: 1.16, uppercaseHeadings: false, letterSpacingHeadings: 0.4,
        accentHex: "#8A3F1F", textHex: "#2A2320", mutedHex: "#5E534C",
        sidebarFillHex: "#ECE7E0", sidebarTextHex: "#2A2320", headerFillHex: nil,
        marginTop: 40, marginSide: 40, marginBottom: 38, sectionSpacing: 14, entrySpacing: 9,
        mainSections: [.summary, .projects, .experience, .education],
        sidebarSections: [.skills, .languages, .awards]
    )

    private static let creativeMinimal = TemplateSpec(
        id: "ck.creative.creative-minimal", name: "Creative Minimal", category: .creative,
        tagline: "Initials in an olive disc, section names in a left margin, New York text.",
        industries: [.creative, .general], levels: [.entry, .mid], designStyle: .minimal,
        isATSFriendly: false, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .monogramBadge, headingStyle: .sideLabel,
        entryLayout: .stacked, bullets: .dash, skillStyle: .commaList, photo: .headerRight,
        headingFont: .avenirNext, bodyFont: .newYork, baseSize: 9.5, nameSize: 30, headingSize: 10,
        lineSpacing: 1.14, uppercaseHeadings: true, letterSpacingHeadings: 1.4,
        accentHex: "#4E5B24", textHex: "#1E1F1A", mutedHex: "#5C5E55",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 44, marginSide: 48, marginBottom: 40, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .skills, .projects, .awards],
        sidebarSections: []
    )

    private static let editorial = TemplateSpec(
        id: "ck.creative.editorial", name: "Editorial", category: .creative,
        tagline: "Large Didot name, titles in the margin and a date column, like a magazine.",
        industries: [.creative, .general], levels: [.mid, .senior], designStyle: .editorial,
        isATSFriendly: false, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .ruledMonogram, headingStyle: .sideLabel,
        entryLayout: .dateGutter, bullets: .none, skillStyle: .bulletColumns, photo: .none,
        headingFont: .didot, bodyFont: .georgia, baseSize: 10, nameSize: 38, headingSize: 10.5,
        lineSpacing: 1.18, uppercaseHeadings: true, letterSpacingHeadings: 1.4,
        accentHex: "#8E1B1B", textHex: "#1F1A1B", mutedHex: "#5F5557",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 46, marginSide: 50, marginBottom: 44, sectionSpacing: 16, entrySpacing: 10,
        mainSections: [.summary, .experience, .education, .skills, .publications, .awards],
        sidebarSections: []
    )

    // MARK: Academic

    private static let academicCv = TemplateSpec(
        id: "ck.academic.academic-cv", name: "Academic CV", category: .academic,
        tagline: "Charter throughout, mahogany Oxford rules and small caps section titles.",
        industries: [.academia, .education], levels: [.mid, .senior], designStyle: .classic,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .doubleRule, headingStyle: .smallCapsAccent,
        entryLayout: .dateRight, bullets: .dash, skillStyle: .groupedLines, photo: .none,
        headingFont: .charter, bodyFont: .charter, baseSize: 10, nameSize: 30, headingSize: 12,
        lineSpacing: 1.15, uppercaseHeadings: false, letterSpacingHeadings: 0.8,
        accentHex: "#5A2E24", textHex: "#1E1B1A", mutedHex: "#5C5652",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 44, marginSide: 50, marginBottom: 42, sectionSpacing: 14, entrySpacing: 7.5,
        mainSections: [.summary, .education, .experience, .publications, .awards, .skills, .memberships],
        sidebarSections: []
    )

    private static let researcher = TemplateSpec(
        id: "ck.academic.researcher", name: "Researcher", category: .academic,
        tagline: "Initials in a sea green disc, Baskerville titles and an honours rail.",
        industries: [.academia], levels: [.mid, .senior], designStyle: .editorial,
        isATSFriendly: false, typicalPages: 2,
        layout: .headerThenTwoColumn, sidebarFraction: 0.29, header: .monogramBadge, headingStyle: .dottedRule,
        entryLayout: .dateBelow, bullets: .disc, skillStyle: .groupedLines, photo: .none,
        headingFont: .baskerville, bodyFont: .georgia, baseSize: 10, nameSize: 28, headingSize: 11.5,
        lineSpacing: 1.16, uppercaseHeadings: false, letterSpacingHeadings: 0.6,
        accentHex: "#2A5A4B", textHex: "#1D2220", mutedHex: "#58625C",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 40, marginSide: 44, marginBottom: 38, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .publications],
        sidebarSections: [.skills, .awards, .memberships, .languages]
    )

    private static let universityGraduate = TemplateSpec(
        id: "ck.academic.university-graduate", name: "University Graduate", category: .academic,
        tagline: "Charter name and short violet bars over each title. Education leads.",
        industries: [.general, .academia, .business], levels: [.student, .entry], designStyle: .minimal,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .leftAligned, headingStyle: .accentBar,
        entryLayout: .dateBelow, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .charter, bodyFont: .avenirNext, baseSize: 10, nameSize: 32, headingSize: 11,
        lineSpacing: 1.14, uppercaseHeadings: true, letterSpacingHeadings: 1,
        accentHex: "#553C8B", textHex: "#1E1C26", mutedHex: "#5B5868",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 42, marginSide: 48, marginBottom: 40, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .education, .experience, .projects, .skills, .awards],
        sidebarSections: []
    )

    private static let scientificCv = TemplateSpec(
        id: "ck.academic.scientific-cv", name: "Scientific CV", category: .academic,
        tagline: "Contact stacked right, titles in a left margin and Georgia for long lists.",
        industries: [.academia, .healthcare], levels: [.mid, .senior], designStyle: .editorial,
        isATSFriendly: false, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .splitContact, headingStyle: .sideLabel,
        entryLayout: .dateRight, bullets: .square, skillStyle: .groupedLines, photo: .none,
        headingFont: .helveticaNeue, bodyFont: .georgia, baseSize: 10, nameSize: 28, headingSize: 10.5,
        lineSpacing: 1.15, uppercaseHeadings: true, letterSpacingHeadings: 1,
        accentHex: "#2F4858", textHex: "#1B2126", mutedHex: "#56626B",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 42, marginSide: 46, marginBottom: 40, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .publications, .skills, .awards, .memberships],
        sidebarSections: []
    )

    // MARK: Entry Level

    private static let freshGraduate = TemplateSpec(
        id: "ck.entry.fresh-graduate", name: "Fresh Graduate", category: .entryLevel,
        tagline: "Centered green Optima name over a short rule, Charter text and underlines.",
        industries: [.general, .business], levels: [.entry], designStyle: .classic,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .centeredAccent, headingStyle: .underlineAccent,
        entryLayout: .dateRight, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .optima, bodyFont: .charter, baseSize: 10, nameSize: 32, headingSize: 11,
        lineSpacing: 1.15, uppercaseHeadings: false, letterSpacingHeadings: 0.4,
        accentHex: "#2D6A3E", textHex: "#1C231F", mutedHex: "#57615B",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 44, marginSide: 50, marginBottom: 42, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .education, .experience, .skills, .projects, .volunteer],
        sidebarSections: []
    )

    private static let studentResume = TemplateSpec(
        id: "ck.entry.student-resume", name: "Student Resume", category: .entryLevel,
        tagline: "Pale sky sidebar for skills and languages, with boxed blue labels.",
        industries: [.general, .education], levels: [.student], designStyle: .bold,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarLeft, sidebarFraction: 0.32, header: .sidebarCard, headingStyle: .boxedLabel,
        entryLayout: .dateBelow, bullets: .chevron, skillStyle: .groupedLines, photo: .sidebarTop,
        headingFont: .avenirNext, bodyFont: .sfPro, baseSize: 10, nameSize: 26, headingSize: 10.5,
        lineSpacing: 1.16, uppercaseHeadings: true, letterSpacingHeadings: 1.2,
        accentHex: "#2D4A8A", textHex: "#1B2030", mutedHex: "#565D6E",
        sidebarFillHex: "#E7EDF7", sidebarTextHex: "#1B2030", headerFillHex: nil,
        marginTop: 36, marginSide: 34, marginBottom: 34, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .education, .experience, .projects],
        sidebarSections: [.skills, .languages, .interests]
    )

    private static let internshipResume = TemplateSpec(
        id: "ck.entry.internship-resume", name: "Internship Resume", category: .entryLevel,
        tagline: "Burnt orange bar beside the name, Georgia titles and internships first.",
        industries: [.general, .business, .technology], levels: [.student, .entry], designStyle: .minimal,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .accentRuleLeft, headingStyle: .plainBold,
        entryLayout: .dateBelow, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .georgia, bodyFont: .helveticaNeue, baseSize: 10, nameSize: 30, headingSize: 12,
        lineSpacing: 1.15, uppercaseHeadings: false, letterSpacingHeadings: 0.2,
        accentHex: "#A3420F", textHex: "#22201E", mutedHex: "#5E5955",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 44, marginSide: 50, marginBottom: 42, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .education, .internships, .experience, .skills, .projects],
        sidebarSections: []
    )

    private static let firstJob = TemplateSpec(
        id: "ck.entry.first-job", name: "First Job", category: .entryLevel,
        tagline: "Aqua sidebar for skills and languages, Gill Sans with teal side bars.",
        industries: [.general], levels: [.student, .entry], designStyle: .minimal,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarRight, sidebarFraction: 0.31, header: .sidebarCard, headingStyle: .leftBorder,
        entryLayout: .stacked, bullets: .dash, skillStyle: .groupedLines, photo: .none,
        headingFont: .gillSans, bodyFont: .gillSans, baseSize: 10.5, nameSize: 28, headingSize: 12,
        lineSpacing: 1.18, uppercaseHeadings: false, letterSpacingHeadings: 0.3,
        accentHex: "#1C5D6B", textHex: "#1A2326", mutedHex: "#55636A",
        sidebarFillHex: "#E4EEF0", sidebarTextHex: "#1A2326", headerFillHex: nil,
        marginTop: 38, marginSide: 38, marginBottom: 36, sectionSpacing: 14, entrySpacing: 9,
        mainSections: [.summary, .experience, .education, .volunteer, .courses],
        sidebarSections: [.skills, .languages]
    )

    // MARK: Technical

    private static let softwareEngineer = TemplateSpec(
        id: "ck.technical.software-engineer", name: "Software Engineer", category: .technical,
        tagline: "Menlo section titles in code blue with dotted leaders. Projects near the top.",
        industries: [.technology], levels: [.mid, .senior], designStyle: .compact,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .leftAligned, headingStyle: .dottedRule,
        entryLayout: .dateRight, bullets: .dash, skillStyle: .groupedLines, photo: .none,
        headingFont: .menlo, bodyFont: .sfPro, baseSize: 10, nameSize: 28, headingSize: 11,
        lineSpacing: 1.14, uppercaseHeadings: false, letterSpacingHeadings: 0.2,
        accentHex: "#2457A6", textHex: "#171B20", mutedHex: "#566069",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 40, marginSide: 44, marginBottom: 38, sectionSpacing: 12, entrySpacing: 7,
        mainSections: [.summary, .experience, .projects, .skills, .education, .certifications],
        sidebarSections: []
    )

    private static let itProfessional = TemplateSpec(
        id: "ck.technical.it-professional", name: "IT Professional", category: .technical,
        tagline: "Heavy emerald rule under the name, underlined titles and piped skills.",
        industries: [.technology, .business], levels: [.mid, .senior], designStyle: .compact,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .ruledMonogram, headingStyle: .underlineAccent,
        entryLayout: .dateBelow, bullets: .square, skillStyle: .pipeList, photo: .none,
        headingFont: .avenirNext, bodyFont: .helveticaNeue, baseSize: 10, nameSize: 30, headingSize: 11,
        lineSpacing: 1.14, uppercaseHeadings: true, letterSpacingHeadings: 1.1,
        accentHex: "#0B6E4F", textHex: "#161B19", mutedHex: "#56605B",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 42, marginSide: 46, marginBottom: 40, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .experience, .certifications, .skills, .education],
        sidebarSections: []
    )

    private static let dataAnalyst = TemplateSpec(
        id: "ck.technical.data-analyst", name: "Data Analyst", category: .technical,
        tagline: "Deep petrol sidebar for tools and certificates, Futura titles on hairlines.",
        industries: [.technology, .business], levels: [.entry, .mid], designStyle: .bold,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarLeft, sidebarFraction: 0.33, header: .sidebarCard, headingStyle: .uppercaseRule,
        entryLayout: .dateRight, bullets: .chevron, skillStyle: .groupedLines, photo: .none,
        headingFont: .futura, bodyFont: .sfPro, baseSize: 10, nameSize: 26, headingSize: 10.5,
        lineSpacing: 1.15, uppercaseHeadings: true, letterSpacingHeadings: 1.2,
        accentHex: "#1F5F7A", textHex: "#1B2228", mutedHex: "#57646E",
        sidebarFillHex: "#123B47", sidebarTextHex: "#EAF3F5", headerFillHex: nil,
        marginTop: 34, marginSide: 34, marginBottom: 34, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .experience, .projects, .education],
        sidebarSections: [.skills, .certifications, .languages]
    )

    private static let productManager = TemplateSpec(
        id: "ck.technical.product-manager", name: "Product Manager", category: .technical,
        tagline: "Amber bar beside a New York name, small caps titles over Avenir text.",
        industries: [.technology, .business], levels: [.mid, .senior], designStyle: .minimal,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .accentRuleLeft, headingStyle: .smallCapsAccent,
        entryLayout: .dateRight, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .newYork, bodyFont: .avenirNext, baseSize: 10, nameSize: 30, headingSize: 12,
        lineSpacing: 1.14, uppercaseHeadings: false, letterSpacingHeadings: 0.6,
        accentHex: "#8A5800", textHex: "#201D18", mutedHex: "#5E5850",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 42, marginSide: 48, marginBottom: 40, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .projects, .skills, .education, .awards],
        sidebarSections: []
    )

    private static let projectManager = TemplateSpec(
        id: "ck.technical.project-manager", name: "Project Manager", category: .technical,
        tagline: "Initials disc, petrol side bars and a dated timeline column for delivery.",
        industries: [.business, .technology, .general], levels: [.mid, .senior], designStyle: .classic,
        isATSFriendly: false, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .monogramBadge, headingStyle: .leftBorder,
        entryLayout: .dateGutter, bullets: .disc, skillStyle: .groupedLines, photo: .none,
        headingFont: .palatino, bodyFont: .helveticaNeue, baseSize: 10, nameSize: 28, headingSize: 11.5,
        lineSpacing: 1.15, uppercaseHeadings: false, letterSpacingHeadings: 0.3,
        accentHex: "#245C73", textHex: "#1B2127", mutedHex: "#58646E",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 42, marginSide: 46, marginBottom: 40, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .skills, .certifications, .projects],
        sidebarSections: []
    )
}
