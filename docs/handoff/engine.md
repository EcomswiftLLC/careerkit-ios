# Engine handoff (render, persistence, ATS, engine tests)

**Nothing here has been compiled or run.** The work was done on Windows with no Mac, no Xcode and no simulator. Everything is written to be conservative and compile-safe, but expect a first CI round to surface a few compiler errors and a few test failures that come from layout assumptions. The riskiest spots are listed at the end so they can be checked first.

## Files

### Sources/Render
| File | Purpose |
|---|---|
| `RenderModels.swift` | `RenderedDocument`, `PDFValidationReport` (exactly as in the contract) |
| `DocumentRenderer.swift` | `DocumentRenderer.render(_:template:)` and `RenderResumeComposer` (geometry, columns, pagination, page drawing) |
| `CoverLetterRenderer.swift` | `CoverLetterRenderer.render(_:template:)`, all six `HeaderLayout` cases |
| `PDFValidator.swift` | `PDFValidator.extractText(from:)`, `validate(_:resume:)` |
| `RenderStyle.swift` | `RenderStyle` (template plus `StyleOverrides`), `RenderTheme`, `RenderContext` |
| `RenderFonts.swift` | `FontChoice` to `UIFont` with safe fallbacks and a name cache |
| `RenderText.swift` | colour helpers, direction detection, attributed string factory, link detector, drawing helpers, photo crop, `RenderPDFWriter` |
| `RenderTextLayout.swift` | TextKit 1 wrapper: measuring, per line splitting, baselines, drawing, link rectangles |
| `RenderFlow.swift` | `RenderFlowItem` (one placeable block), text item factory, `RenderComposite` (baseline aligned rows) |
| `RenderPaginator.swift` | column flow and page breaking |
| `RenderSectionBuilder.swift` | the seven heading styles, text sections, side label sections |
| `RenderEntryBuilder.swift` | the four entry layouts, hanging bullets |
| `RenderSkillBuilder.swift` | the four skill styles |
| `RenderHeaderBuilder.swift` | the six header styles, sidebar card, photo |
| `RenderContact.swift` | contact items, mailto/tel/web URLs, flow and stack layouts |
| `RenderContent.swift` | the single definition of "what is rendered" (visible sections, empty entries, bullet clean up, expected strings) |

All internal types are prefixed `Render` so they cannot clash with other owners' names.

### Sources/Persistence
`DocumentStore.swift`

### Sources/Features/ATS
`ATSAnalyzer.swift` (`ATSFinding`, `ATSReport`, `ATSAnalyzer`; views belong to the editor owner)

### Tests
`EngineFixtures.swift` (12 self built `TemplateSpec` values, 6 letter specs, 24 resume cases, letters), `EngineRenderTests.swift`, `EngineLayoutTests.swift`, `EngineStoreTests.swift`, `EngineATSTests.swift`.

## API as implemented

Matches the contract. Differences and additions:

- `DocumentStore.init(directory: URL? = nil, debounceInterval: TimeInterval = 0.6)` has one extra defaulted parameter (tests use it to shorten the wait). `DocumentStore()` and `DocumentStore(directory:)` still work.
- `duplicate(resumeID:)` and `duplicate(coverLetterID:)` are `@discardableResult`.
- Extra read only members on the store: `rootDirectory`, `resumesDirectory`, `lettersDirectory`, `quarantineDirectory`, `static let currentSchemaVersion`.
- Storage paths: the root is Application Support/CareerKit (or the injected folder). Files are in `Documents/Resumes/<uuid>.json` and `Documents/CoverLetters/<uuid>.json` under that root, with `Quarantine/` next to `Documents/`. The contract wording was ambiguous, this is how it was read.
- `ATSAnalyzer.disclaimerText` is public to the module so views can reuse it.
- `PDFValidator.normalise(_:)` and `PDFValidator.appears(_:in:)` are internal helpers (tests and ATS use them).
- A duplicated resume has its `linkedCoverLetterID` cleared, `isArchived` reset and `createdAt` set to now.
- `upsert` re-sorts both arrays by `updatedAt`, newest first. Editing a resume moves it to the top.

## Algorithm notes

