import Foundation

#if DEBUG
/// Debug-only hooks used by the UI tests that capture real simulator screenshots in CI.
/// None of this is compiled into Release builds.
enum CKScreenshotSupport {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-ck-screenshots")
    }

    private static var wantsSeed: Bool {
        ProcessInfo.processInfo.arguments.contains("-ck-seed")
    }

    /// Fills the store with a few sample documents and skips onboarding. Runs once per launch.
    @MainActor
    static func seedIfRequested(store: DocumentStore, appState: AppState) {
        guard isActive, wantsSeed, store.resumes.isEmpty else { return }
        appState.hasCompletedOnboarding = true

        let picks: [(id: String, title: String)] = [
            ("ck.professional.executive", "Operations Executive"),
            ("ck.creative.creative-designer", "UX Designer"),
            ("ck.technical.software-engineer", "Software Engineer"),
            ("ck.entry.fresh-graduate", "Graduate Analyst")
        ]
        for pick in picks {
            guard let template = TemplateLibrary.spec(id: pick.id) else { continue }
            var resume: Resume = SampleContent.resume(for: template)
            resume.title = pick.title
            store.upsert(resume)
        }
        var letter: CoverLetter = SampleContent.coverLetter()
        letter.title = "Finance Manager cover letter"
        store.upsert(letter)
        store.flushNow()
    }
}
#endif
