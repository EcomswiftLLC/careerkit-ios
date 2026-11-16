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
        let count: Int = matched.count
        let total: Int = totalKeyTerms
        return String(localized: "You cover \(count) of \(total) key terms from this job ad.",
                      comment: "Job ad comparison result. First number: terms found in the resume. Second: terms compared.")
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
        let resume: String = String(resumeText.prefix(200_000))
        // The ad decides the language, so the ad and the resume are cut into words the same way.
        let language: TextLanguage = detectLanguage(job: job, resume: resume)
        let terms: [JobMatchKeyword] = keyTerms(in: job, language: language)
        let index = JobMatchResumeIndex(text: resume, language: language)

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

    /// Language of the ad; a very short ad falls back to the language of the resume.
    static func detectLanguage(job: String, resume: String) -> TextLanguage {
        let letters: Int = job.prefix(4000).filter { $0.isLetter }.count
        if letters < 12 && !CJKText.containsCJK(job) {
            return TextLanguage.detect(resume)
        }
        return TextLanguage.detect(job)
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
        return keyTerms(in: text, language: TextLanguage.detect(text))
    }

    /// Key terms of a job ad written in `language`.
    static func keyTerms(in text: String, language: TextLanguage) -> [JobMatchKeyword] {
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
                    guard isMeaningful(folded), !isStopWord(folded, language: language),
                          !isGenericWord(folded, language: language) else {
                        previousKey = nil
                        previousDisplay = nil
                        continue
                    }
                    let key: String = stemKey(folded, language: language)
                    guard !key.isEmpty, !isGenericWord(key, language: language) else {
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
            // Chinese and Japanese ads use a full-width colon after labels such as "任职要求".
            var line: String = rawLine.replacingOccurrences(of: "\u{FF1A}", with: ":")
                .trimmingCharacters(in: .whitespaces)
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
            // Text without spaces counts as one word per two characters, so a Chinese sentence is not read as a header.
            let wordCount: Int = CJKText.wordCount(lower)

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
            } else if ch == "\u{3002}" || ch == "\u{FF01}" || ch == "\u{FF1F}" || ch == "\u{FF1B}" || ch == "\u{FF0E}" {
                // Chinese and Japanese sentence ends: 。！？；．
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

    private static let clauseBreaks: Set<Character> = [",", ":", "(", ")", "[", "]", "{", "}", "\"", "\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}", "'", "|", "\u{2013}", "\u{2014}", "!", "?", ";", "\u{2022}", "\u{00B7}", "<", ">", "=", "*", "~", "^", "%", "$", "\u{20AC}", "\u{00A3}", "@",
        // Chinese and Japanese punctuation: ，、：；（）《》【】「」『』。！？～
        "\u{FF0C}", "\u{3001}", "\u{FF1A}", "\u{FF1B}", "\u{FF08}", "\u{FF09}", "\u{300A}", "\u{300B}", "\u{3010}", "\u{3011}",
        "\u{300C}", "\u{300D}", "\u{300E}", "\u{300F}", "\u{3002}", "\u{FF01}", "\u{FF1F}", "\u{FF5E}", "\u{00AB}", "\u{00BB}"]

    /// Words of a sentence, grouped into clauses. Phrases are only built inside one clause.
    /// Letters, digits, "+" and "#" make words; ".", "-", "/" and "&" are kept inside a word ("Node.js", "CI/CD").
    /// Chinese and Japanese runs have no spaces, so they are split into words with NLTokenizer.
    static func clauses(in sentence: String) -> [[String]] {
        var out: [[String]] = []
        var clause: [String] = []
        var word: String = ""
        var segmenter: CJKSegmenter? = nil

        func appendCJK(_ w: String) {
            if segmenter == nil { segmenter = CJKSegmenter() }
            guard let splitter = segmenter else { return }
            for token in splitter.split(w) {
                let trimmed: String = token.trimmingCharacters(in: CharacterSet.whitespaces)
                if trimmed.contains(where: { $0.isLetter || $0.isNumber }) {
                    clause.append(trimmed)
                }
            }
        }

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
            if CJKText.containsCJK(w) {
                appendCJK(w)
                return
            }
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
        // Chinese and Japanese words are often two characters long; single characters are mostly particles.
        if CJKText.containsCJK(folded) { return folded.count <= 16 }
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

    /// Light stemming for the language of the ad. English and languages without their own rules use `stemKey(_:)`.
    /// Spanish, French and German fold plurals and common feminine forms; Chinese and Japanese words are kept whole.
    static func stemKey(_ folded: String, language: TextLanguage) -> String {
        if CJKText.containsCJK(folded) { return folded }
        switch language {
        case .english, .chinese, .japanese:
            return stemKey(folded)
        case .spanish:
            return stemSpanish(folded)
        case .french:
            return stemFrench(folded)
        case .german:
            return stemGerman(folded)
        }
    }

    /// "desarrolladores", "desarrolladora" and "desarrollador" compare as one word; so do "proyectos" and "proyecto".
    static func stemSpanish(_ folded: String) -> String {
        var w: String = folded.replacingOccurrences(of: "-", with: "")
        guard w.allSatisfy({ $0.isLetter }), w.count > 3 else { return w }
        if w.hasSuffix("ces") && w.count > 4 {
            w = String(w.dropLast(3)) + "z"
        } else if w.hasSuffix("es") && w.count > 4, let before = w.dropLast(2).last, "lrndzj".contains(before) {
            w = String(w.dropLast(2))
        } else if w.hasSuffix("s") && !w.hasSuffix("ss") && !w.hasSuffix("is") && !w.hasSuffix("us") {
            w = String(w.dropLast())
        }
        if (w.hasSuffix("a") || w.hasSuffix("o")) && w.count > 4 {
            w = String(w.dropLast())
        }
        return w
    }

    /// "développeurs", "développeuse" and "développeur" compare as one word; so do "compétences" and "compétence".
    static func stemFrench(_ folded: String) -> String {
        var w: String = folded.replacingOccurrences(of: "-", with: "")
        guard w.allSatisfy({ $0.isLetter }), w.count > 3 else { return w }
        if w.hasSuffix("aux") && w.count > 4 {
            w = String(w.dropLast(3)) + "al"
        } else if (w.hasSuffix("s") || w.hasSuffix("x")) && !w.hasSuffix("ss") && !w.hasSuffix("is") && !w.hasSuffix("us") {
            w = String(w.dropLast())
        }
        if w.hasSuffix("euse") && w.count > 5 {
            w = String(w.dropLast(4)) + "eur"
        } else if w.hasSuffix("trice") && w.count > 6 {
            w = String(w.dropLast(5)) + "teur"
        }
        if w.hasSuffix("e") && w.count > 4 {
            w = String(w.dropLast())
        }
        return w
    }

    /// "Lösungen" and "Lösung", "Kunden" and "Kunde", "Kenntnisse" and "Kenntnis" compare as one word.
    static func stemGerman(_ folded: String) -> String {
        var w: String = folded.replacingOccurrences(of: "-", with: "")
        guard w.allSatisfy({ $0.isLetter }), w.count > 3 else { return w }
        if w.hasSuffix("innen") && w.count > 6 {
            w = String(w.dropLast(3))
        } else if w.hasSuffix("nisse") {
            w = String(w.dropLast(2))
        } else if w.hasSuffix("en") && w.count > 5 {
            w = String(w.dropLast(2))
        } else if w.hasSuffix("e") && w.count > 4 {
            w = String(w.dropLast())
        } else if w.hasSuffix("s") && w.count > 4 && !w.hasSuffix("ss") && !w.hasSuffix("nis") {
            w = String(w.dropLast())
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
        "est", "sont", "vous", "nous", "votre", "vos", "notre", "nos", "ce", "cette", "ces", "son", "sa", "ses", "pas", "plus",
        // Chinese and Japanese function words. They cannot collide with Latin words, so they apply in every language.
        "的", "了", "和", "与", "及", "或", "在", "是", "有", "为", "对", "等", "我们", "你", "您", "他们", "以及", "并",
        "并且", "或者", "能够", "可以", "具有", "进行", "通过", "根据", "以上", "以下", "及其", "一个", "一定", "各种",
        "如果", "我们的", "欢迎", "加入", "其他", "方面", "以及其他", "之一", "这些", "那些", "如何", "什么", "需要",
        "の", "に", "は", "を", "が", "で", "と", "も", "や", "から", "まで", "など", "こと", "もの", "ため", "および",
        "または", "できる", "ある", "いる", "する", "します", "ください"
    ])

    /// Extra function words for one language. Kept apart from `stopWords` so that, for example, a German
    /// article never hides an English term in an English ad.
    private static let languageStopWords: [TextLanguage: Set<String>] = [
        .spanish: foldedSet([
            "a", "ante", "bajo", "contra", "desde", "durante", "hacia", "hasta", "mediante", "segun", "tras",
            "nuestro", "nuestra", "nuestros", "nuestras", "usted", "ustedes", "ellos", "ellas", "yo", "mi", "mis",
            "te", "ti", "nosotros", "ese", "esa", "esos", "esas", "aquel", "esto", "eso", "cual", "cuales", "quien",
            "quienes", "donde", "cuando", "tambien", "ya", "si", "asi", "aunque", "porque", "pues", "hay", "ha",
            "han", "has", "he", "hemos", "fue", "fueron", "sera", "seran", "sea", "sean", "tiene", "tienen", "tener",
            "puede", "pueden", "poder", "debe", "deben", "menos", "otro", "otra", "otros", "otras", "todo", "toda",
            "todos", "todas", "cada", "algun", "alguna", "algunos", "algunas", "ningun", "ninguna", "mismo",
            "misma", "tan", "tanto", "bien", "solo", "sino", "ni", "buscamos", "busca", "ofrecemos", "valoramos",
            "incorporar", "forma", "parte", "etc", "seras", "tendras", "haras", "unete", "contar"
        ]),
        .french: foldedSet([
            "a", "ce", "cet", "elle", "elles", "eux", "il", "ils", "je", "la", "leur", "leurs", "lui", "ma", "mais",
            "me", "meme", "mes", "moi", "mon", "ne", "ni", "on", "qu", "se", "ta", "te", "tes", "toi", "ton", "tu",
            "un", "y", "aussi", "sans", "sous", "chez", "entre", "vers", "depuis", "pendant", "comme", "dont",
            "tres", "moins", "bien", "tout", "toute", "tous", "toutes", "chaque", "autre", "autres", "etre", "avoir",
            "sera", "seront", "etait", "ete", "fait", "faire", "peut", "peuvent", "doit", "doivent", "recherchons",
            "recherche", "rejoindre", "rejoignez", "sein", "afin", "ainsi", "cadre", "notamment", "egalement", "etc",
            "serez", "aurez", "avez", "etes", "votre", "nos", "selon", "lors", "dès", "des"
        ]),
        .german: foldedSet([
            "aber", "alle", "allem", "allen", "aller", "alles", "also", "am", "an", "andere", "anderen", "bin", "bis",
            "bist", "da", "damit", "dann", "dass", "dein", "deine", "dessen", "dies", "diese", "diesem", "diesen",
            "dieser", "dieses", "doch", "dort", "du", "durch", "eines", "er", "es", "euch", "euer", "gegen", "hat",
            "haben", "hatte", "hier", "ihm", "ihn", "ihnen", "ihrem", "ihren", "ihrer", "in", "ja", "jede", "jedem",
            "jeden", "jeder", "jedes", "kann", "konnen", "mochten", "muss", "mussen", "noch", "nur", "ob", "ohne",
            "sehr", "sein", "seine", "sich", "so", "sollte", "sollten", "um", "uns", "unser", "unsere", "unseren",
            "unserem", "vom", "vor", "wann", "was", "weil", "wenn", "wer", "werden", "wird", "wo", "zwischen",
            "suchen", "bieten", "freuen", "gerne", "bzw", "ca", "sowohl", "bereits", "ab", "sofort", "einen", "deren"
        ])
    ]

    static func isStopWord(_ folded: String, language: TextLanguage) -> Bool {
        if stopWords.contains(folded) { return true }
        return languageStopWords[language]?.contains(folded) ?? false
    }

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
        "closely", "effectively", "directly", "strongly", "actively", "proactively", "regularly", "independently",
        // es / pt / de / fr generic
        "experiencia", "experiencia", "anos", "empresa", "trabajo", "equipo", "trabalho", "equipe", "conhecimento",
        "conocimiento", "erfahrung", "jahre", "team", "unternehmen", "kenntnisse", "experience", "ans", "entreprise",
        "equipe", "poste", "connaissance", "connaissances",
        // Chinese generic words (they cannot collide with Latin words, so they apply in every language).
        "经验", "工作", "团队", "能力", "岗位", "职位", "职责", "要求", "任职", "任职要求", "岗位职责", "工作职责",
        "岗位要求", "职位要求", "职位描述", "任职资格", "公司", "以上", "优秀", "良好", "较强", "熟悉", "精通", "掌握",
        "了解", "具备", "优先", "候选人", "简历", "薪资", "福利", "专业", "相关", "负责", "参与", "完成", "人员",
        "员工", "年以上", "一年", "两年", "三年", "五年", "工作经验", "相关经验", "以上学历", "有限公司", "内容",
        "経験", "業務", "仕事", "必須", "歓迎", "スキル", "チーム", "会社", "募集", "応募"
    ])

    /// Generic words of one language, folded and stemmed with that language's rules.
    private static let languageGenericWords: [TextLanguage: Set<String>] = {
        let lists: [TextLanguage: [String]] = [
            .spanish: [
                "experiencia", "experiencias", "ano", "anos", "empresa", "empresas", "trabajo", "trabajar", "equipo",
                "equipos", "conocimiento", "conocimientos", "puesto", "puestos", "candidato", "candidata",
                "candidatos", "persona", "personas", "perfil", "requisito", "requisitos", "funcion", "funciones",
                "responsabilidad", "responsabilidades", "nivel", "minimo", "valorable", "imprescindible", "deseable",
                "buen", "buena", "buenos", "buenas", "excelente", "excelentes", "fuerte", "capacidad", "capacidades",
                "habilidad", "habilidades", "oportunidad", "area", "sector", "entorno", "tarea", "tareas", "dia",
                "dias", "jornada", "incorporacion", "contrato", "nuevo", "nueva", "nuevos", "manejo", "dominio",
                "solida", "solido", "demostrable", "relacionado", "relacionada", "similar", "puestos", "vacante"
            ],
            .french: [
                "experience", "experiences", "an", "ans", "annee", "annees", "entreprise", "entreprises", "equipe",
                "equipes", "poste", "postes", "connaissance", "connaissances", "candidat", "candidate", "candidats",
                "profil", "mission", "missions", "competence", "competences", "capacite", "capacites", "niveau",
                "minimum", "bon", "bonne", "bons", "bonnes", "excellent", "excellente", "fort", "forte", "solide",
                "solides", "souhaite", "souhaitee", "apprecie", "appreciee", "requis", "requise", "indispensable",
                "opportunite", "environnement", "secteur", "domaine", "tache", "taches", "jour", "jours", "nouveau",
                "nouvelle", "contrat", "maitrise", "maitriser", "travail", "travailler", "role", "similaire",
                "exige", "exigee", "idealement", "premiere", "confirme", "confirmee"
            ],
            .german: [
                "erfahrung", "erfahrungen", "jahr", "jahre", "jahren", "unternehmen", "team", "teams", "kenntnis",
                "kenntnisse", "stelle", "position", "aufgabe", "aufgaben", "profil", "anforderung", "anforderungen",
                "bewerber", "bewerberin", "bewerbung", "kandidat", "fahigkeit", "fahigkeiten", "kompetenz",
                "kompetenzen", "gute", "guten", "gutes", "sicher", "sichere", "sicheren", "fundierte", "fundierten",
                "ausgepragte", "ausgepragten", "mehrjahrige", "mehrjahriger", "idealerweise", "wunschenswert",
                "vorteil", "bereich", "umfeld", "tag", "tagen", "neue", "neuen", "vollzeit", "teilzeit",
                "abgeschlossene", "abgeschlossenes", "abgeschlossenen", "arbeit", "arbeiten", "sehr", "starke",
                "idealer", "einschlagige", "einschlagigen", "vergleichbare", "vergleichbaren"
            ]
        ]
        var out: [TextLanguage: Set<String>] = [:]
        for (language, words) in lists {
            var set: Set<String> = []
            for word in words {
                let folded: String = fold(word)
                set.insert(folded)
                set.insert(stemKey(folded, language: language))
            }
            out[language] = set
        }
        return out
    }()

    static func isGenericWord(_ value: String, language: TextLanguage) -> Bool {
        if genericWords.contains(value) { return true }
        return languageGenericWords[language]?.contains(value) ?? false
    }

    private static let requirementCues: [String] = [
        "required", "requirement", "must ", "must-have", "should have", "you have", "you bring", "you will", "you'll",
        "experience with", "experience in", "proficien", "knowledge of", "familiar", "ability to", "able to",
        "degree", "years of", "qualification", "skills in", "expert", "hands-on", "strong ", "responsib",
        "requisito", "experiencia en", "conhecimento", "experiencia com", "kenntnisse", "erfahrung", "exige",
        "maitrise", "competence", "experience en",
        // Spanish, French, German and Chinese
        "se requiere", "imprescindible", "valorable", "conocimientos de", "dominio de", "manejo de", "titulacion",
        "vous avez", "vous maitrisez", "connaissance de", "connaissances en", "experience de", "diplome",
        "est requis", "indispensable", "sie haben", "sie bringen", "kenntnisse in", "erfahrung in", "erfahrung mit",
        "abgeschlossen", "vorausgesetzt", "wunschenswert", "熟悉", "精通", "掌握", "具备", "要求", "经验", "学历",
        "优先", "必須", "経験"
    ]

    private static let requirementHeaders: [String] = [
        "requirement", "qualification", "what you", "you have", "you bring", "you will", "skills", "responsibilit",
        "about the role", "the role", "must have", "nice to have", "looking for", "your profile", "what we need",
        "key duties", "duties", "requisitos", "perfil", "anforderungen", "ihr profil", "aufgaben", "profil recherche",
        "exigences", "competences", "missions", "responsabilidades",
        "lo que buscamos", "que buscamos", "tu perfil", "funciones", "que haras", "votre profil", "vos missions",
        "ce que nous recherchons", "qualifications", "ihre aufgaben", "das bringen sie mit",
        "was sie mitbringen", "qualifikation", "deine aufgaben", "dein profil",
        "任职要求", "岗位要求", "职位要求", "任职资格", "岗位职责", "工作职责", "职位描述", "工作内容", "岗位描述",
        "应聘条件", "必須スキル", "応募資格", "歓迎スキル", "業務内容"
    ]

    private static let boilerplateHeaders: [String] = [
        "benefit", "perks", "what we offer", "we offer", "about us", "about the company", "who we are", "our company",
        "equal opportunit", "compensation", "salary", "why join", "why you'll love", "how to apply", "our values",
        "beneficios", "ofrecemos", "oferecemos", "wir bieten", "uber uns", "avantages", "nous offrons", "a propos",
        "que ofrecemos", "sobre nosotros", "quienes somos", "ce que nous offrons", "qui sommes-nous", "nos avantages",
        "was wir bieten", "unser angebot", "das bieten wir", "福利待遇", "福利", "公司介绍", "公司简介", "关于我们",
        "我们提供", "薪资待遇", "薪酬福利", "待遇", "会社概要", "待遇・福利厚生", "福利厚生", "給与"
    ]

    private static let boilerplatePhrases: [String] = [
        "equal opportunity", "equal employment", "affirmative action", "without regard to", "race", "religion",
        "national origin", "sexual orientation", "gender identity", "veteran", "disability", "reasonable accommodation",
        "background check", "drug test", "health insurance", "dental", "vision insurance", "401k", "401(k)", "paid time off",
        "pto", "parental leave", "stock options", "salary range", "competitive salary", "compensation", "apply now",
        "click apply", "submit your", "cover letter", "privacy notice", "recruitment agenc", "visa sponsorship",
        "igualdad de oportunidades", "igualdade de oportunidades", "chancengleichheit", "egalite des chances",
        "salario competitivo", "seguro medico", "salaire attractif", "mutuelle", "tickets restaurant",
        "betriebliche altersvorsorge", "urlaubstage", "attraktives gehalt", "五险一金", "带薪年假", "年终奖",
        "社会保険完備", "交通費支給"
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

    private static let certificationHints: [String] = ["certif", "license", "licence", "pmp", "cpa", "cfa", "cissp", "scrum master", "prince2", "itil", "acca",
                                                       "zertifi", "证书", "认证", "资格证", "資格"]
    private static let degreeHints: [String] = ["degree", "bachelor", "master's", "masters", "mba", "phd", "doctorate", "diploma", "bsc", "msc", "licenciatura", "graduacao", "studium",
                                                "titulo universitario", "grado en", "maestria", "diplome", "abschluss", "hochschul",
                                                "学历", "本科", "硕士", "博士", "学位", "大学", "学士", "修士"]
    private static let softSkillPrefixes: [String] = [
        "communicat", "leader", "collaborat", "teamwork", "interpersonal", "adaptab", "flexib", "creativ", "problem solv",
        "organiz", "organis", "attention to detail", "detail", "motivat", "proactive", "self-start", "empath", "initiative",
        "critical thinking", "time management", "customer focus", "ownership", "curious", "curiosity", "resilien",
        "comunicacion", "liderazgo", "trabajo en equipo", "proactiv", "organizacion", "esprit d'equipe", "rigueur",
        "autonomie", "kommunikation", "teamfahig", "belastbar", "zuverlassig", "selbststandig", "eigeninitiative",
        "沟通", "团队合作", "领导", "责任心", "学习能力", "抗压", "コミュニケーション"
    ]
}

/// Words and two-word phrases of a resume, keyed the same way as job ad terms.
struct JobMatchResumeIndex {
    private(set) var stems: Set<String> = []
    private(set) var pairs: Set<String> = []
    private(set) var joinedPairs: Set<String> = []
    /// Folded resume text without spaces, kept only when the resume has Chinese or Japanese text.
    /// Words of those languages are also matched as plain substrings, because a word can be segmented
    /// differently in the ad and in the resume.
    private(set) var cjkText: String = ""
    let language: TextLanguage

    init(text: String, language: TextLanguage = .english) {
        self.language = language
        let normalised: String = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if CJKText.containsCJK(normalised) {
            cjkText = JobMatchAnalyzer.fold(normalised).filter { !$0.isWhitespace }
        }
        for line in normalised.components(separatedBy: "\n") {
            for clause in JobMatchAnalyzer.clauses(in: line) {
                var previous: String? = nil
                for raw in clause {
                    let folded: String = JobMatchAnalyzer.fold(raw)
                    guard folded.contains(where: { $0.isLetter || $0.isNumber }) else {
                        previous = nil
                        continue
                    }
                    let key: String = JobMatchAnalyzer.stemKey(folded, language: language)
                    stems.insert(key)
                    if JobMatchAnalyzer.isStopWord(folded, language: language) {
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
        if !cjkText.isEmpty && CJKText.containsCJK(keyword.key) {
            let flat: String = keyword.key.filter { !$0.isWhitespace }
            if !flat.isEmpty && cjkText.contains(flat) { return true }
        }
        if keyword.isPhrase {
            if pairs.contains(keyword.key) { return true }
            // "cross functional" in the ad, "cross-functional" in the resume.
            return stems.contains(keyword.key.replacingOccurrences(of: " ", with: ""))
        }
        return stems.contains(keyword.key) || joinedPairs.contains(keyword.key)
    }
}
