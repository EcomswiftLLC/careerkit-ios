import Foundation

extension Notification.Name {
    /// Posted on the main thread after "Delete all local data".
    /// Any in-memory cache that can hold pictures of the person's documents (for example `CKImageCache`
    /// in DesignSystem and the thumbnail caches in Preview) should observe it and remove everything.
    /// Posting is safe even when nothing observes it.
    static let ckCachesShouldClear = Notification.Name("CKCachesShouldClear")
}

/// Everything "Delete all local data" has to reset, in one place.
@MainActor
enum CKLocalDataReset {
    /// Deletes documents, quarantine, newer-version files, export grants, temporary share files,
    /// asks caches to clear, forgets the local name and rebuilds the tabs' navigation.
    /// Every step runs even if an earlier one failed; the first file error is rethrown at the end.
    static func eraseEverything(store: DocumentStore, exportGate: ExportGate, appState: AppState) throws {
        var firstError: Error? = nil
        do {
            try store.deleteAllData()
        } catch {
            firstError = error
        }

        // Export grants: forget every stored grant, not only the ones for documents that still existed.
        let grantedIDs: [UUID] = exportGate.logic.grants.map { $0.documentID }
        for id in Set(grantedIDs) {
            exportGate.forget(documentID: id)
        }

        CKTempFiles.removeAll()
        NotificationCenter.default.post(name: .ckCachesShouldClear, object: nil)

        appState.displayName = ""
        appState.resetNavigation()

        if let error = firstError {
            throw error
        }
    }
}
