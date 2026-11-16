import UIKit
@testable import CareerKit

/// Fixtures for the engine tests. Templates are built here on purpose so the engine tests do not depend on the template library.
enum EngineFixtures {
    // MARK: Template specs

    private static let flowSections: [SectionKind] = [
        .summary, .experience, .internships, .education, .projects, .certifications, .awards,
        .publications, .volunteer, .courses, .memberships, .interests, .references, .custom
    ]

    static func spec(id: String,
                     layout: PageLayout = .singleColumn,
                     header: HeaderStyle = .leftAligned,
                     heading: SectionHeadingStyle = .uppercaseRule,
                     entry: EntryLayout = .dateRight,
                     bullets: BulletStyle = .disc,
                     skills: SkillStyle = .commaList,
                     photo: PhotoPlacement = .none,
                     headingFont: FontChoice = .georgia,
                     bodyFont: FontChoice = .helveticaNeue,
                     uppercase: Bool = false) -> TemplateSpec {
        let hasSidebar: Bool = layout != .singleColumn
        let dark: Bool = layout == .sidebarLeft || layout == .sidebarRight
        return TemplateSpec(
            id: id,
            name: id,
            category: .professional,
            tagline: "Engine test template",
            industries: [.general],
            levels: [.mid],
            designStyle: .classic,
            isATSFriendly: layout == .singleColumn,
            typicalPages: 1,
            layout: layout,
            sidebarFraction: 0.30,
            header: header,
            headingStyle: heading,
            entryLayout: entry,
            bullets: bullets,
            skillStyle: skills,
            photo: photo,
            headingFont: headingFont,
            bodyFont: bodyFont,
            baseSize: 10,
            nameSize: 28,
            headingSize: 11,
            lineSpacing: 1.15,
            uppercaseHeadings: uppercase,
            letterSpacingHeadings: 1.0,
            accentHex: "#1F4D3A",
            textHex: "#1F2421",
            mutedHex: "#5B605C",
            sidebarFillHex: dark ? "#1F4D3A" : nil,
            sidebarTextHex: dark ? "#FFFFFF" : nil,
            headerFillHex: header == .banner ? "#16382A" : nil,
            marginTop: 44,
            marginSide: 44,
            marginBottom: 44,
            sectionSpacing: 14,
            entrySpacing: 9,
            mainSections: flowSections,
            sidebarSections: hasSidebar ? [.skills, .languages] : []
        )
    }

    /// Covers every PageLayout, HeaderStyle, SectionHeadingStyle, EntryLayout, BulletStyle, SkillStyle and PhotoPlacement.
    static let specs: [TemplateSpec] = [
        spec(id: "t.single.left", layout: .singleColumn, header: .leftAligned, heading: .uppercaseRule,
             entry: .dateRight, bullets: .disc, skills: .commaList),
        spec(id: "t.single.centered", layout: .singleColumn, header: .centered, heading: .smallCapsAccent,
             entry: .dateBelow, bullets: .dash, skills: .pipeList, headingFont: .newYork, bodyFont: .sfPro),
        spec(id: "t.single.banner", layout: .singleColumn, header: .banner, heading: .boxedLabel,
             entry: .stacked, bullets: .square, skills: .groupedLines, photo: .headerRight,
             headingFont: .avenirNext, bodyFont: .avenirNext),
        spec(id: "t.single.split", layout: .singleColumn, header: .splitContact, heading: .accentBar,
             entry: .dateGutter, bullets: .chevron, skills: .bulletColumns, photo: .headerRight,
             headingFont: .palatino, bodyFont: .palatino),
        spec(id: "t.single.ruled", layout: .singleColumn, header: .ruledMonogram, heading: .plainBold,
             entry: .dateRight, bullets: .none, skills: .commaList, headingFont: .baskerville, bodyFont: .hoeflerText,
             uppercase: true),
        spec(id: "t.single.sidelabel", layout: .singleColumn, header: .leftAligned, heading: .sideLabel,
             entry: .dateBelow, bullets: .disc, skills: .groupedLines, headingFont: .gillSans, bodyFont: .charter),
        spec(id: "t.single.dotted", layout: .singleColumn, header: .centered, heading: .dottedRule,
             entry: .dateGutter, bullets: .dash, skills: .bulletColumns, headingFont: .optima, bodyFont: .iowanOldStyle),
        spec(id: "t.sidebarleft.card", layout: .sidebarLeft, header: .sidebarCard, heading: .uppercaseRule,
             entry: .dateRight, bullets: .disc, skills: .commaList, photo: .sidebarTop),
        spec(id: "t.sidebarright.card", layout: .sidebarRight, header: .sidebarCard, heading: .accentBar,
             entry: .dateBelow, bullets: .square, skills: .bulletColumns, photo: .sidebarTop,
             headingFont: .cochin, bodyFont: .futura),
        spec(id: "t.sidebarleft.banner", layout: .sidebarLeft, header: .banner, heading: .boxedLabel,
             entry: .stacked, bullets: .chevron, skills: .groupedLines, headingFont: .didot, bodyFont: .menlo),
        spec(id: "t.twocol.split", layout: .headerThenTwoColumn, header: .splitContact, heading: .plainBold,
             entry: .dateRight, bullets: .disc, skills: .pipeList),
        spec(id: "t.twocol.banner", layout: .headerThenTwoColumn, header: .banner, heading: .smallCapsAccent,
             entry: .dateGutter, bullets: .dash, skills: .commaList, photo: .headerRight)
    ]

