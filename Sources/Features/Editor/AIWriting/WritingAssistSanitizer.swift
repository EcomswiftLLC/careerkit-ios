import Foundation

/// Cleans the model's raw output and refuses anything that is not safe to offer.
/// Pure and deterministic so every rule is covered by unit tests.
enum WritingAssistSanitizer {
    /// A suggestion may be at most this many times longer than the text it came from.
    static let growthFactor = 3
    /// Very short inputs still get some room (a two-word bullet can become a short sentence).
    static let minimumAllowance = 60

    static func clean(_ raw: String,
                      original: String,
                      context: String = "",
                      mode: WritingAssistMode) -> Result<String, WritingAssistFailure> {
        let source = normalizedNewlines(original)
        var lines = normalizedNewlines(raw).components(separatedBy: "\n")
        lines = lines.filter { !isFence($0) }
        lines = dropLeadingChatter(lines)
        lines = dropTrailingChatter(lines)

        // Quotes wrapped around the whole answer.
        var whole = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        whole = stripWrappingQuotes(whole, original: source)

        let keepNumbering = usesNumberedLines(source)
        var cleaned: [String] = []
        for line in whole.components(separatedBy: "\n") {
            let tidy = cleanLine(line, original: source, keepNumbering: keepNumbering)
            if !tidy.isEmpty { cleaned.append(tidy) }
        }
        let text = cleaned.joined(separator: "\n")

        guard !text.isEmpty else { return .failure(.emptySuggestion) }

        let reference = mode.usesContextAsSource ? context : original
        let referenceCount = reference.trimmingCharacters(in: .whitespacesAndNewlines).count
        let limit = max(referenceCount * growthFactor, minimumAllowance)
        guard text.count <= limit else { return .failure(.suggestionTooLong) }

        // Numbers are facts. Any number the model brings in that the person did not write is rejected.
        let allowed = mode.usesContextAsSource ? original + "\n" + context : original
        guard introducedNumbers(in: text, comparedWith: allowed).isEmpty else { return .failure(.addedDetails) }

        return .success(text)
    }

    // MARK: Number guard

    /// Runs of digits, in any script ("2019", "30", "1" and "200" from "1,200").
    static func numberTokens(in text: String) -> Set<String> {
        var tokens = Set<String>()
        var current = ""
        for character in text {
            if character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                tokens.insert(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.insert(current) }
        return tokens
    }

    static func introducedNumbers(in suggestion: String, comparedWith source: String) -> Set<String> {
        numberTokens(in: suggestion).subtracting(numberTokens(in: source))
    }

    // MARK: Lines

    static func normalizedNewlines(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    static func isFence(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("```") || trimmed == "\"\"\"" || trimmed == "---"
    }

    private static let openers = ["here is", "here's", "here\u{2019}s", "here are", "sure", "certainly", "of course", "okay", "absolutely"]
    private static let labelWords = ["rewritten", "revised", "improved", "shorter", "corrected", "suggest", "summary", "version", "bullet", "text", "result", "output"]
    private static let closers = ["let me know", "i hope", "feel free", "note:", "this version", "i kept", "i have kept", "i've kept", "i removed", "i changed", "i made"]

    /// "Here is the improved text:", "Sure! ...", "Revised version:" at the top.
    static func isLeadingChatter(_ line: String) -> Bool {
        let lower = line.trimmingCharacters(in: .whitespaces).lowercased()
        guard !lower.isEmpty else { return false }
        if openers.contains(where: { hasWordPrefix(lower, $0) }) { return true }
        if lower.hasSuffix(":") && lower.count <= 60 {
            return labelWords.contains(where: { lower.contains($0) })
        }
        return false
    }

    static func dropLeadingChatter(_ input: [String]) -> [String] {
        var lines = input
        for _ in 0..<2 {
            guard let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
                  isLeadingChatter(lines[first]) else { break }
            let line = lines[first]
            // "Here is the text: Led a team of ..." keeps what follows the colon.
            if let colon = line.firstIndex(of: ":") {
                let rest = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty {
                    lines[first] = rest
                    break
                }
            }
            let hasMore = lines[(first + 1)...].contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            guard hasMore else { break }
            lines.remove(at: first)
        }
        return lines
    }

    static func dropTrailingChatter(_ input: [String]) -> [String] {
        var lines = input
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard nonEmpty.count > 1,
              let last = lines.lastIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return lines }
        let lower = lines[last].trimmingCharacters(in: .whitespaces).lowercased()
        if closers.contains(where: { lower.hasPrefix($0) }) || lower.hasPrefix("(note") {
            lines.remove(at: last)
        }
        return lines
    }

    // MARK: One line

    private static let spacedMarkers: [String] = ["-", "*", "+", "\u{2013}", "\u{2014}"]
    private static let symbolMarkers: [Character] = ["\u{2022}", "\u{00B7}", "\u{25AA}", "\u{2023}", "\u{25E6}", "\u{25CF}", "\u{25CB}", "\u{25BA}", "\u{2713}", "\u{2714}"]

    static func cleanLine(_ line: String, original: String, keepNumbering: Bool) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        text = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
        if !original.contains("`") { text = text.replacingOccurrences(of: "`", with: "") }
        text = stripHeading(text)
        for _ in 0..<3 {
            let before = text
            text = stripWrappingQuotes(text, original: original)
            text = stripBulletMarker(text)
            if !keepNumbering { text = stripNumbering(text) }
            text = text.trimmingCharacters(in: .whitespaces)
            if text == before { break }
        }
        return text
    }

