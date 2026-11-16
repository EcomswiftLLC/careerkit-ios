import SwiftUI

/// Read-only preview of a saved resume. Expects to sit inside a NavigationStack.
struct ResumePreviewView: View {
    let resumeID: UUID

    @EnvironmentObject private var store: DocumentStore
    @StateObject private var renderer = LivePreviewRenderer()

    var body: some View {
        let resume = store.resume(id: resumeID)
        Group {
            if let resume {
                PreviewPane(renderer: renderer, accessibilityName: "Preview of \(resume.title)")
                    .onChange(of: resume) { _, updated in
                        renderer.schedule(delay: 0.2, work: EditorRender.work(for: updated))
                    }
                    .task(id: resumeID) {
                        if renderer.document == nil {
                            renderer.schedule(delay: 0, work: EditorRender.work(for: resume))
                        }
                    }
            } else {
                EdUnavailableView(title: "This resume is no longer available",
                                  message: "It may have been deleted. Go back to My Resumes to choose another.")
            }
        }
        .background(CK.Palette.ivory.ignoresSafeArea())
        .navigationTitle(resume?.title ?? "Preview")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { renderer.cancel() }
    }
}

/// Shared empty/error message used when a document id no longer exists.
struct EdUnavailableView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: CK.Space.s) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(CK.Palette.graphite)
                .accessibilityHidden(true)
            Text(title)
                .font(CK.Font.headline())
                .foregroundStyle(CK.Palette.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.graphite)
                .multilineTextAlignment(.center)
        }
        .padding(CK.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CK.Palette.ivory.ignoresSafeArea())
    }
}
