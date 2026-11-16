# Shell area localization notes (es, fr, de, zh-Hans)

Part file: `tools/l10n_parts/shell.json` (389 keys, 9 with plural variations incl. `en`).
Area: Home, My Resumes, Onboarding, Profile, Cover Letters (not CoverLetterSuggestions.swift), Preview (not TemplateThumbnail.swift), App, DesignSystem, Persistence, Ads, Models.

## Before CI: build the catalog

Unit tests are app-hosted and now read English plural forms from the catalog:
- `PersistenceBackupTests.testSummaryMessage` expects "Restored 1 document, skipped 0." (one form of `%lld documents`).
- `testSummaryMessage` / keptBoth expects "separate copy" (one form of `%lld were added as separate copies ...`).
Without the `en` plural entries from shell.json these become "1 documents" / "1 were added as separate copies" and fail.

## Left in English on purpose

- Brand and product names: CareerKit, Ecom Swift LLC, Google AdMob, App Store, Word, Pages, Google Docs, PDF, Rich Text, ATS, iOS; the file-name hint `CareerKit-Backup`.
- Export file-name fallbacks `"Resume"` and `"Cover letter"` passed to `FileNaming.safeFileName` (file names).
- Paper size "A4". Version text `1.0 (3)`. Percent values in the Compare versions table (`"80 %"`, built as plain text).
- Folder names in DocumentStore, UserDefaults keys, identifiers, log messages (AdsLog), `MMM yyyy` date template.
- DEBUG-only screenshot seed titles in `Sources/App/ScreenshotSupport.swift`.

## Document content that is now localized (please confirm this is wanted)

These are written into the person's documents in the device language at the moment they are created:
- Default section headings (`SectionKind.defaultTitle`: "Work Experience", "Skills", ...), "Present" in date ranges.
- Cover letter defaults: "Dear Hiring Manager," / "Dear %@," / "Sincerely,". The suggestion lists in CoverLetterSuggestions.swift (other worker) should use matching wording.
- Title suffixes for duplicates and restored copies: "copy" and "(restored)". `baseTitle(removingCopySuffixFrom:)` only recognises the current language's word, so an English "CV copy" duplicated on a German device becomes "CV copy Kopie". Harmless, but visible.
- `ResumeDateFormat.monthName.example` is now formatted from a real date ("Jan 2024" in English, "ene 2024" in Spanish).

## Extractor issues found (tools/l10n_extract.py, not edited)

1. `String(localized: "...")` is never matched: the pattern is `String\(localized:` followed by `\s*\(`, so it expects a second parenthesis. Same for `LocalizedStringKey(`. `--keys-in` and `--check` therefore miss every `String(localized:)` key (about half of this area). I used a corrected scan for shell.json.
2. `Button(` also matches helpers whose names end in Button, such as `controlButton("chevron.left", ...)`, which made SF Symbol names into keys. I renamed that helper in PreviewPane.swift to `pagerControl`. Check other areas for `...Button("`, `...Text("`, `...Label("`.
3. WORDY counts the `lld` in `%lld%%`, so `Text("\(percent)%")` becomes a key. I added it with translations (`80 %` in es/fr/de).
4. Keys whose only words are 2 letters are skipped (`"%@ at %@"`). Added by hand.
5. Integer detection: an interpolation with a dot (`\(template.typicalPages)`) normalises to `%@`, while Swift generates `%lld` for an Int. I used local Int variables named `count`, `number`, `total`, `pages`, `percent` so the keys match what Swift looks up.
6. `--lint` treats positional specifiers (`%1$@`) as a mismatch, so I kept argument order in every translation instead of reordering.
7. `Tab("Home", ...)`, `DatePicker("Date", ...)`, `.searchable(prompt:)`, `sectionHeader("...")` (Profile helper taking LocalizedStringKey) and `CKOnboardingPage`/`Block` LocalizedStringKey fields are not scanned; their keys are in shell.json by hand.

## Keys that may also appear in other part files

Shared English keys get one translation for the whole app. If another part file defines these differently, the file merged last wins:
"Template", "Templates", "Preview", "Export", "Cancel", "Done", "Delete", "Duplicate", "Style", "Suggestions", "ATS check", "ATS friendly", "%lld pages", "%lld resumes", "Photo", "has a photo area", "Has a photo area", section headings ("Skills", "Education", "Languages", ...), "Close", "Back", "Try again", "None".
"Photo" / "Has a photo area" / "has a photo area" were added to DesignSystem/ComponentsTemplates.swift by another worker during this pass; I translated them here.

## Interface changes other areas depend on

- `EdUnavailableView(title:message:backTitle:)`, `PreviewPane(accessibilityName:)` and `PDFPreview(accessibilityName:)` still take `String`. Editor call sites must pass `String(localized: ...)` (ResumeEditorView, BlankBuilderView still pass plain literals).
- `CoverLetterForm` reads `CoverLetterField.title` into a `String`; keep that property a `String`.
- New helpers: `CKCountText.resumes(_:)`, `CKCountText.coverLetters(_:)`, `CKPreviewNames.preview(of:)`, `CKDateWords.present`, `CKResumeSort.inlineTitle`.

## Layout spots to check on screenshots (de and fr are longest)

- Tab bar: es "Mis currículums", de "Meine Lebensläufe"; Cover Letters tab is shortened to "Cartas" / "Lettres" / "Anschreiben" / "求职信".
- Home: greeting title (`Guten Morgen, Name`), the three Career tools tiles side by side (de "Formatierung eines Lebenslaufs prüfen"), "How CareerKit stays free" card, Create buttons.
- Template cards: badge row (ATS + Photo + pages) now scales down to 0.8 instead of truncating; names scale to 0.85.
- Resume tiles and rows: the "Edited ..." line now wraps to 2 lines ("Bearbeitet vor 2 Tagen").
- My Resumes: filter chips "Lebensläufe (3)" / "Archiviert (1)", the summary line, the toolbar menus.
- Compare versions: value columns are fixed at 55% of a column; label column wraps ("Abschnitte mit Inhalt").
- Profile: segmented Appearance control (es "Sistema / Claro / Oscuro", zh "跟随系统"), long settings rows (they wrap), confirmation dialogs.
- Export sheet: title "Als Word-Dokument exportieren", the primary button "Regarder une publicité pour exporter" (multiline allowed), fallback cards.
- Onboarding: long titles on page 3 and 5 at 30 pt (wrap, not clipped); section chips in the art scale to 0.8.
- Cover letter template grid: names now allow 2 lines in the 150 pt column.
- Preview pager: "Seite 1 von 2" in the capsule control.
