# Templates handoff

Owner: templates. Written on a Windows PC with no Mac. **I could not compile or run anything.** No Swift was built and no test was executed. I checked bracket balance and argument order with small scripts, and I verified palette contrast, numeric ranges, category counts, design-tuple uniqueness and the ATS count with a Python script that also generated `TemplateLibrary.swift`. macOS CI is the first real compile.

## Files

| File | Purpose |
|---|---|
| `Sources/Templates/TemplateLibrary.swift` | 30 `TemplateSpec` values, `defaultTemplateID`, `spec(id:)` |
| `Sources/Templates/CoverLetterTemplateLibrary.swift` | 10 `CoverLetterTemplateSpec` values, `spec(id:)` |
| `Sources/Templates/SampleContent.swift` | 15 fictional personas, `resume(for:)`, `coverLetter()`, `sampleLabel` |
| `Sources/Templates/ResumeFactory.swift` | `newResume`, `blankResume`, `newCoverLetter` |
| `Tests/TemplateLibraryTests.swift` | counts, ids, variety, ATS rules, ranges, contrast (also holds the shared `TemplateTestColor` helper) |
| `Tests/TemplateCoverLetterTests.swift` | cover letter library checks |
| `Tests/TemplateSampleContentTests.swift` | sample content checks |
| `Tests/TemplateResumeFactoryTests.swift` | factory checks |

## Public API (matches the contract)

```swift
enum TemplateLibrary {
    static let all: [TemplateSpec]                 // exactly 30
    static let defaultTemplateID: String           // "ck.professional.executive" (ATS friendly)
    static func spec(id: String) -> TemplateSpec?
    static func templates(in category: TemplateCategory) -> [TemplateSpec]   // extra helper
}
enum CoverLetterTemplateLibrary {
    static let all: [CoverLetterTemplateSpec]      // exactly 10
    static func spec(id: String) -> CoverLetterTemplateSpec?
    static func spec(matchingResumeTemplateID: String) -> CoverLetterTemplateSpec?   // extra helper
}
enum SampleContent {
    static func resume(for template: TemplateSpec) -> Resume
    static func coverLetter() -> CoverLetter
    static let sampleLabel = "Sample content, fictional person"
}
enum ResumeFactory {
    static func newResume(template: TemplateSpec, title: String, pageSize: PageSize) -> Resume
    static func blankResume(title: String, pageSize: PageSize) -> Resume
    static func newCoverLetter(templateID: String, title: String, from resume: Resume?) -> CoverLetter
    static let requiredKinds: [SectionKind]                                   // extra helper
    static func sectionKinds(for template: TemplateSpec) -> [SectionKind]     // extra helper
}
```

Deviations from the contract: none in signatures. The extra helpers are optional to use.

## Design direction

Second pass (distinctness): the CI renders showed about half of the white-paper templates as near-identical cousins (black text, hairlines, the same faces). Every template now has one identity a person would pick on purpose, built from a type pairing, an accent, a header treatment and a heading treatment. No two templates share a font pairing or an accent. Direction came from the frontend-design guidance; no design service was used.

- Palette: dark, restrained accents, each used once: midnight navy, cobalt, pine, claret, gold (on a midnight sidebar), copper, teal, plum, rosewood, steel, tobacco, Prussian blue, mulberry (on aubergine), indigo, sienna (on greige), olive, crimson, mahogany, sea green, violet, slate, kelly green, cornflower (on sky), burnt orange, teal (on aqua), code blue, emerald, petrol (on deep petrol), amber, petrol blue. Accent luminance stays under 0.3, accent and muted text at least 4.5:1 on white and on light fills, body text at least 7:1.
- Type: real iOS families only. Iowan Old Style is not installed on the CI simulator (it rendered as New York), so no template uses it any more; Academic CV is set in Charter, Senior Management in Baskerville, Creative Minimal in New York.
- Name treatments vary: bold or regular weight (the new `doubleRule` and `centeredAccent` headers set the name in regular weight), ink or accent colour, 26 to 38 pt.
- Square bullets now ask for the text form (`U+25AA U+FE0E`). Without it, fonts that lack the glyph fell back to Apple Color Emoji in CI.

