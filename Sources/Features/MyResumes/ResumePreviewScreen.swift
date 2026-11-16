import SwiftUI

/// The read-only preview pushed from Home and My Resumes, with an Export button in the toolbar.
/// Export uses the same flow as the editor (one opt-in video per export, see `ExportFlowSheet`).
struct ResumePreviewScreen: View {
    let resumeID: UUID

    @EnvironmentObject private var store: DocumentStore
    @State private var exportSnapshot: Resume?

    var body: some View {
        ResumePreviewView(resumeID: resumeID)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let resume = store.resume(id: resumeID) {
                        Button {
                            exportSnapshot = resume
                        } label: {
                            Text("Export")
                                .font(CK.Font.label)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(Text("Export"))
                        .accessibilityHint(Text("Opens the options to share or save this resume as a PDF, Word, Rich Text, plain text or web page file"))
                    }
                }
            }
            .sheet(item: $exportSnapshot) { (snapshot: Resume) in
                ExportFlowSheet(documentID: snapshot.id,
                                fileName: FileNaming.safeFileName(snapshot.title, fallback: "Resume"),
                                source: ExportSource.forResume(snapshot))
            }
    }
}
