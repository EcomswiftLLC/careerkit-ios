import XCTest
@testable import CareerKit

final class JobMatchAnalyzerTests: XCTestCase {
    private let sampleAd: String = """
    Senior iOS Engineer

    About the role
    We are looking for an iOS engineer to build our mobile banking app.

    Requirements:
    - 5+ years of experience with Swift and SwiftUI
    - Experience with Core Data and unit testing
    - Strong knowledge of REST APIs and GraphQL
    - Familiar with CI/CD pipelines and Fastlane
    - Experience mentoring engineers and doing code reviews
    - Excellent communication skills

    Nice to have: Kotlin, accessibility, Swift Package Manager.

    Benefits
    Health insurance, dental, 401(k) matching and paid time off.
    We are an equal opportunity employer and value diversity regardless of race or religion.
    """

    private func keys(_ keywords: [JobMatchKeyword]) -> [String] {
        return keywords.map { $0.key }
    }

    private func terms(_ keywords: [JobMatchKeyword]) -> [String] {
        return keywords.map { $0.term.lowercased() }
    }

    // MARK: Matching

    func testMatchesTermsFoundInResume() {
        let resumeText = "iOS developer. Built apps in Swift and SwiftUI with Core Data. Wrote unit tests."
        let result = JobMatchAnalyzer.analyze(jobDescription: sampleAd, resumeText: resumeText)
        XCTAssertTrue(result.hasTerms)
        let matched = terms(result.matched)
        XCTAssertTrue(matched.contains("swift"), "\(matched)")
        XCTAssertTrue(matched.contains("swiftui"), "\(matched)")
        let missing = terms(result.missing)
        XCTAssertTrue(missing.contains("graphql"), "\(missing)")
        XCTAssertFalse(missing.contains("swift"))
        XCTAssertLessThanOrEqual(result.matched.count + result.missing.count, result.totalKeyTerms)
    }

    func testSummaryUsesPlainCounts() {
        let result = JobMatchAnalyzer.analyze(jobDescription: sampleAd, resumeText: "Swift")
        XCTAssertTrue(result.summary.hasPrefix("You cover \(result.matched.count) of \(result.totalKeyTerms) key terms"), result.summary)
        XCTAssertFalse(result.summary.lowercased().contains("score"))
    }

    func testMissingIsCappedAtTwelve() {
        let result = JobMatchAnalyzer.analyze(jobDescription: sampleAd, resumeText: "")
        XCTAssertLessThanOrEqual(result.missing.count, JobMatchAnalyzer.missingLimit)
        XCTAssertTrue(result.matched.isEmpty)
        XCTAssertGreaterThan(result.totalKeyTerms, 0)
        XCTAssertLessThanOrEqual(result.totalKeyTerms, JobMatchAnalyzer.keyTermLimit)
    }

    func testBoilerplateIsDropped() {
        let all = JobMatchAnalyzer.keyTerms(in: sampleAd)
        let found = terms(all)
        for word in ["insurance", "dental", "religion", "race", "diversity", "opportunity"] {
            XCTAssertFalse(found.contains(word), "\(word) should be ignored: \(found)")
        }
    }

    func testRequirementTermsOutrankOtherMentions() {
        let ad = """
        Our office has a terrace and a garden.
        Requirements:
        - Python
        - Python and Airflow
        """
        let all = JobMatchAnalyzer.keyTerms(in: ad)
        XCTAssertEqual(all.first?.term.lowercased(), "python", "\(terms(all))")
        let python = all.first(where: { $0.term.lowercased() == "python" })
        let garden = all.first(where: { $0.term.lowercased() == "garden" })
        XCTAssertNotNil(python)
        if let python, let garden {
            XCTAssertGreaterThan(python.weight, garden.weight)
        }
    }

    func testSuggestedSectionsAreSensible() {
        XCTAssertEqual(JobMatchAnalyzer.suggestedSection(display: "GraphQL", isPhrase: false), .skills)
        XCTAssertEqual(JobMatchAnalyzer.suggestedSection(display: "C++", isPhrase: false), .skills)
        XCTAssertEqual(JobMatchAnalyzer.suggestedSection(display: "communication", isPhrase: false), .summary)
        XCTAssertEqual(JobMatchAnalyzer.suggestedSection(display: "PMP certification", isPhrase: true), .certifications)
        XCTAssertEqual(JobMatchAnalyzer.suggestedSection(display: "bachelor", isPhrase: false), .education)
        XCTAssertEqual(JobMatchAnalyzer.suggestedSection(display: "vendor negotiations", isPhrase: true), .experience)
    }

