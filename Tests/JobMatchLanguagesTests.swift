import XCTest
@testable import CareerKit

/// Job ad comparison with Spanish, French, German, Chinese and Japanese ads.
final class JobMatchLanguagesTests: XCTestCase {
    private func terms(_ keywords: [JobMatchKeyword]) -> [String] {
        return keywords.map { $0.term.lowercased() }
    }

    private let englishAd: String = """
    Senior iOS Engineer
    Requirements:
    - 5+ years of experience with Swift and SwiftUI
    - Experience with Core Data and unit testing
    - Strong knowledge of REST APIs and GraphQL
    """

    private let spanishAd: String = """
    Buscamos desarrolladores backend para nuestro equipo de pagos.
    Requisitos:
    - Experiencia de al menos tres años con Python y Django
    - Conocimientos de PostgreSQL y Docker
    - Gestión de proyectos con metodologías ágiles
    Ofrecemos:
    - Salario competitivo y seguro médico
    - Teletrabajo flexible
    """

    private let frenchAd: String = """
    Nous recherchons un développeur full stack pour rejoindre notre équipe produit.
    Votre profil :
    - Maîtrise de React et TypeScript
    - Connaissances en Node.js et MongoDB
    - Expérience des tests automatisés
    Nous offrons :
    - Tickets restaurant et mutuelle
    - Télétravail partiel
    """

    private let germanAd: String = """
    Wir suchen eine Softwareentwicklerin oder einen Softwareentwickler für unser Plattformteam.
    Ihr Profil:
    - Fundierte Kenntnisse in Java und Spring Boot
    - Erfahrung mit Kubernetes und AWS
    - Sehr gute Deutschkenntnisse
    Wir bieten:
    - 30 Urlaubstage
    - Betriebliche Altersvorsorge
    """

    private let chineseAd: String = """
    高级数据分析师
    岗位职责：
    1、负责用户行为数据分析，输出分析报告；
    2、搭建数据指标体系，支持业务决策。
    任职要求：
    1、熟悉Python和SQL，掌握Tableau；
    2、三年以上数据分析经验，统计学相关专业优先。
    福利待遇：五险一金，带薪年假。
    """

    // MARK: Language detection

    func testDetectsTheLanguageOfTheAd() {
        XCTAssertEqual(TextLanguage.detect(englishAd), .english)
        XCTAssertEqual(TextLanguage.detect(spanishAd), .spanish)
        XCTAssertEqual(TextLanguage.detect(frenchAd), .french)
        XCTAssertEqual(TextLanguage.detect(germanAd), .german)
        XCTAssertEqual(TextLanguage.detect(chineseAd), .chinese)
        XCTAssertEqual(TextLanguage.detect("経験者歓迎。Swiftでのアプリ開発経験が必須です。"), .japanese)
        XCTAssertEqual(TextLanguage.detect(""), .english)
        XCTAssertEqual(TextLanguage.detect("12345 !!!"), .english)
    }

    // MARK: Spanish

    func testSpanishAdMatchesAndMisses() {
        let resume = "Desarrolladora backend. Proyectos en Python, Django y Docker para una empresa de pagos."
        let result = JobMatchAnalyzer.analyze(jobDescription: spanishAd, resumeText: resume)
        XCTAssertTrue(result.hasTerms)
        let matched = terms(result.matched)
        let missing = terms(result.missing)
        XCTAssertTrue(matched.contains("python"), "\(matched)")
        XCTAssertTrue(matched.contains("django"), "\(matched)")
        XCTAssertTrue(matched.contains("docker"), "\(matched)")
        XCTAssertTrue(missing.contains("postgresql"), "\(missing)")
        let all = terms(result.matched + result.missing)
        for word in ["de", "con", "y", "para", "experiencia", "conocimientos", "salario", "seguro"] {
            XCTAssertFalse(all.contains(word), "\(word) in \(all)")
        }
    }

