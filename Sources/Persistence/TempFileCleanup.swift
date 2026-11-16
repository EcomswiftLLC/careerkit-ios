import Foundation

/// Removes the temporary files CareerKit creates for sharing:
/// `CareerKitExport-<uuid>/` folders (exported PDFs) and `CareerKit-Backup-*` files (backups).
/// Not actor isolated: safe to call from a background task.
enum CKTempFiles {
    static let prefixes: [String] = ["CareerKitExport-", "CareerKit-Backup-"]
    /// Anything older than this is no longer being shared and can go.
    static let maxAge: TimeInterval = 60 * 60

    struct Entry: Equatable {
        let name: String
        let modified: Date?
    }

    static func isOurs(_ name: String) -> Bool {
        return prefixes.contains(where: { name.hasPrefix($0) })
    }

    /// Names that belong to CareerKit and are older than `maxAge`. An entry without a date counts as stale,
    /// because nothing can still be using it when the app has just launched. Pure.
    static func staleNames(_ entries: [Entry], now: Date, maxAge: TimeInterval = CKTempFiles.maxAge) -> [String] {
        return entries
            .filter { entry in
                guard isOurs(entry.name) else { return false }
                guard let modified = entry.modified else { return true }
                return now.timeIntervalSince(modified) > maxAge
            }
            .map { $0.name }
    }

    static func entries(in directory: URL) -> [Entry] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let urls: [URL] = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                         includingPropertiesForKeys: keys,
                                                                         options: [])) ?? []
        return urls.map { url in
            let modified: Date? = (try? url.resourceValues(forKeys: Set(keys)))?.contentModificationDate
            return Entry(name: url.lastPathComponent, modified: modified)
        }
    }

    /// Deletes stale CareerKit items. Returns how many were removed.
    @discardableResult
    static func removeStale(in directory: URL = FileManager.default.temporaryDirectory, now: Date = Date()) -> Int {
        let names: [String] = staleNames(entries(in: directory), now: now)
        return remove(names, in: directory)
    }

    /// Deletes every CareerKit item regardless of age. Used by "Delete all local data".
    @discardableResult
    static func removeAll(in directory: URL = FileManager.default.temporaryDirectory) -> Int {
        let names: [String] = entries(in: directory).map { $0.name }.filter { isOurs($0) }
        return remove(names, in: directory)
    }

    /// Runs `removeStale` at background priority. Call once at launch.
    static func cleanStaleInBackground() async {
        let task = Task.detached(priority: .background) { () -> Int in
            return CKTempFiles.removeStale()
        }
        _ = await task.value
    }

    private static func remove(_ names: [String], in directory: URL) -> Int {
        var removed: Int = 0
        for name in names {
            let url: URL = directory.appendingPathComponent(name)
            if (try? FileManager.default.removeItem(at: url)) != nil {
                removed += 1
            }
        }
        return removed
    }
}
