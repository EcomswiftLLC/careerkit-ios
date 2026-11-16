import Foundation

/// One self-contained HTML file: no scripts, no external files, all user text escaped.
/// The page always shows dark text on a white sheet (also in dark mode) and prints on the chosen paper size.
enum HTMLExporter {
    static func data(_ document: ExportDocument) -> Data {
        return Data(html(document).utf8)
    }

    static func html(_ document: ExportDocument) -> String {
        let accent: String = "#" + ExportText.hexDigits(document.accentHex, fallback: "1F4D3A")
        let ink: String = "#" + ExportText.hexDigits(document.inkHex, fallback: "1F2421")
        let muted: String = "#" + ExportText.hexDigits(document.mutedHex, fallback: "5B605C")
        let bodyStack: String = ExportFonts.cssStack(document.bodyFont)
        let headingStack: String = ExportFonts.cssStack(document.headingFont)
        let paper: String = document.pageSize == .usLetter ? "letter" : "A4"
        let pageWidth: Int = Int(Double(document.pageSize.size.width).rounded())
        let rtl: Bool = document.isMostlyRightToLeft
        // The language of right to left text is not known (Arabic, Hebrew, Persian...), so no lang is claimed.
        let langAttribute: String = rtl ? "" : " lang=\"en\""
        let dir: String = rtl ? "rtl" : "ltr"
        let title: String = document.title.isEmpty ? String(localized: "Document") : document.title

        var out: String = ""
        out += "<!DOCTYPE html>\n"
        out += "<html" + langAttribute + " dir=\"" + dir + "\">\n<head>\n"
        out += "<meta charset=\"utf-8\">\n"
        out += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        out += "<meta name=\"color-scheme\" content=\"light\">\n"
        out += "<meta name=\"generator\" content=\"CareerKit\">\n"
        if !document.author.isEmpty {
            out += "<meta name=\"author\" content=\"" + ExportText.htmlEscape(document.author) + "\">\n"
        }
        out += "<title>" + ExportText.htmlEscape(title) + "</title>\n"
        out += "<style>\n"
        out += css(accent: accent, ink: ink, muted: muted, bodyStack: bodyStack, headingStack: headingStack,
                   document: document, paper: paper, pageWidth: pageWidth)
        out += "</style>\n</head>\n<body>\n"
        out += "<main class=\"sheet\">\n"
        out += body(document)
        out += "</main>\n</body>\n</html>\n"
        return out
    }

    // MARK: CSS

    private static func css(accent: String, ink: String, muted: String, bodyStack: String, headingStack: String,
                            document: ExportDocument, paper: String, pageWidth: Int) -> String {
        let body: String = format(document.bodySize)
        let heading: String = format(document.headingSize * 1.05)
        let name: String = format(document.nameSize)
        let line: String = format(document.lineSpacing * 1.2)
        let top: String = format(document.marginTop)
        let side: String = format(document.marginSide)
        let bottom: String = format(document.marginBottom)
        let transform: String = document.uppercaseHeadings ? "uppercase" : "none"
        let tracking: String = document.uppercaseHeadings ? "0.06em" : "0"

        var c: String = ""
        c += ":root { color-scheme: light; --accent: \(accent); --ink: \(ink); --muted: \(muted); }\n"
        c += "* { box-sizing: border-box; }\n"
        c += "html { background: #ECEAE4; -webkit-text-size-adjust: 100%; }\n"
        c += "body { margin: 0; padding: 24px 12px; background: #ECEAE4; color: var(--ink); font-family: \(bodyStack); font-size: \(body)pt; line-height: \(line); }\n"
        c += ".sheet { max-width: \(pageWidth)pt; margin: 0 auto; padding: \(top)pt \(side)pt \(bottom)pt; background: #FFFFFF; color: var(--ink); box-shadow: 0 1px 4px rgba(0,0,0,0.12); overflow-wrap: anywhere; }\n"
        c += "@media (prefers-color-scheme: dark) { html, body { background: #2A2C2B; } .sheet { background: #FFFFFF; color: var(--ink); } }\n"
        c += "@media (max-width: 640px) { body { padding: 0; } .sheet { padding: 24px 16px; box-shadow: none; } }\n"
        c += "header { margin-bottom: 14pt; }\n"
        c += "h1 { font-family: \(headingStack); font-size: \(name)pt; line-height: 1.1; margin: 0 0 4pt; color: var(--ink); }\n"
        c += ".subtitle { margin: 0 0 4pt; color: var(--accent); font-size: 1.1em; }\n"
        c += ".contact { margin: 0; color: var(--muted); font-size: 0.92em; }\n"
        c += ".sep { color: var(--muted); }\n"
        c += "a { color: var(--accent); text-decoration: underline; text-underline-offset: 2px; }\n"
        c += "h2 { font-family: \(headingStack); font-size: \(heading)pt; color: var(--accent); text-transform: \(transform); letter-spacing: \(tracking); margin: 16pt 0 6pt; padding-bottom: 3pt; border-bottom: 1px solid var(--accent); break-after: avoid; page-break-after: avoid; }\n"
        c += "h3 { font-size: 1em; margin: 10pt 0 0; break-after: avoid; page-break-after: avoid; }\n"
        c += "h2 + h3 { margin-top: 0; }\n"
        c += "p { margin: 0 0 6pt; }\n"
        c += "p.meta { margin: 1pt 0 3pt; }\n"
        c += ".muted { color: var(--muted); }\n"
        c += "p.note { margin: 0 0 3pt; font-style: italic; color: var(--muted); font-size: 0.92em; }\n"
        c += "p.line { margin: 0; }\n"
        c += "p.gap { margin: 0; height: 1em; }\n"
        c += "p.signature { margin: 0; font-weight: bold; }\n"
        c += "ul { margin: 2pt 0 6pt; padding-inline-start: 1.2em; }\n"
        c += "li { margin: 0 0 2pt; break-inside: avoid; page-break-inside: avoid; }\n"
        c += "li::marker { color: var(--accent); }\n"
        c += "@page { size: \(paper); margin: \(top)pt \(side)pt \(bottom)pt; }\n"
        c += "@media print { html, body { background: #FFFFFF; padding: 0; } .sheet { max-width: none; margin: 0; padding: 0; box-shadow: none; } a { color: inherit; text-decoration: none; } }\n"
        return c
    }