    func testHonestyNoteNeverInventsExperience() {
        XCTAssertTrue(JobMatchAnalyzer.honestyNote.contains("Add only what is true for you"))
    }

    // MARK: Plurals and stemming

    func testPluralsAndVerbFormsMatch() {
        XCTAssertEqual(JobMatchAnalyzer.stemKey("designs"), JobMatchAnalyzer.stemKey("design"))
        XCTAssertEqual(JobMatchAnalyzer.stemKey("designing"), JobMatchAnalyzer.stemKey("designed"))
        XCTAssertEqual(JobMatchAnalyzer.stemKey("companies"), JobMatchAnalyzer.stemKey("company"))
        XCTAssertEqual(JobMatchAnalyzer.stemKey("managing"), JobMatchAnalyzer.stemKey("manage"))
        XCTAssertEqual(JobMatchAnalyzer.stemKey("planning"), JobMatchAnalyzer.stemKey("plan"))
        XCTAssertEqual(JobMatchAnalyzer.stemKey("processes"), JobMatchAnalyzer.stemKey("process"))
        // Words that only look plural are left alone.
        XCTAssertEqual(JobMatchAnalyzer.stemKey("analysis"), "analysis")
        XCTAssertEqual(JobMatchAnalyzer.stemKey("status"), "status")
        // Technical names are never stemmed.
        XCTAssertEqual(JobMatchAnalyzer.stemKey("node.js"), "node.js")
        XCTAssertEqual(JobMatchAnalyzer.stemKey("c++"), "c++")
    }

    func testPluralInAdMatchesSingularInResume() {
        let ad = "Requirements: experience building dashboards and integrations with payment providers."
        let result = JobMatchAnalyzer.analyze(jobDescription: ad, resumeText: "Built a dashboard and one payment integration.")
        let matched = terms(result.matched)
        XCTAssertTrue(matched.contains("dashboards"), "\(matched)")
        XCTAssertTrue(matched.contains("integrations"), "\(matched)")
    }

    func testHyphenatedAndSpacedPhrasesMatch() {
        let ad = "You will lead cross functional projects. Cross functional work is key. Cross functional planning."
        let result = JobMatchAnalyzer.analyze(jobDescription: ad, resumeText: "Led cross-functional squads.")
        XCTAssertTrue(result.matched.contains(where: { $0.isPhrase && $0.term.lowercased() == "cross functional" }),
                      "\(terms(result.matched)) / \(terms(result.missing))")
    }

    func testRepeatedPhraseIsKeptAsOneTerm() {
        let ad = "Project management is central. You own project management for launches. Project management tools."
        let all = JobMatchAnalyzer.keyTerms(in: ad)
        XCTAssertTrue(all.contains(where: { $0.isPhrase && $0.term.lowercased() == "project management" }), "\(terms(all))")
        // "management" only appears inside the phrase, so it is not listed on its own.
        XCTAssertFalse(all.contains(where: { !$0.isPhrase && $0.term.lowercased() == "management" }), "\(terms(all))")
    }

    // MARK: Stop words

    func testStopWordsAreNeverTerms() {
        let ad = "The and of to with for you your we our will must have been this that"
        XCTAssertTrue(JobMatchAnalyzer.keyTerms(in: ad).isEmpty)
    }

    func testOtherLanguageStopWordsAreDropped() {
        let es = "Buscamos una persona con experiencia en ventas y gestión de clientes para el equipo."
        let found = terms(JobMatchAnalyzer.keyTerms(in: es))
        for word in ["una", "con", "en", "y", "de", "para", "el"] {
            XCTAssertFalse(found.contains(word), "\(word) in \(found)")
        }
        XCTAssertTrue(found.contains("ventas"), "\(found)")
        let de = "Wir suchen eine Person mit Erfahrung in der Buchhaltung und im Controlling."
        let deFound = terms(JobMatchAnalyzer.keyTerms(in: de))
        XCTAssertFalse(deFound.contains("und"))
        XCTAssertTrue(deFound.contains("buchhaltung"), "\(deFound)")
    }

