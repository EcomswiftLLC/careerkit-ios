import SwiftUI
import UIKit

/// "Compare with a job ad" block on the ATS check screen. The pasted ad lives only in memory: it is not saved,
/// sent or attached to the resume.
struct JobMatchSection: View {
    let resumeID: UUID

    @EnvironmentObject private var store: DocumentStore
    @State private var jobText: String = ""
    @State private var result: JobMatchResult?
    @State private var isComparing = false
    @State private var compareToken = 0

    private var trimmedJob: String {
        jobText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Compare with a job ad")
                    .font(CK.Font.headline(18))
                    .foregroundStyle(CK.Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Paste a job description to see which of its key terms already appear in this resume. The text stays on this device and is not saved.")
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }

            EdTextArea(label: String(localized: "Job description"),
                       text: $jobText,
                       prompt: String(localized: "Paste the job ad here"),
                       minHeight: 150)

            if jobText.count > JobMatchAnalyzer.maxInputLength {
                Text("This ad is long. Only the first 20,000 characters are compared.")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
            }

            HStack(spacing: CK.Space.s + 4) {
                Button {
                    compare()
                } label: {
                    if isComparing {
                        ProgressView()
                            .tint(CK.Palette.onForest)
                            .accessibilityLabel("Comparing")
                    } else {
                        Text("Compare")
                    }
                }
                .buttonStyle(.ckPrimary)
                .disabled(trimmedJob.isEmpty || isComparing)
                .accessibilityIdentifier("ats.jobMatch.compare")

                if !jobText.isEmpty || result != nil {
                    Button {
                        clear()
                    } label: {
                        Text("Clear")
                    }
                    .buttonStyle(.ckSecondary)
                    .frame(maxWidth: 140)
                    .accessibilityHint("Removes the pasted job ad and the results")
                }
            }

            if let result {
                resultsView(result)
            } else {
                emptyState
            }
        }
        .padding(CK.Space.m)
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
    }

    // MARK: States

    private var emptyState: some View {
        HStack(alignment: .top, spacing: CK.Space.s + 4) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 18))
                .foregroundStyle(CK.Palette.forest)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text("No job ad yet. Paste one above and tap Compare to see the terms it shares with your resume.")
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CK.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).fill(CK.Palette.ivory))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func resultsView(_ result: JobMatchResult) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            Text(result.summary)
                .ckHeadlineFont(20)
                .foregroundStyle(CK.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("ats.jobMatch.summary")

            if result.hasTerms {
                Text("Terms are ranked by how often the ad uses them and whether they appear in its requirements. This is a wording check, not a score from any employer's system.")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if result.wasTruncated {
                Text("Only the first 20,000 characters of the ad were compared.")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
            }

            if !result.matched.isEmpty {
                chipGroup(title: String(localized: "Already in your resume"), keywords: result.matched, found: true)
            }
            if !result.missing.isEmpty {
                chipGroup(title: String(localized: "Not found in your resume"), keywords: result.missing, found: false)
                placementList(result.missing)
                honestyNote
            }
        }
    }

    private func chipGroup(title: String, keywords: [JobMatchKeyword], found: Bool) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            Text("\(title) (\(keywords.count))")
                .font(CK.Font.label)
                .foregroundStyle(CK.Palette.ink)
                .accessibilityAddTraits(.isHeader)
            EdFlowLayout(spacing: 8) {
                ForEach(keywords) { keyword in
                    JobMatchChip(term: keyword.term, found: found)
                }
            }
        }
    }

    /// Missing terms grouped by the section they would most naturally go in.
    private func placementList(_ missing: [JobMatchKeyword]) -> some View {
        let order: [SectionKind] = [.summary, .experience, .skills, .education, .certifications]
        var groups: [(SectionKind, [JobMatchKeyword])] = []
        for kind in order {
            let items: [JobMatchKeyword] = missing.filter { $0.suggestedSection == kind }
            if !items.isEmpty { groups.append((kind, items)) }
        }
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            Text("Where they could go")
                .font(CK.Font.label)
                .foregroundStyle(CK.Palette.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.offset) { pair in
                    let kind: SectionKind = pair.element.0
                    let terms: String = pair.element.1.map { $0.term }.joined(separator: ", ")
                    HStack(alignment: .top, spacing: CK.Space.s + 4) {
                        Image(systemName: kind.systemImage)
                            .font(.system(size: 15))
                            .foregroundStyle(CK.Palette.forest)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.defaultTitle)
                                .font(CK.Font.label)
                                .foregroundStyle(CK.Palette.ink)
                            Text(terms)
                                .font(CK.Font.callout)
                                .foregroundStyle(CK.Palette.graphite)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, CK.Space.s + 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(kind.defaultTitle): \(terms)")
                    if pair.offset < groups.count - 1 {
                        CKHairline().padding(.leading, 36)
                    }
                }
            }
        }
    }

    private var honestyNote: some View {
        HStack(alignment: .top, spacing: CK.Space.s + 4) {
            Image(systemName: "hand.raised")
                .font(.system(size: 16))
                .foregroundStyle(CK.Palette.forest)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(JobMatchAnalyzer.honestyNote)
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CK.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).fill(CK.Palette.ivory))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).strokeBorder(CK.Palette.champagne.opacity(0.7), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: Work

    private func compare() {
        guard let resume = store.resume(id: resumeID) else { return }
        // Hide the keyboard so the results are visible.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let job: String = jobText
        isComparing = true
        compareToken += 1
        let token: Int = compareToken
        Task {
            let outcome: JobMatchResult = await Task.detached(priority: .userInitiated) {
                JobMatchAnalyzer.analyze(jobDescription: job, resume: resume)
            }.value
            // A Clear or a newer Compare while this one ran wins.
            guard token == compareToken else { return }
            result = outcome
            isComparing = false
            UIAccessibility.post(notification: .announcement, argument: outcome.summary)
        }
    }

    private func clear() {
        compareToken += 1
        jobText = ""
        result = nil
        isComparing = false
    }
}

/// One term. Found terms are forest with a check mark; missing terms are amber with a plus sign, so the state
/// never depends on colour alone. VoiceOver reads the state in words.
struct JobMatchChip: View {
    let term: String
    let found: Bool

    static let amber: Color = CK.Palette.dynamic(light: 0x8A5A0B, dark: 0xE2B25C)

    var body: some View {
        let tint: Color = found ? CK.Palette.forest : JobMatchChip.amber
        HStack(spacing: 5) {
            Image(systemName: found ? "checkmark" : "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(term)
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.ink)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(
            Capsule().strokeBorder(tint.opacity(found ? 0.35 : 0.7),
                                   style: StrokeStyle(lineWidth: 1, dash: found ? [] : [3, 2]))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(found
                            ? String(localized: "\(term), found in your resume")
                            : String(localized: "\(term), not found in your resume"))
    }
}
