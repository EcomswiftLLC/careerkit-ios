import SwiftUI

private enum EditorSheet: String, Identifiable {
    case templates, style, sections, ats, export
    var id: String { rawValue }
}

/// Full resume editor with live preview. Expects to sit inside a NavigationStack.
/// Edits a local copy and calls `store.upsert` on every real change; the store debounces the disk write.
struct ResumeEditorView: View {
    let resumeID: UUID

    @EnvironmentObject private var store: DocumentStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var draft = AutosaveDraft<Resume>()
    @State private var mode: EditorMode = .edit
    @State private var sheet: EditorSheet?
    @State private var expanded: Set<String> = ["personal"]

    init(resumeID: UUID) {
        self.resumeID = resumeID
    }

    var body: some View {
        Group {
            if let resume = Binding($draft.doc) {
                editor(resume)
            } else if draft.isLoaded {
                EdUnavailableView(title: "This resume is no longer available",
                                  message: "It may have been deleted. Go back to My Resumes to choose another.")
            } else {
                CK.Palette.ivory.ignoresSafeArea()
            }
        }
        .onAppear {
            draft.start(initial: store.resume(id: resumeID),
                        persist: { [store] updated in store.upsert(updated) },
                        makeWork: { EditorRender.work(for: $0) })
        }
        .onDisappear {
            draft.renderer.cancel()
            store.flushNow()
        }
    }

    private var isSplit: Bool { sizeClass == .regular }

    // MARK: Layout

    private func editor(_ resume: Binding<Resume>) -> some View {
        VStack(spacing: 0) {
            if !isSplit {
                EdModeSwitch(mode: $mode)
                    .padding(.vertical, CK.Space.s)
                    .frame(maxWidth: .infinity)
                    .background(CK.Palette.ivory)
                    .overlay(alignment: .bottom) { Rectangle().fill(CK.Palette.hairline).frame(height: 0.5) }
            }
            if isSplit {
                HStack(spacing: 0) {
                    editScroll(resume).frame(maxWidth: 560)
                    Rectangle().fill(CK.Palette.hairline).frame(width: 0.5)
                    preview(resume)
                }
            } else if mode == .edit {
                editScroll(resume)
            } else {
                preview(resume)
            }
        }
        .background(CK.Palette.ivory.ignoresSafeArea())
        .navigationTitle(resume.wrappedValue.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbarContent(resume) }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomToolbar }
        .sheet(item: $sheet) { item in
            sheetContent(item, resume)
        }
    }

    private func preview(_ resume: Binding<Resume>) -> some View {
        PreviewPane(renderer: draft.renderer, accessibilityName: "Live preview of \(resume.wrappedValue.title)")
    }

    private func editScroll(_ resume: Binding<Resume>) -> some View {
        ScrollView {
            VStack(spacing: CK.Space.m) {
                titleField(resume)
                EdDisclosureCard(title: "Personal information",
                                 subtitle: personalSummary(resume.wrappedValue.personal),
                                 systemImage: "person",
                                 isExpanded: expandedBinding("personal")) {
                    PersonalInfoEditor(personal: resume.personal, showsPhotoNote: true)
                }
                ForEach(resume.sections) { $section in
                    EdDisclosureCard(title: section.title,
                                     subtitle: section.isVisible ? SectionOps.summaryLine(for: section) : "Hidden from the document",
                                     systemImage: section.kind.systemImage,
                                     dimmed: !section.isVisible,
                                     isExpanded: expandedBinding(section.id.uuidString)) {
                        SectionEditorView(section: $section)
                    }
                }
                Button {
                    sheet = .sections
                } label: {
                    Label("Add or rearrange sections", systemImage: "plus.square.on.square")
                }
                .buttonStyle(.ckSecondary)
                .padding(.top, CK.Space.s)
            }
            .padding(CK.Space.m)
            .padding(.bottom, CK.Space.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func titleField(_ resume: Binding<Resume>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Resume title", text: resume.title)
                .font(CK.Font.title(26))
                .foregroundStyle(CK.Palette.ink)
                .frame(minHeight: 44)
            Text("Shown in My Resumes and used as the file name when you export.")
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func personalSummary(_ personal: PersonalInfo) -> String {
        let name = personal.fullName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return "Add your name and contact details" }
        return personal.professionalTitle.isEmpty ? name : "\(name), \(personal.professionalTitle)"
    }

    private func expandedBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(key) },
            set: { open in
                if open { expanded.insert(key) } else { expanded.remove(key) }
            }
        )
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private func toolbarContent(_ resume: Binding<Resume>) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(resume.wrappedValue.title.isEmpty ? "Untitled resume" : resume.wrappedValue.title)
                    .font(CK.Font.headline(16))
                    .foregroundStyle(CK.Palette.ink)
                    .lineLimit(1)
                EdSaveIndicator(state: store.saveState)
            }
            .accessibilityElement(children: .combine)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Export") { sheet = .export }
                .font(CK.Font.label)
                .foregroundStyle(CK.Palette.forest)
                .accessibilityHint("Opens the export options")
        }
    }

    /// A solid bar that runs to the screen edge, so nothing scrolls into view behind the labels.
    private var bottomToolbar: some View {
        HStack {
            toolButton("Template", symbol: "rectangle.on.rectangle") { open(.templates) }
            Spacer()
            toolButton("Style", symbol: "paintpalette") { open(.style) }
            Spacer()
            toolButton("Sections", symbol: "list.bullet.rectangle") { open(.sections) }
            Spacer()
            toolButton("ATS check", symbol: "checkmark.shield") { open(.ats) }
        }
        .padding(.horizontal, CK.Space.m)
        .padding(.top, CK.Space.xs)
        .background(CK.Palette.ivory.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(CK.Palette.hairline).frame(height: 0.5) }
    }

    private func toolButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 18, weight: .regular))
                Text(title).font(CK.Font.caption)
            }
            .foregroundStyle(CK.Palette.ink)
            .frame(minWidth: 64, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(title)
    }

    /// Template and style changes are easier to judge with the preview in view, so the panel opens over it.
    private func open(_ item: EditorSheet) {
        if (item == .style || item == .templates), !isSplit { mode = .preview }
        sheet = item
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetContent(_ item: EditorSheet, _ resume: Binding<Resume>) -> some View {
        switch item {
        case .templates:
            TemplateSwitcherSheet(currentID: resume.wrappedValue.templateID) { id in
                resume.wrappedValue.templateID = id
            }
        case .style:
            StylePanelSheet(style: resume.style,
                            pageSize: resume.pageSize,
                            defaults: StyleDefaults(template: EditorRender.template(id: resume.wrappedValue.templateID)))
        case .sections:
            SectionManagerSheet(sections: resume.sections)
        case .ats:
            NavigationStack {
                ATSCheckView(resumeID: resumeID)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { sheet = nil }.font(CK.Font.label)
                        }
                    }
            }
        case .export:
            let snapshot = resume.wrappedValue
            ExportFlowSheet(documentID: snapshot.id,
                            fileName: FileNaming.safeFileName(snapshot.title, fallback: "Resume"),
                            renderedProvider: { EditorRender.render(snapshot) })
        }
    }
}
