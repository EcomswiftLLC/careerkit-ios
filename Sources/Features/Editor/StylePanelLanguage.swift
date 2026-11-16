import SwiftUI

/// Style panel group for the document language: the language of the fixed words the app writes into the
/// resume or letter ("Present", month names, page numbers). nil means "same as the app language".
/// The stored value is `StyleOverrides.language`; `ResumeLanguage` lives in `Sources/Models/Resume.swift`.
struct EdLanguageStyleGroup: View {
    @Binding var language: ResumeLanguage?
    var isLetter: Bool = false
    @Binding var isExpanded: Bool

    private var title: String {
        isLetter ? String(localized: "Letter language") : String(localized: "Resume language")
    }

    private var summary: String {
        if let language { return language.displayName }
        let appLanguage: String = ResumeLanguage.resolved(nil).displayName
        return String(localized: "Same as app (\(appLanguage))")
    }

    var body: some View {
        EdStyleGroup(title: title,
                     summary: summary,
                     systemImage: "globe",
                     isModified: language != nil,
                     onReset: { language = nil },
                     isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: CK.Space.s) {
                Picker(title, selection: $language) {
                    Text("Same as app").tag(ResumeLanguage?.none)
                    ForEach(ResumeLanguage.allCases) { option in
                        // Native names ("Deutsch", "Español") read the same in every app language.
                        Text(verbatim: option.displayName).tag(ResumeLanguage?.some(option))
                    }
                }
                .pickerStyle(.menu)
                .tint(CK.Palette.forest)
                .frame(minHeight: 44, alignment: .leading)
                Text("Used for words the app adds to the document, such as Present and page numbers.")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
