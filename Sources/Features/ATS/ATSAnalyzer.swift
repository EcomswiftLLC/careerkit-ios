import Foundation
import PDFKit

struct ATSFinding: Identifiable {
    enum Severity {
        case good
        case info
        case warning
    }

    let id = UUID()
    let severity: Severity
    let title: String
    let detail: String
}

struct ATSReport {
    let findings: [ATSFinding]
    let disclaimer: String

    var warningCount: Int {
        return findings.filter { $0.severity == .warning }.count
    }
}

/// General resume-readability checks. These are common practice guidance, not a score from any employer system.
enum ATSAnalyzer {
    static let disclaimerText: String = String(localized: "This is general guidance based on common resume practice. It is not a score from any employer's system and it does not guarantee that a resume will be accepted or read in a particular way.")

    static func analyze(resume: Resume, template: TemplateSpec, pdfData: Data) -> ATSReport {
        var findings: [ATSFinding] = []
        findings.append(contentsOf: contactFindings(resume))
        findings.append(contentsOf: headingFindings(resume))
        findings.append(contentsOf: dateFindings(resume))
        findings.append(contentsOf: summaryFindings(resume))
        findings.append(contentsOf: extractionFindings(resume, pdfData: pdfData))
        findings.append(contentsOf: layoutFindings(template))
        findings.append(contentsOf: photoFindings(resume, template: template))
        findings.append(contentsOf: symbolFindings(resume))
        findings.append(contentsOf: lengthFindings(resume, pdfData: pdfData))

        // Warnings first, then notes, then things that look fine. Order inside each group is kept.
        var ordered: [ATSFinding] = []
        for severity in [ATSFinding.Severity.warning, ATSFinding.Severity.info, ATSFinding.Severity.good] {
            ordered.append(contentsOf: findings.filter { $0.severity == severity })
        }
        return ATSReport(findings: ordered, disclaimer: disclaimerText)
    }

    // MARK: Contact details

    private static func contactFindings(_ resume: Resume) -> [ATSFinding] {
        var out: [ATSFinding] = []
        let p = resume.personal
        let name = RenderContent.trimmed(p.fullName)
        let email = RenderContent.trimmed(p.email)
        let phone = RenderContent.trimmed(p.phone)

        if name.isEmpty {
            out.append(ATSFinding(severity: .warning,
                                  title: String(localized: "Add your name"),
                                  detail: String(localized: "Your full name is the first thing a recruiter or a parser looks for.")))
        }
        if email.isEmpty {
            out.append(ATSFinding(severity: .warning,
                                  title: String(localized: "Add an email address"),
                                  detail: String(localized: "Most employers reply by email, so it should be easy to find at the top.")))
        } else if !looksLikeEmail(email) {
            out.append(ATSFinding(severity: .warning,
                                  title: String(localized: "Check your email address"),
                                  detail: String(localized: "The address \"\(email)\" does not look complete. Make sure it has a name, an @ sign and a domain.")))
        }
        if phone.isEmpty {
            out.append(ATSFinding(severity: .info,
                                  title: String(localized: "Consider adding a phone number"),
                                  detail: String(localized: "Some employers prefer to call. Leave it out if you would rather be contacted by email.")))
        } else {
            let digits: Int = phone.filter { $0.isNumber }.count
            if digits < 7 || digits > 15 {
                out.append(ATSFinding(severity: .warning,
                                      title: String(localized: "Check your phone number"),
                                      detail: String(localized: "The number has \(digits) digits. Include the country code if you apply abroad.")))
            }
        }
        if !name.isEmpty && looksLikeEmail(email) && (phone.isEmpty || (7...15).contains(phone.filter { $0.isNumber }.count)) {
            out.append(ATSFinding(severity: .good,
                                  title: String(localized: "Contact details look complete"),
                                  detail: String(localized: "Your name and a working way to reach you are at the top of the document.")))
        }
        return out
    }