    static func coverLetterSpecs() -> [CoverLetterTemplateSpec] {
        let headers: [CoverLetterTemplateSpec.HeaderLayout] = [.leftBlock, .rightBlock, .centered, .banner, .sideRule, .letterhead]
        var out: [CoverLetterTemplateSpec] = []
        for (i, header) in headers.enumerated() {
            out.append(CoverLetterTemplateSpec(
                id: "cl.test.\(i)",
                name: "Letter \(i)",
                tagline: "Engine test letter",
                header: header,
                headingFont: i % 2 == 0 ? .georgia : .newYork,
                bodyFont: i % 2 == 0 ? .helveticaNeue : .sfPro,
                baseSize: 10.5,
                nameSize: 26,
                lineSpacing: 1.25,
                accentHex: "#1F4D3A",
                textHex: "#1F2421",
                mutedHex: "#5B605C",
                headerFillHex: header == .banner ? "#16382A" : nil,
                marginTop: 56,
                marginSide: 56,
                marginBottom: 56,
                paragraphSpacing: 10,
                matchingResumeTemplateID: "t.single.left"
            ))
        }
        return out
    }

    // MARK: Builders

    static func month(_ year: Int, _ month: Int? = nil) -> MonthYear {
        return MonthYear(year: year, month: month)
    }

    static func entry(_ heading: String,
                      _ subheading: String = "",
                      location: String = "",
                      start: MonthYear? = nil,
                      end: MonthYear? = nil,
                      current: Bool = false,
                      detail: String = "",
                      extra: String = "",
                      bullets: [String] = []) -> ResumeEntry {
        var e = ResumeEntry()
        e.heading = heading
        e.subheading = subheading
        e.location = location
        e.start = start
        e.end = end
        e.isCurrent = current
        e.detail = detail
        e.extra = extra
        e.bullets = bullets
        return e
    }

    static func section(_ kind: SectionKind,
                        title: String? = nil,
                        text: String = "",
                        entries: [ResumeEntry] = [],
                        skills: [SkillGroup] = [],
                        visible: Bool = true) -> ResumeSection {
        var s = ResumeSection(kind: kind, title: title)
        s.text = text
        s.entries = entries
        s.skillGroups = skills
        s.isVisible = visible
        return s
    }

    static func group(_ name: String, _ items: [String]) -> SkillGroup {
        var g = SkillGroup()
        g.name = name
        g.items = items
        return g
    }

    static func person(_ name: String,
                       title: String = "Product Designer",
                       email: String = "sample.person@example.com",
                       phone: String = "+1 (555) 014-2290",
                       city: String = "Austin",
                       country: String = "United States") -> PersonalInfo {
        var p = PersonalInfo()
        p.fullName = name
        p.professionalTitle = title
        p.email = email
        p.phone = phone
        p.city = city
        p.country = country
        p.linkedIn = "https://www.linkedin.com/in/sample-person"
        p.website = "sampleperson.example.com"
        return p
    }

    private static let verbs: [String] = ["Delivered", "Reduced", "Launched", "Managed", "Improved", "Designed", "Built",
                                          "Negotiated", "Coordinated", "Trained", "Automated", "Streamlined", "Led", "Migrated"]

