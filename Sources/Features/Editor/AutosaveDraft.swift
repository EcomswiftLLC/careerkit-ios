import SwiftUI

/// Holds a local working copy of a document. Every real change is passed to `persist` (the store debounces the disk write)
/// and schedules a background preview render.
///
/// Stale copy rules (an editor can stay open in one tab while the same document changes elsewhere):
/// - `persist` returns false when the store no longer has the document. The draft then drops its copy and reports
///   `isGone`, so a deleted document is never re-created from a stale draft.
/// - `reconcile(with:adopt:)` is called whenever the store publishes. A missing document marks the draft gone;
///   otherwise the caller's `adopt` closure copies store-side fields (title, template, archive flag) into the draft
///   without writing them back.
@MainActor
final class AutosaveDraft<Doc: Equatable>: ObservableObject {
    @Published var doc: Doc? {
        didSet { docDidChange(from: oldValue) }
    }
    @Published private(set) var isLoaded = false
    /// True once the document was deleted elsewhere (or all data was reset) while this editor was open.
    @Published private(set) var isGone = false
    let renderer = LivePreviewRenderer()

    private var persist: (@MainActor (Doc) -> Bool)?
    private var makeWork: ((Doc) -> RenderWork)?
    private var suppress = false

    /// Safe to call more than once: only the first call loads.
    /// `persist` must return false when the store does not hold the document any more; nothing is written then.
    func start(initial: Doc?, persist: (@MainActor (Doc) -> Bool)?, makeWork: @escaping (Doc) -> RenderWork) {
        guard !isLoaded else { return }
        self.persist = persist
        self.makeWork = makeWork
        suppress = true
        doc = initial
        suppress = false
        isLoaded = true
        if let initial {
            renderer.schedule(delay: 0, work: makeWork(initial))
        }
    }

    private func docDidChange(from old: Doc?) {
        guard !suppress, !isGone, let new = doc, let old = old, old != new else { return }
        if let persist, !persist(new) {
            markGone()
            return
        }
        if let makeWork {
            renderer.schedule(work: makeWork(new))
        }
    }

    /// Brings store-side changes into the working copy.
    /// - Parameters:
    ///   - stored: the store's current copy of this document, nil when it was deleted.
    ///   - adopt: copies the fields another screen may change (title, template, archive flag) from the store copy.
    ///     It must leave every other field alone so in-progress edits are kept.
    func reconcile(with stored: Doc?, adopt: (inout Doc, Doc) -> Void) {
        guard isLoaded, !isGone, let current = doc else { return }
        guard let stored else {
            markGone()
            return
        }
        var merged = current
        adopt(&merged, stored)
        guard merged != current else { return }
        // The change came from the store, so it is not written back. The preview still follows it.
        suppress = true
        doc = merged
        suppress = false
        if let makeWork {
            renderer.schedule(work: makeWork(merged))
        }
    }

    private func markGone() {
        isGone = true
        renderer.cancel()
        suppress = true
        doc = nil
        suppress = false
    }

    /// Mutates the working copy in one step.
    func update(_ change: (inout Doc) -> Void) {
        guard var copy = doc else { return }
        change(&copy)
        doc = copy
    }

    func binding<T>(_ keyPath: WritableKeyPath<Doc, T>, fallback: T) -> Binding<T> {
        Binding<T>(
            get: { [weak self] in self?.doc?[keyPath: keyPath] ?? fallback },
            set: { [weak self] newValue in self?.doc?[keyPath: keyPath] = newValue }
        )
    }
}

/// The fields another screen can change on a document while its editor is open (rename, change template, archive).
/// Everything else stays as the editor has it.
enum DraftAdoption {
    static func adopt(_ draft: inout Resume, from stored: Resume) {
        if draft.title != stored.title { draft.title = stored.title }
        if draft.templateID != stored.templateID { draft.templateID = stored.templateID }
        if draft.isArchived != stored.isArchived { draft.isArchived = stored.isArchived }
    }

    static func adopt(_ draft: inout CoverLetter, from stored: CoverLetter) {
        if draft.title != stored.title { draft.title = stored.title }
        if draft.templateID != stored.templateID { draft.templateID = stored.templateID }
    }
}