    // MARK: Edge cases

    func testEmptyInput() {
        let result = JobMatchAnalyzer.analyze(jobDescription: "", resumeText: "Swift")
        XCTAssertFalse(result.hasTerms)
        XCTAssertTrue(result.matched.isEmpty)
        XCTAssertTrue(result.missing.isEmpty)
        XCTAssertFalse(result.summary.isEmpty)
        let blank = JobMatchAnalyzer.analyze(jobDescription: "   \n\n\t ", resumeText: "")
        XCTAssertFalse(blank.hasTerms)
    }

    func testEmptyResumeWithRealModel() {
        let resume = Resume(title: "Empty", templateID: TemplateLibrary.defaultTemplateID, sections: [])
        let result = JobMatchAnalyzer.analyze(jobDescription: sampleAd, resume: resume)
        XCTAssertTrue(result.matched.isEmpty)
        XCTAssertFalse(result.missing.isEmpty)
    }

    func testResumeTextIncludesSkillsAndBullets() {
        var skills = ResumeSection(kind: .skills)
        var group = SkillGroup()
        group.items = ["Kubernetes", "Terraform"]
        skills.skillGroups = [group]
        var experience = ResumeSection(kind: .experience)
        var entry = ResumeEntry()
        entry.heading = "Platform Engineer"
        entry.bullets = ["Ran GraphQL gateways"]
        experience.entries = [entry]
        let resume = Resume(title: "R", templateID: TemplateLibrary.defaultTemplateID, sections: [skills, experience])
        let ad = "Requirements: Kubernetes, Terraform and GraphQL."
        let result = JobMatchAnalyzer.analyze(jobDescription: ad, resume: resume)
        let matched = terms(result.matched)
        XCTAssertTrue(matched.contains("kubernetes"), "\(matched)")
        XCTAssertTrue(matched.contains("terraform"), "\(matched)")
        XCTAssertTrue(matched.contains("graphql"), "\(matched)")
        XCTAssertTrue(result.missing.isEmpty)
    }

    func testVeryLongInputIsCappedAndFast() {
        var ad = ""
        for i in 0..<4000 {
            ad += "Requirement \(i): experience with Swift, Kotlin, GraphQL and term\(i % 300) in production. "
        }
        XCTAssertGreaterThan(ad.count, JobMatchAnalyzer.maxInputLength)
        let started = Date()
        let result = JobMatchAnalyzer.analyze(jobDescription: ad, resumeText: String(repeating: "Swift developer. ", count: 5000))
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertTrue(result.wasTruncated)
        XCTAssertLessThanOrEqual(result.totalKeyTerms, JobMatchAnalyzer.keyTermLimit)
        XCTAssertLessThan(elapsed, 10.0, "Comparing a capped ad took \(elapsed) s")
        XCTAssertTrue(terms(result.matched).contains("swift"))
    }

    func testUnicodeAndEmojiDoNotCrash() {
        let ad = """
        Requisitos: gestión de proyectos, análisis de datos 📊, comunicação, Größe, naïve café.
        要求：熟悉 Swift 和 数据分析。 🚀🚀🚀
        مطلوب خبرة في التسويق
        \u{200B}\u{FEFF} zero width
        """
        let result = JobMatchAnalyzer.analyze(jobDescription: ad, resumeText: "Gestion de proyectos y analisis de datos")
        XCTAssertTrue(result.hasTerms)
        // Accents are ignored when comparing.
        let matched = terms(result.matched)
        XCTAssertTrue(matched.contains("gestión") || matched.contains("proyectos"), "\(matched)")
        XCTAssertFalse(terms(result.matched + result.missing).contains("📊"))
    }

    func testTechnicalTokensStayWhole() {
        let clauses = JobMatchAnalyzer.clauses(in: "Experience with C++, C#, Node.js and CI/CD; client/server apps.")
        let words = clauses.flatMap { $0 }.map { $0.lowercased() }
        XCTAssertTrue(words.contains("c++"), "\(words)")
        XCTAssertTrue(words.contains("c#"), "\(words)")
        XCTAssertTrue(words.contains("node.js"), "\(words)")
        XCTAssertTrue(words.contains("ci/cd"), "\(words)")
        XCTAssertTrue(words.contains("client") && words.contains("server"), "\(words)")
    }
}