    /// Deterministic bullet text. Each one carries a unique tag so a missing bullet is noticed.
    static func bullet(_ index: Int, long: Bool = false) -> String {
        let verb: String = verbs[index % verbs.count]
        var text: String = "\(verb) workstream W\(index) across \(2 + index % 5) teams, cutting cycle time by \(10 + index % 40) percent while quality stayed steady"
        if long {
            text += " and documenting the approach so that new colleagues could repeat the result without extra training, which helped the wider group plan quarterly work with more confidence and fewer last minute changes to scope or budget"
        }
        return text + "."
    }

    static func bullets(_ count: Int, offset: Int = 0, long: Bool = false) -> [String] {
        return (0..<count).map { bullet($0 + offset, long: long) }
    }

    static func jobs(_ count: Int, bulletsEach: Int, long: Bool = false) -> [ResumeEntry] {
        var out: [ResumeEntry] = []
        for i in 0..<count {
            let startYear: Int = 2024 - (i + 1) * 2
            out.append(entry("Role Number \(i) Lead", "Company \(i) Holdings", location: "Austin, TX",
                             start: month(startYear, 3), end: i == 0 ? nil : month(startYear + 2, 1), current: i == 0,
                             bullets: bullets(bulletsEach, offset: i * 10, long: long)))
        }
        return out
    }

    static func standardSkills() -> [SkillGroup] {
        return [
            group("Design", ["Interaction design", "Prototyping", "Design systems", "User research", "Accessibility"]),
            group("Tools", ["Figma", "Sketch", "Swift", "SwiftUI", "HTML", "CSS"]),
            group("Languages", ["English (native)", "Spanish (fluent)"])
        ]
    }

    static func resume(_ title: String,
                       person: PersonalInfo,
                       sections: [ResumeSection],
                       pageSize: PageSize = .a4) -> Resume {
        var r = Resume(title: title, templateID: "t.single.left", sections: sections)
        r.pageSize = pageSize
        r.personal = person
        return r
    }

