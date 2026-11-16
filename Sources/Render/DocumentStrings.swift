import Foundation

/// Fixed words the app writes into a document, in the document's language (not the app language).
///
/// `String(localized:locale:)` does not switch the language of the lookup, so each language's `.lproj`
/// bundle is loaded directly. A key missing from that language falls back to English, then to the key itself
/// (the key is the English source text of the String Catalog entry). Thread safe: the renderer runs on
/// background tasks.
enum DocumentStrings {
    private static let lock = NSLock()
    private static var bundles: [String: Bundle] = [:]
    private static var missingBundles: Set<String> = []
    /// Returned by the bundle when a key is not in its table, so a missing key can be told apart from a
    /// translation that happens to equal the key.
    private static let notFound: String = "\u{1}CK.notFound\u{1}"

    /// The `.lproj` bundle of `language`, or nil when the app has none (English may have none: its words are the keys).
    static func bundle(for language: ResumeLanguage) -> Bundle? {
        let name: String = language.rawValue
        lock.lock()
        if let cached = bundles[name] {
            lock.unlock()
            return cached
        }
        let knownMissing: Bool = missingBundles.contains(name)
        lock.unlock()
        if knownMissing { return nil }

        var found: Bundle? = nil
        var candidates: [String] = [name]
        if language == .zhHans { candidates.append(contentsOf: ["zh_Hans", "zh-CN", "zh"]) }
        if language == .en { candidates.append("Base") }
        for candidate in candidates {
            if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"), let bundle = Bundle(path: path) {
                found = bundle
                break
            }
        }

        lock.lock()
        if let found {
            bundles[name] = found
        } else {
            missingBundles.insert(name)
        }
        lock.unlock()
        return found
    }

    /// `key` (the English source text) in `language`. Falls back to English, then to the key.
    static func string(_ key: String, language: ResumeLanguage) -> String {
        if let value = lookup(key, in: language) { return value }
        if language != .en, let english = lookup(key, in: .en) { return english }
        return key
    }

    /// A format string such as "Dear %@," in `language`, filled with `arguments`.
    static func format(_ key: String, language: ResumeLanguage, _ arguments: CVarArg...) -> String {
        let pattern: String = string(key, language: language)
        return String(format: pattern, locale: language.locale, arguments: arguments)
    }

    private static func lookup(_ key: String, in language: ResumeLanguage) -> String? {
        guard let bundle = bundle(for: language) else { return nil }
        let value: String = bundle.localizedString(forKey: key, value: notFound, table: nil)
        if value == notFound || value.isEmpty { return nil }
        return value
    }

    // MARK: Words used by the renderer and the exporters

    /// End of a date range for a current role: "Present", "Actualidad", "Aujourd’hui", "Heute", "至今".
    /// Catalog key "Present" (tools/l10n_parts/shell.json).
    static func present(_ language: ResumeLanguage) -> String {
        return string("Present", language: language)
    }

    /// Heading of the contact block in a sidebar card. Catalog key "Contact" (tools/l10n_parts/render.json).
    static func contact(_ language: ResumeLanguage) -> String {
        return string("Contact", language: language)
    }

    /// Default heading of a section kind in `language`.
    static func defaultTitle(_ kind: SectionKind, language: ResumeLanguage) -> String {
        return string(kind.defaultTitleKey, language: language)
    }

    /// Greeting when the recipient's name is known. Catalog key "Dear %@," (tools/l10n_parts/shell.json).
    static func greeting(name: String, language: ResumeLanguage) -> String {
        return format("Dear %@,", language: language, name)
    }

    /// Greeting when no name is known. Catalog key "Dear Hiring Manager," (tools/l10n_parts/shell.json).
    static func greetingWithoutName(_ language: ResumeLanguage) -> String {
        return string("Dear Hiring Manager,", language: language)
    }

    /// Default sign-off. Catalog key "Sincerely," (tools/l10n_parts/shell.json).
    static func signOff(_ language: ResumeLanguage) -> String {
        return string("Sincerely,", language: language)
    }

    /// The cover letter date, written the long way in the document language ("16. November 2026", "2026年11月16日").
    static func letterDate(_ date: Date, language: ResumeLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// True when `text` is the untouched default of `key` in any document language (the user did not edit it).
    static func isDefault(_ text: String, key: String) -> Bool {
        let wanted: String = normalisedForComparison(text)
        guard !wanted.isEmpty else { return false }
        if normalisedForComparison(key) == wanted { return true }
        for language in ResumeLanguage.allCases where normalisedForComparison(string(key, language: language)) == wanted {
            return true
        }
        return false
    }

    /// True when `title` is the default heading of `kind` in the app language or in any document language.
    static func isDefaultTitle(_ title: String, of kind: SectionKind) -> Bool {
        if normalisedForComparison(title) == normalisedForComparison(kind.defaultTitle) { return true }
        return isDefault(title, key: kind.defaultTitleKey)
    }

    private static func normalisedForComparison(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .lowercased()
    }
}

// MARK: - Cover letter words in the document language

extension CoverLetter {
    /// Greeting as written on the document. An empty greeting becomes the default in the document language;
    /// with a chosen language, a greeting that is still another language's default is translated too.
    func effectiveGreeting(language: ResumeLanguage, explicit: Bool) -> String {
        let typed: String = greeting.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty {
            let untouched: Bool = explicit && recipientName.isEmpty && DocumentStrings.isDefault(typed, key: "Dear Hiring Manager,")
            if !untouched { return greeting }
        }
        let name: String = recipientName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return DocumentStrings.greeting(name: name, language: language)
        }
        return DocumentStrings.greetingWithoutName(language)
    }

    /// Sign-off as written on the document. With a chosen language, the untouched default sign-off
    /// ("Sincerely," saved in the app language when the letter was created) is written in that language.
    func effectiveSignOff(language: ResumeLanguage, explicit: Bool) -> String {
        guard explicit, DocumentStrings.isDefault(signOff, key: "Sincerely,") else { return signOff }
        return DocumentStrings.signOff(language)
    }
}
