import XCTest
@testable import CareerKit

/// Stand-in for the on-device model. No FoundationModels here.
private final class FakeWritingEngine: WritingAssistEngine {
    var availability: WritingAssistAvailability
    var result: Result<String, Error>
    private(set) var calls: [(text: String, mode: WritingAssistMode, context: String)] = []

    init(availability: WritingAssistAvailability = .available, result: Result<String, Error>) {
        self.availability = availability
        self.result = result
    }

    func rewrite(_ text: String, mode: WritingAssistMode, context: String) async throws -> String {
        calls.append((text, mode, context))
        return try result.get()
    }
}

private struct SomeEngineError: Error {}

final class WritingAssistSanitizerTests: XCTestCase {
    private func clean(_ raw: String, original: String, context: String = "",
                       mode: WritingAssistMode = .improveWording) -> Result<String, WritingAssistFailure> {
        WritingAssistSanitizer.clean(raw, original: original, context: context, mode: mode)
    }

    func testPlainOutputPassesThrough() {
        XCTAssertEqual(clean("Led a small design team.", original: "I led a small team of designers."),
                       .success("Led a small design team."))
    }

    func testStripsWrappingQuotes() {
        XCTAssertEqual(clean("\"Led a small design team.\"", original: "led small team"), .success("Led a small design team."))
        XCTAssertEqual(clean("\u{201C}Led a small design team.\u{201D}", original: "led small team"), .success("Led a small design team."))
    }

    func testKeepsQuotesThePersonWrote() {
        let original = "\"Customer first\" was my motto"
        XCTAssertEqual(clean("\"Customer first\" was my motto.", original: original), .success("\"Customer first\" was my motto."))
    }

    func testStripsMarkdownFencesAndBold() {
        let raw = "```\n**Led** a small design team.\n```"
        XCTAssertEqual(clean(raw, original: "led small team"), .success("Led a small design team."))
    }

    func testStripsLeadingLabelLine() {
        let raw = "Here is the improved text:\n\nLed a small design team."
        XCTAssertEqual(clean(raw, original: "led small team"), .success("Led a small design team."))
    }

    func testStripsInlineLabel() {
        let raw = "Here's a shorter version: Led a small design team."
        XCTAssertEqual(clean(raw, original: "led small team"), .success("Led a small design team."))
    }

    func testStripsSureOpenerAndTrailingNote() {
        let raw = "Sure!\nLed a small design team.\nLet me know if you want more changes."
        XCTAssertEqual(clean(raw, original: "led small team"), .success("Led a small design team."))
    }

    func testDoesNotTreatSuretyAsChatter() {
        XCTAssertFalse(WritingAssistSanitizer.isLeadingChatter("Surety bonds managed for clients"))
        XCTAssertTrue(WritingAssistSanitizer.isLeadingChatter("Sure, here you go"))
        XCTAssertTrue(WritingAssistSanitizer.isLeadingChatter("Revised version:"))
    }

    func testNormalisesBulletsToSeparateLines() {
        let original = "managed social accounts\nwrote weekly newsletter"
        let raw = "- Managed the company social accounts\n\n\u{2022} Wrote the weekly newsletter\n* Kept the tone friendly"
        XCTAssertEqual(clean(raw, original: original),
                       .success("Managed the company social accounts\nWrote the weekly newsletter\nKept the tone friendly"))
    }

    func testStripsNumberedListMarkersWhenOriginalIsNotNumbered() {
        let original = "managed social accounts\nwrote weekly newsletter"
        let raw = "1. Managed social accounts\n2) Wrote the weekly newsletter"
        XCTAssertEqual(clean(raw, original: original), .success("Managed social accounts\nWrote the weekly newsletter"))
    }

    func testEmptyOutputIsRejected() {
        XCTAssertEqual(clean("   \n```\n```\n", original: "led small team"), .failure(.emptySuggestion))
        XCTAssertEqual(clean("\"\"", original: "led small team"), .failure(.emptySuggestion))
    }

    func testOutputLongerThanThreeTimesIsRejected() {
        let original = String(repeating: "word ", count: 30) // 150 characters
        let raw = String(repeating: "longer words ", count: 40) // 520 characters
        XCTAssertEqual(clean(raw, original: original), .failure(.suggestionTooLong))
    }

    func testShortInputStillGetsMinimumRoom() {
        let raw = "Coordinated weekly team meetings and shared notes."
        XCTAssertLessThanOrEqual(raw.count, WritingAssistSanitizer.minimumAllowance)
        XCTAssertEqual(clean(raw, original: "ran meetings"), .success(raw))
    }

