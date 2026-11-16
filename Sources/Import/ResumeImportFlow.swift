import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension View {
    /// Presents the import flow (PDF or pasted text, then review) and reports the new resume id after the sheet is gone.
    func ckImportResumeSheet(isPresented: Binding<Bool>, onCreated: @escaping (UUID) -> Void) -> some View {
        sheet(isPresented: isPresented) {
            ResumeImportFlow(onCreated: { newID in
                isPresented.wrappedValue = false
                CKDeferred.afterDismiss { onCreated(newID) }
            })
        }
    }
}

/// Import an existing resume: pick a PDF or paste text, review what was found, then create the resume.
/// Contains its own NavigationStack, so present it as a sheet. Everything is read on the device.
struct ResumeImportFlow: View {
    let onCreated: (UUID) -> Void

    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var pastedText = ""
    @State private var showPicker = false
    @State private var isReading = false
    @State private var importError: ResumeImportError?
    @State private var draft: ResumeImportDraft = .empty
    @State private var showReview = false

    init(onCreated: @escaping (UUID) -> Void) {
        self.onCreated = onCreated
    }

    private var trimmedPaste: String {
        pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.l) {
                    intro
                    if let importError {
                        errorCard(importError)
                    }
                    pdfCard
                    pasteCard
                    privacyNote
                }
                .padding(CK.Space.m)
                .padding(.bottom, CK.Space.xl)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CK.Palette.ivory.ignoresSafeArea())
            .navigationTitle("Import resume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.font(CK.Font.label)
                }
            }
            .navigationDestination(isPresented: $showReview) {
                ResumeImportReviewView(draft: $draft, onCreate: create)
            }
            .fileImporter(isPresented: $showPicker,
                          allowedContentTypes: [UTType.pdf],
                          allowsMultipleSelection: false) { result in
                handlePick(result)
            }
            .overlay {
                if isReading { readingOverlay }
            }
        }
    }

    // MARK: Pieces

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bring in your current resume")
                .ckTitleFont(28)
                .foregroundStyle(CK.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("CareerKit reads the text of your resume and sorts it into sections. You check the result before anything is saved.")
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pdfCard: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            optionHeader(systemImage: "doc.richtext",
                         title: String(localized: "From a PDF"),
                         detail: String(localized: "A PDF with selectable text, up to 10 MB and 10 pages."))
            Button {
                importError = nil
                showPicker = true
            } label: {
                Label("Choose a PDF", systemImage: "folder")
            }
            .buttonStyle(.ckPrimary)
            .disabled(isReading)
        }
        .padding(CK.Space.m)
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
    }

    private var pasteCard: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            optionHeader(systemImage: "text.alignleft",
                         title: String(localized: "From text"),
                         detail: String(localized: "Copy the text from a document or an email and paste it here."))
            EdTextArea(label: String(localized: "Resume text"),
                       text: $pastedText,
                       prompt: String(localized: "Paste your resume text"),
                       minHeight: 180)
            Button {
                continueWithPaste()
            } label: {
                Text("Continue with this text")
            }
            .buttonStyle(.ckSecondary)
            .disabled(trimmedPaste.isEmpty || isReading)
        }
        .padding(CK.Space.m)
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
    }

    private func optionHeader(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: CK.Space.s + 4) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(CK.Palette.forest)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .ckHeadlineFont(18)
                    .foregroundStyle(CK.Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(detail)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: CK.Space.s + 4) {
            Image(systemName: "lock")
                .font(.system(size: 16))
                .foregroundStyle(CK.Palette.forest)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text("Nothing is uploaded. Scanned pages and photos of a resume hold pictures of text rather than text, so they cannot be imported.")
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func errorCard(_ error: ResumeImportError) -> some View {
        HStack(alignment: .top, spacing: CK.Space.s + 4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18))
                .foregroundStyle(CK.Palette.danger)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(error.title)
                    .font(CK.Font.label)
                    .foregroundStyle(CK.Palette.ink)
                Text(error.message)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(CK.Space.m)
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.danger.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var readingOverlay: some View {
        ZStack {
            CK.Palette.ivory.opacity(0.7).ignoresSafeArea()
            HStack(spacing: CK.Space.s + 4) {
                ProgressView()
                Text("Reading your resume")
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.ink)
            }
            .padding(CK.Space.l)
            .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Work

    private func handlePick(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            importError = .unreadable
        case .success(let urls):
            guard let url = urls.first else { return }
            run {
                let text: String = try ResumeImporter.readPDF(at: url)
                return ResumeImporter.parse(text)
            }
        }
    }

    private func continueWithPaste() {
        let text: String = pastedText
        run {
            try ResumeImporter.draft(fromPastedText: text)
        }
    }

    /// Runs the reading work off the main thread, then shows the review or an error.
    private func run(_ work: @escaping () throws -> ResumeImportDraft) {
        importError = nil
        isReading = true
        Task {
            let outcome: Result<ResumeImportDraft, ResumeImportError> = await Task.detached(priority: .userInitiated) { () -> Result<ResumeImportDraft, ResumeImportError> in
                do {
                    return .success(try work())
                } catch let error as ResumeImportError {
                    return .failure(error)
                } catch {
                    return .failure(.unreadable)
                }
            }.value
            isReading = false
            switch outcome {
            case .success(let value):
                if value.hasContent {
                    draft = value
                    showReview = true
                } else {
                    importError = .emptyText
                }
            case .failure(let error):
                importError = error
                UIAccessibility.post(notification: .announcement, argument: error.title)
            }
        }
    }

    private func create() {
        let resume: Resume = draft.makeResume(title: draft.suggestedTitle,
                                              templateID: TemplateLibrary.defaultTemplateID,
                                              pageSize: appState.defaultPageSize)
        store.upsert(resume)
        store.flushNow()
        onCreated(resume.id)
        dismiss()
    }
}

