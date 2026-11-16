import SwiftUI

/// Plain explanation of the one place an ad is required.
struct CKHowExportsWorkView: View {
    private struct Block: Identifiable {
        let id = UUID()
        let title: LocalizedStringKey
        let text: LocalizedStringKey
    }

    private let blocks: [Block] = [
        Block(
            title: "What is free",
            text: "Creating resumes and cover letters, editing, changing templates, previewing, the ATS check and saving drafts are all free, with no ad and no limit."
        ),
        Block(
            title: "What needs a short video",
            text: "Turning a finished document into a file leaves the app: saving the PDF to Files, sharing it, or printing it. Each of those needs you to watch one short rewarded video first."
        ),
        Block(
            title: "What one video covers",
            text: "One completed video covers one export of that document. The permission is used up once the export finishes, so the next export asks again."
        ),
        Block(
            title: "If a video is not available",
            text: "Videos need an internet connection and an ad to be available. If none loads you can try again in a moment. Your document is never lost or locked."
        ),
        Block(
            title: "Banner ads",
            text: "A small banner sits at the bottom of Home, My Resumes, Templates, Cover Letters and Profile. It never appears in the editor, the preview or the export screen."
        ),
        Block(
            title: "Your documents and your choices",
            text: "Resumes and cover letters stay on this device, and there is no account. Ads are provided by Google AdMob and follow the consent choices you make. If your region requires it, Profile shows an Ad privacy choices row where you can change them."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CK.Space.l) {
                Text("CareerKit has no subscription and no paywall. This is the full picture of where ads appear and why.")
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    CKHairline()
                    ForEach(blocks) { block in
                        VStack(alignment: .leading, spacing: CK.Space.s) {
                            Text(block.title)
                                .ckHeadline(19)
                                .accessibilityAddTraits(.isHeader)
                            Text(block.text)
                                .font(CK.Font.callout)
                                .foregroundStyle(CK.Palette.graphite)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, CK.Space.m)
                        CKHairline()
                    }
                }
            }
            .padding(CK.Space.m)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("How exports work")
        .navigationBarTitleDisplayMode(.inline)
        .ckScreen()
    }
}
