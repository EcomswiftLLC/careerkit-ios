import SwiftUI

/// Second step of the Blank Resume path: shape the empty document while watching a live preview.
/// Layout safeguards (minimum margin, maximum text size) come from `StyleLimits.blank`.
struct BlankBuilderView: View {
    let title: String
    let pageSize: PageSize
    let onCreate: (Resume) -> Void

    private enum BuilderTab: String, CaseIterable, Identifiable {
        case sections = "Sections"
        case layout = "Fonts and layout"
        var id: String { rawValue }

        var title: String {
            switch self {
            case .sections: return String(localized: "Sections")
            case .layout: return String(localized: "Fonts and layout")
            }
        }
    }

    @StateObject private var draft = AutosaveDraft<Resume>()
    @State private var tab: BuilderTab = .sections

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                PreviewPane(renderer: draft.renderer,
                            accessibilityName: String(localized: "Blank resume preview"),
                            showsPageControls: true,
                            showsZoomControls: false)
                    .frame(height: max(proxy.size.height * 0.38, 220))
                Text("Empty parts show sample text here. You write your own after the resume is created.")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, CK.Space.m)
                    .padding(.vertical, CK.Space.s)
                    .background(CK.Palette.ivory)
                Picker("Builder tab", selection: $tab) {
                    ForEach(BuilderTab.allCases) { item in Text(item.title).tag(item) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, CK.Space.m)
                .padding(.bottom, CK.Space.s)
                controls
                createBar
            }
        }
        .background(CK.Palette.ivory.ignoresSafeArea())
        .navigationTitle("Build your layout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let start = ResumeFactory.blankResume(title: title, pageSize: pageSize)
            draft.start(initial: start,
                        persist: nil,
                        makeWork: { EditorRender.work(for: BlankPreviewMapper.previewResume(from: $0)) })
        }
        .onDisappear { draft.renderer.cancel() }
    }

    @ViewBuilder
    private var controls: some View {
        switch tab {
        case .sections:
            EdSectionManagerList(sections: draft.binding(\.sections, fallback: []))
        case .layout:
            ScrollView {
                EdStyleControls(style: draft.binding(\.style, fallback: StyleOverrides()),
                                pageSize: draft.binding(\.pageSize, fallback: pageSize),
                                defaults: StyleDefaults(template: EditorRender.template(id: draft.doc?.templateID ?? "")),
                                limits: .blank,
                                showsPhotoToggle: false)
                    .padding(CK.Space.m)
            }
        }
    }

    private var createBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(CK.Palette.hairline).frame(height: 0.5)
            Button("Create resume") { create() }
                .buttonStyle(.ckPrimary)
                .padding(CK.Space.m)
                .disabled(draft.doc == nil)
        }
        .background(CK.Palette.ivory)
    }

    private func create() {
        guard var resume = draft.doc else { return }
        resume.style = StyleLimits.blank.clamped(resume.style)
        resume.sections = SectionOps.normalized(resume.sections)
        resume.isBlank = true
        onCreate(resume)
    }
}
