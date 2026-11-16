import SwiftUI

/// Owns the alerts, dialogs and sheets behind the resume quick actions, and hands the caller a
/// `CKResumeActions` bundle to give to cards and rows. Used by Home and My Resumes.
struct ResumeActionHost<Content: View>: View {
    @EnvironmentObject private var store: DocumentStore

    private let openEditor: (UUID) -> Void
    private let openPreview: (UUID) -> Void
    private let content: (CKResumeActions) -> Content

    @State private var showRename = false
    @State private var renameID: UUID?
    @State private var renameText = ""

    @State private var showDelete = false
    @State private var deleteTarget: Resume?

    @State private var templateTarget: Resume?
    @State private var toast: String?

    init(
        openEditor: @escaping (UUID) -> Void,
        openPreview: @escaping (UUID) -> Void,
        @ViewBuilder content: @escaping (CKResumeActions) -> Content
    ) {
        self.openEditor = openEditor
        self.openPreview = openPreview
        self.content = content
    }

    var body: some View {
        content(actions)
            .alert("Rename resume", isPresented: $showRename) {
                TextField("Resume name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") { commitRename() }
            } message: {
                Text("The name is only for you. It does not appear on the document.")
            }
            .confirmationDialog(
                "Delete this resume?",
                isPresented: $showDelete,
                titleVisibility: .visible,
                presenting: deleteTarget
            ) { target in
                Button("Delete resume", role: .destructive) { performDelete(target) }
                Button("Cancel", role: .cancel) {}
            } message: { target in
                Text("\"\(target.title)\" will be removed from this device. This cannot be undone.")
            }
            .sheet(item: $templateTarget) { target in
                CKTemplatePickerSheet(currentTemplateID: target.templateID) { newTemplateID in
                    changeTemplate(of: target.id, to: newTemplateID)
                }
            }
            .ckToast($toast)
    }

    // MARK: Actions bundle

    private var actions: CKResumeActions {
        CKResumeActions(
            edit: { resume in openEditor(resume.id) },
            preview: { resume in openPreview(resume.id) },
            duplicate: { resume in duplicate(resume) },
            rename: { resume in beginRename(resume) },
            changeTemplate: { resume in templateTarget = resume },
            toggleArchive: { resume in toggleArchive(resume) },
            createFromExisting: { resume in createFromExisting(resume) },
            delete: { resume in
                deleteTarget = resume
                showDelete = true
            }
        )
    }

    // MARK: Implementations

    private func duplicate(_ resume: Resume) {
        if let copy = store.duplicate(resumeID: resume.id) {
            toast = String(localized: "Duplicated as \"\(copy.title)\"")
        }
    }

    private func beginRename(_ resume: Resume) {
        renameID = resume.id
        renameText = resume.title
        showRename = true
    }

    private func commitRename() {
        guard let id = renameID, var current = store.resume(id: id) else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != current.title else { return }
        current.title = trimmed
        store.upsert(current)
        toast = String(localized: "Renamed")
    }

    private func toggleArchive(_ resume: Resume) {
        let archive = !resume.isArchived
        store.setArchived(archive, resumeID: resume.id)
        toast = archive
            ? String(localized: "Archived. Find it under Archived in My Resumes.")
            : String(localized: "Moved back to your resumes")
    }

    private func createFromExisting(_ resume: Resume) {
        if let copy = store.duplicate(resumeID: resume.id) {
            openEditor(copy.id)
        }
    }

    private func performDelete(_ resume: Resume) {
        store.delete(resumeID: resume.id)
        toast = String(localized: "Deleted \"\(resume.title)\"")
    }

    private func changeTemplate(of id: UUID, to templateID: String) {
        guard var current = store.resume(id: id), current.templateID != templateID else { return }
        current.templateID = templateID
        store.upsert(current)
        let name = TemplateLibrary.spec(id: templateID)?.name ?? String(localized: "the new template")
        toast = String(localized: "Now using \(name)")
    }
}
