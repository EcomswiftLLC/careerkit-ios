import Foundation

// MARK: - Resume template library
//
// Thirty free resume templates. Every template is plain data (`TemplateSpec`);
// the renderer decides how to draw it. Distinct looks come from the combination
// of layout, header, heading style, entry layout, bullets, skill style, fonts,
// sizes, spacing and a restrained palette (navy, forest, oxblood, slate, bronze, ink).
//
// ATS friendly means: one column, no photo, no sidebar, no banner or chip headings,
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
        tagline: "Two pages for senior leaders. One column with a heavy rule under the name.",
        industries: [.business, .general], levels: [.senior, .executive], designStyle: .classic,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .ruledMonogram, headingStyle: .uppercaseRule,
        entryLayout: .dateRight, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .baskerville, bodyFont: .charter, baseSize: 10.5, nameSize: 34, headingSize: 11,
        lineSpacing: 1.18, uppercaseHeadings: true, letterSpacingHeadings: 1.2,
        accentHex: "#1B3358", textHex: "#1A1E24", mutedHex: "#55606C",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 48, marginSide: 52, marginBottom: 46, sectionSpacing: 16, entrySpacing: 9,
        mainSections: [.summary, .experience, .education, .skills, .memberships, .awards],
        sidebarSections: []
    )

    private static let corporate = TemplateSpec(
        id: "ck.professional.corporate", name: "Corporate", category: .professional,
        tagline: "Small caps headings and tight spacing. Fits a long career on two pages.",
        industries: [.business, .general], levels: [.mid, .senior], designStyle: .compact,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .leftAligned, headingStyle: .smallCapsAccent,
        entryLayout: .dateBelow, bullets: .square, skillStyle: .groupedLines, photo: .none,
        headingFont: .helveticaNeue, bodyFont: .helveticaNeue, baseSize: 10, nameSize: 30, headingSize: 11,
        lineSpacing: 1.15, uppercaseHeadings: false, letterSpacingHeadings: 0.6,
        accentHex: "#3E5566", textHex: "#1D242A", mutedHex: "#56636D",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 44, marginSide: 48, marginBottom: 42, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .skills, .certifications],
        sidebarSections: []
    )

    private static let modernProfessional = TemplateSpec(
        id: "ck.professional.modern-professional", name: "Modern Professional", category: .professional,
        tagline: "A narrow right rail holds skills and certifications. One page.",
        industries: [.business, .technology, .general], levels: [.mid], designStyle: .minimal,
        isATSFriendly: false, typicalPages: 1,
        layout: .headerThenTwoColumn, sidebarFraction: 0.3, header: .splitContact, headingStyle: .accentBar,
        entryLayout: .dateRight, bullets: .chevron, skillStyle: .groupedLines, photo: .none,
        headingFont: .avenirNext, bodyFont: .sfPro, baseSize: 10, nameSize: 30, headingSize: 10.5,
        lineSpacing: 1.16, uppercaseHeadings: true, letterSpacingHeadings: 1.4,
        accentHex: "#1F4D3A", textHex: "#1C221F", mutedHex: "#55605A",
        sidebarFillHex: "#EEF3F0", sidebarTextHex: "#1C221F", headerFillHex: nil,
        marginTop: 40, marginSide: 42, marginBottom: 38, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education],
        sidebarSections: [.skills, .certifications, .languages]
    )

    private static let classicProfessional = TemplateSpec(
        id: "ck.professional.classic-professional", name: "Classic Professional", category: .professional,
        tagline: "Centered name with dotted dividers. A traditional one-page layout.",
        industries: [.general, .business, .healthcare], levels: [.mid, .senior], designStyle: .classic,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .centered, headingStyle: .dottedRule,
        entryLayout: .dateRight, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .palatino, bodyFont: .palatino, baseSize: 11, nameSize: 30, headingSize: 11,
        lineSpacing: 1.22, uppercaseHeadings: true, letterSpacingHeadings: 1,
        accentHex: "#6E1F2B", textHex: "#221A1C", mutedHex: "#645A5C",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 54, marginSide: 56, marginBottom: 50, sectionSpacing: 15, entrySpacing: 9,
        mainSections: [.summary, .experience, .education, .skills, .awards],
        sidebarSections: []
    )

    private static let businessElite = TemplateSpec(
        id: "ck.professional.business-elite", name: "Business Elite", category: .professional,
        tagline: "Dark navy sidebar for contact details and skills. Photo is optional.",
        industries: [.business], levels: [.senior, .executive], designStyle: .bold,
        isATSFriendly: false, typicalPages: 2,
        layout: .sidebarLeft, sidebarFraction: 0.33, header: .sidebarCard, headingStyle: .uppercaseRule,
        entryLayout: .dateBelow, bullets: .dash, skillStyle: .groupedLines, photo: .sidebarTop,
        headingFont: .didot, bodyFont: .avenirNext, baseSize: 10, nameSize: 26, headingSize: 11,
        lineSpacing: 1.17, uppercaseHeadings: true, letterSpacingHeadings: 1.4,
        accentHex: "#85682A", textHex: "#1F2328", mutedHex: "#5B6068",
        sidebarFillHex: "#1B2F4E", sidebarTextHex: "#F2F4F7", headerFillHex: nil,
        marginTop: 36, marginSide: 36, marginBottom: 36, sectionSpacing: 15, entrySpacing: 9,
        mainSections: [.summary, .experience, .education, .awards],
        sidebarSections: [.skills, .languages, .certifications]
    )

    private static let seniorManagement = TemplateSpec(
        id: "ck.professional.senior-management", name: "Senior Management", category: .professional,
        tagline: "Plain headings and stacked job lines. Reads cleanly as plain text.",
        industries: [.general, .business, .healthcare], levels: [.senior, .executive], designStyle: .classic,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .splitContact, headingStyle: .plainBold,
        entryLayout: .stacked, bullets: .dash, skillStyle: .commaList, photo: .none,
        headingFont: .newYork, bodyFont: .sfPro, baseSize: 10.5, nameSize: 32, headingSize: 11.5,
        lineSpacing: 1.2, uppercaseHeadings: false, letterSpacingHeadings: 0.3,
        accentHex: "#253241", textHex: "#15181B", mutedHex: "#565D66",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 48, marginSide: 50, marginBottom: 44, sectionSpacing: 15, entrySpacing: 10,
        mainSections: [.summary, .experience, .education, .skills, .certifications, .memberships],
        sidebarSections: []
    )

    // MARK: Modern

    private static let modernMinimal = TemplateSpec(
        id: "ck.modern.modern-minimal", name: "Modern Minimal", category: .modern,
        tagline: "Wide margins, light type and almost no decoration.",
        industries: [.general, .technology, .creative], levels: [.entry, .mid], designStyle: .minimal,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .leftAligned, headingStyle: .plainBold,
        entryLayout: .dateRight, bullets: .dash, skillStyle: .pipeList, photo: .none,
        headingFont: .sfPro, bodyFont: .sfPro, baseSize: 10, nameSize: 34, headingSize: 10,
        lineSpacing: 1.25, uppercaseHeadings: true, letterSpacingHeadings: 1.8,
        accentHex: "#2B3138", textHex: "#15181B", mutedHex: "#5A6068",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 52, marginSide: 54, marginBottom: 48, sectionSpacing: 18, entrySpacing: 10,
        mainSections: [.summary, .experience, .projects, .education, .skills],
        sidebarSections: []
    )

    private static let contemporary = TemplateSpec(
        id: "ck.modern.contemporary", name: "Contemporary", category: .modern,
        tagline: "A pale sidebar on the right keeps skills next to your story.",
        industries: [.technology, .creative, .general], levels: [.mid], designStyle: .bold,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarRight, sidebarFraction: 0.32, header: .sidebarCard, headingStyle: .smallCapsAccent,
        entryLayout: .dateRight, bullets: .chevron, skillStyle: .groupedLines, photo: .sidebarTop,
        headingFont: .avenirNext, bodyFont: .avenirNext, baseSize: 10, nameSize: 26, headingSize: 11,
        lineSpacing: 1.17, uppercaseHeadings: false, letterSpacingHeadings: 0.8,
        accentHex: "#23406B", textHex: "#1C2430", mutedHex: "#586270",
        sidebarFillHex: "#ECF0F5", sidebarTextHex: "#1D2733", headerFillHex: nil,
        marginTop: 38, marginSide: 38, marginBottom: 36, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .projects],
        sidebarSections: [.skills, .languages, .certifications]
    )

    private static let elegant = TemplateSpec(
        id: "ck.modern.elegant", name: "Elegant", category: .modern,
        tagline: "Centered name and widely spaced headings, set in serif type.",
        industries: [.general, .education, .healthcare], levels: [.mid, .senior], designStyle: .classic,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .centered, headingStyle: .uppercaseRule,
        entryLayout: .dateBelow, bullets: .dash, skillStyle: .commaList, photo: .none,
        headingFont: .cochin, bodyFont: .hoeflerText, baseSize: 10.5, nameSize: 34, headingSize: 10.5,
        lineSpacing: 1.22, uppercaseHeadings: true, letterSpacingHeadings: 2,
        accentHex: "#85682A", textHex: "#25221D", mutedHex: "#625A4D",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 52, marginSide: 56, marginBottom: 50, sectionSpacing: 16, entrySpacing: 9,
        mainSections: [.summary, .experience, .education, .skills, .certifications, .volunteer],
        sidebarSections: []
    )

    private static let cleanLines = TemplateSpec(
        id: "ck.modern.clean-lines", name: "Clean Lines", category: .modern,
        tagline: "Thin rules between sections and a compact skills block.",
        industries: [.technology, .general, .business], levels: [.entry, .mid], designStyle: .compact,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .leftAligned, headingStyle: .uppercaseRule,
        entryLayout: .dateRight, bullets: .square, skillStyle: .groupedLines, photo: .none,
        headingFont: .futura, bodyFont: .helveticaNeue, baseSize: 10, nameSize: 30, headingSize: 10.5,
        lineSpacing: 1.15, uppercaseHeadings: true, letterSpacingHeadings: 1.2,
        accentHex: "#2F4B5E", textHex: "#1B2227", mutedHex: "#57646D",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 42, marginSide: 46, marginBottom: 40, sectionSpacing: 13, entrySpacing: 7.5,
        mainSections: [.summary, .experience, .education, .skills, .projects, .certifications],
        sidebarSections: []
    )

    private static let modernClassic = TemplateSpec(
        id: "ck.modern.modern-classic", name: "Modern Classic", category: .modern,
        tagline: "Serif headings over sans text, with a narrow rail on the right.",
        industries: [.education, .healthcare, .general], levels: [.mid, .senior], designStyle: .classic,
        isATSFriendly: false, typicalPages: 2,
        layout: .headerThenTwoColumn, sidebarFraction: 0.29, header: .ruledMonogram, headingStyle: .smallCapsAccent,
        entryLayout: .dateBelow, bullets: .disc, skillStyle: .groupedLines, photo: .none,
        headingFont: .georgia, bodyFont: .gillSans, baseSize: 10, nameSize: 30, headingSize: 11,
        lineSpacing: 1.18, uppercaseHeadings: false, letterSpacingHeadings: 0.6,
        accentHex: "#17402F", textHex: "#1F2420", mutedHex: "#575F59",
        sidebarFillHex: "#F4F0E6", sidebarTextHex: "#2A2620", headerFillHex: nil,
        marginTop: 42, marginSide: 44, marginBottom: 40, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .awards],
        sidebarSections: [.skills, .certifications, .languages]
    )

    private static let professionalGrid = TemplateSpec(
        id: "ck.modern.professional-grid", name: "Professional Grid", category: .modern,
        tagline: "A navy band across the top with two columns below.",
        industries: [.business, .general], levels: [.mid, .senior], designStyle: .bold,
        isATSFriendly: false, typicalPages: 2,
        layout: .headerThenTwoColumn, sidebarFraction: 0.31, header: .banner, headingStyle: .boxedLabel,
        entryLayout: .dateRight, bullets: .square, skillStyle: .groupedLines, photo: .headerRight,
        headingFont: .sfPro, bodyFont: .charter, baseSize: 9.5, nameSize: 30, headingSize: 10,
        lineSpacing: 1.14, uppercaseHeadings: true, letterSpacingHeadings: 1.2,
        accentHex: "#1F3F6E", textHex: "#1A1F26", mutedHex: "#56606C",
        sidebarFillHex: "#EEF1F6", sidebarTextHex: "#1A1F26", headerFillHex: "#1B2F4E",
        marginTop: 34, marginSide: 38, marginBottom: 34, sectionSpacing: 12, entrySpacing: 7,
        mainSections: [.summary, .experience, .education, .awards],
        sidebarSections: [.skills, .certifications, .languages]
    )

    // MARK: Creative

    private static let creativeDesigner = TemplateSpec(
        id: "ck.creative.creative-designer", name: "Creative Designer", category: .creative,
        tagline: "Charcoal sidebar with oxblood accents and space for a portrait.",
        industries: [.creative, .technology], levels: [.entry, .mid], designStyle: .bold,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarLeft, sidebarFraction: 0.34, header: .sidebarCard, headingStyle: .accentBar,
        entryLayout: .stacked, bullets: .square, skillStyle: .groupedLines, photo: .sidebarTop,
        headingFont: .futura, bodyFont: .avenirNext, baseSize: 10, nameSize: 26, headingSize: 10.5,
        lineSpacing: 1.2, uppercaseHeadings: true, letterSpacingHeadings: 1.6,
        accentHex: "#6E1F2B", textHex: "#20181A", mutedHex: "#635759",
        sidebarFillHex: "#1F2428", sidebarTextHex: "#F2F2F0", headerFillHex: nil,
        marginTop: 38, marginSide: 36, marginBottom: 36, sectionSpacing: 14, entrySpacing: 9,
        mainSections: [.summary, .experience, .education, .projects],
        sidebarSections: [.skills, .languages, .awards]
    )

    private static let marketingProfessional = TemplateSpec(
        id: "ck.creative.marketing-professional", name: "Marketing Professional", category: .creative,
        tagline: "A deep green band with a spot for a photo. Built for campaign work.",
        industries: [.creative, .business], levels: [.mid, .senior], designStyle: .bold,
        isATSFriendly: false, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .banner, headingStyle: .boxedLabel,
        entryLayout: .dateRight, bullets: .disc, skillStyle: .bulletColumns, photo: .headerRight,
        headingFont: .gillSans, bodyFont: .helveticaNeue, baseSize: 10, nameSize: 30, headingSize: 10.5,
        lineSpacing: 1.17, uppercaseHeadings: true, letterSpacingHeadings: 1.3,
        accentHex: "#1F4D3A", textHex: "#1C221F", mutedHex: "#55605A",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: "#17382A",
        marginTop: 36, marginSide: 42, marginBottom: 36, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .skills, .certifications, .awards],
        sidebarSections: []
    )

    private static let visualPortfolio = TemplateSpec(
        id: "ck.creative.visual-portfolio", name: "Visual Portfolio", category: .creative,
        tagline: "Projects come first, with a warm sidebar on the right.",
        industries: [.creative], levels: [.entry, .mid], designStyle: .editorial,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarRight, sidebarFraction: 0.33, header: .sidebarCard, headingStyle: .dottedRule,
        entryLayout: .dateBelow, bullets: .dash, skillStyle: .groupedLines, photo: .sidebarTop,
        headingFont: .optima, bodyFont: .optima, baseSize: 10, nameSize: 26, headingSize: 11,
        lineSpacing: 1.2, uppercaseHeadings: false, letterSpacingHeadings: 0.8,
        accentHex: "#7A5C1E", textHex: "#2A2620", mutedHex: "#625A4D",
        sidebarFillHex: "#F3EEE3", sidebarTextHex: "#2A2620", headerFillHex: nil,
        marginTop: 40, marginSide: 40, marginBottom: 38, sectionSpacing: 14, entrySpacing: 9,
        mainSections: [.summary, .projects, .experience, .education],
        sidebarSections: [.skills, .languages, .awards]
    )

    private static let creativeMinimal = TemplateSpec(
        id: "ck.creative.creative-minimal", name: "Creative Minimal", category: .creative,
        tagline: "Left-hand section labels and plenty of white space. Small photo optional.",
        industries: [.creative, .general], levels: [.entry, .mid], designStyle: .minimal,
        isATSFriendly: false, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .leftAligned, headingStyle: .sideLabel,
        entryLayout: .stacked, bullets: .dash, skillStyle: .commaList, photo: .headerRight,
        headingFont: .avenirNext, bodyFont: .iowanOldStyle, baseSize: 10, nameSize: 36, headingSize: 10.5,
        lineSpacing: 1.24, uppercaseHeadings: true, letterSpacingHeadings: 1.6,
        accentHex: "#7A2633", textHex: "#1E1A1B", mutedHex: "#5F5557",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 50, marginSide: 52, marginBottom: 46, sectionSpacing: 17, entrySpacing: 10,
        mainSections: [.summary, .experience, .education, .skills, .projects, .awards],
        sidebarSections: []
    )

    private static let editorial = TemplateSpec(
        id: "ck.creative.editorial", name: "Editorial", category: .creative,
        tagline: "Large name, side labels and a date column, like a magazine contents page.",
        industries: [.creative, .general], levels: [.mid, .senior], designStyle: .editorial,
        isATSFriendly: false, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .ruledMonogram, headingStyle: .sideLabel,
        entryLayout: .dateGutter, bullets: .none, skillStyle: .bulletColumns, photo: .none,
        headingFont: .didot, bodyFont: .georgia, baseSize: 10.5, nameSize: 38, headingSize: 10.5,
        lineSpacing: 1.22, uppercaseHeadings: true, letterSpacingHeadings: 1.4,
        accentHex: "#6B1E2A", textHex: "#1F1A1B", mutedHex: "#5F5557",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 48, marginSide: 50, marginBottom: 46, sectionSpacing: 18, entrySpacing: 11,
        mainSections: [.summary, .experience, .education, .skills, .publications, .awards],
        sidebarSections: []
    )

    // MARK: Academic

    private static let academicCv = TemplateSpec(
        id: "ck.academic.academic-cv", name: "Academic CV", category: .academic,
        tagline: "Education first, then research, publications and awards. Up to two pages.",
        industries: [.academia, .education], levels: [.mid, .senior], designStyle: .classic,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .centered, headingStyle: .uppercaseRule,
        entryLayout: .dateRight, bullets: .dash, skillStyle: .groupedLines, photo: .none,
        headingFont: .iowanOldStyle, bodyFont: .iowanOldStyle, baseSize: 10.5, nameSize: 28, headingSize: 11,
        lineSpacing: 1.2, uppercaseHeadings: true, letterSpacingHeadings: 0.8,
        accentHex: "#22385C", textHex: "#1B1E24", mutedHex: "#575E69",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 46, marginSide: 50, marginBottom: 44, sectionSpacing: 15, entrySpacing: 8,
        mainSections: [.summary, .education, .experience, .publications, .awards, .skills, .memberships],
        sidebarSections: []
    )

    private static let researcher = TemplateSpec(
        id: "ck.academic.researcher", name: "Researcher", category: .academic,
        tagline: "Publications in the main column, honours and memberships in the rail.",
        industries: [.academia], levels: [.mid, .senior], designStyle: .editorial,
        isATSFriendly: false, typicalPages: 2,
        layout: .headerThenTwoColumn, sidebarFraction: 0.29, header: .leftAligned, headingStyle: .dottedRule,
        entryLayout: .dateBelow, bullets: .disc, skillStyle: .groupedLines, photo: .none,
        headingFont: .baskerville, bodyFont: .georgia, baseSize: 10, nameSize: 28, headingSize: 10.5,
        lineSpacing: 1.18, uppercaseHeadings: false, letterSpacingHeadings: 0.8,
        accentHex: "#2A5A4B", textHex: "#1D2220", mutedHex: "#58625C",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 40, marginSide: 44, marginBottom: 38, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .publications],
        sidebarSections: [.skills, .awards, .memberships, .languages]
    )

    private static let universityGraduate = TemplateSpec(
        id: "ck.academic.university-graduate", name: "University Graduate", category: .academic,
        tagline: "Education and projects lead. Written for a first role after a degree.",
        industries: [.general, .academia, .business], levels: [.student, .entry], designStyle: .minimal,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .leftAligned, headingStyle: .accentBar,
        entryLayout: .dateBelow, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .charter, bodyFont: .avenirNext, baseSize: 10.5, nameSize: 30, headingSize: 11,
        lineSpacing: 1.2, uppercaseHeadings: true, letterSpacingHeadings: 1,
        accentHex: "#34546E", textHex: "#1C2329", mutedHex: "#58656F",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 46, marginSide: 48, marginBottom: 42, sectionSpacing: 14, entrySpacing: 9,
        mainSections: [.summary, .education, .experience, .projects, .skills, .awards],
        sidebarSections: []
    )

    private static let scientificCv = TemplateSpec(
        id: "ck.academic.scientific-cv", name: "Scientific CV", category: .academic,
        tagline: "Side labels and long publication lists, set in a book serif.",
        industries: [.academia, .healthcare], levels: [.mid, .senior], designStyle: .editorial,
        isATSFriendly: false, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .splitContact, headingStyle: .sideLabel,
        entryLayout: .dateRight, bullets: .square, skillStyle: .groupedLines, photo: .none,
        headingFont: .helveticaNeue, bodyFont: .georgia, baseSize: 10, nameSize: 28, headingSize: 11,
        lineSpacing: 1.17, uppercaseHeadings: true, letterSpacingHeadings: 1,
        accentHex: "#2F4858", textHex: "#1B2126", mutedHex: "#56626B",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 44, marginSide: 48, marginBottom: 42, sectionSpacing: 14, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .publications, .skills, .awards, .memberships],
        sidebarSections: []
    )

    // MARK: Entry Level

    private static let freshGraduate = TemplateSpec(
        id: "ck.entry.fresh-graduate", name: "Fresh Graduate", category: .entryLevel,
        tagline: "Centered name and clear headings for a first full-time role.",
        industries: [.general, .business], levels: [.entry], designStyle: .classic,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .centered, headingStyle: .smallCapsAccent,
        entryLayout: .dateRight, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .avenirNext, bodyFont: .charter, baseSize: 10.5, nameSize: 32, headingSize: 11,
        lineSpacing: 1.2, uppercaseHeadings: false, letterSpacingHeadings: 0.6,
        accentHex: "#2A5A45", textHex: "#1C2320", mutedHex: "#57615B",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 46, marginSide: 50, marginBottom: 44, sectionSpacing: 15, entrySpacing: 9,
        mainSections: [.summary, .education, .experience, .skills, .projects, .volunteer],
        sidebarSections: []
    )

    private static let studentResume = TemplateSpec(
        id: "ck.entry.student-resume", name: "Student Resume", category: .entryLevel,
        tagline: "Green sidebar with room for coursework, projects and languages.",
        industries: [.general, .education], levels: [.student], designStyle: .bold,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarLeft, sidebarFraction: 0.32, header: .sidebarCard, headingStyle: .boxedLabel,
        entryLayout: .dateBelow, bullets: .chevron, skillStyle: .groupedLines, photo: .sidebarTop,
        headingFont: .optima, bodyFont: .sfPro, baseSize: 10, nameSize: 26, headingSize: 10.5,
        lineSpacing: 1.2, uppercaseHeadings: true, letterSpacingHeadings: 1.2,
        accentHex: "#1F4D3A", textHex: "#1C221F", mutedHex: "#55605A",
        sidebarFillHex: "#E9F0EC", sidebarTextHex: "#1C221F", headerFillHex: nil,
        marginTop: 36, marginSide: 34, marginBottom: 34, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .education, .experience, .projects],
        sidebarSections: [.skills, .languages, .interests]
    )

    private static let internshipResume = TemplateSpec(
        id: "ck.entry.internship-resume", name: "Internship Resume", category: .entryLevel,
        tagline: "Internships get their own section. Plain and parser friendly.",
        industries: [.general, .business, .technology], levels: [.student, .entry], designStyle: .minimal,
        isATSFriendly: true, typicalPages: 1,
        layout: .singleColumn, sidebarFraction: 0.3, header: .leftAligned, headingStyle: .plainBold,
        entryLayout: .dateBelow, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .georgia, bodyFont: .helveticaNeue, baseSize: 10.5, nameSize: 28, headingSize: 11,
        lineSpacing: 1.2, uppercaseHeadings: true, letterSpacingHeadings: 0.8,
        accentHex: "#24406B", textHex: "#1B2028", mutedHex: "#586170",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 46, marginSide: 50, marginBottom: 44, sectionSpacing: 14, entrySpacing: 9,
        mainSections: [.summary, .education, .internships, .experience, .skills, .projects],
        sidebarSections: []
    )

    private static let firstJob = TemplateSpec(
        id: "ck.entry.first-job", name: "First Job", category: .entryLevel,
        tagline: "Light sidebar for skills and languages when work history is short.",
        industries: [.general], levels: [.student, .entry], designStyle: .minimal,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarRight, sidebarFraction: 0.31, header: .sidebarCard, headingStyle: .accentBar,
        entryLayout: .stacked, bullets: .dash, skillStyle: .groupedLines, photo: .none,
        headingFont: .gillSans, bodyFont: .gillSans, baseSize: 10.5, nameSize: 28, headingSize: 11,
        lineSpacing: 1.22, uppercaseHeadings: true, letterSpacingHeadings: 1,
        accentHex: "#3E5566", textHex: "#1D242A", mutedHex: "#56636D",
        sidebarFillHex: "#EEF1F4", sidebarTextHex: "#1D242A", headerFillHex: nil,
        marginTop: 38, marginSide: 38, marginBottom: 36, sectionSpacing: 15, entrySpacing: 9,
        mainSections: [.summary, .experience, .education, .volunteer, .courses],
        sidebarSections: [.skills, .languages]
    )

    // MARK: Technical

    private static let softwareEngineer = TemplateSpec(
        id: "ck.technical.software-engineer", name: "Software Engineer", category: .technical,
        tagline: "Monospaced headings, tight lines and projects near the top.",
        industries: [.technology], levels: [.mid, .senior], designStyle: .compact,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .leftAligned, headingStyle: .plainBold,
        entryLayout: .dateRight, bullets: .dash, skillStyle: .groupedLines, photo: .none,
        headingFont: .menlo, bodyFont: .sfPro, baseSize: 10, nameSize: 28, headingSize: 10,
        lineSpacing: 1.14, uppercaseHeadings: false, letterSpacingHeadings: 0.2,
        accentHex: "#2C4A63", textHex: "#171B20", mutedHex: "#566069",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 40, marginSide: 44, marginBottom: 38, sectionSpacing: 12, entrySpacing: 7,
        mainSections: [.summary, .experience, .projects, .skills, .education, .certifications],
        sidebarSections: []
    )

    private static let itProfessional = TemplateSpec(
        id: "ck.technical.it-professional", name: "IT Professional", category: .technical,
        tagline: "Certifications and skills appear early, followed by dated job entries.",
        industries: [.technology, .business], levels: [.mid, .senior], designStyle: .compact,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .splitContact, headingStyle: .accentBar,
        entryLayout: .dateBelow, bullets: .square, skillStyle: .pipeList, photo: .none,
        headingFont: .helveticaNeue, bodyFont: .sfPro, baseSize: 10, nameSize: 30, headingSize: 11,
        lineSpacing: 1.15, uppercaseHeadings: true, letterSpacingHeadings: 1,
        accentHex: "#253241", textHex: "#15181B", mutedHex: "#565D66",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 42, marginSide: 46, marginBottom: 40, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .experience, .certifications, .skills, .education],
        sidebarSections: []
    )

    private static let dataAnalyst = TemplateSpec(
        id: "ck.technical.data-analyst", name: "Data Analyst", category: .technical,
        tagline: "Slate sidebar for tools and certificates, main column for results.",
        industries: [.technology, .business], levels: [.entry, .mid], designStyle: .bold,
        isATSFriendly: false, typicalPages: 1,
        layout: .sidebarLeft, sidebarFraction: 0.33, header: .sidebarCard, headingStyle: .uppercaseRule,
        entryLayout: .dateRight, bullets: .chevron, skillStyle: .groupedLines, photo: .none,
        headingFont: .futura, bodyFont: .sfPro, baseSize: 10, nameSize: 26, headingSize: 10.5,
        lineSpacing: 1.17, uppercaseHeadings: true, letterSpacingHeadings: 1.2,
        accentHex: "#2F5D7A", textHex: "#1B2228", mutedHex: "#57646E",
        sidebarFillHex: "#26343F", sidebarTextHex: "#EEF2F5", headerFillHex: nil,
        marginTop: 34, marginSide: 34, marginBottom: 34, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .experience, .projects, .education],
        sidebarSections: [.skills, .certifications, .languages]
    )

    private static let productManager = TemplateSpec(
        id: "ck.technical.product-manager", name: "Product Manager", category: .technical,
        tagline: "Outcome-led bullets and a projects section. Two pages.",
        industries: [.technology, .business], levels: [.mid, .senior], designStyle: .minimal,
        isATSFriendly: true, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .leftAligned, headingStyle: .smallCapsAccent,
        entryLayout: .dateRight, bullets: .disc, skillStyle: .commaList, photo: .none,
        headingFont: .newYork, bodyFont: .avenirNext, baseSize: 10, nameSize: 30, headingSize: 11,
        lineSpacing: 1.18, uppercaseHeadings: false, letterSpacingHeadings: 0.5,
        accentHex: "#2B5B47", textHex: "#1C2320", mutedHex: "#57615B",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 44, marginSide: 48, marginBottom: 42, sectionSpacing: 14, entrySpacing: 9,
        mainSections: [.summary, .experience, .projects, .skills, .education, .awards],
        sidebarSections: []
    )

    private static let projectManager = TemplateSpec(
        id: "ck.technical.project-manager", name: "Project Manager", category: .technical,
        tagline: "A dated timeline column for delivery history.",
        industries: [.business, .technology, .general], levels: [.mid, .senior], designStyle: .classic,
        isATSFriendly: false, typicalPages: 2,
        layout: .singleColumn, sidebarFraction: 0.3, header: .ruledMonogram, headingStyle: .dottedRule,
        entryLayout: .dateGutter, bullets: .disc, skillStyle: .groupedLines, photo: .none,
        headingFont: .palatino, bodyFont: .helveticaNeue, baseSize: 10, nameSize: 28, headingSize: 10.5,
        lineSpacing: 1.16, uppercaseHeadings: false, letterSpacingHeadings: 0.6,
        accentHex: "#3A4F63", textHex: "#1B2127", mutedHex: "#58646E",
        sidebarFillHex: nil, sidebarTextHex: nil, headerFillHex: nil,
        marginTop: 42, marginSide: 46, marginBottom: 40, sectionSpacing: 13, entrySpacing: 8,
        mainSections: [.summary, .experience, .education, .skills, .certifications, .projects],
        sidebarSections: []
    )
}