**Pipeline.** `Resume` + `TemplateSpec` -> `RenderStyle` (template values with user overrides: accent, fonts, `fontScale`, `lineSpacing`, `marginPoints`, `showPhoto`; clamped to safe ranges) -> sections filtered by `RenderContent` -> flow items per column -> `RenderPaginator` per column -> one `UIGraphicsPDFRenderer` pass that draws every page. The same code produces preview and export.

**Text.** Every text block is an `NSAttributedString` laid out by a private `NSLayoutManager` (TextKit 1) and drawn with `drawGlyphs`, so the PDF contains real selectable text. Ligatures are switched off so extraction and search return plain letters. Line spacing uses `NSParagraphStyle.lineSpacing` (space below lines) so the first line of a block sits exactly at the block top and baselines can be computed. Right to left text uses a detected base writing direction and natural alignment.

**Flow items.** A block has a measured height, `spaceBefore`, `keepWithNext`, an optional indent and an optional split function. Entries are an atomic header (heading rows, extra line) plus detail plus one block per bullet. Dates in `dateRight` and `dateGutter` share a baseline with the heading through `RenderComposite.addRow`.

**Pagination rules (`RenderPaginator`).**
1. A chain of `keepWithNext` blocks moves as one (section heading + entry header + first bullet).
2. If a chain ends in a long paragraph, only the first two lines of that paragraph must fit, then the paragraph splits.
3. Text splits between lines with at least two lines on each side (no widows or orphans); at the top of a page any line boundary is allowed.
4. Second to last bullet is glued to the last, so a single bullet is not left alone on the next page.
5. A block that cannot be split and is taller than a page is placed anyway on a fresh page. Nothing is dropped.
6. `spaceBefore` is ignored at the top of a column on a page.

**Layouts.** `singleColumn`: header region then one column. `sidebarLeft/Right`: the sidebar band is filled full page height on every page, the sidebar column and the main column paginate independently and the page count is the larger of the two. The sidebar text width is `contentWidth * sidebarFraction`. With `HeaderStyle.sidebarCard` name, photo and contact live at the top of the sidebar. With any other header the header sits at the top of the main column and a banner fill bleeds to the page edge on the main side only. `headerThenTwoColumn`: header full width on page one only, then main column plus rail with a hairline divider. If a layout has a sidebar but nothing to put in it, the renderer falls back to a single column.

**Style handling worth knowing.**
- Narrow columns (under about 250 pt) fall back automatically: `dateRight` and `dateGutter` become `dateBelow`, `groupedLines` stacks, `bulletColumns` uses one column, `sideLabel` becomes `uppercaseRule`.
- `smallCapsAccent` is drawn small caps (big first letter, smaller capitals) rather than relying on font features, so it works in every font.
- If the user changes the accent colour and the template's banner or sidebar fill equals the template accent, the fill follows the new accent.
- Photo: circle for banner, centred and sidebar headers, rounded square elsewhere. Shown only when the template has a photo placement, `showPhoto` is true and the data decodes.
- Bullet text that already starts with a pasted marker (bullet, hyphen, asterisk) has the marker removed so it is not doubled. The validator applies the same rule.
- `ResumeEntry.extra` is shown in the entry header block (good for GPA), not after the bullets.
- Section content is rendered from `text`, `entries` and `skillGroups` regardless of `SectionKind.shape`, so a custom section with both text and entries shows both.
- Cover letters do not add a subject line. The `jobTitle`, `jobDescription` fields are not printed.
- Date and bullet marker strings come from the model (`dateRange`, `BulletStyle.glyph`).

**Links.** Email (`mailto:`), phone (`tel:`) and web contact items get exact link rectangles. Explicit URLs and email addresses typed inside body text are detected with `NSDataDetector` (only text with a scheme, `www.` or `@`, so "Node.js" is not linked). Annotations are added with `UIGraphicsPDFRendererContext.setURL(_:for:)` from `RenderCanvas.addLink`.

**Validator.** Opens the PDF with PDFKit and checks page count, page size, blank pages (only when the resume has content), replacement characters, and that name, email, phone, visible section titles, summary paragraphs, entry headings, subheadings and bullets appear in the extracted text. Comparison ignores case, whitespace, ligatures, width forms, soft hyphens and bidi marks (NFKC). Because PDFKit can interleave columns, a multi word string that is not found whole passes when each of its words is found. Right to left strings pass when found, found reversed, or when all their letters are present, since extraction order for Arabic is not guaranteed.