    // MARK: Number guard

    func testNewNumberIsRejected() {
        XCTAssertEqual(clean("Increased sales by 30 percent.", original: "Increased sales a lot"),
                       .failure(.addedDetails))
    }

    func testNewYearIsRejected() {
        XCTAssertEqual(clean("Led the team since 2019.", original: "Led the team"), .failure(.addedDetails))
    }

    func testNumbersFromTheOriginalAreAllowed() {
        XCTAssertEqual(clean("Grew sales by 30% in 2023.", original: "sales went up 30% in 2023"),
                       .success("Grew sales by 30% in 2023."))
    }

    func testRemovingNumbersIsAllowed() {
        XCTAssertEqual(clean("Grew sales.", original: "sales went up 30%"), .success("Grew sales."))
    }

    func testChangedNumberIsRejected() {
        XCTAssertEqual(clean("Managed 12 people.", original: "Managed 10 people"), .failure(.addedDetails))
    }

    func testSummaryFromExperienceMayUseNumbersFromExperience() {
        let context = "Role: Nurse at City Hospital\n- Cared for 20 patients a shift"
        XCTAssertEqual(clean("Nurse who cares for 20 patients a shift.", original: "", context: context,
                             mode: .professionalSummaryFromExperience),
                       .success("Nurse who cares for 20 patients a shift."))
        XCTAssertEqual(clean("Nurse with 8 years of experience.", original: "", context: context,
                             mode: .professionalSummaryFromExperience),
                       .failure(.addedDetails))
    }

    func testRewriteModesDoNotAllowNumbersFromContext() {
        XCTAssertEqual(clean("Led 5 projects.", original: "Led projects", context: "Role: Lead at Team 5"),
                       .failure(.addedDetails))
    }

    func testNumberTokens() {
        XCTAssertEqual(WritingAssistSanitizer.numberTokens(in: "Saved $1,200 in 2024, 15%"), ["1", "200", "2024", "15"])
        XCTAssertTrue(WritingAssistSanitizer.numberTokens(in: "No digits here").isEmpty)
        XCTAssertEqual(WritingAssistSanitizer.introducedNumbers(in: "3 and 4", comparedWith: "3"), ["4"])
    }
}

final class WritingAssistSupportTests: XCTestCase {
    func testAvailabilityMapping() {
        XCTAssertTrue(WritingAssistAvailability.available.isAvailable)
        XCTAssertTrue(WritingAssistAvailability.available.showsEntryPoint)
        let reasons: [WritingAssistAvailability.Reason] = [.systemTooOld, .deviceNotEligible, .appleIntelligenceOff, .modelNotReady, .other]
        for reason in reasons {
            XCTAssertFalse(WritingAssistAvailability.unavailable(reason).isAvailable)
            XCTAssertFalse(WritingAssistAvailability.unavailable(reason).showsEntryPoint)
        }
    }

    func testModesPerTarget() {
        XCTAssertEqual(WritingAssistMode.modes(for: .summary),
                       [.improveWording, .makeConcise, .fixGrammar, .professionalSummaryFromExperience])
        XCTAssertEqual(WritingAssistMode.modes(for: .bullets),
                       [.improveWording, .strongerActionVerbs, .makeConcise, .fixGrammar])
        XCTAssertEqual(WritingAssistMode.makeConcise.title, "Make it shorter")
        XCTAssertEqual(WritingAssistMode.strongerActionVerbs.title, "Stronger action verbs")
    }

    func testCanRun() {
        XCTAssertFalse(WritingAssistMode.improveWording.canRun(text: "  \n", context: "experience"))
        XCTAssertTrue(WritingAssistMode.improveWording.canRun(text: "Led a team", context: ""))
        XCTAssertFalse(WritingAssistMode.professionalSummaryFromExperience.canRun(text: "Summary", context: " "))
        XCTAssertTrue(WritingAssistMode.professionalSummaryFromExperience.canRun(text: "", context: "Role: Nurse"))
    }

    func testPromptIncludesTextAndTruncates() {
        let long = String(repeating: "a", count: 5_000)
        XCTAssertEqual(WritingAssistPrompt.truncated(long).count, WritingAssistPrompt.inputLimit)
        XCTAssertEqual(WritingAssistPrompt.truncated("short"), "short")
        let prompt = WritingAssistPrompt.prompt(for: .fixGrammar, text: "i led a team", context: "")
        XCTAssertTrue(prompt.contains("i led a team"))
        XCTAssertFalse(prompt.contains("About the role"))
        XCTAssertLessThan(WritingAssistPrompt.prompt(for: .improveWording, text: long, context: long).count, 4_600)
    }

