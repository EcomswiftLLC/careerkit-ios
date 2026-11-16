import XCTest
@testable import CareerKit

/// Resume import of Spanish, French, German and Chinese resumes: headings, dates and names.
final class ResumeImporterLanguagesTests: XCTestCase {

    // MARK: Fixtures

    private let spanishCV: String = """
    Ana Martínez López
    Analista de Datos
    ana.martinez@example.com | +34 600 123 456 | Valencia, España

    Resumen profesional
    Analista con cinco años de experiencia en análisis de datos, informes y automatización de procesos para empresas de retail.

    Experiencia laboral
    Analista de Datos Senior | Grupo Ejemplo
    enero de 2021 - actual
    • Automaticé informes semanales con Python y SQL.

    Analista de Datos | Datos Claros
    marzo 2018 - diciembre 2020
    • Diseñé paneles en Power BI para el equipo de ventas.

    Formación académica
    Grado en Estadística
    Universidad de Valencia, 2013 - 2017

    Habilidades
    Python, SQL, Power BI

    Idiomas
    Español (nativo), Inglés (B2)

    Certificaciones
    Google Data Analytics, 2022
    """

    private let frenchCV: String = """
    Camille Dubois
    Cheffe de projet digital
    camille.dubois@example.fr · 06 12 34 56 78 · Lyon, France

    Profil
    Cheffe de projet avec huit ans d'expérience dans la conduite de projets web et mobiles pour des marques nationales.

    Expérience professionnelle
    Cheffe de projet | Agence Exemple
    janvier 2020 - présent
    • Pilotage de projets pour des clients du secteur bancaire.

    Chargée de projet | Studio Lumière
    sept. 2016 - déc. 2019
    • Coordination des équipes design et développement.

    Formation
    Master Management de projet
    Université Lyon 2, 2014 - 2016

    Compétences
    Gestion de projet, Scrum, Jira

    Langues
    Français (langue maternelle), Anglais (courant)

    Centres d'intérêt
    Photographie, randonnée
    """

    private let germanCV: String = """
    Lukas Schneider
    Softwareentwickler
    lukas.schneider@example.de | +49 151 23456789 | Berlin, Deutschland

    Profil
    Softwareentwickler mit sieben Jahren Erfahrung in der Entwicklung von Webanwendungen mit Java und Kotlin.

    Berufserfahrung
    Senior Softwareentwickler | Beispiel GmbH
    Jan. 2020 - heute
    • Entwicklung von Microservices mit Spring Boot.

    Softwareentwickler | Muster AG
    03.2016 - 12.2019
    • Wartung und Ausbau einer Webplattform.

    Ausbildung
    B.Sc. Informatik
    Technische Universität München, 2012 - 2016

    Kenntnisse
    Java, Kotlin, Spring Boot, Docker

    Sprachen
    Deutsch (Muttersprache), Englisch (fließend)

    Zertifikate
    Oracle Certified Professional, 2019
    """

    private let chineseCV: String = """
    张伟
    高级软件工程师
    电话：138 0013 8000 | 邮箱：zhangwei@example.com
    现居：北京

    个人简介
    八年后端开发经验，熟悉分布式系统设计，带领过十人以上的研发团队，负责多个核心项目从零到一的落地。

    工作经历
    腾讯科技 | 高级软件工程师
    2020.01-至今
    • 负责支付系统核心模块的设计与开发。

    百度在线 | 软件工程师
    2016年7月 - 2019年12月
    • 参与搜索推荐服务的性能优化。

    教育背景
    北京大学 | 计算机科学与技术 本科
    2012.09 - 2016.06

    专业技能
    Java、Go、MySQL、Redis、Kubernetes

    语言能力
    英语（CET-6），普通话

    证书
    PMP 项目管理专业人士认证，2021
    """

    // MARK: Helpers

    private func section(_ draft: ResumeImportDraft, _ kind: SectionKind) -> ResumeSection? {
        return draft.sections.first(where: { $0.section.kind == kind && !$0.isFallback })?.section
    }

    private func kinds(_ draft: ResumeImportDraft) -> [SectionKind] {
        return draft.sections.filter { !$0.isFallback }.map { $0.section.kind }
    }

    private func items(_ section: ResumeSection?) -> [String] {
        return (section?.skillGroups ?? []).flatMap { $0.items }
    }

    // MARK: Whole resumes