    private static func looksLikeEmail(_ value: String) -> Bool {
        guard !value.contains(" ") else { return false }
        let parts: [Substring] = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain: Substring = parts[1]
        guard let dot = domain.lastIndex(of: ".") else { return false }
        let tld = domain[domain.index(after: dot)...]
        return domain.first != "." && tld.count >= 2
    }

    // MARK: Headings

    private static let standardHeadings: Set<String> = [
        "summary", "professional summary", "profile", "professional profile", "objective", "career objective",
        "experience", "work experience", "professional experience", "employment history", "work history",
        "education", "education and training", "skills", "technical skills", "key skills", "core skills",
        "certifications", "certificates", "licenses and certifications", "licences and certifications",
        "projects", "awards", "honors", "honours", "awards and honors", "languages",
        "publications", "volunteer experience", "volunteering", "internships", "memberships",
        "professional memberships", "references", "courses", "training", "interests", "additional information"
    ]

    private static func headingFindings(_ resume: Resume) -> [ATSFinding] {
        let sections: [ResumeSection] = RenderContent.visibleSections(resume)
        var unusual: [String] = []
        for section in sections {
            let label: String = RenderContent.label(for: section)
            let lower: String = label.lowercased()
            if standardHeadings.contains(lower) { continue }
            if lower == section.kind.defaultTitle.lowercased() { continue }
            unusual.append(label)
        }
        var out: [ATSFinding] = []
        if unusual.isEmpty {
            if !sections.isEmpty {
                out.append(ATSFinding(severity: .good,
                                      title: String(localized: "Section headings are standard"),
                                      detail: String(localized: "Headings such as Work Experience and Education are easy for software and people to find.")))
            }
        } else {
            let list: String = unusual.prefix(4).map { "\"\($0)\"" }.joined(separator: ", ")
            out.append(ATSFinding(severity: .warning,
                                  title: String(localized: "Some headings are unusual"),
                                  detail: String(localized: "Software may not recognise \(list). Common names such as Work Experience, Education and Skills are safer.")))
        }

        let hasExperience: Bool = sections.contains(where: { [SectionKind.experience, .internships, .volunteer, .projects].contains($0.kind) })
        if !hasExperience && !sections.isEmpty {
            out.append(ATSFinding(severity: .info,
                                  title: String(localized: "No experience section"),
                                  detail: String(localized: "If you have worked, interned, volunteered or built projects, a section for it shows what you can do.")))
        }
        if !sections.contains(where: { $0.kind == .education }) && !sections.isEmpty {
            out.append(ATSFinding(severity: .info,
                                  title: String(localized: "No education section"),
                                  detail: String(localized: "Many employers look for education or training even when it is brief.")))
        }
        if !sections.contains(where: { $0.kind == .skills }) && !sections.isEmpty {
            out.append(ATSFinding(severity: .info,
                                  title: String(localized: "No skills section"),
                                  detail: String(localized: "A short skills list helps a reader match you to a role quickly.")))
        }
        return out
    }

    // MARK: Dates

    private static func dateFindings(_ resume: Resume) -> [ATSFinding] {
        let jobKinds: [SectionKind] = [.experience, .internships, .volunteer]
        var total: Int = 0
        var undated: Int = 0
        var openEnded: Int = 0
        for section in RenderContent.visibleSections(resume) where jobKinds.contains(section.kind) {
            for entry in RenderContent.renderableEntries(section) {
                total += 1
                if entry.start == nil && entry.end == nil && !entry.isCurrent {
                    undated += 1
                } else if entry.start != nil && entry.end == nil && !entry.isCurrent {
                    openEnded += 1
                }
            }
        }
        guard total > 0 else { return [] }
        var out: [ATSFinding] = []
        if undated > 0 {
            out.append(ATSFinding(severity: .warning,
                                  title: String(localized: "Some roles have no dates"),
                                  detail: String(localized: "\(undated) of \(total) roles have no start or end date. Dates help readers see your timeline.")))
        }
        if openEnded > 0 {
            out.append(ATSFinding(severity: .info,
                                  title: String(localized: "Some roles have no end date"),
                                  detail: String(localized: "\(openEnded) roles show a start date only. Mark a role as current if you still hold it.")))
        }
        if undated == 0 && openEnded == 0 {
            out.append(ATSFinding(severity: .good,
                                  title: String(localized: "Roles have dates"),
                                  detail: String(localized: "Every role shows when you held it.")))
        }
        return out
    }

