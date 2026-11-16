import SwiftUI
import UIKit

/// Runs the general ATS guidance checks on a freshly rendered PDF and shows the results grouped by importance.
/// Expects to sit inside a NavigationStack.
struct ATSCheckView: View {
    let resumeID: UUID

    private struct CheckResult {
        let report: ATSReport
        let extractedText: String
        let pageCount: Int
    }

    private enum Phase {
        case running
        case finished(CheckResult)
    }

    @EnvironmentObject private var store: DocumentStore
    @State private var phase: Phase = .running
    @State private var copied = false
    @State private var showText = false
    @State private var runToken = 0

    init(resumeID: UUID) {
        self.resumeID = resumeID
    }

    var body: some View {
        Group {
            if store.resume(id: resumeID) == nil {
                EdUnavailableView(title: "This resume is no longer available",
                                  message: "It may have been deleted.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: CK.Space.l) {
                        header
                        disclaimerCard
                        switch phase {
                        case .running:
                            runningView
                        case .finished(let result):
                            resultsView(result)
                        }
                        // Job ad keyword match. The pasted ad stays in memory only.
                        JobMatchSection(resumeID: resumeID)
                    }
                    .padding(CK.Space.m)
                    .padding(.bottom, CK.Space.xl)
                }
            }
        }
        .background(CK.Palette.ivory.ignoresSafeArea())
        .navigationTitle("ATS check")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: runToken) { await runCheck() }
    }

    // MARK: Header and disclaimer

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How machine-readable is this resume?")
                .font(CK.Font.title(26))
                .foregroundStyle(CK.Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Applicant tracking systems read the text inside your PDF. These checks look at the document the same way, using the exact file you would export.")
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.graphite)
        }
    }

    private var disclaimerText: String {
        if case .finished(let result) = phase { return result.report.disclaimer }
        return "These checks are general guidance. They are not a score from any employer's system, and they cannot promise that a resume will be accepted or shortlisted."
    }

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: CK.Space.s + 4) {
            Image(systemName: "info.circle")
                .font(.system(size: 18))
                .foregroundStyle(CK.Palette.forest)
                .accessibilityHidden(true)
            Text(disclaimerText)
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CK.Space.m)
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.champagne.opacity(0.7), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: States

    private var runningView: some View {
        HStack(spacing: CK.Space.s + 4) {
            ProgressView()
            Text("Checking your resume")
                .font(CK.Font.body)
                .foregroundStyle(CK.Palette.graphite)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .accessibilityElement(children: .combine)
    }

    private func resultsView(_ result: CheckResult) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            summaryLine(result)
            group(title: "Needs attention", severity: .warning, findings: result.report.findings)
            group(title: "Worth knowing", severity: .info, findings: result.report.findings)
            group(title: "Looks good", severity: .good, findings: result.report.findings)
            extractionSection(result)
            Button {
                phase = .running
                copied = false
                runToken += 1
            } label: {
                Label("Check again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.ckSecondary)
        }
    }

    private func summaryLine(_ result: CheckResult) -> some View {
        let warnings = result.report.warningCount
        let text: String
        if warnings == 0 {
            text = "No items need attention."
        } else if warnings == 1 {
            text = "1 item needs attention."
        } else {
            text = "\(warnings) items need attention."
        }
        let pages = result.pageCount == 1 ? "1 page" : "\(result.pageCount) pages"
        return Text("\(text) The document has \(pages).")
            .font(CK.Font.headline(18))
            .foregroundStyle(CK.Palette.ink)
    }

    @ViewBuilder
    private func group(title: String, severity: ATSFinding.Severity, findings: [ATSFinding]) -> some View {
        let items = findings.filter { $0.severity == severity }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(CK.Font.headline(18))
                    .foregroundStyle(CK.Palette.ink)
                    .padding(.bottom, CK.Space.s)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { pair in
                        findingRow(pair.element, severity: severity)
                        if pair.offset < items.count - 1 {
                            Rectangle().fill(CK.Palette.hairline).frame(height: 0.5).padding(.leading, 44)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
            }
        }
    }

    private func findingRow(_ finding: ATSFinding, severity: ATSFinding.Severity) -> some View {
        HStack(alignment: .top, spacing: CK.Space.s + 4) {
            Image(systemName: symbol(for: severity))
                .font(.system(size: 18))
                .foregroundStyle(color(for: severity))
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(finding.title)
                    .font(CK.Font.label)
                    .foregroundStyle(CK.Palette.ink)
                Text(finding.detail)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(CK.Space.m)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label(for: severity)): \(finding.title). \(finding.detail)")
    }

    private func symbol(for severity: ATSFinding.Severity) -> String {
        switch severity {
        case .good: return "checkmark.circle"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        }
    }

    private func color(for severity: ATSFinding.Severity) -> Color {
        switch severity {
        case .good: return CK.Palette.forest
        case .info: return CK.Palette.graphite
        case .warning: return CK.Palette.danger
        }
    }

    private func label(for severity: ATSFinding.Severity) -> String {
        switch severity {
        case .good: return "Looks good"
        case .info: return "Worth knowing"
        case .warning: return "Needs attention"
        }
    }

    // MARK: Text extraction

    private func extractionSection(_ result: CheckResult) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            Text("Text extraction")
                .font(CK.Font.headline(18))
                .foregroundStyle(CK.Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("This is the plain text a parser can read from your PDF. If something is missing or out of order here, a system may miss it too.")
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.graphite)
            HStack {
                EdTextButton(title: showText ? "Hide text" : "Show text", systemImage: showText ? "chevron.up" : "chevron.down") {
                    showText.toggle()
                }
                Spacer()
                EdTextButton(title: copied ? "Copied" : "Copy text", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = result.extractedText
                    copied = true
                }
            }
            if showText {
                Text(result.extractedText.isEmpty ? "No text could be read from this document." : result.extractedText)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(CK.Palette.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CK.Space.m)
                    .background(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).fill(CK.Palette.ivory))
                    .overlay(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 1))
            }
        }
    }

    // MARK: Work

    private func runCheck() async {
        guard let resume = store.resume(id: resumeID) else { return }
        let template = EditorRender.template(id: resume.templateID)
        let outcome: CheckResult = await Task.detached(priority: .userInitiated) {
            let document = DocumentRenderer.render(resume, template: template)
            let report = ATSAnalyzer.analyze(resume: resume, template: template, pdfData: document.pdfData)
            let text = PDFValidator.extractText(from: document.pdfData)
            return CheckResult(report: report, extractedText: text, pageCount: document.pageCount)
        }.value
        if Task.isCancelled { return }
        phase = .finished(outcome)
    }
}