    func testSpanishResume() {
        let draft = ResumeImporter.parse(spanishCV)
        XCTAssertEqual(draft.personal.fullName, "Ana Martínez López")
        XCTAssertEqual(draft.personal.professionalTitle, "Analista de Datos")
        XCTAssertEqual(draft.personal.email, "ana.martinez@example.com")
        XCTAssertEqual(draft.personal.city, "Valencia")
        let found = kinds(draft)
        for kind in [SectionKind.summary, .experience, .education, .skills, .languages, .certifications] {
            XCTAssertTrue(found.contains(kind), "missing \(kind) in \(found)")
        }
        let jobs = section(draft, .experience)?.entries ?? []
        XCTAssertEqual(jobs.count, 2)
        XCTAssertEqual(jobs.first?.heading, "Analista de Datos Senior")
        XCTAssertEqual(jobs.first?.subheading, "Grupo Ejemplo")
        XCTAssertEqual(jobs.first?.start, MonthYear(year: 2021, month: 1))
        XCTAssertEqual(jobs.first?.isCurrent, true)
        XCTAssertEqual(jobs.last?.start, MonthYear(year: 2018, month: 3))
        XCTAssertEqual(jobs.last?.end, MonthYear(year: 2020, month: 12))
        XCTAssertEqual(section(draft, .education)?.entries.first?.end?.year, 2017)
        XCTAssertTrue(items(section(draft, .skills)).contains("Power BI"))
        XCTAssertNil(draft.fallbackSection, draft.allText)
    }

    func testFrenchResume() {
        let draft = ResumeImporter.parse(frenchCV)
        XCTAssertEqual(draft.personal.fullName, "Camille Dubois")
        XCTAssertEqual(draft.personal.email, "camille.dubois@example.fr")
        XCTAssertEqual(draft.personal.city, "Lyon")
        XCTAssertFalse(draft.personal.phone.isEmpty)
        let found = kinds(draft)
        for kind in [SectionKind.summary, .experience, .education, .skills, .languages, .interests] {
            XCTAssertTrue(found.contains(kind), "missing \(kind) in \(found)")
        }
        let jobs = section(draft, .experience)?.entries ?? []
        XCTAssertEqual(jobs.count, 2)
        XCTAssertEqual(jobs.first?.start, MonthYear(year: 2020, month: 1))
        XCTAssertEqual(jobs.first?.isCurrent, true)
        XCTAssertEqual(jobs.last?.start, MonthYear(year: 2016, month: 9))
        XCTAssertEqual(jobs.last?.end, MonthYear(year: 2019, month: 12))
        XCTAssertTrue(items(section(draft, .skills)).contains("Scrum"))
    }

    func testGermanResume() {
        let draft = ResumeImporter.parse(germanCV)
        XCTAssertEqual(draft.personal.fullName, "Lukas Schneider")
        XCTAssertEqual(draft.personal.email, "lukas.schneider@example.de")
        XCTAssertEqual(draft.personal.city, "Berlin")
        let found = kinds(draft)
        for kind in [SectionKind.summary, .experience, .education, .skills, .languages, .certifications] {
            XCTAssertTrue(found.contains(kind), "missing \(kind) in \(found)")
        }
        let jobs = section(draft, .experience)?.entries ?? []
        XCTAssertEqual(jobs.count, 2)
        XCTAssertEqual(jobs.first?.heading, "Senior Softwareentwickler")
        XCTAssertEqual(jobs.first?.start, MonthYear(year: 2020, month: 1))
        XCTAssertEqual(jobs.first?.isCurrent, true)
        XCTAssertEqual(jobs.last?.start, MonthYear(year: 2016, month: 3))
        XCTAssertEqual(jobs.last?.end, MonthYear(year: 2019, month: 12))
        XCTAssertTrue(items(section(draft, .skills)).contains("Spring Boot"))
    }

