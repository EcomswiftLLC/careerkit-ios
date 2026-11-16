import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

// Pure helpers used by the editor screens. No SwiftUI, no store access, so they are unit tested.

// MARK: - Reordering

enum ListEditing {
    static func canMove(index: Int, count: Int, by offset: Int) -> Bool {
        let target = index + offset
        return index >= 0 && index < count && target >= 0 && target < count
    }

    /// Moves one element up (negative offset) or down (positive offset). Returns false when it cannot move.
    @discardableResult
    static func move<T>(_ items: inout [T], index: Int, by offset: Int) -> Bool {
        guard canMove(index: index, count: items.count, by: offset) else { return false }
        let item = items.remove(at: index)
        items.insert(item, at: index + offset)
        return true
    }

    /// Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`, kept here so it can be tested without SwiftUI.
    static func move<T>(_ items: inout [T], fromOffsets source: IndexSet, toOffset destination: Int) {
        let valid = source.sorted().filter { items.indices.contains($0) }
        guard !valid.isEmpty else { return }
        let moving: [T] = valid.map { items[$0] }
        let before = valid.filter { $0 < destination }.count
        for index in valid.reversed() { items.remove(at: index) }
        let insertAt = min(max(destination - before, 0), items.count)
        items.insert(contentsOf: moving, at: insertAt)
    }

    @discardableResult
    static func remove<T>(_ items: inout [T], at index: Int) -> T? {
        guard items.indices.contains(index) else { return nil }
        return items.remove(at: index)
    }
}

// MARK: - Sections

enum SectionOps {
    /// "Custom Section", then "Custom Section 2", "Custom Section 3"... so headings stay distinct.
    static func uniqueTitle(for kind: SectionKind, existing: [ResumeSection]) -> String {
        let taken = Set(existing.map { $0.title.trimmingCharacters(in: .whitespaces).lowercased() })
        let base = kind.defaultTitle
        if !taken.contains(base.lowercased()) { return base }
        var n = 2
        while taken.contains("\(base) \(n)".lowercased()) { n += 1 }
        return "\(base) \(n)"
    }

    static func newSection(kind: SectionKind, existing: [ResumeSection]) -> ResumeSection {
        var section = ResumeSection(kind: kind, title: uniqueTitle(for: kind, existing: existing))
        if kind.shape == .skillGroups { section.skillGroups = [SkillGroup()] }
        return section
    }

    /// Replaces blank headings with the default heading for the kind.
    static func normalized(_ sections: [ResumeSection]) -> [ResumeSection] {
        sections.map { section in
            var copy = section
            if copy.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.title = copy.kind.defaultTitle
            }
            return copy
        }
    }

    static func duplicated(_ entry: ResumeEntry) -> ResumeEntry {
        var copy = entry
        copy.id = UUID()
        return copy
    }

    static func duplicateEntry(in section: inout ResumeSection, at index: Int) {
        guard section.entries.indices.contains(index) else { return }
        section.entries.insert(duplicated(section.entries[index]), at: index + 1)
    }

    /// Short status line for a collapsed section card.
    static func summaryLine(for section: ResumeSection) -> String {
        let empty = String(localized: "Nothing added yet")
        switch section.kind.shape {
        case .text:
            let words: Int = section.text.split(whereSeparator: { $0.isWhitespace }).count
            return words == 0 ? empty : String(localized: "\(words) words")
        case .entries:
            let count: Int = section.entries.filter { !$0.isEmpty }.count
            if count == 0 { return empty }
            return String(localized: "\(count) items")
        case .skillGroups:
            let count: Int = section.skillGroups.reduce(0) { $0 + $1.items.count }
            if count == 0 { return empty }
            return String(localized: "\(count) items")
        }
    }
}

// MARK: - Dates

enum MonthYearHelper {
    static let earliestYear = 1960

    static func currentYear(now: Date = Date()) -> Int {
        Calendar(identifier: .gregorian).component(.year, from: now)
    }

