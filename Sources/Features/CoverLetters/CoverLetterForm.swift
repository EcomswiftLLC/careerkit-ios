import SwiftUI

/// The edit-mode form for a cover letter: sender, recipient and job, then the letter itself.
struct CoverLetterForm: View {
    @Binding var letter: CoverLetter
    let resumes: [Resume]
    let onSuggest: (CoverLetterField) -> Void

    @State private var expanded: Set<String> = ["letter"]
    @State private var showReplaceSender = false

    private var linkedResume: Resume? {
        guard let id = letter.linkedResumeID else { return nil }
        return resumes.first(where: { $0.id == id })
    }

    var body: some View {
        VStack(spacing: CK.Space.m) {
            titleBlock
            resumeLink
            matchingStyleBanner
            EdDisclosureCard(title: "Sender", subtitle: letter.senderName.isEmpty ? "Your name and contact details" : letter.senderName,
                             systemImage: "person", isExpanded: binding("sender")) { senderFields }
            EdDisclosureCard(title: "Recipient and job",
                             subtitle: letter.companyName.isEmpty ? "Company, hiring manager, role" : letter.companyName,
                             systemImage: "building.2", isExpanded: binding("recipient")) { recipientFields }
            EdDisclosureCard(title: "Letter", subtitle: "Greeting, body and sign-off",
                             systemImage: "envelope", isExpanded: binding("letter")) { letterFields }
        }
    }