    func testChineseResume() {
        let draft = ResumeImporter.parse(chineseCV)
        XCTAssertEqual(draft.personal.fullName, "张伟")
        XCTAssertEqual(draft.personal.professionalTitle, "高级软件工程师")
        XCTAssertEqual(draft.personal.email, "zhangwei@example.com")
        XCTAssertEqual(draft.personal.city, "北京")
        XCTAssertFalse(draft.personal.phone.isEmpty)
        let found = kinds(draft)
        for kind in [SectionKind.summary, .experience, .education, .skills, .languages, .certifications] {
            XCTAssertTrue(found.contains(kind), "missing \(kind) in \(found)")
        }
        let jobs = section(draft, .experience)?.entries ?? []
        XCTAssertEqual(jobs.count, 2, "\(jobs.map { $0.heading })")
        XCTAssertEqual(jobs.first?.heading, "腾讯科技")
        XCTAssertEqual(jobs.first?.subheading, "高级软件工程师")
        XCTAssertEqual(jobs.first?.start, MonthYear(year: 2020, month: 1))
        XCTAssertEqual(jobs.first?.isCurrent, true)
        XCTAssertEqual(jobs.last?.start, MonthYear(year: 2016, month: 7))
        XCTAssertEqual(jobs.last?.end, MonthYear(year: 2019, month: 12))
        let school = section(draft, .education)?.entries.first
        XCTAssertEqual(school?.start, MonthYear(year: 2012, month: 9))
        XCTAssertEqual(school?.end, MonthYear(year: 2016, month: 6))
        let skills = items(section(draft, .skills))
        for skill in ["Java", "Go", "MySQL", "Redis", "Kubernetes"] {
            XCTAssertTrue(skills.contains(skill), "\(skill) in \(skills)")
        }
        XCTAssertEqual(section(draft, .certifications)?.entries.first?.end?.year, 2021)
    }

    func testNothingIsDroppedInAnyLanguage() {
        let samples: [(String, [String])] = [
            (spanishCV, ["Automaticé informes semanales", "Universidad de Valencia", "Google Data Analytics"]),
            (frenchCV, ["Pilotage de projets", "Studio Lumière", "Photographie"]),
            (germanCV, ["Wartung und Ausbau", "Technische Universität München", "Oracle Certified Professional"]),
            (chineseCV, ["负责支付系统核心模块", "北京大学", "普通话", "PMP"])
        ]
        for (text, needles) in samples {
            let all = ResumeImporter.parse(text).allText
            for needle in needles {
                XCTAssertTrue(all.contains(needle), "\(needle) missing from \(all)")
            }
        }
    }

    // MARK: Headings

    func testLocalizedHeadingsAreRecognised() {
        let expected: [(String, SectionKind)] = [
            ("Experiencia laboral", .experience), ("Educación", .education), ("Formación académica", .education),
            ("Habilidades", .skills), ("Idiomas", .languages), ("Perfil", .summary),
            ("Resumen profesional", .summary), ("Certificaciones", .certifications), ("Proyectos", .projects),
            ("Expérience professionnelle", .experience), ("Formation", .education), ("Compétences", .skills),
            ("Langues", .languages), ("Profil", .summary), ("Certifications", .certifications),
            ("Projets", .projects), ("Centres d'intérêt", .interests),
            ("Berufserfahrung", .experience), ("Ausbildung", .education), ("Kenntnisse", .skills),
            ("Fähigkeiten", .skills), ("Sprachen", .languages), ("Zertifikate", .certifications),
            ("Projekte", .projects), ("Interessen", .interests), ("IT-Kenntnisse", .skills),
            ("工作经历", .experience), ("工作经验", .experience), ("教育背景", .education), ("教育经历", .education),
            ("技能", .skills), ("专业技能", .skills), ("语言能力", .languages), ("自我评价", .summary),
            ("个人简介", .summary), ("证书", .certifications), ("项目经历", .projects), ("兴趣爱好", .interests),
            ("实习经历", .internships)
        ]
        for (heading, kind) in expected {
            XCTAssertEqual(ResumeImporter.sectionKind(forHeading: heading), kind, heading)
        }
        XCTAssertNil(ResumeImporter.sectionKind(forHeading: "My Adventures"))
        XCTAssertNil(ResumeImporter.sectionKind(forHeading: "联系方式"))
    }

    func testBilingualAndSpacedChineseHeadings() {
        let text = """
        李娜
        工作经历 Work Experience
        产品经理 | 某某科技
        2019.03 - 至今
        教 育 背 景
        复旦大学 | 新闻学 本科
        2013.09 - 2017.06
        """
        let draft = ResumeImporter.parse(text)
        XCTAssertEqual(draft.personal.fullName, "李娜")
        XCTAssertTrue(kinds(draft).contains(.experience), "\(kinds(draft))")
        XCTAssertTrue(kinds(draft).contains(.education), "\(kinds(draft))")
        XCTAssertEqual(section(draft, .experience)?.entries.first?.isCurrent, true)
    }

