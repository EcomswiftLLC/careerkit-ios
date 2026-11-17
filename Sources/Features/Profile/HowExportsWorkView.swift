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
            title: "What uses an export",
            text: "Turning a finished document into a file leaves the app: saving it to Files, sharing it, or printing it. Each of those uses one export. Your backup and the text you copy from the ATS check do not."
        ),
        Block(
            title: "Ways to get exports",
            text: "An export pack gives you 3 exports for one purchase. Premium is one purchase with no limit and no subscription. Or you can watch one short video to export one document once. Prices are shown by the App Store before you buy."
        ),
        Block(
            title: "File types you can export",
            text: "PDF keeps your design exactly and is the best choice for most applications. Word (.docx) and Rich Text open as editable documents in Word, Pages or Google Docs. Plain text is for pasting into online application forms. A web page opens in any browser. Printing is available for PDF."
        ),
        Block(
            title: "When an export is used up",
            text: "An export is used up only after the file was really saved, shared or printed. If you close the share sheet or something goes wrong, nothing is used. One export covers one file in any type."
        ),
        Block(
            title: "What one video covers",
            text: "One completed video covers one export of that document, in any file type, and stays valid for 24 hours. It is used up once the export finishes."
        ),
        Block(
            title: "If a video or the App Store is not available",
            text: "If no video can be shown, or the App Store cannot be reached, the app says so and nothing is unlocked or charged. Your documents are never lost or locked, and you can still edit and preview them."
        ),
        Block(
            title: "Restoring purchases",
            text: "Premium can be restored on a new device with Restore purchases in Profile. Export packs are used up as you export, so they cannot be restored."
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
                Text("CareerKit is free to use. This is the full picture of what is free, what uses an export, and where ads appear.")
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