    /// Newest first. Includes a few future years (expected graduation), and `extra` when it falls outside the range.
    static func years(now: Date = Date(), including extra: Int? = nil) -> [Int] {
        let top = currentYear(now: now) + 6
        var list: [Int] = Array((earliestYear...top).reversed())
        if let extra, extra > 0, !list.contains(extra) {
            list.append(extra)
            list.sort(by: >)
        }
        return list
    }

    static func shortMonthNames(locale: Locale = .current) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols: [String] = formatter.shortMonthSymbols ?? []
        if symbols.count == 12 { return symbols }
        return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    }

    /// nil when `year` is not a real year. An out-of-range month becomes "year only".
    static func make(year: Int, month: Int?) -> MonthYear? {
        guard year > 0 else { return nil }
        var checked = month
        if let m = checked, !(1...12).contains(m) { checked = nil }
        return MonthYear(year: year, month: checked)
    }

    /// True when `end` is not earlier than `start`, or when either is missing.
    static func isValidRange(start: MonthYear?, end: MonthYear?) -> Bool {
        guard let s = start, let e = end else { return true }
        if e.year != s.year { return e.year > s.year }
        guard let sm = s.month, let em = e.month else { return true }
        return em >= sm
    }
}

// MARK: - Text helpers

enum TokenParsing {
    /// Splits "Swift, SwiftUI; Core Data" into separate trimmed items.
    static func split(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Appends new items, skipping any that already exist (case-insensitive).
    static func appendUnique(existing: [String], new: [String]) -> [String] {
        var result = existing
        var seen = Set(existing.map { $0.lowercased() })
        for item in new {
            let key = item.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }
}

enum TextInsertion {
    /// Empty text is replaced, otherwise the addition becomes a new paragraph.
    static func insert(_ addition: String, into existing: String) -> String {
        let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return addition }
        return trimmed + "\n\n" + addition
    }
}

enum FileNaming {
    /// File name without extension, safe for Files and the share sheet.
    static func safeFileName(_ title: String, fallback: String) -> String {
        let blocked = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.newlines).union(.controlCharacters)
        let cleaned = title.unicodeScalars
            .map { blocked.contains($0) ? "-" : String($0) }
            .joined()
        let collapsed = cleaned
            .split(whereSeparator: { $0 == " " })
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .-"))
        let limited = String(collapsed.prefix(80))
        return limited.isEmpty ? fallback : limited
    }
}

// MARK: - Entry labels

struct EntryLabels {
    let heading: String
    let subheading: String
    let extra: String
    let addButton: String
    let currentToggle: String?
    let showsDates: Bool
    let showsBullets: Bool
    let showsLocation: Bool
    /// Offers the "Writing examples" sheet for achievement bullets.
    let offersExamples: Bool

