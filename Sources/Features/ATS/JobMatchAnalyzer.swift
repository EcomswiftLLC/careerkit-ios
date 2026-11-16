import Foundation

// Compares the wording of a job ad with the text of a resume, on the device.
// It reports which key terms of the ad already appear and which do not. It is not a score from any
// employer's system, and it never suggests adding anything that is not true.

/// One key term found in a job ad.
struct JobMatchKeyword: Identifiable, Equatable, Hashable {
    /// The term as written in the ad ("Kubernetes", "project management").
    let term: String
    /// Comparison key: folded, lowercased and lightly stemmed. Two words for a phrase.
    let key: String
    let weight: Double
    let isPhrase: Bool
    /// Where the term would most naturally go if it is true for the user.
    let suggestedSection: SectionKind

    var id: String { key }
}

struct JobMatchResult: Equatable {
    /// Key terms that already appear in the resume, most important first.
    let matched: [JobMatchKeyword]
    /// Key terms that do not appear, most important first, at most `JobMatchAnalyzer.missingLimit`.
    let missing: [JobMatchKeyword]
    /// How many key terms were compared (matched plus every missing term, not only the ones shown).
    let totalKeyTerms: Int
    /// True when the ad was longer than `JobMatchAnalyzer.maxInputLength` and only the start was read.
    let wasTruncated: Bool

    var hasTerms: Bool { totalKeyTerms > 0 }

    /// Plain-language summary, for example "You cover 14 of 22 key terms from this job ad."
    var summary: String {
        guard hasTerms else {
            return String(localized: "No key terms were found. Paste the full job ad, including the requirements.")
        }
        let covered: Int = matched.count
        let total: Int = totalKeyTerms
        return String(localized: "You cover \(covered) of \(total) key terms from this job ad.")
    }
}

enum JobMatchAnalyzer {
    /// Longer ads are cut to this many characters before they are read.
    static let maxInputLength: Int = 20_000
    /// Most terms compared from one ad.
    static let keyTermLimit: Int = 25
    /// Most missing terms shown.
    static let missingLimit: Int = 12

    static let honestyNote: String = String(localized: "Add only what is true for you. A missing term is a prompt to check your wording, not a reason to claim experience you do not have.")

    // MARK: Entry points

    static func analyze(jobDescription: String, resume: Resume) -> JobMatchResult {
        return analyze(jobDescription: jobDescription, resumeText: resumeText(resume))
    }

    static func analyze(jobDescription: String, resumeText: String) -> JobMatchResult {
        let truncated: Bool = jobDescription.count > maxInputLength
        let job: String = truncated ? String(jobDescription.prefix(maxInputLength)) : jobDescription
        let terms: [JobMatchKeyword] = keyTerms(in: job)
        let index = JobMatchResumeIndex(text: String(resumeText.prefix(200_000)))

        var matched: [JobMatchKeyword] = []
        var missing: [JobMatchKeyword] = []
        for term in terms {
            if index.contains(term) {
                matched.append(term)
            } else {
                missing.append(term)
            }
        }
        return JobMatchResult(matched: matched,
                              missing: Array(missing.prefix(missingLimit)),
                              totalKeyTerms: terms.count,
                              wasTruncated: truncated)
    }

