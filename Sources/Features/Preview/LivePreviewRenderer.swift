import SwiftUI

typealias RenderWork = @Sendable () -> RenderedDocument

/// Pure bookkeeping for live preview renders: at most one render in flight and one pending (the latest request wins).
/// A synchronous render cannot be interrupted, so instead of starting a new render on every keystroke the newest
/// request waits for the running one and replaces any older waiting request.
struct PreviewRenderQueue: Equatable {
    /// Generation currently rendering on a background thread.
    private(set) var inFlight: Int?
    /// Newest generation waiting for the running render to finish.
    private(set) var pending: Int?
    /// Newest generation whose result was shown.
    private(set) var lastPublished: Int = 0
    /// Results of this generation and older are dropped (set by `cancelAll`).
    private(set) var discardThrough: Int = 0

    enum Submission: Equatable {
        case startNow(Int)
        /// Waiting behind the running render. Carries the older pending generation it replaced, if any.
        case queued(replaced: Int?)
    }

    struct Completion: Equatable {
        /// Show this result.
        let publish: Bool
        /// Start this pending generation now.
        let next: Int?
    }

    var isBusy: Bool { inFlight != nil || pending != nil }

    mutating func submit(_ generation: Int) -> Submission {
        guard inFlight != nil else {
            inFlight = generation
            return .startNow(generation)
        }
        let replaced: Int? = pending
        pending = generation
        return .queued(replaced: replaced)
    }

    mutating func complete(_ generation: Int) -> Completion {
        guard inFlight == generation else { return Completion(publish: false, next: nil) }
        inFlight = nil
        let publish: Bool = generation > lastPublished && generation > discardThrough
        if publish { lastPublished = generation }
        var next: Int? = nil
        if let waiting = pending {
            pending = nil
            inFlight = waiting
            next = waiting
        }
        return Completion(publish: publish, next: next)
    }

    /// Drops the waiting request and the result of the running one. The running render itself finishes in the
    /// background (it cannot be stopped); a later request queues behind it, so there is never more than one.
    mutating func cancelAll(through generation: Int) {
        pending = nil
        discardThrough = max(discardThrough, generation)
    }
}

/// Debounced background rendering. The last finished document stays visible while a new one renders.
/// Rendering never runs on the main thread: the work closure is executed inside `Task.detached`.
/// Requests within the debounce window (0.35 s by default) collapse to the last one; while a render runs, newer
/// requests collapse to a single pending render that starts when the running one ends.
@MainActor
final class LivePreviewRenderer: ObservableObject {
    @Published private(set) var document: RenderedDocument?
    @Published private(set) var isRendering = false

    private var queue = PreviewRenderQueue()
    private var debounceTask: Task<Void, Never>?
    private var waitingGeneration: Int?
    private var pendingWork: RenderWork?
    private var generation = 0

    /// Replaces any not-yet-started request and renders `work` after `delay` seconds.
    func schedule(delay: TimeInterval = 0.35, work: @escaping RenderWork) {
        debounceTask?.cancel()
        debounceTask = nil
        generation += 1
        let myGeneration: Int = generation
        if delay <= 0 {
            waitingGeneration = nil
            submit(myGeneration, work: work)
            return
        }
        waitingGeneration = myGeneration
        refreshBusy()
        let nanoseconds: UInt64 = UInt64(delay * 1_000_000_000)
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            if Task.isCancelled { return }
            self?.debounceFired(myGeneration, work: work)
        }
    }

    /// Stops waiting requests and ignores the running render's result. Call when the screen goes away.
    func cancel() {
        debounceTask?.cancel()
        debounceTask = nil
        waitingGeneration = nil
        pendingWork = nil
        queue.cancelAll(through: generation)
        refreshBusy()
    }

    private func debounceFired(_ myGeneration: Int, work: @escaping RenderWork) {
        guard waitingGeneration == myGeneration else { return }
        waitingGeneration = nil
        debounceTask = nil
        submit(myGeneration, work: work)
    }

    private func submit(_ myGeneration: Int, work: @escaping RenderWork) {
        switch queue.submit(myGeneration) {
        case .startNow(let started):
            start(started, work: work)
        case .queued:
            pendingWork = work
        }
        refreshBusy()
    }

    private func start(_ myGeneration: Int, work: @escaping RenderWork) {
        Task { [weak self] in
            let result: RenderedDocument = await Task.detached(priority: .userInitiated) { () -> RenderedDocument in
                work()
            }.value
            self?.complete(myGeneration, result: result)
        }
    }

    private func complete(_ myGeneration: Int, result: RenderedDocument) {
        let outcome: PreviewRenderQueue.Completion = queue.complete(myGeneration)
        if outcome.publish {
            document = result
        }
        if let next = outcome.next {
            if let work = pendingWork {
                pendingWork = nil
                start(next, work: work)
            } else {
                // Cannot happen (pending work is stored with every queued request); keep the queue consistent.
                _ = queue.complete(next)
            }
        }
        refreshBusy()
    }

    private func refreshBusy() {
        let busy: Bool = queue.isBusy || waitingGeneration != nil
        if isRendering != busy { isRendering = busy }
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
