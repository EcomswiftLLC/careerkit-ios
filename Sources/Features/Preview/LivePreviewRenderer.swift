import SwiftUI

typealias RenderWork = @Sendable () -> RenderedDocument

/// Debounced, cancellable background rendering. The last finished document stays visible while a new one renders.
/// Rendering never runs on the main thread: the work closure is executed inside `Task.detached`.
@MainActor
final class LivePreviewRenderer: ObservableObject {
    @Published private(set) var document: RenderedDocument?
    @Published private(set) var isRendering = false

    private var task: Task<Void, Never>?
    private var generation = 0

    /// Cancels any pending render and starts a new one after `delay` seconds.
    func schedule(delay: TimeInterval = 0.35, work: @escaping RenderWork) {
        task?.cancel()
        generation += 1
        let myGeneration = generation
        isRendering = true
        task = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            if Task.isCancelled { return }
            let job = Task.detached(priority: .userInitiated) { () -> RenderedDocument in
                work()
            }
            let result: RenderedDocument = await withTaskCancellationHandler(
                operation: { await job.value },
                onCancel: { job.cancel() }
            )
            if Task.isCancelled { return }
            self?.finish(result, generation: myGeneration)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isRendering = false
    }

    private func finish(_ result: RenderedDocument, generation finished: Int) {
        guard finished == generation else { return }
        document = result
        isRendering = false
    }
}

// MARK: - Render helpers shared by the editor screens

enum EditorRender {
    static func template(id: String) -> TemplateSpec {
        if let spec = TemplateLibrary.spec(id: id) { return spec }
        if let fallback = TemplateLibrary.spec(id: TemplateLibrary.defaultTemplateID) { return fallback }
        return TemplateLibrary.all[0]
    }

    static func coverTemplate(id: String) -> CoverLetterTemplateSpec {
        if let spec = CoverLetterTemplateLibrary.spec(id: id) { return spec }
        return CoverLetterTemplateLibrary.all[0]
    }

    static func work(for resume: Resume) -> RenderWork {
        let spec = template(id: resume.templateID)
        return { DocumentRenderer.render(resume, template: spec) }
    }

    static func work(for letter: CoverLetter) -> RenderWork {
        let spec = coverTemplate(id: letter.templateID)
        return { CoverLetterRenderer.render(letter, template: spec) }
    }

    /// Synchronous render, used only by the export sheet's provider closure.
    static func render(_ resume: Resume) -> RenderedDocument {
        DocumentRenderer.render(resume, template: template(id: resume.templateID))
    }

    static func render(_ letter: CoverLetter) -> RenderedDocument {
        CoverLetterRenderer.render(letter, template: coverTemplate(id: letter.templateID))
    }
}
