import SwiftUI

/// Two resumes side by side with their live previews. Expects to sit inside a NavigationStack or a sheet with one.
struct VersionCompareView: View {
    @State private var leftID: UUID
    @State private var rightID: UUID

    init(leftID: UUID, rightID: UUID) {
        _leftID = State(initialValue: leftID)
        _rightID = State(initialValue: rightID)
    }

    var body: some View {
        HStack(spacing: 1) {
            ComparePane(resumeID: leftID)
            Rectangle().fill(CK.Palette.hairline).frame(width: 1)
            ComparePane(resumeID: rightID)
        }
        .background(CK.Palette.ivory.ignoresSafeArea())
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let previous = leftID
                    leftID = rightID
                    rightID = previous
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Swap sides")
            }
        }
    }
}

private struct ComparePane: View {
    let resumeID: UUID

    @EnvironmentObject private var store: DocumentStore
    @StateObject private var renderer = LivePreviewRenderer()

    var body: some View {
        let resume = store.resume(id: resumeID)
        VStack(spacing: 0) {
            header(resume)
            if let resume {
                PreviewPane(renderer: renderer,
                            accessibilityName: CKPreviewNames.preview(of: resume.title),
                            showsPageControls: true,
                            showsZoomControls: false)
                    .task(id: resume) {
                        renderer.schedule(delay: 0, work: EditorRender.work(for: resume))
                    }
            } else {
                EdUnavailableView(title: String(localized: "Not available"), message: String(localized: "This resume was deleted."))
            }
        }
        .frame(maxWidth: .infinity)
        .onDisappear { renderer.cancel() }
    }

    private func header(_ resume: Resume?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(resume?.title ?? String(localized: "Unavailable"))
                .ckHeadlineFont(16)
                .foregroundStyle(CK.Palette.ink)
                .lineLimit(1)
            if let resume {
                Text("\(EditorRender.template(id: resume.templateID).name), edited \(resume.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CK.Space.s + 4)
        .padding(.vertical, CK.Space.s)
        .background(CK.Palette.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(CK.Palette.hairline).frame(height: 0.5) }
        .accessibilityElement(children: .combine)
    }
}
