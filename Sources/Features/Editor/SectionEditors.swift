import SwiftUI

/// Chooses the editor that matches the section's shape.
struct SectionEditorView: View {
    @Binding var section: ResumeSection

    var body: some View {
        switch section.kind.shape {
        case .text:
            TextSectionEditor(section: $section)
        case .entries:
            EntriesSectionEditor(section: $section)
        case .skillGroups:
            SkillGroupsEditor(section: $section)
        }
    }
}

struct TextSectionEditor: View {
    @Binding var section: ResumeSection
    @State private var showExamples = false

    private var wordCount: Int {
        section.text.split(whereSeparator: { $0.isWhitespace }).count
    }

    private var tip: String {
        switch section.kind {
        case .summary: return "Two to four sentences work well. Mention your field, your strongest skills and what you are looking for."
        case .interests: return "Keep it short. A few real interests can start a conversation."
        default: return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.s + 2) {
            EdTextArea(text: $section.text,
                       prompt: section.kind == .summary ? "Write a short professional summary" : "Write here",
                       minHeight: 150)
            HStack {
                Text(wordCount == 1 ? "1 word" : "\(wordCount) words")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                Spacer()
                if section.kind == .summary {
                    EdTextButton(title: "Writing examples", systemImage: "text.book.closed") { showExamples = true }
                }
            }
            if !tip.isEmpty {
                Text(tip)
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
            }
        }
        .sheet(isPresented: $showExamples) {
            WritingExamplesSheet(mode: .summaries) { example in
                section.text = TextInsertion.insert(example, into: section.text)
            }
        }
    }
}

// MARK: - Personal information

struct PersonalInfoEditor: View {
    @Binding var personal: PersonalInfo
    let showsPhotoNote: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            PhotoRow(photoData: $personal.photoData, showsNote: showsPhotoNote)
            EdField(label: "Full name", text: $personal.fullName, contentType: .name, capitalization: .words)
            EdField(label: "Professional title", text: $personal.professionalTitle, prompt: "For example, Marketing Manager", capitalization: .words)
            EdField(label: "Email", text: $personal.email, keyboard: .emailAddress, contentType: .emailAddress, capitalization: .never)
            EdField(label: "Phone", text: $personal.phone, keyboard: .phonePad, contentType: .telephoneNumber)
            HStack(alignment: .top, spacing: CK.Space.m) {
                EdField(label: "City", text: $personal.city, contentType: .addressCity, capitalization: .words)
                EdField(label: "Country", text: $personal.country, contentType: .countryName, capitalization: .words)
            }
            EdField(label: "LinkedIn", text: $personal.linkedIn, prompt: "linkedin.com/in/yourname", keyboard: .URL, contentType: .URL, capitalization: .never)
            EdField(label: "Portfolio", text: $personal.portfolio, prompt: "Link to your work", keyboard: .URL, contentType: .URL, capitalization: .never)
            EdField(label: "Website", text: $personal.website, prompt: "Personal website", keyboard: .URL, contentType: .URL, capitalization: .never)
        }
    }
}