// MARK: - Review

/// Shows what the importer found, section by section. Each section can be renamed or left out.
struct ResumeImportReviewView: View {
    @Binding var draft: ResumeImportDraft
    let onCreate: () -> Void

    private var includedSummary: String {
        let count: Int = draft.sections.filter { $0.isIncluded }.count
        if count == 1 { return String(localized: "1 section will be added.") }
        return String(localized: "\(count) sections will be added.")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CK.Space.l) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Check what was found")
                        .ckTitleFont(28)
                        .foregroundStyle(CK.Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Remove anything that does not belong and fix the details below. Every word stays editable in the editor afterwards.")
                        .font(CK.Font.callout)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if draft.wasTruncated {
                    Text("This text was very long, so only the first 100,000 characters were read.")
                        .font(CK.Font.callout)
                        .foregroundStyle(CK.Palette.ink)
                        .padding(CK.Space.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).fill(CK.Palette.stone))
                }

                detailsCard

                VStack(alignment: .leading, spacing: CK.Space.s) {
                    Text("Sections")
                        .ckHeadlineFont(20)
                        .foregroundStyle(CK.Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    if draft.sections.isEmpty {
                        Text("No sections were recognised. Your details above will be used, and you can add sections in the editor.")
                            .font(CK.Font.callout)
                            .foregroundStyle(CK.Palette.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(includedSummary)
                            .font(CK.Font.caption)
                            .foregroundStyle(CK.Palette.graphite)
                    }
                }

                ForEach($draft.sections) { $item in
                    ImportSectionCard(item: $item)
                }

                Button {
                    onCreate()
                } label: {
                    Text("Create resume")
                }
                .buttonStyle(.ckPrimary)
                .disabled(!draft.hasContent)
                .padding(.top, CK.Space.s)
            }
            .padding(CK.Space.m)
            .padding(.bottom, CK.Space.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(CK.Palette.ivory.ignoresSafeArea())
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            HStack(spacing: CK.Space.s + 4) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 18))
                    .foregroundStyle(CK.Palette.forest)
                    .accessibilityHidden(true)
                Text("Your details")
                    .ckHeadlineFont(18)
                    .foregroundStyle(CK.Palette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            EdField(label: String(localized: "Full name"), text: $draft.personal.fullName, contentType: .name, capitalization: .words)
            EdField(label: String(localized: "Professional title"), text: $draft.personal.professionalTitle, contentType: .jobTitle, capitalization: .words)
            EdField(label: String(localized: "Email"), text: $draft.personal.email, keyboard: .emailAddress, contentType: .emailAddress, capitalization: .never)
            EdField(label: String(localized: "Phone"), text: $draft.personal.phone, keyboard: .phonePad, contentType: .telephoneNumber, capitalization: .never)
            EdField(label: String(localized: "City"), text: $draft.personal.city, contentType: .addressCity, capitalization: .words)
            EdField(label: String(localized: "Country or region"), text: $draft.personal.country, contentType: .countryName, capitalization: .words)
            if !draft.personal.linkedIn.isEmpty {
                EdField(label: String(localized: "LinkedIn"), text: $draft.personal.linkedIn, keyboard: .URL, contentType: .URL, capitalization: .never)
            }
            if !draft.personal.portfolio.isEmpty {
                EdField(label: String(localized: "Portfolio"), text: $draft.personal.portfolio, keyboard: .URL, contentType: .URL, capitalization: .never)
            }
            if !draft.personal.website.isEmpty {
                EdField(label: String(localized: "Website"), text: $draft.personal.website, keyboard: .URL, contentType: .URL, capitalization: .never)
            }
        }
        .padding(CK.Space.m)
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
    }
}

