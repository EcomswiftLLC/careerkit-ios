# Editor area localization notes (es, fr, de, zh-Hans)

Part file: `tools/l10n_parts/editor.json`, 698 keys. That is every key `--keys-in` lists for Sources/Features/Editor, Sources/Features/Templates, Sources/Features/Preview/TemplateThumbnail.swift, Sources/Templates and Sources/Features/CoverLetters/CoverLetterSuggestions.swift. Four keys have plural variations that include `en`: `%lld items`, `%lld words`, `%lld pages` and `%lld templates`.
- 43 keys also exist in shell.json and 10 in analysis.json. They are copied word for word, so the merge order makes no difference.
- `--lint` reports 0 problems. Nothing has been compiled. Build the catalog before CI: `EditorSupportTests` expects the English one-forms "1 item" and "3 words"/"2 items".

## How template names are localized

- Template and cover letter template `name` and `tagline` are wrapped where they are built: `name: String(localized: "Executive")` in TemplateLibrary and CoverLetterTemplateLibrary. Every `template.name` in the app, DesignSystem included, is localized. Ids and stored data stay English. Tests run in English, so names stay unique and the 90-character limit still holds.
- `TemplateCategory`, `ProfessionalLevel`, `DesignStyle` and `Industry` have a `displayName` (String(localized:)). Raw values are unchanged and are still stored.
- `Industry.education` uses the key `industry.education` with an `en` value of "Education". The plain key "Education" is the section heading ("Formación", "Ausbildung"), which reads wrong as a field of work.
- Template search (`CKTemplateFilter.searchText`) matches the localized words and the English raw values. It ignores case and accents. Grouping and order follow the library and enum order, not names.

## Left in English on purpose

- Model-facing text in `WritingAssistPrompt` (instructions, task lines, "Role:", "Organisation:", "Text:"). The instructions already said "Write in the same language as the text. Do not translate." I added one line: a summary written from work experience uses the language of that experience.
- `WritingAssistSanitizer` chatter phrases ("here is", "let me know", ...). They detect English model chatter only. A German or French preamble from the model would not be stripped. That is a logic change for later, not a string issue.
- Font names (`FontChoice.displayName`), brand and format names (LinkedIn, ATS, A4, US Letter), the sample tool names in the skills style tiles ("Swift", "Figma", "SQL", "Excel", now `Text(verbatim:)`), placeholder e-mail and phone in BlankPreview, `"Jan 2020 - Dec 2024"` in SampleFitModel (it only measures text and is never shown), and the search helper words "ats friendly" and "photo picture".
- `uniqueTitle` numbering ("Custom Section 2") and `"%@, %@"` style VoiceOver joins have no words to translate.

## Decisions worth checking

- New resume default title: the key is now `"%@ resume"` (English "Executive resume"), not `"%@ Resume"`. analysis.json uses `"%@ Resume"` for "Currículum de %@" with a person's name, and the two meanings would have collided.
- Example bullets: the English source writes "percent" and the translations do the same (por ciento, pour cent, Prozent, and full-width ％ in Chinese). These keys have no format arguments, and a bare "%" followed by a space and a letter, as in "3 % del", can be read as a format specifier. Keep it that way if you edit them.
- Cover letter suggestions: the translations use a new `{position}` placeholder ("the %@ position" / "the advertised position") instead of `{role}`. `fill()` replaces both, and English still uses `{role}`. German puts `{company}` only after dative prepositions and `{position}` only in accusative slots.
- WritingExamples: the summary category "Education" is now "Education and training" in English (the id stays `education`), so it does not take the section-heading translation.
- "Healthcare" appears in the template industries and in the example categories. The template wording wins (Salud / Santé / Gesundheitswesen / 医疗健康).
- German uses "Sie" to match shell.json. Spanish uses "tú", French "vous", Chinese "你". Cover letter sentences use the formal register in every language (usted / vous / Sie), as letters do.
- shell.json owns "None" (es "Ninguno", de "Keiner"). The bullet style and photo border chips reuse it, so the gender does not match everywhere, for example "Keiner" for a bullet.
- "Hidden", "Shown", "Small", "Medium" and "Large" are translated for the photo, so es and fr use feminine forms (Oculta / Masquée, Pequeña / Petite). Check them if another area reuses these keys for a masculine noun.
- Style panel: the new Language group (`StylePanelLanguage.swift`) sits between Page and Photo. It shows for resumes ("Resume language") and letters ("Letter language"). The collapsed summary reads "Same as app (Deutsch)" or the chosen native name. "Reset everything to template" also clears the language, because it resets the whole `StyleOverrides`.

## Layout spots to check on screenshots (de and fr are longest)

- Style panel sample tiles (`EdSampleChip`, fixed 84 pt label width): a single long word breaks mid-word. I picked shorter German and French labels ("Kurze Linie", "Gesperrt", "Gestapelt", "Trennlinien", "Trait court", "Chronologie"). Check "Kapitälchen", "Doppellinie", "Zeitleiste" and "Petites capitales".
- Blank builder segmented control: "Sections | Fonts and layout" becomes "Abschnitte | Gestaltung" and "Sections | Mise en forme".
- Bottom editor toolbar: "Vorlage / Stil / Abschnitte / ATS-Prüfung" (caption, minimumScaleFactor 0.8). Mode switch: "Bearbeiten / Vorschau".
- Template switcher cards (150 pt): names now allow 2 lines with scale 0.85. The "Plain layout" tag reads "Schlichtes Layout" / "Mise en page simple".
- New resume sheet: tags now wrap to 2 lines and scale down. The title "Mit einer leeren Seite beginnen" is set at 28 pt.
- Font chips: "Vorlage (Helvetica Neue)". Style group summary: "Avenir Next und Georgia, Größe 100 %".
- Language menu in the style panel: the menu button shows the native names.
- Writing help sheet buttons ("Vorschlag verwenden", "Meinen behalten") and the menu items ("Grammatik und Rechtschreibung korrigieren").
- Templates tab filter chips (DesignSystem `CKFilterChipBar` / `CKFilterMenuChip`, not in this area): "Wissenschaft und Forschung" and the long industry names.

## Compile notes

- New file `Sources/Features/Editor/StylePanelLanguage.swift` (`EdLanguageStyleGroup`). It uses `ResumeLanguage`, `.displayName`, `ResumeLanguage.resolved(_:)` and `StyleOverrides.language` from Sources/Models/Resume.swift, which are already there.
- `String(localized: "industry.education", defaultValue: "Education")` is iOS 16+ API.
- Int interpolations were moved into local `count`, `number`, `total`, `pages`, `percent` and `words` variables, so the extractor keys match the `%lld` keys Swift generates. That covers section positions, word counts, zoom percent, margin points, the photo template count and typical pages.
- `ResumeEditorView.toolButton` now takes a `hint:` argument. The string switch on English titles is gone.
