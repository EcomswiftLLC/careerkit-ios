import SwiftUI

/// Holds a local working copy of a document. Every real change is passed to `persist` (the store debounces the disk write)
/// and schedules a background preview render.
@MainActor
final class AutosaveDraft<Doc: Equatable>: ObservableObject {
    @Published var doc: Doc? {
        didSet { docDidChange(from: oldValue) }
    }
    @Published private(set) var isLoaded = false
    let renderer = LivePreviewRenderer()

    private var persist: (@MainActor (Doc) -> Void)?
    private var makeWork: ((Doc) -> RenderWork)?
    private var suppress = false

    /// Safe to call more than once: only the first call loads.
    func start(initial: Doc?, persist: (@MainActor (Doc) -> Void)?, makeWork: @escaping (Doc) -> RenderWork) {
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
        guard !suppress, let new = doc, let old = old, old != new else { return }
        persist?(new)
        if let makeWork {
            renderer.schedule(work: makeWork(new))
        }
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
