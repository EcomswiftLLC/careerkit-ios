import Foundation

// MARK: - Fonts

/// Curated fonts that ship with iOS (no licensing or bundling needed).
/// `postScriptName` values are verified iOS system fonts; `.system*` cases use SF / New York.
enum FontChoice: String, Codable, CaseIterable, Identifiable {
    case sfPro
    case newYork
    case helveticaNeue
    case avenirNext
    case georgia
    case palatino
    case baskerville
    case hoeflerText
    case charter
    case iowanOldStyle
    case gillSans
    case optima
    case cochin
    case didot
    case futura
    case menlo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sfPro: return "SF Pro"
        case .newYork: return "New York"
        case .helveticaNeue: return "Helvetica Neue"
        case .avenirNext: return "Avenir Next"
        case .georgia: return "Georgia"
        case .palatino: return "Palatino"
        case .baskerville: return "Baskerville"
        case .hoeflerText: return "Hoefler Text"
        case .charter: return "Charter"
        case .iowanOldStyle: return "Iowan Old Style"
        case .gillSans: return "Gill Sans"
        case .optima: return "Optima"
        case .cochin: return "Cochin"
        case .didot: return "Didot"
        case .futura: return "Futura"
        case .menlo: return "Menlo"
        }
    }

    /// Family names for UIFont lookup. nil for the two system designs.
    var familyName: String? {
        switch self {
        case .sfPro, .newYork: return nil
        case .helveticaNeue: return "Helvetica Neue"
        case .avenirNext: return "Avenir Next"
        case .georgia: return "Georgia"
        case .palatino: return "Palatino"
        case .baskerville: return "Baskerville"
        case .hoeflerText: return "Hoefler Text"
        case .charter: return "Charter"
        case .iowanOldStyle: return "Iowan Old Style"
        case .gillSans: return "Gill Sans"
        case .optima: return "Optima"
        case .cochin: return "Cochin"
        case .didot: return "Didot"
        case .futura: return "Futura"
        case .menlo: return "Menlo"
        }
    }

    var isSerif: Bool {
        switch self {
        case .newYork, .georgia, .palatino, .baskerville, .hoeflerText, .charter, .iowanOldStyle, .cochin, .didot:
            return true
        default: return false
        }
    }
}

// MARK: - Template taxonomy

enum TemplateCategory: String, Codable, CaseIterable, Identifiable {
    case professional = "Professional"
    case modern = "Modern"
    case creative = "Creative"
    case academic = "Academic"
    case entryLevel = "Entry Level"
    case technical = "Technical"
    var id: String { rawValue }
}

enum ProfessionalLevel: String, Codable, CaseIterable, Identifiable {
    case student = "Student"
    case entry = "Entry level"
    case mid = "Mid career"
    case senior = "Senior"
    case executive = "Executive"
    var id: String { rawValue }
}

enum DesignStyle: String, Codable, CaseIterable, Identifiable {
    case classic = "Classic"
    case minimal = "Minimal"
    case bold = "Bold"
    case editorial = "Editorial"
    case compact = "Compact"
    var id: String { rawValue }
}

enum Industry: String, Codable, CaseIterable, Identifiable {
    case general = "General"
    case business = "Business & Finance"
    case technology = "Technology"
    case creative = "Design & Marketing"
    case academia = "Academia & Research"
    case education = "Education"
    case healthcare = "Healthcare"
    var id: String { rawValue }
}

// MARK: - Layout vocabulary

enum PageLayout: String, Codable {
    /// Header on top, one full-width column.
    case singleColumn
    /// Narrow tinted sidebar on the left holding `sidebarSections` + contact.
    case sidebarLeft
    /// Sidebar on the right.
    case sidebarRight
    /// Main column plus a narrow right rail, header stays full width.
    case headerThenTwoColumn
}

enum HeaderStyle: String, Codable {
    case leftAligned      // name left, contact line(s) under or right
    case centered         // centered name, centered contact line
    case banner           // full-bleed filled band with light text
    case splitContact     // name left, contact stacked right
    case sidebarCard      // name + photo live at the top of the sidebar
    case ruledMonogram    // name with thick rule below, small caps title
    case monogramBadge    // initials in an accent disc (or the photo) beside name, title and contact. Decorative, not ATS.
    case accentRuleLeft   // thick vertical accent bar to the left of the name block
    case centeredAccent   // centered regular-weight name in the accent colour over a short rule, small caps title
    case doubleRule       // regular-weight name between a hairline above and a thick-and-thin rule below
    case rightAligned     // name, title and contact set flush right, a short accent rule under the name
    case tintedCard       // name left and contact stacked right inside a pale accent panel. Decorative, not ATS.
    case bannerCentered   // full-bleed filled band with everything centered (photo centered above the name)
    case initialLetter    // very large pale initials beside the name (the photo takes their place). Decorative, not ATS.
    case smallCapsCentered // small, widely tracked capital name centered between two full-width hairlines
}

enum SectionHeadingStyle: String, Codable {
    case uppercaseRule     // UPPERCASE LABEL with hairline under it
    case smallCapsAccent   // small caps in accent color, no rule
    case accentBar         // short thick accent bar above the label
    case boxedLabel        // label on a filled accent chip
    case plainBold         // bold label only
    case sideLabel         // label sits in a left gutter, content indented (editorial)
    case dottedRule        // label then dotted line
    case underlineAccent   // label with a short thick accent underline below it
    case centeredRule      // label centered between two hairlines
    case leftBorder        // thick accent bar to the left of the label
    case tintedBand        // label on a full-width pale tint of the accent
    case fullBar           // label reversed out of a full-width solid accent bar. Decorative, not ATS.
    case ruleAbove         // a heavy full-width rule above the label
}

