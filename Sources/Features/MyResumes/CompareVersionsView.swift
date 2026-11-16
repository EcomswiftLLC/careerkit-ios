import SwiftUI

/// Pick two resumes and read them next to each other. Previews are the real rendered first pages.
struct CKCompareVersionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DocumentStore

    let candidates: [Resume]

    @State private var leftID: UUID
    @State private var rightID: UUID
    @State private var contentWidth: CGFloat = 0
    @State private var fullPreview: CKUUIDItem?

    init(candidates: [Resume]) {
        self.candidates = candidates
        let first = candidates.first?.id ?? UUID()
        let second = candidates.dropFirst().first?.id ?? first
        _leftID = State(initialValue: first)
        _rightID = State(initialValue: second)
    }

    private let gap: CGFloat = 16

    private var columnWidth: CGFloat {
        guard contentWidth > 0 else { return 150 }
        return max(120, floor((contentWidth - gap) / 2))
    }

    private func resume(for id: UUID) -> Resume? {
        store.resume(id: id) ?? candidates.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.l) {
                    Text("Choose two resumes to compare. This shows what each one contains right now. It does not track edits over time.")
                        .font(CK.Font.callout)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)

                    if let left = resume(for: leftID), let right = resume(for: rightID) {
                        HStack(alignment: .top, spacing: gap) {
                            column(resume: left, selection: $leftID, side: String(localized: "First"),
                                   accessibilityName: String(localized: "First resume"))
                            column(resume: right, selection: $rightID, side: String(localized: "Second"),
                                   accessibilityName: String(localized: "Second resume"))
                        }
                        comparisonTable(left: left, right: right)
                    }
                }
                .ckReadWidth($contentWidth)
                .padding(CK.Space.m)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Compare versions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .ckScreen()
            .sheet(item: $fullPreview) { item in
                NavigationStack {
                    ResumePreviewView(resumeID: item.id)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { fullPreview = nil }
                            }
                        }
                }
            }
        }
    }

    // MARK: Columns

    private func column(resume: Resume, selection: Binding<UUID>, side: String, accessibilityName: String) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.s + 2) {
            Menu {
                Picker(side, selection: selection) {
                    ForEach(candidates) { option in
                        Text(option.title).tag(option.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(resume.title)
                        .font(CK.Font.label)
                        .foregroundStyle(CK.Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CK.Palette.graphite)
                }
                .padding(.horizontal, 12)
                .frame(width: columnWidth)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).fill(CK.Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous)
                        .strokeBorder(CK.Palette.hairline, lineWidth: 1)
                )
            }
            .accessibilityLabel(Text(accessibilityName))
            .accessibilityValue(Text(resume.title))

            CKResumeThumbnail(resume: resume, width: columnWidth)

            Text(CKResumeMeta.templateName(resume))
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
            Text(CKDate.edited(resume.updatedAt))
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)

            Button {
                fullPreview = CKUUIDItem(id: resume.id)
            } label: {
                Text("Open full preview")
                    .font(CK.Font.label)
                    .foregroundStyle(CK.Palette.forest)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: columnWidth, alignment: .leading)
    }

    // MARK: Table

    private func comparisonTable(left: Resume, right: Resume) -> some View {
        let leftStats = CKResumeStats(left)
        let rightStats = CKResumeStats(right)
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            Text("Side by side")
                .ckHeadline(20)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                CKHairline()
                row(String(localized: "Template"), CKResumeMeta.templateName(left), CKResumeMeta.templateName(right))
                row(String(localized: "Completion"), "\(CKResumeMeta.completionPercent(left)) %", "\(CKResumeMeta.completionPercent(right)) %")
                row(String(localized: "Sections with content"), "\(leftStats.sectionsWithContent)", "\(rightStats.sectionsWithContent)")
                row(String(localized: "Entries"), "\(leftStats.entries)", "\(rightStats.entries)")
                row(String(localized: "Bullet points"), "\(leftStats.bullets)", "\(rightStats.bullets)")
                row(String(localized: "Words"), "\(leftStats.words)", "\(rightStats.words)")
                row(String(localized: "Paper size"), left.pageSize.displayName, right.pageSize.displayName)
            }
        }
    }

    private func row(_ label: String, _ leftValue: String, _ rightValue: String) -> some View {
        let differs = leftValue != rightValue
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: CK.Space.s) {
                Text(label)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(leftValue)
                    .font(CK.Font.callout.weight(differs ? .semibold : .regular))
                    .foregroundStyle(CK.Palette.ink)
                    .frame(width: columnWidth * 0.55, alignment: .trailing)
                Text(rightValue)
                    .font(CK.Font.callout.weight(differs ? .semibold : .regular))
                    .foregroundStyle(CK.Palette.ink)
                    .frame(width: columnWidth * 0.55, alignment: .trailing)
            }
            .padding(.vertical, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(differs
                ? String(localized: "\(label): first \(leftValue), second \(rightValue), different")
                : String(localized: "\(label): first \(leftValue), second \(rightValue)")))
            CKHairline()
        }
    }
}
