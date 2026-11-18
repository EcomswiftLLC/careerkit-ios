import SwiftUI

/// One entry in the career tools row.
struct CKToolTile: View {
    let systemImage: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: CK.Space.s) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CK.Palette.forest)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(CK.Palette.forest.opacity(0.10)))
                Text(title)
                    .font(CK.Font.label)
                    .foregroundStyle(CK.Palette.ink)
                    .multilineTextAlignment(.leading)
                Text(detail)
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .ckCard(padding: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title). \(detail)"))
        .accessibilityAddTraits(.isButton)
    }
}

/// Shortcut into the Cover Letters tab, drawn with the paper motif.
struct CKCoverLetterShortcut: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CK.Space.m) {
                CKPaperSheet(lineCount: 6, accent: CK.Palette.champagne)
                    .frame(width: 58, height: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Write a matching cover letter")
                        .font(CK.Font.headline(17))
                        .foregroundStyle(CK.Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text("Ten letter templates share the look of your resume. Your details are filled in from the resume you choose.")
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CK.Palette.graphite)
            }
            .frame(minHeight: 76)
            .ckCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Write a matching cover letter. Opens Cover Letters."))
        .accessibilityAddTraits(.isButton)
    }
}

/// States the business model in plain words, with a link to the longer explanation.
struct CKFreeModelCard: View {
    let learnMore: () -> Void
    @EnvironmentObject private var exportStore: ExportStore

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.s + 2) {
            Text("How CareerKit stays free")
                .ckHeadline(19)
                .accessibilityAddTraits(.isHeader)
            Text(exportStore.offersPurchases
                 ? String(localized: "Writing, editing, previewing and the ATS check are free. Saving, sharing or printing a finished document uses one export. You can buy a pack of 3 exports or Premium for unlimited exports, or watch one short video to export once. Banner ads appear at the end of browse screens, and never in the editor.")
                 : String(localized: "There is no subscription and no paywall. Banner ads appear at the bottom of browse screens, and never in the editor. Exporting a finished document needs one short rewarded video that you choose to watch. Writing, editing, previewing and the ATS check never show an ad."))
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: learnMore) {
                Text("How exports work")
                    .font(CK.Font.label)
                    .foregroundStyle(CK.Palette.forest)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ckCard(padding: CK.Space.m + 2)
    }
}

/// Lets the person choose which resume a tool (such as the ATS check) should run on.
struct CKResumePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String
    let resumes: [Resume]
    let onPick: (UUID) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(resumes) { resume in
                        Button {
                            onPick(resume.id)
                        } label: {
                            HStack(spacing: CK.Space.m) {
                                CKResumeThumbnail(resume: resume, width: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resume.title)
                                        .font(CK.Font.label)
                                        .foregroundStyle(CK.Palette.ink)
                                    Text(CKResumeMeta.templateName(resume))
                                        .font(CK.Font.caption)
                                        .foregroundStyle(CK.Palette.graphite)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(CK.Palette.graphite)
                            }
                            .frame(minHeight: 56)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(CK.Palette.surface)
                    }
                } footer: {
                    Text(message)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .ckScreen()
        }
        .presentationDetents([.medium, .large])
    }
}