    static func photoData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400))
        let image: UIImage = renderer.image { context in
            UIColor(red: 0.82, green: 0.78, blue: 0.70, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
            UIColor(red: 0.20, green: 0.30, blue: 0.26, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 90, y: 70, width: 120, height: 140))
            context.cgContext.fillEllipse(in: CGRect(x: 40, y: 230, width: 220, height: 220))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    // MARK: Resume cases

    struct Case {
        let name: String
        let resume: Resume
        /// Strings that must be found in the extracted text of every rendering.
        let keys: [String]
        let minPages: Int
        let maxPages: Int
    }

    static func cases() -> [Case] {
        var out: [Case] = []
        let standard: PersonalInfo = person("Jordan Whitfield")

        // 1. Very short.
        var tiny = PersonalInfo()
        tiny.fullName = "Sam Okafor"
        tiny.email = "sam.okafor@example.com"
        out.append(Case(name: "very short",
                        resume: resume("Very short", person: tiny, sections: []),
                        keys: ["Sam Okafor", "sam.okafor@example.com"], minPages: 1, maxPages: 1))

        // 2. One page.
        out.append(Case(name: "one page",
                        resume: resume("One page", person: standard, sections: [
                            section(.summary, text: "Product designer with eight years of experience shipping consumer and business software."),
                            section(.experience, entries: jobs(3, bulletsEach: 3)),
                            section(.education, entries: [entry("BA Graphic Design", "State University", start: month(2010), end: month(2014))]),
                            section(.skills, skills: standardSkills())
                        ]),
                        keys: ["Jordan Whitfield", "Role Number 0 Lead", "State University"], minPages: 1, maxPages: 3))

        // 3. Long multi page CV.
        var longPerson = person("Dr. Amelia Hartley-Brooks", title: "Professor of Applied Statistics")
        longPerson.email = "amelia.hartley@example.edu"
        out.append(Case(name: "long cv",
                        resume: resume("Long CV", person: longPerson, sections: [
                            section(.summary, text: "Researcher and teacher with two decades of work in statistics, public health and data education."),
                            section(.experience, entries: jobs(8, bulletsEach: 6)),
                            section(.education, entries: [
                                entry("PhD Statistics", "University of Northfield", start: month(2002), end: month(2007)),
                                entry("MSc Biostatistics", "Harbour College", start: month(2000), end: month(2002)),
                                entry("BSc Mathematics", "Eastfield University", start: month(1997), end: month(2000))
                            ]),
                            section(.publications, entries: (0..<14).map { entry("Paper title number \($0) on estimation", "Journal of Method \($0)", start: month(2005 + $0)) }),
                            section(.awards, entries: (0..<6).map { entry("Teaching award \($0)", "Faculty Board", start: month(2010 + $0)) }),
                            section(.projects, entries: (0..<5).map { entry("Open dataset project \($0)", "", detail: "Maintained a public dataset with documentation for students and researchers.", bullets: bullets(3, offset: $0)) }),
                            section(.skills, skills: standardSkills())
                        ]),
                        keys: ["Dr. Amelia Hartley-Brooks", "amelia.hartley@example.edu", "PhD Statistics"], minPages: 2, maxPages: 14))

        // 4. Long job descriptions.
        out.append(Case(name: "long descriptions",
                        resume: resume("Long descriptions", person: standard, sections: [
                            section(.experience, entries: jobs(4, bulletsEach: 5, long: true))
                        ]),
                        keys: ["Jordan Whitfield", "Role Number 3 Lead"], minPages: 1, maxPages: 10))

        // 5. Many education entries.
        out.append(Case(name: "many education",
                        resume: resume("Many education", person: standard, sections: [
                            section(.education, entries: (0..<9).map { entry("Degree number \($0)", "Institute \($0)", location: "City \($0)", start: month(1990 + $0), end: month(1993 + $0), extra: "Grade \($0).5 of 4.0") })
                        ]),
                        keys: ["Degree number 8", "Institute 4"], minPages: 1, maxPages: 5))

        // 6. Many certifications.
        out.append(Case(name: "many certifications",
                        resume: resume("Many certifications", person: standard, sections: [
                            section(.certifications, entries: (0..<28).map { entry("Certificate track \($0)", "Issuer \($0)", start: month(2000 + $0 % 24, 5)) })
                        ]),
                        keys: ["Certificate track 27", "Issuer 13"], minPages: 1, maxPages: 6))

        // 7. Special characters and accents.
        var accented = person("Fran\u{00E7}ois Z\u{00F8}e M\u{00FC}ller-O\u{2019}Brien", title: "R&D Engineer, C++ and Swift")
        accented.email = "francois.muller@example.fr"
        out.append(Case(name: "special characters",
                        resume: resume("Special", person: accented, sections: [
                            section(.summary, text: "Specialist in \u{201C}smart\u{201D} quotes, na\u{00EF}ve Bayes, \u{00D1}and\u{00FA} routing and caf\u{00E9} analytics at 50% scale."),
                            section(.experience, entries: [
                                entry("Ing\u{00E9}nieur logiciel senior", "Soci\u{00E9}t\u{00E9} G\u{00E9}n\u{00E9}rale d\u{2019}Analyse", location: "Z\u{00FC}rich",
                                      start: month(2016, 9), current: true,
                                      bullets: ["Cut build time from 14 min to 3 min (a 78% gain) using C++ & CMake caching.",
                                                "Wrote 120+ unit tests; coverage rose from 41% to 88%.",
                                                "Mentored 6 engineers at S\u{00E3}o Paulo and \u{0141}\u{00F3}d\u{017A} offices."])
                            ]),
                            section(.skills, skills: [group("Languages", ["C++", "C#", "F#", "Swift", "Objective-C"])])
                        ]),
                        keys: ["francois.muller@example.fr", "R&D Engineer"], minPages: 1, maxPages: 3))

        // 8. Arabic name with mixed content.
        var arabic = person("\u{0645}\u{062D}\u{0645}\u{062F} \u{0639}\u{0628}\u{062F} \u{0627}\u{0644}\u{0644}\u{0647}", title: "\u{0645}\u{0647}\u{0646}\u{062F}\u{0633} \u{0628}\u{0631}\u{0645}\u{062C}\u{064A}\u{0627}\u{062A}")
        arabic.email = "mohammed.abdullah@example.com"
        out.append(Case(name: "arabic",
                        resume: resume("Arabic", person: arabic, sections: [
                            section(.summary, text: "\u{0645}\u{0647}\u{0646}\u{062F}\u{0633} \u{0628}\u{0631}\u{0645}\u{062C}\u{064A}\u{0627}\u{062A} \u{0644}\u{062F}\u{064A}\u{0647} \u{062E}\u{0628}\u{0631}\u{0629} \u{0641}\u{064A} \u{062A}\u{0637}\u{0648}\u{064A}\u{0631} \u{062A}\u{0637}\u{0628}\u{064A}\u{0642}\u{0627}\u{062A} \u{0627}\u{0644}\u{0647}\u{0627}\u{062A}\u{0641}."),
                            section(.experience, entries: [
                                entry("\u{0645}\u{0647}\u{0646}\u{062F}\u{0633} \u{0623}\u{0648}\u{0644}", "Gulf Software Co", start: month(2018, 2), current: true,
                                      bullets: ["\u{0642}\u{0627}\u{062F} \u{0641}\u{0631}\u{064A}\u{0642}\u{0627}\u{064B} \u{0645}\u{0646} \u{062E}\u{0645}\u{0633}\u{0629} \u{0645}\u{0647}\u{0646}\u{062F}\u{0633}\u{064A}\u{0646}.",
                                                "Shipped release 4.2 with offline support."])
                            ])
                        ]),
                        keys: ["mohammed.abdullah@example.com", "Gulf Software Co"], minPages: 1, maxPages: 3))

        // 9. CJK names.
        var cjk = person("\u{5C71}\u{7530} \u{592A}\u{90CE}", title: "\u{30BD}\u{30D5}\u{30C8}\u{30A6}\u{30A7}\u{30A2}\u{30A8}\u{30F3}\u{30B8}\u{30CB}\u{30A2}")
        cjk.email = "taro.yamada@example.jp"
        out.append(Case(name: "cjk",
                        resume: resume("CJK", person: cjk, sections: [
                            section(.summary, text: "\u{30E2}\u{30D0}\u{30A4}\u{30EB}\u{30A2}\u{30D7}\u{30EA}\u{306E}\u{958B}\u{767A}\u{3068}\u{54C1}\u{8CEA}\u{6539}\u{5584}\u{306B}\u{53D6}\u{308A}\u{7D44}\u{3093}\u{3067}\u{3044}\u{307E}\u{3059}\u{3002}"),
                            section(.experience, entries: [
                                entry("\u{30B7}\u{30CB}\u{30A2}\u{30A8}\u{30F3}\u{30B8}\u{30CB}\u{30A2}", "Tokyo Apps KK", start: month(2019, 4), current: true,
                                      bullets: ["\u{30A2}\u{30D7}\u{30EA}\u{306E}\u{8D77}\u{52D5}\u{6642}\u{9593}\u{3092}\u{534A}\u{5206}\u{306B}\u{77ED}\u{7E2E}\u{3057}\u{307E}\u{3057}\u{305F}\u{3002}",
                                                "\u{5927}\u{578B}\u{30EA}\u{30EA}\u{30FC}\u{30B9}\u{306E}\u{8A08}\u{753B}\u{3092}\u{4E3B}\u{5C0E}\u{3057}\u{307E}\u{3057}\u{305F}\u{3002}"])
                            ])
                        ]),
                        keys: ["taro.yamada@example.jp", "Tokyo Apps KK"], minPages: 1, maxPages: 3))

        var chinese = person("\u{674E}\u{660E}", title: "\u{4EA7}\u{54C1}\u{7ECF}\u{7406}")
        chinese.email = "li.ming@example.cn"
        out.append(Case(name: "chinese",
                        resume: resume("Chinese", person: chinese, sections: [
                            section(.experience, entries: [
                                entry("\u{9AD8}\u{7EA7}\u{4EA7}\u{54C1}\u{7ECF}\u{7406}", "Shanghai Digital Ltd", start: month(2017), end: month(2023),
                                      bullets: ["\u{8D1F}\u{8D23}\u{4ECE}\u{9700}\u{6C42}\u{5230}\u{53D1}\u{5E03}\u{7684}\u{5168}\u{6D41}\u{7A0B}\u{3002}"])
                            ])
                        ]),
                        keys: ["li.ming@example.cn", "Shanghai Digital Ltd"], minPages: 1, maxPages: 2))

        // 10. Very long URLs.
        var urlPerson = person("Priya Raman")
        urlPerson.portfolio = "https://portfolio.example.com/" + String(repeating: "case-study-segment/", count: 12) + "final"
        urlPerson.website = "https://example.org/" + String(repeating: "abcdefghij", count: 22)
        out.append(Case(name: "long urls",
                        resume: resume("Long URLs", person: urlPerson, sections: [
                            section(.projects, entries: [
                                entry("Portfolio rebuild", "Self", extra: "https://example.net/" + String(repeating: "path/segment/", count: 14),
                                      bullets: ["See https://example.com/" + String(repeating: "x", count: 150) + " for the full write up of the work."])
                            ])
                        ]),
                        keys: ["Priya Raman", "Portfolio rebuild"], minPages: 1, maxPages: 3))

        // 11 and 12. Both page sizes.
        for (label, size) in [("a4", PageSize.a4), ("us letter", PageSize.usLetter)] {
            out.append(Case(name: "page size " + label,
                            resume: resume("Size " + label, person: standard, sections: [
                                section(.experience, entries: jobs(5, bulletsEach: 4)),
                                section(.skills, skills: standardSkills())
                            ], pageSize: size),
                            keys: ["Jordan Whitfield", "Role Number 4 Lead"], minPages: 1, maxPages: 6))
        }

        // 13. Hidden sections.
        out.append(Case(name: "hidden sections",
                        resume: resume("Hidden", person: standard, sections: [
                            section(.experience, entries: jobs(2, bulletsEach: 2)),
                            section(.awards, entries: [entry("SECRETHIDDEN award", "SECRETHIDDEN body")], visible: false),
                            section(.interests, text: "SECRETHIDDEN interests", visible: false)
                        ]),
                        keys: ["Role Number 1 Lead"], minPages: 1, maxPages: 3))

        // 14. Photo present.
        var withPhoto = person("Elena Vasquez")
        withPhoto.photoData = photoData()
        out.append(Case(name: "photo",
                        resume: resume("Photo", person: withPhoto, sections: [
                            section(.summary, text: "Operations lead who builds calm, reliable teams."),
                            section(.experience, entries: jobs(2, bulletsEach: 3))
                        ]),
                        keys: ["Elena Vasquez", "Role Number 1 Lead"], minPages: 1, maxPages: 3))

        // 15. Heavy skills.
        out.append(Case(name: "heavy skills",
                        resume: resume("Skills", person: standard, sections: [
                            section(.skills, skills: (0..<5).map { g in group("Group \(g)", (0..<30).map { "Skill\(g)x\($0)" }) })
                        ]),
                        keys: ["Group 4", "Skill4x29"], minPages: 1, maxPages: 6))

        // 16. Only a name.
        out.append(Case(name: "name only",
                        resume: resume("Name only", person: person("Lone Name"), sections: []),
                        keys: ["Lone Name"], minPages: 1, maxPages: 1))

        // 17. Entries without dates and sparse fields.
        out.append(Case(name: "sparse entries",
                        resume: resume("Sparse", person: standard, sections: [
                            section(.experience, entries: [
                                entry("Freelance work"),
                                entry("", "Self employed", bullets: ["Handled invoicing and delivery for small clients."]),
                                entry("", "", detail: "A paragraph of detail with no heading at all."),
                                entry("Empty bullets", bullets: ["", "   ", "Kept this one."])
                            ])
                        ]),
                        keys: ["Freelance work", "Kept this one"], minPages: 1, maxPages: 2))

        // 18. Very long summary that must split between lines.
        let longSummary: String = (0..<70).map { "Sentence \($0) describes a result achieved with a partner team and the lesson that followed." }.joined(separator: " ")
        out.append(Case(name: "long summary",
                        resume: resume("Long summary", person: standard, sections: [
                            section(.summary, text: longSummary),
                            section(.experience, entries: jobs(2, bulletsEach: 2))
                        ]),
                        keys: ["Sentence 0 describes", "Sentence 69 describes"], minPages: 2, maxPages: 8))

        // 19. Style overrides.
        var styled = resume("Styled", person: withPhoto, sections: [
            section(.summary, text: "Style overrides are applied on top of the template."),
            section(.experience, entries: jobs(3, bulletsEach: 4)),
            section(.skills, skills: standardSkills())
        ])
        styled.style.accentHex = "#8A2BE2"
        styled.style.bodyFont = .georgia
        styled.style.headingFont = .futura
        styled.style.fontScale = 1.15
        styled.style.lineSpacing = 1.3
        styled.style.marginPoints = 60
        out.append(Case(name: "style overrides", resume: styled, keys: ["Elena Vasquez", "Role Number 2 Lead"], minPages: 1, maxPages: 6))

        // 20. Photo hidden by the user.
        var hiddenPhoto = styled
        hiddenPhoto.style = StyleOverrides()
        hiddenPhoto.style.showPhoto = false
        out.append(Case(name: "photo turned off", resume: hiddenPhoto, keys: ["Elena Vasquez"], minPages: 1, maxPages: 5))

        // 21. Right to left only.
        var rtlOnly = PersonalInfo()
        rtlOnly.fullName = "\u{0633}\u{0627}\u{0631}\u{0629} \u{0623}\u{062D}\u{0645}\u{062F}"
        rtlOnly.email = "sara.ahmed@example.com"
        out.append(Case(name: "rtl only",
                        resume: resume("RTL", person: rtlOnly, sections: [
                            section(.summary, text: "\u{0645}\u{062F}\u{064A}\u{0631}\u{0629} \u{0645}\u{0634}\u{0627}\u{0631}\u{064A}\u{0639} \u{0644}\u{062F}\u{064A}\u{0647}\u{0627} \u{062E}\u{0628}\u{0631}\u{0629} \u{0648}\u{0627}\u{0633}\u{0639}\u{0629}.")
                        ]),
                        keys: ["sara.ahmed@example.com"], minPages: 1, maxPages: 2))

        // 22. Many languages and interests.
        out.append(Case(name: "languages and interests",
                        resume: resume("Languages", person: standard, sections: [
                            section(.languages, skills: [group("", ["English", "German", "French", "Portuguese", "Italian"])]),
                            section(.interests, text: "Trail running\nPottery\nBoard game design"),
                            section(.references, entries: [entry("Available on request")])
                        ]),
                        keys: ["Portuguese", "Board game design", "Available on request"], minPages: 1, maxPages: 2))

        // 23. Custom section with text and entries.
        out.append(Case(name: "custom section",
                        resume: resume("Custom", person: standard, sections: [
                            section(.custom, title: "Speaking", text: "Regular conference speaker on design systems.",
                                    entries: [entry("Keynote at DesignConf", "DesignConf", start: month(2022, 10), bullets: ["Audience of 600 designers."])])
                        ]),
                        keys: ["Speaking", "Keynote at DesignConf", "Audience of 600 designers."], minPages: 1, maxPages: 2))

        // 24. Bullets with pasted markers.
        out.append(Case(name: "pasted bullet markers",
                        resume: resume("Markers", person: standard, sections: [
                            section(.experience, entries: [
                                entry("Analyst", "Bank Co", bullets: ["\u{2022} Built the monthly report.", "- Cleaned the ledger data.", "* Trained two juniors."])
                            ])
                        ]),
                        keys: ["Built the monthly report.", "Cleaned the ledger data.", "Trained two juniors."], minPages: 1, maxPages: 2))

        return out
    }

    // MARK: Cover letters

    static func letter(long: Bool = false, size: PageSize = .a4) -> CoverLetter {
        var l = CoverLetter(title: "Letter for Northwind", templateID: "cl.test.0")
        l.pageSize = size
        l.senderName = "Jordan Whitfield"
        l.senderTitle = "Product Designer"
        l.senderEmail = "sample.person@example.com"
        l.senderPhone = "+1 (555) 014-2290"
        l.senderLocation = "Austin, TX"
        l.recipientName = "Alex Rivera"
        l.recipientTitle = "Head of Design"
        l.companyName = "Northwind Studio"
        l.companyAddress = "12 Harbour Street\nPortland, OR"
        l.jobTitle = "Senior Product Designer"
        l.introduction = "I am writing to apply for the Senior Product Designer role at Northwind Studio."
        l.experienceParagraph = long
            ? (0..<60).map { "In project \($0) I led design work that shipped on time and was praised by customers." }.joined(separator: " ")
            : "Over eight years I have shipped consumer and business products, most recently leading a team of five."
        l.interestParagraph = "Your focus on calm, accessible software is what draws me to the team."
        l.closing = "Thank you for your time. I would welcome a conversation."
        return l
    }
}
