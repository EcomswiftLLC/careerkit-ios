import SwiftUI

/// Start a new resume from a template, or from the Blank Resume path when `templateID` is nil.
/// Contains its own NavigationStack, so present it as a sheet or full-screen cover.
/// On success the resume is already stored, `onCreated` is called with its id, and the flow dismisses itself.
struct NewResumeFlow: View {
    let templateID: String?
    let onCreated: (UUID) -> Void

    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var pageSize: PageSize = .a4
    @State private var didApplyDefaults = false
    @State private var showBuilder = false

    init(templateID: String?, onCreated: @escaping (UUID) -> Void) {
        self.templateID = templateID
        self.onCreated = onCreated
    }

    private var template: TemplateSpec? {
        guard let templateID else { return nil }
        return EditorRender.template(id: templateID)
    }

    private var defaultTitle: String {
        if let template { return String(localized: "\(template.name) resume") }
        return String(localized: "My Resume")
    }

    private var cleanTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultTitle : trimmed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.l) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(template == nil ? String(localized: "Start from a blank page") : String(localized: "Name your resume"))
                            .ckTitleFont(28)
                            .foregroundStyle(CK.Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text(template == nil
                             ? String(localized: "You choose the sections, fonts and margins. Everything stays editable later.")
                             : String(localized: "You can rename it and change the template at any time."))
                            .font(CK.Font.callout)
                            .foregroundStyle(CK.Palette.graphite)
                    }
                    EdField(label: String(localized: "Resume title"), text: $title, prompt: defaultTitle, capitalization: .words)
                    VStack(alignment: .leading, spacing: CK.Space.s) {
                        Text("Page size").font(CK.Font.label).foregroundStyle(CK.Palette.ink)
                        Picker("Page size", selection: $pageSize) {
                            ForEach(PageSize.allCases) { size in Text(size.displayName).tag(size) }
                        }
                        .pickerStyle(.segmented)
                        Text("A4 is common in most of the world. US Letter is standard in the United States and Canada.")
                            .font(CK.Font.caption)
                            .foregroundStyle(CK.Palette.graphite)
                    }
                    if let template { templateSummary(template) } else { blankSummary }
                    Button(template == nil ? String(localized: "Continue") : String(localized: "Create resume")) { primaryAction() }
                        .buttonStyle(.ckPrimary)
                        .padding(.top, CK.Space.s)
                }
                .padding(CK.Space.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CK.Palette.ivory.ignoresSafeArea())
            .navigationTitle("New resume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.font(CK.Font.label)
                }
            }
            .navigationDestination(isPresented: $showBuilder) {
                BlankBuilderView(title: cleanTitle, pageSize: pageSize) { resume in finish(resume) }
            }
        }
        .onAppear {
            if !didApplyDefaults {
                pageSize = appState.defaultPageSize
                didApplyDefaults = true
            }
        }
    }

    // MARK: Summaries

    private func templateSummary(_ template: TemplateSpec) -> some View {
        HStack(alignment: .top, spacing: CK.Space.m) {
            TemplateThumbnail(template: template, size: 112)
            VStack(alignment: .leading, spacing: CK.Space.s) {
                Text(template.name)
                    .ckHeadlineFont(20)
                    .foregroundStyle(CK.Palette.ink)
                Text(template.tagline)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                EdFlowLayout(spacing: 6) {
                    tag(template.category.displayName)
                    tag(template.designStyle.displayName)
                    tag(pagesLabel(template))
                    if template.isATSFriendly { tag(String(localized: "Plain layout")) }
                }
            }
        }
        .padding(CK.Space.m)
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
    }

    private var blankSummary: some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            Text("What happens next")
                .ckHeadlineFont(18)
                .foregroundStyle(CK.Palette.ink)
            Text("You start with a clean document that has only your personal details and a summary. Next you add the sections you need, choose fonts and margins, and watch the page update as you go.")
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.graphite)
        }
        .padding(CK.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
    }

    private func pagesLabel(_ template: TemplateSpec) -> String {
        let pages: Int = template.typicalPages
        return String(localized: "\(pages) pages")
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .font(CK.Font.caption)
            .foregroundStyle(CK.Palette.graphite)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(CK.Palette.stone))
    }

    // MARK: Actions

    private func primaryAction() {
        if let template {
            let resume = ResumeFactory.newResume(template: template, title: cleanTitle, pageSize: pageSize)
            finish(resume)
        } else {
            showBuilder = true
        }
    }

    private func finish(_ resume: Resume) {
        store.upsert(resume)
        onCreated(resume.id)
        dismiss()
    }
}