    func testSpanishPluralAndGenderFormsCompareAsOne() {
        XCTAssertEqual(JobMatchAnalyzer.stemSpanish("desarrolladores"), JobMatchAnalyzer.stemSpanish("desarrollador"))
        XCTAssertEqual(JobMatchAnalyzer.stemSpanish("desarrolladora"), JobMatchAnalyzer.stemSpanish("desarrollador"))
        XCTAssertEqual(JobMatchAnalyzer.stemSpanish("proyectos"), JobMatchAnalyzer.stemSpanish("proyecto"))
        XCTAssertEqual(JobMatchAnalyzer.stemSpanish("gestiones"), JobMatchAnalyzer.stemSpanish("gestion"))
        XCTAssertEqual(JobMatchAnalyzer.stemSpanish("clientes"), JobMatchAnalyzer.stemSpanish("cliente"))
        XCTAssertEqual(JobMatchAnalyzer.stemSpanish("analisis"), "analisis")
        // The ad says "desarrolladores", the resume "Desarrolladora": that is a match.
        let result = JobMatchAnalyzer.analyze(jobDescription: spanishAd, resumeText: "Desarrolladora backend con Python.")
        XCTAssertTrue(terms(result.matched).contains("desarrolladores"), "\(terms(result.matched))")
    }

    // MARK: French

    func testFrenchAdMatchesAndMisses() {
        let resume = "Développeuse React et TypeScript. Mise en place de tests automatisés."
        let result = JobMatchAnalyzer.analyze(jobDescription: frenchAd, resumeText: resume)
        let matched = terms(result.matched)
        let missing = terms(result.missing)
        XCTAssertTrue(matched.contains("react"), "\(matched)")
        XCTAssertTrue(matched.contains("typescript"), "\(matched)")
        XCTAssertTrue(missing.contains("mongodb"), "\(missing)")
        let all = terms(result.matched + result.missing)
        for word in ["un", "pour", "notre", "et", "des", "mutuelle", "maîtrise", "connaissances"] {
            XCTAssertFalse(all.contains(word), "\(word) in \(all)")
        }
        XCTAssertTrue(matched.contains(where: { $0.hasPrefix("développeur") }), "\(matched)")
    }

    func testFrenchFormsCompareAsOne() {
        XCTAssertEqual(JobMatchAnalyzer.stemFrench("developpeuse"), JobMatchAnalyzer.stemFrench("developpeur"))
        XCTAssertEqual(JobMatchAnalyzer.stemFrench("developpeurs"), JobMatchAnalyzer.stemFrench("developpeur"))
        XCTAssertEqual(JobMatchAnalyzer.stemFrench("competences"), JobMatchAnalyzer.stemFrench("competence"))
        XCTAssertEqual(JobMatchAnalyzer.stemFrench("journaux"), JobMatchAnalyzer.stemFrench("journal"))
        XCTAssertEqual(JobMatchAnalyzer.stemFrench("directrice"), JobMatchAnalyzer.stemFrench("directeur"))
    }

    // MARK: German

    func testGermanAdMatchesAndMisses() {
        let resume = "Softwareentwickler mit Java, Spring Boot und Kubernetes."
        let result = JobMatchAnalyzer.analyze(jobDescription: germanAd, resumeText: resume)
        let matched = terms(result.matched)
        let missing = terms(result.missing)
        XCTAssertTrue(matched.contains("java"), "\(matched)")
        XCTAssertTrue(matched.contains("kubernetes"), "\(matched)")
        XCTAssertTrue(missing.contains("aws"), "\(missing)")
        let all = terms(result.matched + result.missing)
        for word in ["und", "mit", "eine", "kenntnisse", "erfahrung", "urlaubstage", "unser"] {
            XCTAssertFalse(all.contains(word), "\(word) in \(all)")
        }
    }

    func testGermanFormsCompareAsOne() {
        XCTAssertEqual(JobMatchAnalyzer.stemGerman("losungen"), JobMatchAnalyzer.stemGerman("losung"))
        XCTAssertEqual(JobMatchAnalyzer.stemGerman("kunden"), JobMatchAnalyzer.stemGerman("kunde"))
        XCTAssertEqual(JobMatchAnalyzer.stemGerman("kenntnisse"), JobMatchAnalyzer.stemGerman("kenntnis"))
        XCTAssertEqual(JobMatchAnalyzer.stemGerman("entwicklerinnen"), JobMatchAnalyzer.stemGerman("entwicklerin"))
        XCTAssertEqual(JobMatchAnalyzer.stemGerman("teams"), JobMatchAnalyzer.stemGerman("team"))
    }