    static func labels(for kind: SectionKind) -> EntryLabels {
        switch kind {
        case .experience:
            return EntryLabels(heading: String(localized: "Job title"), subheading: String(localized: "Company"), extra: String(localized: "Extra line"), addButton: String(localized: "Add position"),
                               currentToggle: String(localized: "I currently work here"), showsDates: true, showsBullets: true,
                               showsLocation: true, offersExamples: true)
        case .internships:
            return EntryLabels(heading: String(localized: "Role"), subheading: String(localized: "Organization"), extra: String(localized: "Extra line"), addButton: String(localized: "Add internship"),
                               currentToggle: String(localized: "I currently work here"), showsDates: true, showsBullets: true,
                               showsLocation: true, offersExamples: true)
        case .education:
            return EntryLabels(heading: String(localized: "Degree or program"), subheading: String(localized: "School"), extra: String(localized: "Grade, honors or GPA"),
                               addButton: String(localized: "Add education"), currentToggle: String(localized: "I currently study here"), showsDates: true,
                               showsBullets: true, showsLocation: true, offersExamples: false)
        case .certifications:
            return EntryLabels(heading: String(localized: "Certification"), subheading: String(localized: "Issuing organization"), extra: String(localized: "Credential ID or link"),
                               addButton: String(localized: "Add certification"), currentToggle: nil, showsDates: true, showsBullets: false,
                               showsLocation: false, offersExamples: false)
        case .projects:
            return EntryLabels(heading: String(localized: "Project name"), subheading: String(localized: "Role or organization"), extra: String(localized: "Link"),
                               addButton: String(localized: "Add project"), currentToggle: String(localized: "This project is ongoing"), showsDates: true,
                               showsBullets: true, showsLocation: false, offersExamples: true)
        case .awards:
            return EntryLabels(heading: String(localized: "Award"), subheading: String(localized: "Presented by"), extra: String(localized: "Extra line"), addButton: String(localized: "Add award"),
                               currentToggle: nil, showsDates: true, showsBullets: false, showsLocation: false,
                               offersExamples: false)
        case .publications:
            return EntryLabels(heading: String(localized: "Title"), subheading: String(localized: "Publisher or journal"), extra: String(localized: "Link"), addButton: String(localized: "Add publication"),
                               currentToggle: nil, showsDates: true, showsBullets: false, showsLocation: false,
                               offersExamples: false)
        case .volunteer:
            return EntryLabels(heading: String(localized: "Role"), subheading: String(localized: "Organization"), extra: String(localized: "Extra line"), addButton: String(localized: "Add role"),
                               currentToggle: String(localized: "I currently volunteer here"), showsDates: true, showsBullets: true,
                               showsLocation: true, offersExamples: true)
        case .memberships:
            return EntryLabels(heading: String(localized: "Membership"), subheading: String(localized: "Organization"), extra: String(localized: "Extra line"), addButton: String(localized: "Add membership"),
                               currentToggle: String(localized: "This membership is current"), showsDates: true, showsBullets: false,
                               showsLocation: false, offersExamples: false)
        case .references:
            return EntryLabels(heading: String(localized: "Name"), subheading: String(localized: "Title and company"), extra: String(localized: "Email or phone"),
                               addButton: String(localized: "Add reference"), currentToggle: nil, showsDates: false, showsBullets: false,
                               showsLocation: false, offersExamples: false)
        case .courses:
            return EntryLabels(heading: String(localized: "Course"), subheading: String(localized: "Provider"), extra: String(localized: "Link"), addButton: String(localized: "Add course"),
                               currentToggle: nil, showsDates: true, showsBullets: false, showsLocation: false,
                               offersExamples: false)
        case .summary, .skills, .languages, .interests, .custom:
            return EntryLabels(heading: String(localized: "Title"), subheading: String(localized: "Subtitle"), extra: String(localized: "Extra line"), addButton: String(localized: "Add item"),
                               currentToggle: nil, showsDates: true, showsBullets: true, showsLocation: true,
                               offersExamples: false)
        }
    }
}

// MARK: - Style limits (layout safeguards)

struct StyleLimits {
    let fontScale: ClosedRange<Double>
    let lineSpacing: ClosedRange<Double>
    let margin: ClosedRange<Double>

    static let standard = StyleLimits(fontScale: 0.85...1.2, lineSpacing: 0.9...1.4, margin: 20...72)
    /// The blank builder is stricter so a hand-built layout can never overlap or clip.
    static let blank = StyleLimits(fontScale: 0.9...1.1, lineSpacing: 0.95...1.3, margin: 28...72)

    func clamped(_ style: StyleOverrides) -> StyleOverrides {
        var result = style
        result.fontScale = min(max(style.fontScale, fontScale.lowerBound), fontScale.upperBound)
        result.lineSpacing = min(max(style.lineSpacing, lineSpacing.lowerBound), lineSpacing.upperBound)
        if let margin = style.marginPoints {
            result.marginPoints = min(max(margin, self.margin.lowerBound), self.margin.upperBound)
        }
        return result
    }
}

// MARK: - Photo

/// Turns a picked photo into a small JPEG for the resume. Uses ImageIO thumbnails, so a 48 MP HEIC or ProRAW file
/// is decoded straight to the target size instead of being expanded to full resolution in memory first.
enum PhotoProcessor {
    static let maxDimension: CGFloat = 800
    static let defaultQuality: CGFloat = 0.85
    /// Files larger than this are refused before decoding.
    static let maxInputBytes: Int = 150 * 1024 * 1024
    /// Images with more pixels than this are refused (about 14000 x 14000). Real camera photos are far below it.
    static let maxSourcePixels: Double = 200_000_000