/// One detected section: its title (editable), where it came from, a short preview, and Remove / Add back.
struct ImportSectionCard: View {
    @Binding var item: ImportedSection

    private var origin: String {
        if item.isFallback {
            return String(localized: "Text that could not be placed. It is kept here so nothing is lost; move or delete it in the editor.")
        }
        if item.detectedHeading.isEmpty {
            return String(localized: "Found above the first heading.")
        }
        let heading: String = item.detectedHeading
        return String(localized: "Found under \"\(heading)\".")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.s + 4) {
            HStack(alignment: .top, spacing: CK.Space.s + 4) {
                Image(systemName: item.isFallback ? "tray" : item.section.kind.systemImage)
                    .font(.system(size: 17))
                    .foregroundStyle(item.isIncluded ? CK.Palette.forest : CK.Palette.graphite)
                    .frame(width: 24)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.isFallback ? String(localized: "Imported text") : item.section.kind.defaultTitle)
                        .font(CK.Font.overline)
                        .foregroundStyle(CK.Palette.graphite)
                    Text(origin)
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: CK.Space.s)
                EdTextButton(title: item.isIncluded ? String(localized: "Remove") : String(localized: "Add back"),
                             systemImage: item.isIncluded ? "minus.circle" : "plus.circle",
                             role: item.isIncluded ? .destructive : nil) {
                    item.isIncluded.toggle()
                }
                .accessibilityLabel(item.isIncluded
                                    ? String(localized: "Remove \(item.section.title)")
                                    : String(localized: "Add back \(item.section.title)"))
            }

            if item.isIncluded {
                EdField(label: String(localized: "Section title"), text: $item.section.title, capitalization: .words)
                let lines: [String] = item.previewLines
                if !lines.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(lines.prefix(6).enumerated()), id: \.offset) { pair in
                            Text(pair.element)
                                .font(CK.Font.callout)
                                .foregroundStyle(CK.Palette.ink)
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(CK.Space.s + 4)
                    .background(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).fill(CK.Palette.ivory))
                    .accessibilityElement(children: .combine)
                }
            } else {
                Text("\(item.section.title) will not be added.")
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
            }
        }
        .padding(CK.Space.m)
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous)
            .strokeBorder(item.isFallback ? CK.Palette.champagne.opacity(0.7) : CK.Palette.hairline,
                          lineWidth: item.isFallback ? 1 : 0.5))
        .opacity(item.isIncluded ? 1 : 0.7)
    }
}