    // MARK: Chinese and Japanese

    func testChineseTokenizationGivesMultiCharacterWords() {
        let words = JobMatchAnalyzer.clauses(in: "负责用户行为数据分析，输出分析报告").flatMap { $0 }
        XCTAssertGreaterThan(words.count, 2, "\(words)")
        XCTAssertTrue(words.contains(where: { $0.count >= 2 && CJKText.containsCJK($0) }), "\(words)")
        // The clause is cut into words, not kept as one long run.
        XCTAssertFalse(words.contains("负责用户行为数据分析"), "\(words)")
    }

    func testChineseKeyTermsAreWordsNotCharacters() {
        let all = JobMatchAnalyzer.keyTerms(in: chineseAd)
        XCTAssertFalse(all.isEmpty)
        let cjkTerms = all.map { $0.term }.filter { CJKText.containsCJK($0) }
        XCTAssertFalse(cjkTerms.isEmpty, "\(all.map { $0.term })")
        for term in cjkTerms {
            XCTAssertGreaterThanOrEqual(term.count, 2, term)
        }
        let found = all.map { $0.term }
        for word in ["的", "和", "五险一金", "带薪年假", "经验", "熟悉"] {
            XCTAssertFalse(found.contains(word), "\(word) in \(found)")
        }
    }

    func testChineseAdMatchesAndMisses() {
        let resume = "数据分析师，熟练使用 Python、SQL 完成数据分析和可视化，定期输出分析报告。"
        let result = JobMatchAnalyzer.analyze(jobDescription: chineseAd, resumeText: resume)
        XCTAssertTrue(result.hasTerms)
        let matched = terms(result.matched)
        let missing = terms(result.missing)
        XCTAssertTrue(matched.contains("python"), "\(matched)")
        XCTAssertTrue(matched.contains("sql"), "\(matched)")
        XCTAssertTrue(missing.contains("tableau"), "\(missing)")
        XCTAssertTrue(matched.contains(where: { $0.contains("数据") || $0.contains("分析") }), "\(matched)")
    }

    func testJapaneseAdDoesNotCrash() {
        let ad = "【必須スキル】\nSwiftでのiOSアプリ開発経験3年以上\nGitを使ったチーム開発の経験\n【歓迎スキル】\nKotlin"
        let result = JobMatchAnalyzer.analyze(jobDescription: ad, resumeText: "iOSアプリをSwiftで開発。")
        XCTAssertTrue(result.hasTerms)
        XCTAssertTrue(terms(result.matched).contains("swift"), "\(terms(result.matched))")
    }

    // MARK: Robustness

    func testMixedAndOddInputDoesNotCrash() {
        let inputs: [String] = [
            "要求：熟悉 Swift 和 数据分析。🚀",
            "。。。，，，、、、",
            "数",
            "Requisitos: Python 和 SQL; Kenntnisse in Java; Maîtrise de React",
            String(repeating: "数据分析 Python ", count: 3000),
            "\u{200B}\u{FEFF}"
        ]
        for input in inputs {
            let result = JobMatchAnalyzer.analyze(jobDescription: input, resumeText: input)
            XCTAssertLessThanOrEqual(result.totalKeyTerms, JobMatchAnalyzer.keyTermLimit)
        }
    }

    func testEnglishAdKeepsTheOriginalBehaviour() {
        let viaDetection = JobMatchAnalyzer.keyTerms(in: englishAd)
        let explicit = JobMatchAnalyzer.keyTerms(in: englishAd, language: .english)
        XCTAssertEqual(viaDetection.map { $0.key }, explicit.map { $0.key })
        XCTAssertEqual(JobMatchAnalyzer.stemKey("designs", language: .english), JobMatchAnalyzer.stemKey("designs"))
    }

    func testSummaryStaysHonestInEveryLanguage() {
        for ad in [spanishAd, frenchAd, germanAd, chineseAd] {
            let result = JobMatchAnalyzer.analyze(jobDescription: ad, resumeText: "")
            XCTAssertTrue(result.matched.isEmpty)
            XCTAssertFalse(result.missing.isEmpty)
            XCTAssertFalse(result.summary.lowercased().contains("score"))
        }
    }
}