    func testInstructionsStateTheFactRules() {
        let text = WritingAssistPrompt.instructions.lowercased()
        XCTAssertTrue(text.contains("never invent"))
        XCTAssertTrue(text.contains("same language"))
        XCTAssertTrue(text.contains("no markdown"))
    }

    func testBulletJoinAndSplit() {
        XCTAssertEqual(WritingAssistText.joinBullets(["  Led team ", "", "Wrote docs"]), "Led team\nWrote docs")
        XCTAssertEqual(WritingAssistText.splitBullets("Led team\n\n Wrote docs \n"), ["Led team", "Wrote docs"])
    }

    func testRoleLine() {
        XCTAssertEqual(WritingAssistText.roleLine(heading: "Designer", subheading: "Acme"), "Role: Designer at Acme")
        XCTAssertEqual(WritingAssistText.roleLine(heading: "Designer", subheading: " "), "Role: Designer")
        XCTAssertEqual(WritingAssistText.roleLine(heading: "", subheading: ""), "")
    }

    func testExperienceContextUsesVisibleWorkSectionsWithoutDates() {
        var experience = ResumeSection(kind: .experience)
        var job = ResumeEntry()
        job.heading = "Nurse"
        job.subheading = "City Hospital"
        job.start = MonthYearHelper.make(year: 2019, month: 3)
        job.bullets = ["Cared for patients", " "]
        experience.entries = [job]
        var hidden = ResumeSection(kind: .internships)
        hidden.isVisible = false
        var intern = ResumeEntry()
        intern.heading = "Secret internship"
        hidden.entries = [intern]
        var education = ResumeSection(kind: .education)
        var school = ResumeEntry()
        school.heading = "Nursing degree"
        education.entries = [school]

        let context = WritingAssistText.experienceContext(from: [experience, hidden, education])
        XCTAssertEqual(context, "Role: Nurse at City Hospital\n- Cared for patients")
        XCTAssertFalse(context.contains("2019"))
    }

    func testUndoOnlyWhileTextIsTheSuggestion() {
        let undo = WritingAssistUndo(previous: "mine", applied: "suggested")
        XCTAssertTrue(undo.canUndo(current: "suggested"))
        XCTAssertFalse(undo.canUndo(current: "suggested and edited"))
        let bullets = WritingAssistUndo(previous: ["a"], applied: ["b", "c"])
        XCTAssertTrue(bullets.canUndo(current: ["b", "c"]))
        XCTAssertFalse(bullets.canUndo(current: ["b"]))
    }

    func testFailureMessagesArePlain() {
        XCTAssertEqual(WritingAssistFailure.addedDetails.message,
                       "The suggestion added details that are not in your text, so it was not used.")
        let all: [WritingAssistFailure] = [.nothingToRewrite, .noExperience, .inputTooLong, .unavailable, .unsupportedLanguage,
                                           .declined, .emptySuggestion, .suggestionTooLong, .addedDetails, .generic]
        for failure in all {
            XCTAssertFalse(failure.message.isEmpty)
            XCTAssertFalse(failure.message.contains("AI"), failure.message)
            XCTAssertFalse(failure.message.contains("\u{2014}"), failure.message)
        }
    }
}

final class WritingAssistViewModelTests: XCTestCase {
    private func request(_ mode: WritingAssistMode = .improveWording, target: WritingAssistTarget = .summary,
                         original: String = "i led a small team", context: String = "") -> WritingAssistRequest {
        WritingAssistRequest(mode: mode, target: target, original: original, context: context)
    }

    @MainActor
    func testSuccessfulSuggestion() async {
        let engine = FakeWritingEngine(result: .success("Here is the improved text:\n\"Led a small team.\""))
        let model = WritingAssistViewModel(request: request(), engine: engine)
        XCTAssertEqual(model.phase, .idle)
        await model.run()
        XCTAssertEqual(model.phase, .suggestion("Led a small team."))
        XCTAssertEqual(model.suggestion, "Led a small team.")
        XCTAssertEqual(engine.calls.count, 1)
        XCTAssertEqual(engine.calls.first?.mode, .improveWording)
        XCTAssertEqual(engine.calls.first?.text, "i led a small team")
    }