    // MARK: Top blocks

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Letter title", text: $letter.title)
                .font(CK.Font.title(26))
                .foregroundStyle(CK.Palette.ink)
                .frame(minHeight: 44)
            Text("Shown in your list and used as the file name when you export.")
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var resumeLink: some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            Menu {
                Button("No linked resume") { link(nil) }
                ForEach(resumes) { resume in
                    Button(resume.title) { link(resume) }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Linked resume").font(CK.Font.caption).foregroundStyle(CK.Palette.graphite)
                        Text(linkedResume?.title ?? "None").font(CK.Font.body).foregroundStyle(CK.Palette.ink)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 13)).foregroundStyle(CK.Palette.graphite)
                }
                .padding(CK.Space.m)
                .frame(minHeight: 56)
                .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
            }
            .accessibilityLabel("Linked resume, \(linkedResume?.title ?? "none")")
            if linkedResume != nil {
                EdTextButton(title: "Replace sender details with resume details", systemImage: "arrow.down.doc") {
                    showReplaceSender = true
                }
            }
        }
        .confirmationDialog("Replace sender details?", isPresented: $showReplaceSender, titleVisibility: .visible) {
            Button("Replace") {
                if let resume = linkedResume { CoverLetterPrefill.apply(resume, to: &letter, overwrite: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your name, title, email, phone and location in this letter will be overwritten with the values from the resume.")
        }
    }

    @ViewBuilder
    private var matchingStyleBanner: some View {
        if let resume = linkedResume,
           let match = CoverLetterTemplateLibrary.all.first(where: { $0.matchingResumeTemplateID == resume.templateID }),
           match.id != letter.templateID {
            VStack(alignment: .leading, spacing: CK.Space.s) {
                Text("Match your resume")
                    .font(CK.Font.headline(17))
                    .foregroundStyle(CK.Palette.ink)
                Text("\"\(resume.title)\" uses the \(EditorRender.template(id: resume.templateID).name) design. The \(match.name) letter template shares it, so the two documents look like a set.")
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                EdTextButton(title: "Use \(match.name)", systemImage: "wand.and.stars") {
                    letter.templateID = match.id
                    letter.style.accentHex = resume.style.accentHex
                    letter.style.bodyFont = resume.style.bodyFont
                    letter.style.headingFont = resume.style.headingFont
                }
            }
            .padding(CK.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.champagne.opacity(0.7), lineWidth: 1))
        }
    }

    // MARK: Field groups

    private var senderFields: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            EdField(label: "Your name", text: $letter.senderName, contentType: .name, capitalization: .words)
            EdField(label: "Your title", text: $letter.senderTitle, capitalization: .words)
            EdField(label: "Email", text: $letter.senderEmail, keyboard: .emailAddress, contentType: .emailAddress, capitalization: .never)
            EdField(label: "Phone", text: $letter.senderPhone, keyboard: .phonePad, contentType: .telephoneNumber)
            EdField(label: "Location", text: $letter.senderLocation, prompt: "City, country", capitalization: .words)
        }
    }

    private var recipientFields: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            EdField(label: "Hiring manager", text: $letter.recipientName, prompt: "Name, if you know it", capitalization: .words)
            EdField(label: "Their title", text: $letter.recipientTitle, capitalization: .words)
            EdField(label: "Company", text: $letter.companyName, capitalization: .words)
            EdField(label: "Company address", text: $letter.companyAddress, capitalization: .words)
            EdField(label: "Job title you are applying for", text: $letter.jobTitle, capitalization: .words)
            DatePicker("Date", selection: $letter.date, displayedComponents: .date)
                .font(CK.Font.body)
                .tint(CK.Palette.forest)
                .frame(minHeight: 44)
            EdTextArea(label: "Job description (optional)", text: $letter.jobDescription,
                       prompt: "Paste the advert here to keep it beside your letter", minHeight: 110)
            Label("The job description stays on this device. It is not added to your letter.", systemImage: "lock")
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
        }
    }

    private var letterFields: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            VStack(alignment: .leading, spacing: 6) {
                EdField(label: "Greeting", text: $letter.greeting, prompt: letter.effectiveGreeting)
                suggestButton(.greeting)
            }
            paragraph(.introduction, text: $letter.introduction, prompt: "Say which role you are applying for and why you are a good fit.")
            paragraph(.experience, text: $letter.experienceParagraph, prompt: "Give one or two examples of work that matches what they need.")
            paragraph(.interest, text: $letter.interestParagraph, prompt: "Explain what draws you to this company.")
            paragraph(.closing, text: $letter.closing, prompt: "Thank the reader and say how to reach you.")
            VStack(alignment: .leading, spacing: 6) {
                EdField(label: "Sign-off", text: $letter.signOff)
                suggestButton(.signOff)
            }
        }
    }

    private func paragraph(_ field: CoverLetterField, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            EdTextArea(label: field.title, text: text, prompt: prompt, minHeight: 110)
            suggestButton(field)
        }
    }

    private func suggestButton(_ field: CoverLetterField) -> some View {
        EdTextButton(title: "Suggestions", systemImage: "text.book.closed") { onSuggest(field) }
            .accessibilityLabel("\(field.title) suggestions")
    }

    // MARK: Helpers

    private func binding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(key) },
            set: { open in
                if open { expanded.insert(key) } else { expanded.remove(key) }
            }
        )
    }

    private func link(_ resume: Resume?) {
        letter.linkedResumeID = resume?.id
        if let resume { CoverLetterPrefill.apply(resume, to: &letter, overwrite: false) }
    }

    /// Applies a chosen suggestion to the right field, filling in company, role and manager.
    static func apply(_ field: CoverLetterField, suggestion: String, to letter: inout CoverLetter) {
        let filled = CoverLetterSuggestions.fill(suggestion, company: letter.companyName,
                                                 role: letter.jobTitle, manager: letter.recipientName)
        switch field {
        case .greeting: letter.greeting = filled
        case .signOff: letter.signOff = filled
        case .introduction: letter.introduction = TextInsertion.insert(filled, into: letter.introduction)
        case .experience: letter.experienceParagraph = TextInsertion.insert(filled, into: letter.experienceParagraph)
        case .interest: letter.interestParagraph = TextInsertion.insert(filled, into: letter.interestParagraph)
        case .closing: letter.closing = TextInsertion.insert(filled, into: letter.closing)
        }
    }
}

// MARK: - Suggestion sheet

struct CoverLetterSuggestionSheet: View {
    let field: CoverLetterField
    let letter: CoverLetter
    let onUse: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.m) {
                    Text("Company, role and manager names are filled in from your letter. Change anything so it sounds like you.")
                        .font(CK.Font.callout)
                        .foregroundStyle(CK.Palette.graphite)
                    ForEach(CoverLetterSuggestions.items(for: field), id: \.self) { item in
                        let filled = CoverLetterSuggestions.fill(item, company: letter.companyName,
                                                                 role: letter.jobTitle, manager: letter.recipientName)
                        VStack(alignment: .leading, spacing: CK.Space.s) {
                            Text(filled)
                                .font(CK.Font.body)
                                .foregroundStyle(CK.Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Spacer()
                                EdTextButton(title: "Use this", systemImage: "plus") {
                                    onUse(item)
                                    dismiss()
                                }
                            }
                        }
                        .padding(CK.Space.m)
                        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
                        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
                    }
                }
                .padding(CK.Space.m)
            }
            .background(CK.Palette.ivory.ignoresSafeArea())
            .navigationTitle(field.suggestionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.font(CK.Font.label)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