    enum Failure: Error, Equatable {
        /// Not an image format iOS can read, or the data is damaged.
        case unreadable
        /// The file or the image dimensions are too large to process safely.
        case tooLarge

        /// Plain message for the editor.
        var message: String {
            switch self {
            case .unreadable: return String(localized: "That image could not be read. Try another photo.")
            case .tooLarge: return String(localized: "That image is too large to use. Try a smaller photo.")
            }
        }
    }

    /// Fits `size` inside a `maxDimension` square. Never upscales.
    static func targetSize(for size: CGSize, maxDimension: CGFloat = PhotoProcessor.maxDimension) -> CGSize {
        guard size.width > 0, size.height > 0, maxDimension > 0 else { return .zero }
        let longest = max(size.width, size.height)
        if longest <= maxDimension { return size }
        let scale = maxDimension / longest
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }

    /// Pixel size of the first image in `data` as stored (before orientation), read from the header only.
    static func pixelSize(of data: Data) -> CGSize? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any] else { return nil }
        let width: Double = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let height: Double = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        guard width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
    }

    /// Decodes any image ImageIO understands (JPEG, PNG, HEIC, ProRAW DNG and more) to at most `maxDimension` pixels
    /// on its longest side, applies the EXIF orientation, flattens transparency onto white and encodes a JPEG.
    static func process(_ data: Data,
                        maxDimension: CGFloat = PhotoProcessor.maxDimension,
                        quality: CGFloat = PhotoProcessor.defaultQuality,
                        maxInputBytes: Int = PhotoProcessor.maxInputBytes,
                        maxSourcePixels: Double = PhotoProcessor.maxSourcePixels) -> Result<Data, Failure> {
        guard !data.isEmpty else { return .failure(.unreadable) }
        guard data.count <= maxInputBytes else { return .failure(.tooLarge) }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              CGImageSourceGetCount(source) > 0 else { return .failure(.unreadable) }
        if let size = pixelSize(of: data), Double(size.width) * Double(size.height) > maxSourcePixels {
            return .failure(.tooLarge)
        }
        let limit: Int = max(1, Int(maxDimension.rounded()))
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: limit
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return .failure(.unreadable)
        }
        guard let flattened = flattenedOnWhite(thumbnail, maxDimension: limit) else { return .failure(.unreadable) }
        guard let jpeg = jpegData(flattened, quality: quality) else { return .failure(.unreadable) }
        return .success(jpeg)
    }

    /// Small preview image for the editor row. Safe for any stored data size (decodes a thumbnail only).
    static func previewImage(from data: Data, maxPixels: Int = 192) -> UIImage? {
        guard !data.isEmpty, data.count <= maxInputBytes else { return nil }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixels)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    /// Convenience used where only success matters.
    static func downscaledJPEG(from data: Data, maxDimension: CGFloat = PhotoProcessor.maxDimension,
                               quality: CGFloat = PhotoProcessor.defaultQuality) -> Data? {
        switch process(data, maxDimension: maxDimension, quality: quality) {
        case .success(let jpeg): return jpeg
        case .failure: return nil
        }
    }

    /// Draws the image into an opaque sRGB bitmap. Also enforces the size limit in case a decoder ignored it.
    private static func flattenedOnWhite(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let target: CGSize = targetSize(for: CGSize(width: image.width, height: image.height),
                                        maxDimension: CGFloat(maxDimension))
        let width: Int = Int(target.width)
        let height: Int = Int(target.height)
        guard width > 0, height > 0 else { return nil }
        let space: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(rect)
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        return context.makeImage()
    }

    private static func jpegData(_ image: CGImage, quality: CGFloat) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData,
                                                                 UTType.jpeg.identifier as CFString,
                                                                 1, nil) else { return nil }
        let clamped: CGFloat = min(max(quality, 0.1), 1)
        let properties = [kCGImageDestinationLossyCompressionQuality: clamped] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
