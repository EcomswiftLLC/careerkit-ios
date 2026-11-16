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
            text: "Turning a finished document into a file leaves the app: saving it to Files, sharing it, or printing it. Each of those starts with one optional short video."
        ),
        Block(
            title: "File types you can export",
            text: "PDF keeps your design exactly and is the best choice for most applications. Word (.docx) and Rich Text open as editable documents in Word, Pages or Google Docs. Plain text is for pasting into online application forms. A web page opens in any browser. Printing is available for PDF."
        ),
        Block(
            title: "What one video covers",
            text: "One completed video covers one export of that document, in any file type, and stays valid for 24 hours. It is used up once the export finishes, so the next export asks again."
        ),
        Block(
            title: "If a video is not available",
            text: "If no video can be shown, for example when you are offline or no ad is available, the app says so and lets you export without a video. Your document is never lost or locked."
        ),
        Block(
            title: "Banner ads",
            text: "A small labelled banner appears at the end of the lists on Home, My Resumes, Templates, Cover Letters and Profile. It never appears in the editor, the preview or the export screen. You can report an ad from Profile."
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