    /// All the text of a resume that a reader would see: title, every visible section, skills included.
    static func resumeText(_ resume: Resume) -> String {
        var lines: [String] = []
        lines.append(resume.personal.professionalTitle)
        for section in resume.sections where section.isVisible {
            lines.append(section.title)
            lines.append(section.text)
            for entry in section.entries {
                lines.append(entry.heading)
                lines.append(entry.subheading)
                lines.append(entry.detail)
                lines.append(entry.extra)
                lines.append(contentsOf: entry.bullets)
            }
            for group in section.skillGroups {
                lines.append(group.name)
                lines.append(contentsOf: group.items)
            }
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    // MARK: Key terms

    private struct Candidate {
        var display: String
        var weight: Double
        var count: Int
        var firstIndex: Int
        var inRequirement: Bool
        var isPhrase: Bool
        var parts: [String]
    }

    /// Key terms of a job ad, most important first, at most `keyTermLimit`.
    static func keyTerms(in text: String) -> [JobMatchKeyword] {
        var unigrams: [String: Candidate] = [:]
        var bigrams: [String: Candidate] = [:]
        var order: Int = 0

        for sentence in sentences(in: text) where !sentence.isBoilerplate {
            let multiplier: Double = sentence.isRequirement ? 1.6 : 1.0
            for clause in clauses(in: sentence.text) {
                var previousKey: String? = nil
                var previousDisplay: String? = nil
                for raw in clause {
                    let folded: String = fold(raw)
                    guard isMeaningful(folded), !stopWords.contains(folded), !genericWords.contains(folded) else {
                        previousKey = nil
                        previousDisplay = nil
                        continue
                    }
                    let key: String = stemKey(folded)
                    guard !key.isEmpty, !genericWords.contains(key) else {
                        previousKey = nil
                        previousDisplay = nil
                        continue
                    }
                    order += 1
                    add(&unigrams, key: key, display: raw, weight: multiplier, order: order,
                        requirement: sentence.isRequirement, phrase: false, parts: [key])
                    if let pk = previousKey, let pd = previousDisplay, pk != key {
                        add(&bigrams, key: pk + " " + key, display: pd + " " + raw, weight: multiplier * 1.5, order: order,
                            requirement: sentence.isRequirement, phrase: true, parts: [pk, key])
                    }
                    previousKey = key
                    previousDisplay = raw
                }
            }
        }

        // Phrases are kept when they repeat or are a well known pairing.
        var chosen: [Candidate] = []
        var phraseCounts: [String: Int] = [:]
        for (key, candidate) in bigrams where candidate.count >= 2 || commonPhraseKeys.contains(key) {
            chosen.append(candidate)
            for part in candidate.parts {
                phraseCounts[part] = max(phraseCounts[part] ?? 0, candidate.count)
            }
        }
        for (key, candidate) in unigrams {
            // A word that only ever appears inside a kept phrase is represented by the phrase.
            if let inPhrase = phraseCounts[key], candidate.count <= inPhrase { continue }
            chosen.append(candidate)
        }

        chosen.sort { a, b in
            if a.weight != b.weight { return a.weight > b.weight }
            if a.firstIndex != b.firstIndex { return a.firstIndex < b.firstIndex }
            if a.isPhrase != b.isPhrase { return a.isPhrase }
            return a.display < b.display
        }

        var out: [JobMatchKeyword] = []
        for candidate in chosen.prefix(keyTermLimit) {
            let key: String = candidate.parts.joined(separator: " ")
            out.append(JobMatchKeyword(term: candidate.display,
                                       key: key,
                                       weight: candidate.weight,
                                       isPhrase: candidate.isPhrase,
                                       suggestedSection: suggestedSection(display: candidate.display,
                                                                          isPhrase: candidate.isPhrase)))
        }
        return out
    }

    private static func add(_ table: inout [String: Candidate], key: String, display: String, weight: Double,
                            order: Int, requirement: Bool, phrase: Bool, parts: [String]) {
        if var existing = table[key] {
            existing.weight += weight
            existing.count += 1
            existing.inRequirement = existing.inRequirement || requirement
            // Prefer the lowercase spelling over one capitalised only because it started a sentence.
            if display == display.lowercased() && existing.display != existing.display.lowercased()
                && isCapitalisedWord(existing.display) {
                existing.display = display
            }
            table[key] = existing
        } else {
            table[key] = Candidate(display: display, weight: weight, count: 1, firstIndex: order,
                                   inRequirement: requirement, isPhrase: phrase, parts: parts)
        }
    }

    /// "Managing" or "Project management": only the first letter is upper case.
    private static func isCapitalisedWord(_ value: String) -> Bool {
        guard let first = value.first, first.isUppercase else { return false }
        return value.dropFirst().allSatisfy { !$0.isUppercase }
    }

    // MARK: Section suggestion

    static func suggestedSection(display: String, isPhrase: Bool) -> SectionKind {
        let lower: String = fold(display)
        if certificationHints.contains(where: { lower.contains($0) }) { return .certifications }
        if degreeHints.contains(where: { lower.contains($0) }) { return .education }
        if softSkillPrefixes.contains(where: { lower.hasPrefix($0) }) { return .summary }
        if looksTechnical(display) { return .skills }
        return isPhrase ? .experience : .skills
    }

    private static func looksTechnical(_ display: String) -> Bool {
        if display.contains(where: { $0.isNumber || $0 == "+" || $0 == "#" || $0 == "." || $0 == "/" }) { return true }
        let uppercase: Int = display.filter { $0.isUppercase }.count
        return uppercase >= 2
    }

    // MARK: Text splitting

    struct Sentence {
        let text: String
        let isRequirement: Bool
        let isBoilerplate: Bool
    }

    private enum BlockMode {
        case neutral
        case requirements
        case boilerplate
    }

    /// Splits an ad into sentences and marks the ones that state requirements or are boilerplate.
    static func sentences(in text: String) -> [Sentence] {
        var out: [Sentence] = []
        var mode: BlockMode = .neutral
        let normalised: String = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        for rawLine in normalised.components(separatedBy: "\n") {
            var line: String = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            // "Requirements: Kubernetes, Terraform" on one line: the label sets the mode and the rest is content.
            if let colon = line.firstIndex(of: ":") {
                let after: String = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                let before: String = fold(String(line[..<colon]))
                let beforeWords: Int = before.split(whereSeparator: { $0.isWhitespace }).count
                if !after.isEmpty, beforeWords >= 1, beforeWords <= 4,
                   requirementHeaders.contains(where: { before.hasPrefix($0) }) {
                    mode = .requirements
                    line = after
                }
            }
            let lower: String = fold(line)
            let wordCount: Int = lower.split(whereSeparator: { $0.isWhitespace }).count

            let bulleted: Bool = line.first.map { bulletCharacters.contains($0) } ?? false

            // Short lines such as "Requirements:" or "What we offer" switch the mode for what follows.
            // A bullet such as "Strong SQL skills" is content, not a header, so only the start of the line is matched.
            if !bulleted && wordCount <= 6 && !lower.contains(". ") {
                let endsWithColon: Bool = lower.hasSuffix(":")
                let head: String = endsWithColon ? String(lower.dropLast()) : lower
                func matches(_ list: [String]) -> Bool {
                    if list.contains(where: { head.hasPrefix($0) }) { return true }
                    return endsWithColon && list.contains(where: { head.contains($0) })
                }
                if matches(requirementHeaders) {
                    mode = .requirements
                    continue
                }
                if matches(boilerplateHeaders) {
                    // "Salary: 50,000" is skipped without hiding what follows.
                    if !lower.contains(where: { $0.isNumber }) { mode = .boilerplate }
                    continue
                }
            }
            if mode == .boilerplate { continue }

            for piece in splitSentences(line) {
                let pieceLower: String = fold(piece)
                let boilerplate: Bool = boilerplatePhrases.contains(where: { pieceLower.contains($0) })
                let requirement: Bool = mode == .requirements || bulleted
                    || requirementCues.contains(where: { pieceLower.contains($0) })
                out.append(Sentence(text: piece, isRequirement: requirement, isBoilerplate: boilerplate))
            }
        }
        return out
    }

    private static let bulletCharacters: Set<Character> = ["-", "*", "\u{2022}", "\u{25AA}", "\u{25CF}", "\u{25E6}", "\u{2023}", "\u{00B7}", "\u{2013}", "\u{2014}", "\u{25A0}", "\u{2043}"]

    /// Breaks a line at sentence ends and bullet glyphs. A full stop only ends a sentence when a space or the
    /// end of the line follows, so "Node.js" and "e.g." stay whole.
    private static func splitSentences(_ line: String) -> [String] {
        let chars: [Character] = Array(line)
        var out: [String] = []
        var current: String = ""
        var i: Int = 0
        while i < chars.count {
            let ch: Character = chars[i]
            var breakHere: Bool = false
            if ch == "!" || ch == "?" || ch == ";" || ch == "\u{2022}" || ch == "\u{25AA}" || ch == "\u{25CF}" || ch == "\u{00B7}" {
                breakHere = true
            } else if ch == "." {
                if i + 1 >= chars.count || chars[i + 1].isWhitespace { breakHere = true }
            }
            if breakHere {
                let trimmed: String = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { out.append(trimmed) }
                current = ""
            } else {
                current.append(ch)
            }
            i += 1
        }
        let trimmed: String = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { out.append(trimmed) }
        return out
    }

    private static let clauseBreaks: Set<Character> = [",", ":", "(", ")", "[", "]", "{", "}", "\"", "\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}", "'", "|", "\u{2013}", "\u{2014}", "!", "?", ";", "\u{2022}", "\u{00B7}", "<", ">", "=", "*", "~", "^", "%", "$", "\u{20AC}", "\u{00A3}", "@"]

    /// Words of a sentence, grouped into clauses. Phrases are only built inside one clause.
    /// Letters, digits, "+" and "#" make words; ".", "-", "/" and "&" are kept inside a word ("Node.js", "CI/CD").
    static func clauses(in sentence: String) -> [[String]] {
        var out: [[String]] = []
        var clause: [String] = []
        var word: String = ""

        func flushWord() {
            var w: String = word
            word = ""
            while let last = w.last, last == "." || last == "-" || last == "/" || last == "&" {
                w.removeLast()
            }
            while let first = w.first, first == "-" || first == "/" || first == "&" {
                w.removeFirst()
            }
            guard !w.isEmpty, w.contains(where: { $0.isLetter || $0.isNumber }) else { return }
            // "client/server" reads as two words; "CI/CD" and "TCP/IP" stay as one.
            if w.contains("/") {
                let parts: [String] = w.split(separator: "/").map(String.init)
                if parts.count > 1 && parts.allSatisfy({ $0.count >= 3 && $0.allSatisfy({ $0.isLetter }) }) {
                    clause.append(contentsOf: parts)
                    return
                }
            }
            clause.append(w)
        }

        func flushClause() {
            flushWord()
            if !clause.isEmpty { out.append(clause) }
            clause = []
        }

        for ch in sentence {
            if ch.isLetter || ch.isNumber || ch == "+" || ch == "#" {
                word.append(ch)
            } else if ch == "." || ch == "-" || ch == "/" || ch == "&" {
                if word.isEmpty && ch != "." {
                    continue
                }
                word.append(ch)
            } else if clauseBreaks.contains(ch) {
                flushClause()
            } else {
                flushWord()
            }
        }
        flushClause()
        return out
    }

    // MARK: Normalising

    /// Lowercase, without accents or width differences.
    static func fold(_ value: String) -> String {
        return value.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil).lowercased()
    }

    /// True for words worth comparing: they have a letter, are not a bare number or a web address.
    static func isMeaningful(_ folded: String) -> Bool {
        guard folded.count <= 40 else { return false }
        guard folded.contains(where: { $0.isLetter }) else { return false }
        if folded.hasPrefix("www.") || folded.hasPrefix("http") { return false }
        if folded.count < 2 { return false }
        if folded.count == 2 && !folded.contains(where: { $0 == "+" || $0 == "#" }) {
            // Two letter words are mostly noise, apart from upper case acronyms handled by the caller's spelling.
            return twoLetterTerms.contains(folded)
        }
        return true
    }

    /// Light stemming so "designs", "designed" and "designing" compare as one word.
    /// Words with digits or symbols ("C++", "Node.js", "S3") are left alone.
    static func stemKey(_ folded: String) -> String {
        var w: String = folded.replacingOccurrences(of: "-", with: "")
        guard w.allSatisfy({ $0.isLetter }) else { return w }
        guard w.count > 3 else { return w }

        func dropSuffix(_ count: Int) { w = String(w.dropLast(count)) }

        if w.hasSuffix("ies") && w.count > 4 {
            dropSuffix(3)
            w += "y"
            return w
        }
        if w.hasSuffix("ing") && w.count > 5 {
            dropSuffix(3)
            undoubleConsonant(&w)
        } else if w.hasSuffix("ed") && w.count > 5 {
            dropSuffix(2)
            undoubleConsonant(&w)
        } else if w.hasSuffix("es") && w.count > 4 && (w.dropLast(2).hasSuffix("s") || w.dropLast(2).hasSuffix("x")
                    || w.dropLast(2).hasSuffix("z") || w.dropLast(2).hasSuffix("ch") || w.dropLast(2).hasSuffix("sh")) {
            dropSuffix(2)
        } else if w.hasSuffix("s") && !w.hasSuffix("ss") && !w.hasSuffix("us") && !w.hasSuffix("is") {
            dropSuffix(1)
        }
        if w.hasSuffix("e") && w.count > 3 {
            dropSuffix(1)
        }
        return w
    }

    private static func undoubleConsonant(_ w: inout String) {
        let chars: [Character] = Array(w)
        guard chars.count >= 3 else { return }
        let last: Character = chars[chars.count - 1]
        let before: Character = chars[chars.count - 2]
        let keep: Set<Character> = ["s", "l", "z", "f"]
        if last == before && !"aeiou".contains(last) && !keep.contains(last) {
            w.removeLast()
        }
    }

    // MARK: Word lists

    private static func foldedSet(_ words: [String]) -> Set<String> {
        return Set(words.map { fold($0) })
    }

    private static let twoLetterTerms: Set<String> = ["ai", "ml", "ui", "ux", "qa", "hr", "pr", "bi", "ar", "vr", "ci", "cd", "3d", "2d"]

    static let stopWords: Set<String> = foldedSet([
        // English
        "a", "about", "above", "after", "again", "against", "all", "also", "am", "an", "and", "and/or", "any", "are", "as", "at",
        "be", "because", "been", "before", "being", "below", "between", "both", "but", "by", "can", "could", "did", "do", "does",
        "doing", "don", "doesn", "isn", "won", "ll", "ve", "re", "down", "during", "each", "e.g", "eg", "i.e", "ie", "etc", "few",
        "for", "from", "further", "had", "has", "have", "having", "he", "her", "here", "hers", "him", "his", "how", "i", "if",
        "in", "into", "is", "it", "its", "itself", "just", "me", "more", "most", "my", "no", "nor", "not", "of", "off", "on",
        "once", "only", "or", "other", "our", "ours", "ourselves", "out", "over", "own", "same", "she", "should", "so", "some",
        "such", "than", "that", "the", "their", "theirs", "them", "then", "there", "these", "they", "this", "those", "through",
        "to", "too", "under", "until", "up", "very", "was", "we", "were", "what", "when", "where", "which", "while", "who",
        "whom", "why", "will", "with", "would", "you", "your", "yours", "yourself", "us", "via", "per", "within", "without",
        "across", "around", "among", "upon", "may", "might", "must", "shall", "able", "every", "many", "much", "less", "least",
        "like", "including", "include", "includes", "plus", "along", "well", "really", "always", "often", "least", "toward",
        "towards", "whether", "yet", "however", "therefore", "thus", "who", "whose", "one", "two", "three", "four", "five",
        // Spanish
        "el", "la", "los", "las", "un", "una", "unos", "unas", "y", "o", "de", "del", "al", "en", "con", "por", "para", "que",
        "se", "su", "sus", "es", "son", "como", "mas", "pero", "lo", "le", "les", "nos", "muy", "sin", "sobre", "entre", "tu",
        "tus", "este", "esta", "estos", "estas", "ser", "estar",
        // Portuguese
        "os", "as", "um", "uma", "uns", "umas", "e", "do", "da", "dos", "das", "no", "na", "nos", "nas", "em", "com", "por",
        "para", "que", "seu", "sua", "seus", "suas", "ao", "aos", "mais", "mas", "ou", "voce",
        // German
        "der", "die", "das", "den", "dem", "des", "ein", "eine", "einen", "einem", "einer", "und", "oder", "mit", "von", "zu",
        "zum", "zur", "im", "ins", "auf", "fur", "ist", "sind", "wir", "sie", "ihr", "ihre", "bei", "aus", "als", "auch", "nicht",
        "sowie", "uber", "unter", "nach", "wie",
        // French
        "le", "les", "une", "des", "et", "ou", "du", "au", "aux", "en", "dans", "avec", "pour", "par", "sur", "que", "qui",
        "est", "sont", "vous", "nous", "votre", "vos", "notre", "nos", "ce", "cette", "ces", "son", "sa", "ses", "pas", "plus"
    ])

    /// Words that appear in almost every ad and say nothing about the role.
    static let genericWords: Set<String> = foldedSet([
        "experience", "experienc", "work", "working", "team", "teams", "ability", "abilities", "role", "roles", "candidate",
        "candidates", "position", "positions", "company", "companies", "job", "jobs", "year", "years", "strong", "excellent",
        "skill", "skills", "knowledge", "requirement", "requirements", "required", "require", "preferred", "prefer", "ideal",
        "ideally", "looking", "join", "joining", "opportunity", "opportunities", "responsibility", "responsibilities",
        "responsible", "new", "good", "great", "highly", "related", "relevant", "field", "environment", "including", "use",
        "using", "used", "make", "help", "helping", "ensure", "ensuring", "based", "level", "minimum", "least", "proven",
        "demonstrated", "solid", "hands", "day", "days", "part", "fulltime", "parttime",
        "person", "someone", "who", "want", "need", "needs", "seeking", "seek", "apply", "applicant", "applicants", "please",
        "send", "resume", "cv", "plus", "bonus", "nice", "have", "must", "should", "will", "can", "get", "take", "within",
        "other", "others", "various", "multiple", "several", "key", "main", "successful", "success", "proficient",
        "proficiency", "familiar", "familiarity", "understanding", "background", "equivalent", "similar", "etc", "e.g",
        "best", "fast-paced", "self", "level", "mid", "world", "work", "deliver", "provide", "providing", "ensure",
        // es / pt / de / fr generic
        "experiencia", "experiencia", "anos", "empresa", "trabajo", "equipo", "trabalho", "equipe", "conhecimento",
        "conocimiento", "erfahrung", "jahre", "team", "unternehmen", "kenntnisse", "experience", "ans", "entreprise",
        "equipe", "poste", "connaissance", "connaissances"
    ])

    private static let requirementCues: [String] = [
        "required", "requirement", "must ", "must-have", "should have", "you have", "you bring", "you will", "you'll",
        "experience with", "experience in", "proficien", "knowledge of", "familiar", "ability to", "able to",
        "degree", "years of", "qualification", "skills in", "expert", "hands-on", "strong ", "responsib",
        "requisito", "experiencia en", "conhecimento", "experiencia com", "kenntnisse", "erfahrung", "exige",
        "maitrise", "competence", "experience en"
    ]

    private static let requirementHeaders: [String] = [
        "requirement", "qualification", "what you", "you have", "you bring", "you will", "skills", "responsibilit",
        "about the role", "the role", "must have", "nice to have", "looking for", "your profile", "what we need",
        "key duties", "duties", "requisitos", "perfil", "anforderungen", "ihr profil", "aufgaben", "profil recherche",
        "exigences", "competences", "missions", "responsabilidades"
    ]

    private static let boilerplateHeaders: [String] = [
        "benefit", "perks", "what we offer", "we offer", "about us", "about the company", "who we are", "our company",
        "equal opportunit", "compensation", "salary", "why join", "why you'll love", "how to apply", "our values",
        "beneficios", "ofrecemos", "oferecemos", "wir bieten", "uber uns", "avantages", "nous offrons", "a propos"
    ]

    private static let boilerplatePhrases: [String] = [
        "equal opportunity", "equal employment", "affirmative action", "without regard to", "race", "religion",
        "national origin", "sexual orientation", "gender identity", "veteran", "disability", "reasonable accommodation",
        "background check", "drug test", "health insurance", "dental", "vision insurance", "401k", "401(k)", "paid time off",
        "pto", "parental leave", "stock options", "salary range", "competitive salary", "compensation", "apply now",
        "click apply", "submit your", "cover letter", "privacy notice", "recruitment agenc", "visa sponsorship",
        "igualdad de oportunidades", "igualdade de oportunidades", "chancengleichheit", "egalite des chances"
    ]

    private static let commonPhrases: [String] = [
        "project management", "product management", "machine learning", "data analysis", "customer service",
        "software development", "software engineering", "business development", "supply chain", "quality assurance",
        "user research", "user experience", "account management", "financial analysis", "financial reporting",
        "data science", "deep learning", "social media", "content marketing", "digital marketing",
        "stakeholder management", "change management", "risk management", "problem solving", "time management",
        "patient care", "unit testing", "version control", "cloud computing", "computer science", "power bi",
        "google analytics", "front end", "back end", "full stack", "public speaking", "sales management",
        "team leadership", "people management", "inventory management", "event planning", "graphic design",
        "web development", "mobile development", "continuous integration", "test automation", "data visualization",
        "data engineering", "information security", "technical support", "accounts payable", "accounts receivable",
        "process improvement", "budget management", "vendor management", "lead generation", "case management"
    ]

    private static let commonPhraseKeys: Set<String> = {
        var out: Set<String> = []
        for phrase in commonPhrases {
            let words: [String] = phrase.split(separator: " ").map { stemKey(fold(String($0))) }
            out.insert(words.joined(separator: " "))
        }
        return out
    }()

    private static let certificationHints: [String] = ["certif", "license", "licence", "pmp", "cpa", "cfa", "cissp", "scrum master", "prince2", "itil", "acca"]
    private static let degreeHints: [String] = ["degree", "bachelor", "master's", "masters", "mba", "phd", "doctorate", "diploma", "bsc", "msc", "licenciatura", "graduacao", "studium"]
    private static let softSkillPrefixes: [String] = [
        "communicat", "leader", "collaborat", "teamwork", "interpersonal", "adaptab", "flexib", "creativ", "problem solv",
        "organiz", "organis", "attention to detail", "detail", "motivat", "proactive", "self-start", "empath", "initiative",
        "critical thinking", "time management", "customer focus", "ownership", "curious", "curiosity", "resilien"
    ]
}

/// Words and two-word phrases of a resume, keyed the same way as job ad terms.
struct JobMatchResumeIndex {
    private(set) var stems: Set<String> = []
    private(set) var pairs: Set<String> = []
    private(set) var joinedPairs: Set<String> = []

    init(text: String) {
        let normalised: String = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        for line in normalised.components(separatedBy: "\n") {
            for clause in JobMatchAnalyzer.clauses(in: line) {
                var previous: String? = nil
                for raw in clause {
                    let folded: String = JobMatchAnalyzer.fold(raw)
                    guard folded.contains(where: { $0.isLetter || $0.isNumber }) else {
                        previous = nil
                        continue
                    }
                    let key: String = JobMatchAnalyzer.stemKey(folded)
                    stems.insert(key)
                    if JobMatchAnalyzer.stopWords.contains(folded) {
                        previous = nil
                        continue
                    }
                    if let p = previous {
                        pairs.insert(p + " " + key)
                        joinedPairs.insert(p + key)
                    }
                    previous = key
                }
            }
        }
    }

    func contains(_ keyword: JobMatchKeyword) -> Bool {
        if keyword.isPhrase {
            if pairs.contains(keyword.key) { return true }
            // "cross functional" in the ad, "cross-functional" in the resume.
            return stems.contains(keyword.key.replacingOccurrences(of: " ", with: ""))
        }
        return stems.contains(keyword.key) || joinedPairs.contains(keyword.key)
    }
}