### New renderer vocabulary (enum cases added at the end of each enum)

- `HeaderStyle`: `monogramBadge`, `accentRuleLeft`, `centeredAccent`, `doubleRule`. `monogramBadge` prints initials as decoration, so it counts as non-plain for ATS (like `banner`).
- `SectionHeadingStyle`: `underlineAccent`, `centeredRule`, `leftBorder`, `tintedBand`.
- All new cases are drawn in `RenderHeaderBuilder` / `RenderSectionBuilder` with vector fills and selectable text, are offered in the style panel (`TemplateSpec.offeredHeaderStyles` / `offeredHeadingStyles`, names and tiles in `StylePanelSamples.swift`) and are covered by `EngineFixtures.specs`.

### Side label fix

Side labels used a fixed 80 to 112 pt gutter, so long labels broke inside words ("PROFESSION AL SUMMARY", "WORK EXPERIENC E") and the PDF text check failed on Creative Minimal. The gutter is now sized to the widest word among the template's default section titles (between 18 and 32 percent of the column), so it wraps only between words; a renamed label with a longer word is set smaller (down to 70 percent) instead of breaking. A label taller than its section holds the next block on its page and pads the last block, so it never collides with the next heading.

## What the renderer owner needs to know

- **ATS friendly** means: `singleColumn`, `photo == .none`, no sidebar sections, header not `banner`, `sidebarCard` or `monogramBadge`, heading style not `boxedLabel` or `sideLabel`, entry layout not `dateGutter`, skill style not `bulletColumns`, and default section titles. 14 templates qualify. A test asserts the flag equals this rule for every template.
- `sidebarCard` is used only with `sidebarLeft` and `sidebarRight`. `banner` goes with a non-nil `headerFillHex`, and banner text is assumed to be white (fill contrast with white is at least 4.5:1).
- `headerThenTwoColumn` uses `sidebarFraction` and `sidebarSections` for the right rail. Researcher has no rail fill (nil, nil).
- Sidebar fills: dark on Business Elite (midnight), Creative Designer (aubergine) and Data Analyst (deep petrol) with light text; light tints (lavender, greige, sky, aqua) on the others.
- Photo: `sidebarTop` on 5 sidebar templates, `headerRight` on Professional Grid, Marketing Professional and Creative Minimal (where the photo takes the monogram disc's place), `none` elsewhere.
- Ranges: margins 34 to 56 pt, base size 9.5 to 10.5 pt, name size 26 to 38 pt, heading size 10 to 12 pt, line spacing 1.14 to 1.18, heading tracking 0.2 to 2.0 pt.
- Usage: header sidebarCard 7, splitContact 3, accentRuleLeft 3, leftAligned 3, ruledMonogram 3, monogramBadge 3, doubleRule 2, centeredAccent 2, centered 2, banner 2. Heading underlineAccent 4, dottedRule 4, smallCapsAccent 4, leftBorder 3, boxedLabel 3, sideLabel 3, centeredRule 2, tintedBand 2, uppercaseRule 2, accentBar 2, plainBold 1. Entry dateRight 14, dateBelow 10, stacked 4, dateGutter 2.

## The 30 templates

| # | Template (id) | Identity | Layout | Header | Heading | Entry | Fonts (heading / body) | Accent | ATS | Pages |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Executive (`ck.professional.executive`) | Baskerville name between a hairline and an Oxford rule. Centered section titles. | singleColumn | doubleRule | centeredRule | dateRight | baskerville / charter | #1B2A4A | yes | 2 |
| 2 | Corporate (`ck.professional.corporate`) | Tight Helvetica with cobalt bars beside mixed-case section titles. | singleColumn | splitContact | leftBorder | dateBelow | helveticaNeue / helveticaNeue | #1D4E89 | yes | 2 |
| 3 | Modern Professional (`ck.professional.modern-professional`) | Pine bar beside the name, Charter text and a skills rail on the right. | headerThenTwoColumn | accentRuleLeft | underlineAccent | dateRight | avenirNext / charter | #1E4D3A | no | 1 |
| 4 | Classic Professional (`ck.professional.classic-professional`) | Claret Palatino name over a short rule, with dotted leaders after each title. | singleColumn | centeredAccent | dottedRule | dateRight | palatino / palatino | #6E1F2B | yes | 1 |
| 5 | Business Elite (`ck.professional.business-elite`) | Midnight navy sidebar, Didot name and gold underlines on each section. | sidebarLeft | sidebarCard | underlineAccent | dateBelow | didot / avenirNext | #7D6224 | no | 2 |
| 6 | Senior Management (`ck.professional.senior-management`) | Copper-tinted section bands, Gill Sans titles over Baskerville text. | singleColumn | centered | tintedBand | stacked | gillSans / baskerville | #8A4B2A | yes | 2 |
| 7 | Modern Minimal (`ck.modern.modern-minimal`) | Oversized Futura name, teal small caps titles and wide white margins. | singleColumn | leftAligned | smallCapsAccent | dateRight | futura / avenirNext | #155E63 | yes | 1 |
| 8 | Contemporary (`ck.modern.contemporary`) | Lavender sidebar with the photo, and plum tinted bands on each section. | sidebarRight | sidebarCard | tintedBand | dateRight | optima / avenirNext | #5A2A5E | no | 1 |
| 9 | Elegant (`ck.modern.elegant`) | Cochin name centered over rosewood titles set between hairlines. | singleColumn | centered | centeredRule | dateBelow | cochin / hoeflerText | #7B2D45 | yes | 1 |
| 10 | Clean Lines (`ck.modern.clean-lines`) | Steel blue hairlines, Helvetica titles and contact details stacked right. | singleColumn | splitContact | uppercaseRule | dateRight | helveticaNeue / sfPro | #2F4F6F | yes | 1 |
| 11 | Modern Classic (`ck.modern.modern-classic`) | Georgia name on a heavy tobacco rule, Gill Sans text and a side rail. | headerThenTwoColumn | ruledMonogram | smallCapsAccent | dateBelow | georgia / gillSans | #6A4A1F | no | 2 |
| 12 | Professional Grid (`ck.modern.professional-grid`) | Prussian blue band with the photo, boxed labels and a skills rail. | headerThenTwoColumn | banner | boxedLabel | dateRight | sfPro / charter | #1F4E79 | no | 2 |
| 13 | Creative Designer (`ck.creative.creative-designer`) | Aubergine sidebar with a portrait, Futura titles and mulberry accent bars. | sidebarLeft | sidebarCard | accentBar | stacked | futura / helveticaNeue | #7C2D55 | no | 1 |
| 14 | Marketing Professional (`ck.creative.marketing-professional`) | Indigo band with the photo, boxed section labels and two-column skills. | singleColumn | banner | boxedLabel | dateRight | gillSans / helveticaNeue | #3A3F8F | no | 1 |
| 15 | Visual Portfolio (`ck.creative.visual-portfolio`) | Projects first, a greige sidebar with the photo and sienna dotted leaders. | sidebarRight | sidebarCard | dottedRule | dateBelow | cochin / optima | #8A3F1F | no | 1 |
| 16 | Creative Minimal (`ck.creative.creative-minimal`) | Initials in an olive disc, section names in a left margin, New York text. | singleColumn | monogramBadge | sideLabel | stacked | avenirNext / newYork | #4E5B24 | no | 1 |
| 17 | Editorial (`ck.creative.editorial`) | Large Didot name, titles in the margin and a date column, like a magazine. | singleColumn | ruledMonogram | sideLabel | dateGutter | didot / georgia | #8E1B1B | no | 2 |
| 18 | Academic CV (`ck.academic.academic-cv`) | Charter throughout, mahogany Oxford rules and small caps section titles. | singleColumn | doubleRule | smallCapsAccent | dateRight | charter / charter | #5A2E24 | yes | 2 |
| 19 | Researcher (`ck.academic.researcher`) | Initials in a sea green disc, Baskerville titles and an honours rail. | headerThenTwoColumn | monogramBadge | dottedRule | dateBelow | baskerville / georgia | #2A5A4B | no | 2 |
| 20 | University Graduate (`ck.academic.university-graduate`) | Charter name and short violet bars over each title. Education leads. | singleColumn | leftAligned | accentBar | dateBelow | charter / avenirNext | #553C8B | yes | 1 |
| 21 | Scientific CV (`ck.academic.scientific-cv`) | Contact stacked right, titles in a left margin and Georgia for long lists. | singleColumn | splitContact | sideLabel | dateRight | helveticaNeue / georgia | #2F4858 | no | 2 |
| 22 | Fresh Graduate (`ck.entry.fresh-graduate`) | Centered green Optima name over a short rule, Charter text and underlines. | singleColumn | centeredAccent | underlineAccent | dateRight | optima / charter | #2D6A3E | yes | 1 |
| 23 | Student Resume (`ck.entry.student-resume`) | Pale sky sidebar for skills and languages, with boxed blue labels. | sidebarLeft | sidebarCard | boxedLabel | dateBelow | avenirNext / sfPro | #2D4A8A | no | 1 |
| 24 | Internship Resume (`ck.entry.internship-resume`) | Burnt orange bar beside the name, Georgia titles and internships first. | singleColumn | accentRuleLeft | plainBold | dateBelow | georgia / helveticaNeue | #A3420F | yes | 1 |
| 25 | First Job (`ck.entry.first-job`) | Aqua sidebar for skills and languages, Gill Sans with teal side bars. | sidebarRight | sidebarCard | leftBorder | stacked | gillSans / gillSans | #1C5D6B | no | 1 |
| 26 | Software Engineer (`ck.technical.software-engineer`) | Menlo section titles in code blue with dotted leaders. Projects near the top. | singleColumn | leftAligned | dottedRule | dateRight | menlo / sfPro | #2457A6 | yes | 2 |
| 27 | IT Professional (`ck.technical.it-professional`) | Heavy emerald rule under the name, underlined titles and piped skills. | singleColumn | ruledMonogram | underlineAccent | dateBelow | avenirNext / helveticaNeue | #0B6E4F | yes | 2 |
| 28 | Data Analyst (`ck.technical.data-analyst`) | Deep petrol sidebar for tools and certificates, Futura titles on hairlines. | sidebarLeft | sidebarCard | uppercaseRule | dateRight | futura / sfPro | #1F5F7A | no | 1 |
| 29 | Product Manager (`ck.technical.product-manager`) | Amber bar beside a New York name, small caps titles over Avenir text. | singleColumn | accentRuleLeft | smallCapsAccent | dateRight | newYork / avenirNext | #8A5800 | yes | 2 |
| 30 | Project Manager (`ck.technical.project-manager`) | Initials disc, petrol side bars and a dated timeline column for delivery. | singleColumn | monogramBadge | leftBorder | dateGutter | palatino / helveticaNeue | #245C73 | no | 2 |

## Cover letter templates (10)

| Id | Header | Fonts (heading / body) | Accent | Pairs with |
|---|---|---|---|---|
| ck.letter.executive | letterhead | baskerville / charter | #1B2A4A | ck.professional.executive |
| ck.letter.corporate | leftBlock | helveticaNeue / helveticaNeue | #1D4E89 | ck.professional.corporate |
| ck.letter.classic | centered | palatino / palatino | #6E1F2B | ck.professional.classic-professional |
| ck.letter.minimal | rightBlock | futura / avenirNext | #155E63 | ck.modern.modern-minimal |
| ck.letter.elegant | sideRule | cochin / hoeflerText | #7B2D45 | ck.modern.elegant |
| ck.letter.grid | banner (#13355B) | sfPro / charter | #1F4E79 | ck.modern.professional-grid |
| ck.letter.editorial | letterhead | didot / georgia | #8E1B1B | ck.creative.editorial |
| ck.letter.academic | leftBlock | charter / charter | #5A2E24 | ck.academic.academic-cv |
| ck.letter.marketing | banner (#2B2F6B) | gillSans / helveticaNeue | #3A3F8F | ck.creative.marketing-professional |
| ck.letter.engineer | sideRule | menlo / sfPro | #2457A6 | ck.technical.software-engineer |

All six header layouts are used. Each pair shares heading font, body font, accent, text colour and banner fill (a test checks this).

## Sample content

15 invented personas, each tied to a category, industry and level: operations executive (Daniela Whitcombe), finance manager (Marcus Lindqvist), project manager (Tomas Ibarra), product manager (Aisha Rahman), marketing lead (Tessa Okafor), nurse (Grace Mwangi), secondary teacher (Claire Hartley), software engineer (Samuel Okonkwo), UX designer (Noor Haddad), IT administrator (Ravi Kulkarni), data analyst (Sofia Marchetti), postdoctoral researcher (Hannah Lindgren), new graduate (Jordan Reyes), student (Amara Singh), first-job seeker (Diego Park). Companies, schools, journals, awards and numbers are invented; emails use `example.com`; phone numbers use 555 style ranges. The mapping from template id to persona is the `persona(for:)` switch, with a fallback by category.

Length control: every sample (one or two pages) goes through `fit(_:template:)`, which trims the least important lines until `SampleFitModel` (`Sources/Templates/SampleFitModel.swift`) estimates the content fits `typicalPages` pages at 95 percent of the usable height. The model mirrors the renderer geometry and was calibrated against the CI PDFs (glyph widths per font, line heights, heading and header heights); its predictions landed within about 5 percent of the measured heights, mostly on the tall side. Trim order: bullets down to two per entry, extra sections down to two entries, jobs beyond the third, skill groups beyond four and education beyond two, then the smallest optional section (awards, memberships, courses, interests, references, volunteer, certifications, languages) in the crowded column when it is no more than 1.5 times the overflow, then one bullet per entry, one entry per extra section, context lines after the first entry, two jobs, three skill groups, one education entry, and as a last resort the smallest optional section. Required sections are never removed and no entry list is emptied. A Python twin of the model, run on the new specs, predicts one-page samples at 230 to 319 words filling 0.86 to 0.95 of the page, and two-page samples at 449 to 593 words. The old `onePageWordBudget` is gone.

## Known gaps and risks

1. **Not compiled, not run.** Expect small compile fixes on the first CI run. The riskiest spots are the large literal arrays in `SampleContent.swift` (type-checker time) and the tuple-returning helper `entryWithMostBullets`.
2. **Page fit is an estimate.** Before this pass, 8 one-page templates rendered on two pages and 6 two-page templates on three. `SampleFitModel` replaces the word budget; if a CI render still spills, lower `fillTarget` in `SampleContent` or raise the font's `charWidth`. The tests only assert loose word ranges (one page 220 to 560, two pages at least 400).
3. **No visual review.** The brief asked for screenshots plus design critique, accessibility review and UX copy review before delivery. Templates are pure data and the renderer belongs to another owner, so there was nothing to screenshot. Run a thumbnail pass once the renderer exists. Text contrast was checked numerically.
4. **Fonts.** CI showed Iowan Old Style is missing on the simulator (it falls back to New York); no template uses it now. Hoefler Text's bold is its Black weight (Elegant entry titles). Didot and Cochin are used for headings and names only.
5. **`SampleContent.swift` is about 1,100 lines**, over the 400 line guide. Ownership allowed only four source files, so the personas stay together there. Splitting into `SampleContent+Personas.swift` is a safe follow-up if the lead allows new files.
6. **Gutter and side-label templates** (Editorial, Project Manager, Creative Minimal, Scientific CV): the side label gutter is now sized from the default titles, so Scientific CV (Publications, Memberships) gets a wider gutter than before. Check it in the next CI render.
7. **Sidebar sections.** The Student sample puts skills, languages and interests in the sidebar through `sidebarSections`. If the renderer ignores that list, they will appear in the main column.
8. Academic CV and Scientific CV use the same Hannah Lindgren content with a different section order (education first versus experience first).
