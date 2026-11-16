import SwiftUI

/// Choose a template, optionally link a resume (details are copied from it), and create the letter.
struct NewCoverLetterSheet: View {
    let onCreated: (UUID) -> Void

    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var templateID: String = CoverLetterTemplateLibrary.all.first?.id ?? ""
    @State private var resumeID: UUID?

    private var resumes: [Resume] { store.resumes.filter { !$0.isArchived } }
    private var linkedResume: Resume? {
        guard let resumeID else { return nil }
        return store.resume(id: resumeID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.l) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("New cover letter")
                            .ckTitleFont(28)
                            .foregroundStyle(CK.Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("Link a resume to fill in your contact details. You can change everything afterwards.")
                            .font(CK.Font.callout)
                            .foregroundStyle(CK.Palette.graphite)
                    }
                    EdField(label: "Letter title", text: $title, prompt: "Cover letter", capitalization: .words)
                    resumePicker
                    VStack(alignment: .leading, spacing: CK.Space.m) {
                        Text("Template").font(CK.Font.label).foregroundStyle(CK.Palette.ink)
                        CoverLetterTemplateGrid(selectedID: templateID) { id in templateID = id }
                    }
                }
                .padding(CK.Space.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CK.Palette.ivory.ignoresSafeArea())
            .navigationTitle("New letter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.font(CK.Font.label)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Rectangle().fill(CK.Palette.hairline).frame(height: 0.5)
                    Button("Create letter") { create() }
                        .buttonStyle(.ckPrimary)
                        .padding(CK.Space.m)
                }
                .background(CK.Palette.ivory)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var resumePicker: some View {
        Menu {
            Button("No resume") { resumeID = nil }
            ForEach(resumes) { resume in
                Button(resume.title) { select(resume) }
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
    }

    private func select(_ resume: Resume) {
        resumeID = resume.id
        // Start from the letter design that pairs with the chosen resume.
        if let match = CoverLetterTemplateLibrary.all.first(where: { $0.matchingResumeTemplateID == resume.templateID }) {
            templateID = match.id
        }
    }

    private func create() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Cover letter" : trimmed
        let resume = linkedResume
        var letter = ResumeFactory.newCoverLetter(templateID: templateID, title: name, from: resume)
        letter.linkedResumeID = resume?.id
        letter.pageSize = resume?.pageSize ?? appState.defaultPageSize
        store.upsert(letter)
        onCreated(letter.id)
        dismiss()
    }
}