**DocumentStore.** One JSON file per document, `JSONEncoder` with ISO 8601 dates and sorted keys, writes through `Data.write(.atomic)`. Before each overwrite the old file is copied to `<uuid>.json.bak`. On load an unreadable file is moved to `Quarantine/` (name plus timestamp plus `.corrupt`); if a `.bak` decodes it is restored as the main file, otherwise the `.bak` is quarantined too. Saves are debounced 0.6 s with a cancelled and restarted `Task`; `flushNow()` is synchronous and failed documents stay dirty for the next attempt. Deleting a document also cancels its pending save. `makeBackupFile()` flushes, then writes `CareerKit-Backup-<date>.json` (format, schemaVersion, createdAt, resumes, coverLetters) to the temporary directory. `schemaVersion` passes through `migrated(_:)`, a no-op for v1.

**ATS checks.** Contact details, standard headings, missing key sections, dates on roles, summary length, text extraction ratio, layout (single column good, sidebar or two column warning), photo shown, unusual symbols and emoji, page count (3 or more pages warns), very little content, long bullets. Findings are ordered warnings, notes, good. The disclaimer says it is general guidance, not a score from any employer system and no guarantee.

## Known gaps

- No page numbers or footer.
- No justified text, no hyphenation (very long unbroken URLs rely on the character wrap fallback of TextKit).
- Photos are drawn as given (no face detection, plain centre crop).
- `sideLabel` aligns the label to the top of the first block using an ascender estimate, not an exact shared baseline.
- Link rectangles for a link that wraps over several lines are one rectangle per line, which is correct, but a link broken across a page split only gets the part on each page.
- ATS wording is English only (wrapped in `String(localized:)` so strings can be extracted later).
- No test checks pixels. Visual quality (spacing, alignment) has to be reviewed by looking at the PDFs from CI or the simulator.
- Fonts rely on the system families listed in `FontChoice`. On a device where a family is missing the system font is used.

## Riskiest spots to check first

1. **Compile errors.** Never built. Most likely areas: the memberwise `TemplateSpec(...)` and `CoverLetterTemplateSpec(...)` calls in `Tests/EngineFixtures.swift` (argument order must match the struct), `String(localized:)` with interpolation, nested functions that mutate captured variables in `RenderPaginator`, closure types in `RenderFlow.swift`, and the `@MainActor` test class.
2. **Link annotation coordinates.** `UIGraphicsPDFRendererContext.setURL(_:for:)` is called with UIKit style coordinates (top left origin). If links land flipped in the PDF, change only `RenderCanvas.addLink` to `CGPDFContextSetURLForRect(context.cgContext, url as CFURL, rect.applying(context.cgContext.ctm))`. `testMetadataAndLinkAnnotations` checks that mailto, tel and a body link exist as URL actions but not their position.
3. **TextKit drawing in a PDF context.** `NSLayoutManager.drawGlyphs(forGlyphRange:at:)` is positioned from line fragment rectangles in `RenderTextLayout.draw`. If text appears vertically offset or clipped, check that function and the baseline math in `RenderComposite.addRow`.
4. **Character wrapping of long words.** Tests `testLongWordWrapsInsteadOfOverflowing` and the long URL fixture assume TextKit breaks a word that is wider than the column.
5. **Text extraction order.** The validator is deliberately lenient for columns and right to left text. If a fixture still fails on CI, open the PDF, look at `PDFValidationReport.extractedText`, and decide whether the layout or the check is wrong.
6. **Page count bounds in fixtures** (`minPages`, `maxPages`) and `testLongDocumentWarns` (14 jobs) depend on real text metrics. Adjust the numbers if a sidebar template legitimately needs more room.
7. **Timing tests.** `testDebouncedSaveWritesAfterTheDelay` sleeps 1.3 s against a 0.6 s debounce.
8. **Font names.** `RenderFonts.pickFontName` scores installed font names by traits and keywords. `EngineLayoutTests.testEveryFontChoiceResolvesInAllVariants` only checks size and non-empty names, so check a rendered PDF with Futura, Optima and Baskerville to be sure the weights look right.