enum EntryLayout: String, Codable {
    case dateRight         // heading left, dates right on the same line
    case dateBelow         // heading, then subheading · dates
    case dateGutter        // dates in a left gutter column (timeline feel)
    case stacked           // heading / subheading / dates, each on its own line
    case timeline          // dates in a left gutter, an accent dot and a vertical spine beside each entry
}

enum BulletStyle: String, Codable {
    case disc, dash, square, chevron, none

    var glyph: String {
        switch self {
        case .disc: return "•"
        case .dash: return "–"
        // U+FE0E asks for the text form. Without it, fonts that lack U+25AA fall back to the emoji font.
        case .square: return "\u{25AA}\u{FE0E}"
        case .chevron: return "›"
        case .none: return ""
        }
    }
}

enum SkillStyle: String, Codable {
    case commaList         // "Swift, SwiftUI, Core Data"
    case pipeList          // "Swift | SwiftUI | Core Data"
    case groupedLines      // "Languages: Swift, Kotlin" per group line
    case bulletColumns     // two-column bullet list
    case pills             // each skill in a soft rounded pill. Decorative, not ATS.
}

/// Where a template shows the photo. Raw values of the first three cases are stored in old builds' data
/// and must never change.
enum PhotoPlacement: String, Codable {
    case none, headerRight, sidebarTop
    /// Photo at the left of the header row, text beside it.
    case headerLeft
    /// Photo centered above the name (centered headers and the centered band).
    case headerCenter
    /// Photo across the full width of the sidebar band, bleeding to the page top.
    case sidebarBleed

    var isHeaderSide: Bool { return self == .headerLeft || self == .headerRight }
    var isSidebar: Bool { return self == .sidebarTop || self == .sidebarBleed }
}

/// Page-level decoration drawn behind the content on every page. Vector only, so text extraction is unaffected.
enum PageAccent: String, Codable {
    case none
    /// Solid accent bar across the top edge of each page.
    case topBar
    /// Solid accent strip down the left edge of each page.
    case leftEdge
    /// Hairline accent frame inset from the page edge.
    case frame
    /// Solid accent bar across the bottom edge of each page.
    case bottomBar
}

// MARK: - Template spec

/// A template is pure data. `DocumentRenderer` turns a `Resume` + `TemplateSpec`
/// into laid-out pages, and the same renderer produces preview and exported PDF.
struct TemplateSpec: Identifiable, Hashable {
    let id: String
    let name: String
    let category: TemplateCategory
    let tagline: String
    let industries: [Industry]
    let levels: [ProfessionalLevel]
    let designStyle: DesignStyle
    /// True when the template avoids sidebars, photos, tables and decoration that confuse parsers.
    let isATSFriendly: Bool
    /// Typical page count for the sample resume: 1 or 2.
    let typicalPages: Int

    // Layout
    let layout: PageLayout
    /// Sidebar width as a fraction of the content width (0.28...0.36). Ignored for single column.
    let sidebarFraction: Double
    let header: HeaderStyle
    let headingStyle: SectionHeadingStyle
    let entryLayout: EntryLayout
    let bullets: BulletStyle
    let skillStyle: SkillStyle
    let photo: PhotoPlacement

    // Typography
    let headingFont: FontChoice
    let bodyFont: FontChoice
    let baseSize: Double          // body size in pt, 9.5...11
    let nameSize: Double          // 24...38
    let headingSize: Double       // 10...13
    let lineSpacing: Double       // multiplier 1.0...1.3
    let uppercaseHeadings: Bool
    let letterSpacingHeadings: Double // kerning in pt, 0...2

    // Colour (hex "#RRGGBB")
    let accentHex: String
    let textHex: String
    let mutedHex: String
    let sidebarFillHex: String?   // sidebar background, nil when no sidebar
    let sidebarTextHex: String?
    let headerFillHex: String?    // banner header background

    // Spacing in pt
    let marginTop: Double
    let marginSide: Double
    let marginBottom: Double
    let sectionSpacing: Double
    let entrySpacing: Double

    // Content defaults
    /// Order sections appear in the main column for a new resume.
    let mainSections: [SectionKind]
    /// Sections that live in the sidebar when `layout` has one.
    let sidebarSections: [SectionKind]

    // Added in the distinctness pass. Defaults keep older construction sites unchanged.
    /// Page decoration behind the content.
    var pageAccent: PageAccent = .none
    /// Page background "#RRGGBB". nil is white.
    var paperHex: String? = nil
    /// Side of the rail in `headerThenTwoColumn`. Other layouts ignore it.
    var railSide: SidebarPosition = .right
}

// MARK: - Cover letter template spec

struct CoverLetterTemplateSpec: Identifiable, Hashable {
    enum HeaderLayout: String, Codable {
        case leftBlock        // sender block top-left
        case rightBlock       // sender block top-right
        case centered
        case banner           // filled band with name
        case sideRule         // thin vertical accent rule beside the sender block
        case letterhead       // name large, hairline, contact in one line
    }

    let id: String
    let name: String
    let tagline: String
    let header: HeaderLayout
    let headingFont: FontChoice
    let bodyFont: FontChoice
    let baseSize: Double
    let nameSize: Double
    let lineSpacing: Double
    let accentHex: String
    let textHex: String
    let mutedHex: String
    let headerFillHex: String?
    let marginTop: Double
    let marginSide: Double
    let marginBottom: Double
    let paragraphSpacing: Double
    /// Resume template id that shares this design language, for "matching set" suggestions.
    let matchingResumeTemplateID: String
}
