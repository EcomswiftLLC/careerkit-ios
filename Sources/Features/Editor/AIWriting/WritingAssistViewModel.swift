import Foundation

/// Drives one writing help request: checks the input, asks the engine, sanitizes the answer.
/// It never changes the person's text. Only the sheet's "Use suggestion" button hands a result back.
@MainActor
final class WritingAssistViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case working
        case suggestion(String)
        case noChange
        case failed(WritingAssistFailure)
    }

    @Published private(set) var phase: Phase = .idle

    let request: WritingAssistRequest
    private let engine: any WritingAssistEngine
    private var task: Task<Void, Never>?

    init(request: WritingAssistRequest, engine: any WritingAssistEngine) {
        self.request = request
        self.engine = engine
    }

    var suggestion: String? {
        if case .suggestion(let text) = phase { return text }
        return nil
    }

    var isWorking: Bool { phase == .working }

    /// Problems found before anything is sent to the model.
    static func precheck(_ request: WritingAssistRequest) -> WritingAssistFailure? {
        if request.mode.usesContextAsSource {
            if WritingAssistText.isBlank(request.context) { return .noExperience }
        } else if WritingAssistText.isBlank(request.original) {
            return .nothingToRewrite
        }
        // A cut-off text would lose its end when the suggestion replaces it, so long text is refused, not truncated.
        if request.original.count > WritingAssistPrompt.inputLimit { return .inputTooLong }
        return nil
    }

    func start() {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            await self.run()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if phase == .working { phase = .idle }
    }

    /// One full attempt. `start()` runs this in a task; tests await it directly.
    func run() async {
        if let problem = Self.precheck(request) {
            phase = .failed(problem)
            return
        }
        guard engine.availability.isAvailable else {
            phase = .failed(.unavailable)
            return
        }
        phase = .working
        do {
            let raw = try await engine.rewrite(WritingAssistPrompt.truncated(request.original),
                                               mode: request.mode,
                                               context: WritingAssistPrompt.truncated(request.context))
            if Task.isCancelled { return }
            switch WritingAssistSanitizer.clean(raw, original: request.original, context: request.context, mode: request.mode) {
            case .success(let text):
                if !request.mode.usesContextAsSource && WritingAssistText.isSameText(text, request.original) {
                    phase = .noChange
                } else {
                    phase = .suggestion(text)
                }
            case .failure(let failure):
                phase = .failed(failure)
            }
        } catch is CancellationError {
            if phase == .working { phase = .idle }
        } catch let failure as WritingAssistFailure {
            if Task.isCancelled { return }
            phase = .failed(failure)
        } catch {
            if Task.isCancelled { return }
            phase = .failed(.generic)
        }
    }
}