    static func stripHeading(_ text: String) -> String {
        guard text.hasPrefix("#") else { return text }
        let rest = text.drop(while: { $0 == "#" })
        guard rest.first == " " else { return text }
        return rest.trimmingCharacters(in: .whitespaces)
    }

    static func stripBulletMarker(_ text: String) -> String {
        for marker in spacedMarkers where text.hasPrefix(marker + " ") {
            return String(text.dropFirst(marker.count + 1))
        }
        if let first = text.first, symbolMarkers.contains(first) {
            return String(text.dropFirst())
        }
        return text
    }

    /// "1. ", "2) " and "(3) " at the start of a line.
    static func stripNumbering(_ text: String) -> String {
        var rest = Substring(text)
        let hasParen = rest.first == "("
        if hasParen { rest = rest.dropFirst() }
        let digits = rest.prefix(while: { $0.isASCII && $0.isNumber })
        guard !digits.isEmpty, digits.count <= 2 else { return text }
        rest = rest.dropFirst(digits.count)
        guard let mark = rest.first, mark == "." || mark == ")" else { return text }
        if hasParen && mark != ")" { return text }
        rest = rest.dropFirst()
        guard rest.first == " " else { return text }
        return rest.trimmingCharacters(in: .whitespaces)
    }

    /// True when the person's own lines start with "1." style numbers, so they are kept.
    static func usesNumberedLines(_ original: String) -> Bool {
        original.components(separatedBy: "\n").contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && stripNumbering(trimmed) != trimmed
        }
    }

    private static let quotePairs: [(Character, Character)] = [
        ("\"", "\""), ("\u{201C}", "\u{201D}"), ("\u{201E}", "\u{201C}"),
        ("\u{00AB}", "\u{00BB}"), ("'", "'"), ("\u{2018}", "\u{2019}")
    ]

    /// Removes one pair of quotes around the text, unless the person's own text starts with that quote.
    static func stripWrappingQuotes(_ text: String, original: String) -> String {
        guard text.count >= 2, let first = text.first, let last = text.last else { return text }
        let originalStart = original.trimmingCharacters(in: .whitespacesAndNewlines).first
        for (open, close) in quotePairs where first == open && last == close {
            if originalStart == open { return text }
            return String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return text
    }

    private static func hasWordPrefix(_ text: String, _ word: String) -> Bool {
        guard text.hasPrefix(word) else { return false }
        guard let next = text.dropFirst(word.count).first else { return true }
        return !next.isLetter
    }
}
