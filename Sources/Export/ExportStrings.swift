import Foundation

/// The few fixed words an exported file can contain, in the language the file is exported in.
/// Everything else in an export (headings, names, dates as typed) comes from the document itself.
/// `language` is a language code such as "en", "es", "fr", "de" or "zh-Hans"; the default follows the app.
enum ExportStrings {
    /// The language the app is shown in right now, for example "es" or "zh-Hans".
    static var currentLanguage: String {
        let preferred: String = Bundle.main.preferredLocalizations.first ?? "en"
        return preferred == "Base" ? "en" : preferred
    }

    /// The `.lproj` bundle of `language`, or the main bundle when the app has no such localization.
    static func bundle(for language: String) -> Bundle {
        var candidates: [String] = [language]
        if let base = language.split(separator: "-").first.map(String.init), base != language {
            candidates.append(base)
        }
        if language.hasPrefix("zh") && !candidates.contains("zh-Hans") {
            candidates.append("zh-Hans")
        }
        for name in candidates {
            if let path = Bundle.main.path(forResource: name, ofType: "lproj"), let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return Bundle.main
    }

    /// Locale used for dates in the file. The current locale is kept when it already speaks `language`,
    /// so its region (for example "en_GB") is respected.
    static func locale(for language: String) -> Locale {
        let wanted: String = baseCode(language)
        if let current = Locale.current.language.languageCode?.identifier, current == wanted {
            return Locale.current
        }
        return Locale(identifier: language)
    }

    /// "zh-Hans" becomes "zh", "es-MX" becomes "es".
    static func baseCode(_ language: String) -> String {
        let lower: String = language.lowercased()
        return lower.split(separator: "-").first.map(String.init) ?? lower
    }

    /// Looks `key` (the English source text of a String Catalog entry) up in the strings of `language`.
    /// English, or a language the app does not have, gives the key back unchanged.
    static func lookup(_ key: String, language: String) -> String {
        let source: Bundle = bundle(for: language)
        return source.localizedString(forKey: key, value: key, table: nil)
    }

    /// Shown for a current role in place of an end date: "Present".
    /// Catalog key "Present" (tools/l10n_parts/analysis.json).
    static func present(_ language: String = currentLanguage) -> String {
        return lookup("Present", language: language)
    }

    /// Title of an exported file whose document has no title or name.
    /// Catalog key "Document" (tools/l10n_parts/analysis.json).
    static func untitledDocument(_ language: String = currentLanguage) -> String {
        return lookup("Document", language: language)
    }

    /// Value of the HTML lang attribute: "en", "es", "fr", "de" or "zh-Hans".
    static func htmlLanguageTag(_ language: String) -> String {
        switch baseCode(language) {
        case "es": return "es"
        case "fr": return "fr"
        case "de": return "de"
        case "zh": return "zh-Hans"
        default: return "en"
        }
    }

    /// Word proofing language for the document defaults: "en-US", "es-ES", "fr-FR", "de-DE" or "zh-CN".
    static func wordLanguageTag(_ language: String) -> String {
        switch baseCode(language) {
        case "es": return "es-ES"
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        case "zh": return "zh-CN"
        default: return "en-US"
        }
    }
}
