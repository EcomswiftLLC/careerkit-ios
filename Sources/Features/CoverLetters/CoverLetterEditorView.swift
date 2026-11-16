import SwiftUI

private enum LetterSheet: Identifiable {
    case templates
    case style
    case export
    case suggestions(CoverLetterField)

    var id: String {
        switch self {
        case .templates: return "templates"
        case .style: return "style"
        case .export: return "export"
        case .suggestions(let field): return "suggestions.\(field.rawValue)"
        }
    }
}

/// Cover letter editor with live preview. No ads here. Expects to sit inside a NavigationStack.
struct CoverLetterEditorView: View {
    let letterID: UUID

    @EnvironmentObject private var store: DocumentStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var draft = AutosaveDraft<CoverLetter>()
    @State private var mode: EditorMode = .edit
    @State private var sheet: LetterSheet?

    init(letterID: UUID) {
        self.letterID = letterID
    }

    private var isSplit: Bool { sizeClass == .regular }

    var body: some View {
        Group {
            if let letter = Binding($draft.doc) {
                editor(letter)
            } else if draft.isLoaded {
                EdUnavailableView(title: "This letter is no longer available",
                                  message: "It may have been deleted. Go back to your cover letters to choose another.")
            } else {
                CK.Palette.ivory.ignoresSafeArea()
            }
        }
        .onAppear {
            draft.start(initial: store.coverLetter(id: letterID),
                        persist: { [store] updated in store.upsert(updated) },
                        makeWork: { EditorRender.work(for: $0) })
        }
        .onDisappear {
            draft.renderer.cancel()
            store.flushNow()
        }
    }

    // MARK: Layout

    private func editor(_ letter: Binding<CoverLetter>) -> some View {
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
                    form(letter).frame(maxWidth: 560)
                    Rectangle().fill(CK.Palette.hairline).frame(width: 0.5)
                    preview(letter)
                }
            } else if mode == .edit {
                form(letter)
            } else {
                preview(letter)
            }
        }
        .background(CK.Palette.ivory.ignoresSafeArea())
        .navigationTitle(letter.wrappedValue.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbarContent(letter) }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomToolbar }
        .sheet(item: $sheet) { item in
            sheetContent(item, letter)
        }
    }

    private func form(_ letter: Binding<CoverLetter>) -> some View {
        ScrollView {
            CoverLetterForm(
                letter: letter,
                resumes: store.resumes.filter { !$0.isArchived },
                onSuggest: { field in sheet = .suggestions(field) }
            )
            .padding(CK.Space.m)
            .padding(.bottom, CK.Space.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func preview(_ letter: Binding<CoverLetter>) -> some View {
        PreviewPane(renderer: draft.renderer, accessibilityName: "Live preview of \(letter.wrappedValue.title)")
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private func toolbarContent(_ letter: Binding<CoverLetter>) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(letter.wrappedValue.title.isEmpty ? "Untitled letter" : letter.wrappedValue.title)
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
        }
        .padding(.horizontal, CK.Space.xl)
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

    private func open(_ item: LetterSheet) {
        if !isSplit { mode = .preview }
        sheet = item
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetContent(_ item: LetterSheet, _ letter: Binding<CoverLetter>) -> some View {
        switch item {
        case .templates:
            CoverLetterTemplateSheet(currentID: letter.wrappedValue.templateID) { id in
                letter.wrappedValue.templateID = id
            }
        case .style:
            StylePanelSheet(style: letter.style,
                            pageSize: letter.pageSize,
                            defaults: StyleDefaults(letterTemplate: EditorRender.coverTemplate(id: letter.wrappedValue.templateID)),
                            showsPhotoToggle: false)
        case .export:
            let snapshot = letter.wrappedValue
            ExportFlowSheet(documentID: snapshot.id,
                            fileName: FileNaming.safeFileName(snapshot.title, fallback: "Cover letter"),
                            renderedProvider: { EditorRender.render(snapshot) })
        case .suggestions(let field):
            CoverLetterSuggestionSheet(field: field, letter: letter.wrappedValue) { suggestion in
                var updated = letter.wrappedValue
                CoverLetterForm.apply(field, suggestion: suggestion, to: &updated)
                letter.wrappedValue = updated
            }
        }
    }
}
