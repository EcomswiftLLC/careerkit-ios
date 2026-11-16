import Foundation
import NaturalLanguage

// Small language helpers shared by the job ad comparison, the ATS checks and the resume importer.
// Everything runs on the device with Apple's NaturalLanguage framework; nothing is sent anywhere.

/// Characters of scripts that are written without spaces between words (Chinese and Japanese).
enum CJKText {
    static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2A6DF, 0x2A700...0x2EBEF:
            return true
        default:
            return false
        }
    }

    static func isKana(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x309F, 0x30A0...0x30FF, 0x31F0...0x31FF, 0xFF66...0xFF9D:
            return true
        default:
            return false
        }
    }

    static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        return isHan(scalar) || isKana(scalar)
    }

    static func containsCJK(_ text: String) -> Bool {
        return text.unicodeScalars.contains(where: { isCJK($0) })
    }

    static func containsKana(_ text: String) -> Bool {
        return text.unicodeScalars.contains(where: { isKana($0) })
    }

    /// Number of Chinese or Japanese characters in `text`.
    static func cjkCount(_ text: String) -> Int {
        var count: Int = 0
        for scalar in text.unicodeScalars where isCJK(scalar) {
            count += 1
        }
        return count
    }

    /// Word count that also works for text without spaces. A whitespace separated token counts as one word,
    /// except that Chinese and Japanese characters count as one word per two characters (a common average).
    static func wordCount(_ text: String) -> Int {
        var total: Int = 0
        for token in text.split(whereSeparator: { $0.isWhitespace }) {
            var cjk: Int = 0
            var other: Bool = false
            for scalar in token.unicodeScalars {
                if isCJK(scalar) {
                    cjk += 1
                } else if CharacterSet.alphanumerics.contains(scalar) {
                    other = true
                }
            }
            if cjk == 0 {
                total += 1
            } else {
                total += (cjk + 1) / 2 + (other ? 1 : 0)
            }
        }
        return total
    }
}

/// Splits Chinese or Japanese text into words with NLTokenizer. Not thread safe: create one per call site.
final class CJKSegmenter {
    private let tokenizer: NLTokenizer = NLTokenizer(unit: .word)
    private var language: NLLanguage? = nil

    func split(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let wanted: NLLanguage = CJKText.containsKana(text) ? .japanese : .simplifiedChinese
        if language != wanted {
            tokenizer.setLanguage(wanted)
            language = wanted
        }
        tokenizer.string = text
        var out: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token: String = String(text[range])
            if !token.isEmpty { out.append(token) }
            return true
        }
        return out.isEmpty ? [text] : out
    }
}

/// The language a job ad or resume is written in, as far as the word lists are concerned.
/// `.english` also stands for every language without its own word lists (the original behaviour).
enum TextLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case chinese = "zh"
    case japanese = "ja"

    /// True for languages written without spaces between words.
    var isCJK: Bool {
        return self == .chinese || self == .japanese
    }

    /// Detects the main language of `text`. Chinese and Japanese are recognised by their characters first,
    /// so a short ad with a few Latin product names still counts as Chinese.
    static func detect(_ text: String) -> TextLanguage {
        let sample: String = String(text.prefix(4000))
        var letters: Int = 0
        var cjk: Int = 0
        var kana: Int = 0
        for scalar in sample.unicodeScalars {
            if CJKText.isKana(scalar) {
                kana += 1
                cjk += 1
                letters += 1
            } else if CJKText.isHan(scalar) {
                cjk += 1
                letters += 1
            } else if CharacterSet.letters.contains(scalar) {
                letters += 1
            }
        }
        guard letters > 0 else { return .english }
        // One Chinese character carries about as much as a short Latin word, so a third is a clear majority.
        if Double(cjk) / Double(letters) >= 0.3 {
            return kana > 0 ? .japanese : .chinese
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.english, .spanish, .french, .german, .portuguese, .italian, .dutch,
                                          .simplifiedChinese, .traditionalChinese, .japanese]
        recognizer.processString(sample)
        let hypotheses: [NLLanguage: Double] = recognizer.languageHypotheses(withMaximum: 3)
        var best: NLLanguage? = nil
        var bestValue: Double = 0
        for (language, value) in hypotheses where value > bestValue {
            best = language
            bestValue = value
        }
        guard let language = best else { return .english }
        // Only switch away from the original behaviour when the recogniser is fairly sure.
        if bestValue < 0.5 { return .english }
        if language == .spanish { return .spanish }
        if language == .french { return .french }
        if language == .german { return .german }
        if language == .simplifiedChinese || language == .traditionalChinese { return .chinese }
        if language == .japanese { return .japanese }
        return .english
    }
}