    private static func format(_ value: Double) -> String {
        let rounded: Double = (value * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), rounded)
    }

    // MARK: Body

    private static func body(_ document: ExportDocument) -> String {
        var out: String = ""
        var headerOpen: Bool = false
        var sectionOpen: Bool = false
        var listOpen: Bool = false

        func closeList() {
            if listOpen {
                out += "</ul>\n"
                listOpen = false
            }
        }
        func closeHeader() {
            if headerOpen {
                out += "</header>\n"
                headerOpen = false
            }
        }
        func closeSection() {
            closeList()
            if sectionOpen {
                out += "</section>\n"
                sectionOpen = false
            }
        }

        var headerDone: Bool = false
        for block in document.blocks {
            let content: String = runs(block.runs)
            switch block.kind {
            case .name, .subtitle, .contact:
                if !headerOpen && !headerDone && !sectionOpen {
                    out += "<header>\n"
                    headerOpen = true
                    headerDone = true
                }
                if block.kind == .name {
                    out += "<h1 dir=\"auto\">" + content + "</h1>\n"
                } else if block.kind == .subtitle {
                    out += "<p class=\"subtitle\" dir=\"auto\">" + content + "</p>\n"
                } else {
                    out += "<p class=\"contact\" dir=\"auto\">" + content + "</p>\n"
                }
            case .heading:
                closeHeader()
                closeSection()
                out += "<section>\n<h2 dir=\"auto\">" + content + "</h2>\n"
                sectionOpen = true
            case .entryTitle:
                closeHeader()
                closeList()
                out += "<h3 dir=\"auto\">" + content + "</h3>\n"
            case .entryMeta:
                closeHeader()
                closeList()
                out += "<p class=\"meta\" dir=\"auto\">" + content + "</p>\n"
            case .entryNote:
                closeHeader()
                closeList()
                out += "<p class=\"note\" dir=\"auto\">" + content + "</p>\n"
            case .paragraph:
                closeHeader()
                closeList()
                out += "<p dir=\"auto\">" + content + "</p>\n"
            case .line:
                closeHeader()
                closeList()
                out += "<p class=\"line\" dir=\"auto\">" + content + "</p>\n"
            case .signature:
                closeHeader()
                closeList()
                out += "<p class=\"signature\" dir=\"auto\">" + content + "</p>\n"
            case .gap:
                closeHeader()
                closeList()
                out += "<p class=\"gap\" aria-hidden=\"true\"></p>\n"
            case .bullet:
                closeHeader()
                if !listOpen {
                    out += "<ul>\n"
                    listOpen = true
                }
                out += "<li dir=\"auto\">" + content + "</li>\n"
            }
        }
        closeHeader()
        closeSection()
        return out
    }

    private static func runs(_ runs: [ExportRun]) -> String {
        var out: String = ""
        for run in runs where !run.text.isEmpty {
            var piece: String = ExportText.htmlEscape(run.text).replacingOccurrences(of: "\n", with: "<br>")
            if let link = ExportText.safeLink(run.url) {
                piece = "<a href=\"" + ExportText.htmlEscape(link) + "\">" + piece + "</a>"
            }
            if run.italic { piece = "<em>" + piece + "</em>" }
            if run.bold { piece = "<strong>" + piece + "</strong>" }
            if run.muted {
                let isSeparator: Bool = run.text.trimmingCharacters(in: CharacterSet.whitespaces) == "|"
                piece = "<span class=\"" + (isSeparator ? "sep" : "muted") + "\">" + piece + "</span>"
            }
            out += piece
        }
        return out
    }
}