    // MARK: Summary

    private static func summaryFindings(_ resume: Resume) -> [ATSFinding] {
        let summary: ResumeSection? = RenderContent.visibleSections(resume).first(where: { $0.kind == .summary })
        guard let section = summary else {
            return [ATSFinding(severity: .info,
                               title: String(localized: "No summary"),
                               detail: String(localized: "Two or three sentences at the top can tell a reader who you are and what you are looking for."))]
        }
        let words: Int = wordCount(section.text)
        if words > 120 {
            return [ATSFinding(severity: .info,
                               title: String(localized: "Summary is long"),
                               detail: String(localized: "Your summary has \(words) words. Around 40 to 90 words is easier to read at a glance."))]
        }
        if words < 20 {
            return [ATSFinding(severity: .info,
                               title: String(localized: "Summary is very short"),
                               detail: String(localized: "Your summary has \(words) words. A couple of sentences gives a reader more to work with."))]
        }
        return [ATSFinding(severity: .good,
                           title: String(localized: "Summary is present"),
                           detail: String(localized: "A short summary of \(words) words opens the document."))]
    }

    // MARK: Text extraction

    private static func extractionFindings(_ resume: Resume, pdfData: Data) -> [ATSFinding] {
        guard !pdfData.isEmpty else {
            return [ATSFinding(severity: .warning,
                               title: String(localized: "Preview is not ready"),
                               detail: String(localized: "The document could not be checked yet. Open the preview and try again."))]
        }
        let text: String = PDFValidator.extractText(from: pdfData)
        let flat: String = PDFValidator.normalise(text)
        if flat.isEmpty {
            return [ATSFinding(severity: .warning,
                               title: String(localized: "Text could not be read from the PDF"),
                               detail: String(localized: "Software needs real text, not an image of text. Try another template and check again."))]
        }
        let expected: [String] = RenderContent.expectedStrings(for: resume)
        guard !expected.isEmpty else { return [] }
        var found: Int = 0
        for value in expected {
            let needle: String = PDFValidator.normalise(value)
            if needle.isEmpty || flat.contains(needle) { found += 1 }
        }
        let ratio: Double = Double(found) / Double(expected.count)
        if ratio >= 0.9 {
            return [ATSFinding(severity: .good,
                               title: String(localized: "Text reads back correctly"),
                               detail: String(localized: "The text in the PDF can be selected and read in order, which is what parsing software needs."))]
        }
        let percent: Int = Int((ratio * 100).rounded())
        return [ATSFinding(severity: .warning,
                           title: String(localized: "Some text reads back out of order"),
                           detail: String(localized: "About \(percent) percent of your text was found in a clean order. A single column template is the safest choice."))]
    }

    // MARK: Layout and photo

    private static func layoutFindings(_ template: TemplateSpec) -> [ATSFinding] {
        switch template.layout {
        case .singleColumn:
            if template.isATSFriendly {
                return [ATSFinding(severity: .good,
                                   title: String(localized: "Single column layout"),
                                   detail: String(localized: "One column is read from top to bottom without surprises."))]
            }
            return [ATSFinding(severity: .info,
                               title: String(localized: "Decorative styling"),
                               detail: String(localized: "This template uses colour or banners. The text is still real text, but plain styles are the safest."))]
        case .sidebarLeft, .sidebarRight:
            return [ATSFinding(severity: .warning,
                               title: String(localized: "Sidebar layout"),
                               detail: String(localized: "Some software reads a sidebar before or after the main text, or mixes the two. A single column template avoids this."))]
        case .headerThenTwoColumn:
            return [ATSFinding(severity: .warning,
                               title: String(localized: "Two column layout"),
                               detail: String(localized: "Some software can mix the lines of two columns. A single column template avoids this."))]
        }
    }