    @MainActor
    func testUnavailableEngineIsNeverCalled() async {
        let engine = FakeWritingEngine(availability: .unavailable(.appleIntelligenceOff), result: .success("x"))
        let model = WritingAssistViewModel(request: request(), engine: engine)
        await model.run()
        XCTAssertEqual(model.phase, .failed(.unavailable))
        XCTAssertNil(model.suggestion)
        XCTAssertTrue(engine.calls.isEmpty)
    }

    @MainActor
    func testEmptyTextIsNotSent() async {
        let engine = FakeWritingEngine(result: .success("x"))
        let model = WritingAssistViewModel(request: request(original: "  \n "), engine: engine)
        await model.run()
        XCTAssertEqual(model.phase, .failed(.nothingToRewrite))
        XCTAssertTrue(engine.calls.isEmpty)
    }

    @MainActor
    func testSummaryFromExperienceNeedsExperience() async {
        let engine = FakeWritingEngine(result: .success("x"))
        let model = WritingAssistViewModel(request: request(.professionalSummaryFromExperience, original: "", context: ""),
                                           engine: engine)
        await model.run()
        XCTAssertEqual(model.phase, .failed(.noExperience))
        XCTAssertTrue(engine.calls.isEmpty)
    }

    @MainActor
    func testSummaryFromExperienceSendsContext() async {
        let engine = FakeWritingEngine(result: .success("Caring nurse at City Hospital."))
        let model = WritingAssistViewModel(request: request(.professionalSummaryFromExperience, original: "",
                                                            context: "Role: Nurse at City Hospital"),
                                           engine: engine)
        await model.run()
        XCTAssertEqual(model.phase, .suggestion("Caring nurse at City Hospital."))
        XCTAssertEqual(engine.calls.first?.context, "Role: Nurse at City Hospital")
    }

    @MainActor
    func testTooLongTextIsRefusedNotTruncated() async {
        let engine = FakeWritingEngine(result: .success("x"))
        let long = String(repeating: "word ", count: 500)
        let model = WritingAssistViewModel(request: request(original: long), engine: engine)
        await model.run()
        XCTAssertEqual(model.phase, .failed(.inputTooLong))
        XCTAssertTrue(engine.calls.isEmpty)
    }

    @MainActor
    func testInventedNumberFallsBackToFailure() async {
        let engine = FakeWritingEngine(result: .success("Led a team of 8 people."))
        let model = WritingAssistViewModel(request: request(original: "led a team"), engine: engine)
        await model.run()
        XCTAssertEqual(model.phase, .failed(.addedDetails))
        XCTAssertNil(model.suggestion)
    }

    @MainActor
    func testSameTextShowsNoChange() async {
        let engine = FakeWritingEngine(result: .success("Led a small team."))
        let model = WritingAssistViewModel(request: request(.fixGrammar, original: "Led a  small\nteam."), engine: engine)
        await model.run()
        XCTAssertEqual(model.phase, .noChange)
    }

    @MainActor
    func testEngineFailuresMapToPlainStates() async {
        let failing = FakeWritingEngine(result: .failure(WritingAssistFailure.unsupportedLanguage))
        let first = WritingAssistViewModel(request: request(), engine: failing)
        await first.run()
        XCTAssertEqual(first.phase, .failed(.unsupportedLanguage))

        let unknown = FakeWritingEngine(result: .failure(SomeEngineError()))
        let second = WritingAssistViewModel(request: request(), engine: unknown)
        await second.run()
        XCTAssertEqual(second.phase, .failed(.generic))
    }

    @MainActor
    func testCancellationReturnsToIdle() async {
        let engine = FakeWritingEngine(result: .failure(CancellationError()))
        let model = WritingAssistViewModel(request: request(), engine: engine)
        await model.run()
        XCTAssertEqual(model.phase, .idle)
        model.cancel()
        XCTAssertEqual(model.phase, .idle)
    }

    @MainActor
    func testBulletSuggestionBecomesSeparateBullets() async {
        let engine = FakeWritingEngine(result: .success("- Managed social accounts\n- Wrote the weekly newsletter"))
        let original = WritingAssistText.joinBullets(["managed social", "wrote newsletter"])
        let model = WritingAssistViewModel(request: request(.strongerActionVerbs, target: .bullets, original: original,
                                                            context: "Role: Marketer at Acme"),
                                           engine: engine)
        await model.run()
        let suggestion = try? XCTUnwrap(model.suggestion)
        XCTAssertEqual(WritingAssistText.splitBullets(suggestion ?? ""), ["Managed social accounts", "Wrote the weekly newsletter"])
    }
}
