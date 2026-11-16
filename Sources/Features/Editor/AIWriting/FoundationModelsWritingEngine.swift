// The only file in the app that imports FoundationModels. Everything here is inside
// `#if canImport(FoundationModels)` and `@available(iOS 26.0, *)`, so iOS 17 to 25 builds never see it.
// The model runs on the device. No text leaves the phone.

#if canImport(FoundationModels)
import Foundation
import FoundationModels

@available(iOS 26.0, *)
struct FoundationModelsWritingEngine: WritingAssistEngine {
    var availability: WritingAssistAvailability {
        let model = SystemLanguageModel.default
        if model.isAvailable { return .available }
        if case .unavailable(let reason) = model.availability {
            switch reason {
            case .deviceNotEligible:
                return .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                return .unavailable(.appleIntelligenceOff)
            case .modelNotReady:
                return .unavailable(.modelNotReady)
            @unknown default:
                return .unavailable(.other)
            }
        }
        return .unavailable(.other)
    }

    func rewrite(_ text: String, mode: WritingAssistMode, context: String) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else { throw WritingAssistFailure.unavailable }

        // A fresh session per request, so one suggestion never leaks into the next.
        let session = LanguageModelSession(instructions: WritingAssistPrompt.instructions)
        let prompt = WritingAssistPrompt.prompt(for: mode,
                                                text: WritingAssistPrompt.truncated(text),
                                                context: WritingAssistPrompt.truncated(context))
        // Low temperature: editing, not creative writing.
        let options = GenerationOptions(temperature: 0.3)
        do {
            let response = try await session.respond(to: prompt, options: options)
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .guardrailViolation:
                throw WritingAssistFailure.declined
            case .unsupportedLanguageOrLocale:
                throw WritingAssistFailure.unsupportedLanguage
            case .exceededContextWindowSize:
                throw WritingAssistFailure.inputTooLong
            case .assetsUnavailable:
                throw WritingAssistFailure.unavailable
            default:
                throw WritingAssistFailure.generic
            }
        }
        // CancellationError and anything else pass through; the view model handles them.
    }
}
#endif