    private static func photoFindings(_ resume: Resume, template: TemplateSpec) -> [ATSFinding] {
        let shown: Bool = resume.personal.photoData != nil && resume.style.showPhoto && template.photo != .none
        if shown {
            return [ATSFinding(severity: .warning,
                               title: String(localized: "Photo included"),
                               detail: String(localized: "Software ignores photos, and in some countries employers prefer resumes without one. Check the norm for where you are applying."))]
        }
        return []
    }

    // MARK: Symbols

    private static func symbolFindings(_ resume: Resume) -> [ATSFinding] {
        var texts: [String] = RenderContent.expectedStrings(for: resume)
        for section in RenderContent.visibleSections(resume) {
            for entry in RenderContent.renderableEntries(section) {
                texts.append(entry.detail)
                texts.append(entry.extra)
            }
            for group in RenderContent.renderableSkillGroups(section) {
                texts.append(group.name)
                texts.append(contentsOf: group.items)
            }
        }
        let allowed: Set<UInt32> = [0x00A9, 0x00AE, 0x2122, 0x00B0]
        var seen: [Character] = []
        for text in texts {
            for scalar in text.unicodeScalars {
                guard !allowed.contains(scalar.value) else { continue }
                let props = scalar.properties
                let isEmoji: Bool = props.isEmojiPresentation || (props.isEmoji && scalar.value >= 0x2190)
                let isSymbol: Bool = props.generalCategory == .otherSymbol || props.generalCategory == .privateUse
                if isEmoji || isSymbol {
                    let ch = Character(scalar)
                    if !seen.contains(ch) { seen.append(ch) }
                }
            }
        }
        if seen.isEmpty {
            return [ATSFinding(severity: .good,
                               title: String(localized: "No unusual symbols"),
                               detail: String(localized: "The text uses ordinary letters, numbers and punctuation."))]
        }
        let sample: String = seen.prefix(6).map { String($0) }.joined(separator: " ")
        return [ATSFinding(severity: .warning,
                           title: String(localized: "Unusual symbols found"),
                           detail: String(localized: "Symbols and pictures such as \(sample) may not be read by some software. Plain words are safer."))]
    }

    // MARK: Length

    private static func lengthFindings(_ resume: Resume, pdfData: Data) -> [ATSFinding] {
        var out: [ATSFinding] = []
        let pages: Int = PDFDocument(data: pdfData)?.pageCount ?? 0
        let words: Int = RenderContent.expectedStrings(for: resume).reduce(0) { $0 + wordCount($1) }

        if pages >= 3 {
            out.append(ATSFinding(severity: .warning,
                                  title: String(localized: "Document runs to \(pages) pages"),
                                  detail: String(localized: "Most resumes are one or two pages. Consider trimming older roles or shortening bullet points.")))
        } else if pages > 0 {
            out.append(ATSFinding(severity: .good,
                                  title: pages == 1 ? String(localized: "Fits on one page") : String(localized: "Two pages"),
                                  detail: String(localized: "The length is within what most employers expect.")))
        }
        if words > 0 && words < 120 {
            out.append(ATSFinding(severity: .info,
                                  title: String(localized: "Very little content so far"),
                                  detail: String(localized: "There are about \(words) words in the document. Add roles, results and skills to give a reader more to go on.")))
        }

        var longBullets: Int = 0
        for section in RenderContent.visibleSections(resume) {
            for entry in RenderContent.renderableEntries(section) {
                for bullet in RenderContent.renderableBullets(entry) where wordCount(bullet) > 45 {
                    longBullets += 1
                }
            }
        }
        if longBullets > 0 {
            out.append(ATSFinding(severity: .info,
                                  title: String(localized: "Some bullet points are long"),
                                  detail: String(localized: "\(longBullets) bullets have more than 45 words. One or two lines each is easier to scan.")))
        }
        return out
    }

    private static func wordCount(_ text: String) -> Int {
        return text.split(whereSeparator: { $0.isWhitespace }).count
    }
}