    // MARK: Dates

    func testLocalizedDateRanges() {
        let cases: [(String, MonthYear, MonthYear?, Bool)] = [
            ("enero 2020 - actual", MonthYear(year: 2020, month: 1), nil, true),
            ("enero de 2020 - la actualidad", MonthYear(year: 2020, month: 1), nil, true),
            ("marzo 2017 - diciembre 2019", MonthYear(year: 2017, month: 3), MonthYear(year: 2019, month: 12), false),
            ("janvier 2020 - présent", MonthYear(year: 2020, month: 1), nil, true),
            ("févr. 2015 - août 2018", MonthYear(year: 2015, month: 2), MonthYear(year: 2018, month: 8), false),
            ("Jan. 2020 - heute", MonthYear(year: 2020, month: 1), nil, true),
            ("März 2016 – Dez. 2019", MonthYear(year: 2016, month: 3), MonthYear(year: 2019, month: 12), false),
            ("2020年1月 - 至今", MonthYear(year: 2020, month: 1), nil, true),
            ("2020年1月至今", MonthYear(year: 2020, month: 1), nil, true),
            ("2020.01-至今", MonthYear(year: 2020, month: 1), nil, true),
            ("2018年9月-2022年6月", MonthYear(year: 2018, month: 9), MonthYear(year: 2022, month: 6), false),
            ("2018.09 - 2022.06", MonthYear(year: 2018, month: 9), MonthYear(year: 2022, month: 6), false),
            ("2018/09 ~ 2022/06", MonthYear(year: 2018, month: 9), MonthYear(year: 2022, month: 6), false)
        ]
        for (text, start, end, current) in cases {
            let found = ImportDateParser.find(in: text, allowSingle: false)
            XCTAssertNotNil(found, text)
            XCTAssertEqual(found?.start, start, text)
            XCTAssertEqual(found?.end, end, text)
            XCTAssertEqual(found?.isCurrent, current, text)
        }
    }

    func testSinceMeansCurrent() {
        for text in ["seit März 2019", "depuis 2019", "desde 2019", "since 2019"] {
            let found = ImportDateParser.find(in: text, allowSingle: true)
            XCTAssertEqual(found?.start?.year, 2019, text)
            XCTAssertEqual(found?.isCurrent, true, text)
        }
        // Long prose lines are not read as dates.
        XCTAssertNil(ImportDateParser.find(in: "Managed budgets since 2019 across three regions", allowSingle: false))
    }

    func testEnglishDatesStillWork() {
        let found = ImportDateParser.find(in: "Jan 2020 – Present", allowSingle: false)
        XCTAssertEqual(found?.start, MonthYear(year: 2020, month: 1))
        XCTAssertEqual(found?.isCurrent, true)
        let years = ImportDateParser.find(in: "State University, 2012 - 2016", allowSingle: false)
        XCTAssertEqual(years?.start?.year, 2012)
        XCTAssertEqual(years?.end?.year, 2016)
        XCTAssertEqual(years?.remainder, "State University")
    }

    // MARK: Names

    func testChineseAndJapaneseNames() {
        XCTAssertTrue(ResumeImporter.looksLikeCJKName("张伟"))
        XCTAssertTrue(ResumeImporter.looksLikeCJKName("欧阳娜娜"))
        XCTAssertTrue(ResumeImporter.looksLikeCJKName("山田 太郎"))
        XCTAssertTrue(ResumeImporter.looksLikeCJKName("迪丽热巴·迪力木拉提"))
        XCTAssertFalse(ResumeImporter.looksLikeCJKName("高级软件工程师"))
        XCTAssertFalse(ResumeImporter.looksLikeCJKName("张"))
        XCTAssertFalse(ResumeImporter.looksLikeCJKName("张伟 Zhang"))
    }

    func testLabelledName() {
        XCTAssertEqual(ResumeImporter.labelledName("姓名:王芳"), "王芳")
        XCTAssertEqual(ResumeImporter.labelledName("Nombre: Ana López"), "Ana López")
        XCTAssertNil(ResumeImporter.labelledName("Skills: Swift"))
        let draft = ResumeImporter.parse("姓名：王芳\n电话：139 1234 5678\n\n技能\nExcel、PPT")
        XCTAssertEqual(draft.personal.fullName, "王芳")
        XCTAssertTrue(items(section(draft, .skills)).contains("Excel"))
    }
}
