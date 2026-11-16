import Foundation

/// Turns a document title into a safe PDF file name.
enum ExportFileName {
    static let fallback = "Resume"
    static let maxLength = 100
    private static let forbidden: Set<Character> = ["/", "\\", ":", "?", "*", "\"", "<", ">", "|"]

    /// Strips / \ : ? * " < > |, turns line breaks and tabs into spaces, collapses repeated spaces,
    /// trims spaces and dots from both ends, limits the length, and falls back to "Resume" when nothing is left.
    static func sanitized(_ raw: String) -> String {
        var mapped = ""
        for character in raw {
            if forbidden.contains(character) { continue }
            if character.isNewline || character == "\t" {
                mapped.append(" ")
            } else if character.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
                continue
            } else {
                mapped.append(character)
            }
        }
        let trimSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))
        let collapsed = mapped
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
            .trimmingCharacters(in: trimSet)
        let limited = String(collapsed.prefix(maxLength)).trimmingCharacters(in: trimSet)
        return limited.isEmpty ? fallback : limited
    }

    /// "<sanitised name>.pdf"
    static func pdfFileName(for raw: String) -> String {
        sanitized(raw) + ".pdf"
    }
}

enum ExportFileError: Error {
    case emptyDocument
}

/// Writes the rendered PDF to a fresh temporary folder so the file keeps its exact name.
enum ExportFileWriter {
    /// Returns the file URL and the folder that contains it. The caller removes the folder when done.
    static func write(pdfData: Data, baseName: String) throws -> (url: URL, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CareerKitExport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(ExportFileName.pdfFileName(for: baseName))
        try pdfData.write(to: url, options: .atomic)
        return (url, directory)
    }
}
