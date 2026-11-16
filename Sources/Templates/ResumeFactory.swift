import Foundation

// MARK: - Resume and cover letter factory

/// Creates new, empty documents. Nothing here invents content: every section starts empty
/// so the editor can guide the user through filling it in.
enum ResumeFactory {

    /// Sections every resume has, whatever the template.
    static let requiredKinds: [SectionKind] = [.summary, .experience, .education, .skills]

    /// Section kinds for a new resume, in the order the template lists them:
    /// main column first, then the sidebar or rail. Required kinds are added if a template omits them.
    static func sectionKinds(for template: TemplateSpec) -> [SectionKind] {
        var kinds: [SectionKind] = []
        for kind in template.mainSections + template.sidebarSections {
            if !kinds.contains(kind) { kinds.append(kind) }
        }
        for kind in requiredKinds {
            if !kinds.contains(kind) { kinds.append(kind) }
        }
        return kinds
    }

    /// A new resume with empty sections in the template's order.
    static func newResume(template: TemplateSpec, title: String, pageSize: PageSize) -> Resume {
        let sections: [ResumeSection] = sectionKinds(for: template).map { kind in
            ResumeSection(kind: kind)
        }
        return Resume(
            title: title,
            templateID: template.id,
            pageSize: pageSize,
            sections: sections
        )
    }

    /// A blank resume: personal details plus one empty summary. Uses the default template.
    static func blankResume(title: String, pageSize: PageSize) -> Resume {
        var resume = Resume(
            title: title,
            templateID: TemplateLibrary.defaultTemplateID,
            pageSize: pageSize,
            sections: [ResumeSection(kind: .summary)]
        )
        resume.isBlank = true
        return resume
    }

    /// A new cover letter. When a resume is given, the sender block, page size and link are copied from it.
    /// Recipient and body text stay empty.
    static func newCoverLetter(templateID: String, title: String, from resume: Resume?) -> CoverLetter {
        var letter = CoverLetter(title: title, templateID: templateID)
        if let resume = resume {
            letter.pageSize = resume.pageSize
            letter.linkedResumeID = resume.id
            letter.senderName = resume.personal.fullName
            letter.senderTitle = resume.personal.professionalTitle
            letter.senderEmail = resume.personal.email
            letter.senderPhone = resume.personal.phone
            letter.senderLocation = resume.personal.locationLine
        }
        return letter
    }
}
