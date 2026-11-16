import SwiftUI
import PDFKit
import UIKit

// MARK: - PDF to images

/// Turns rendered PDF data into page images. Used for resume cards, compare and the template preview.
enum CKPageImages {
    static func images(from pdfData: Data, width: CGFloat, scale: CGFloat, maxPages: Int) -> [UIImage] {
        guard let document = PDFDocument(data: pdfData) else { return [] }
        var result: [UIImage] = []
        let count = min(document.pageCount, maxPages)
        guard count > 0 else { return [] }
        for index in 0..<count {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0 else { continue }
            let height = width * bounds.height / bounds.width
            let pixelSize = CGSize(width: width * scale, height: height * scale)
            result.append(page.thumbnail(of: pixelSize, for: .mediaBox))
        }
        return result
    }
}

// MARK: - Resume metadata

enum CKResumeMeta {
    static func templateName(_ resume: Resume) -> String {
        TemplateLibrary.spec(id: resume.templateID)?.name ?? String(localized: "Template")
    }

    static func completionPercent(_ resume: Resume) -> Int {
        Int((resume.completion * 100).rounded())
    }
}

// MARK: - Cache clearing

/// Image caches register here. They are emptied when the app posts "CKCachesShouldClear"
/// (for example after "Delete all data" or a restore). NSCache already evicts under memory pressure.
enum CKCacheClearing {
    static let notification = Notification.Name("CKCachesShouldClear")

    static func register(_ clear: @escaping () -> Void) {
        _ = NotificationCenter.default.addObserver(forName: notification, object: nil, queue: nil) { _ in
            clear()
        }
    }

    /// Bytes an image holds once decoded, used as its NSCache cost.
    static func cost(of image: UIImage) -> Int {
        let pixels: CGFloat = image.size.width * image.scale * image.size.height * image.scale
        return max(1, Int(pixels * 4))
    }
}

/// One cached page image plus the content fingerprint it was rendered from.
final class CKThumbnailEntry {
    let image: UIImage
    let fingerprint: Int

    init(image: UIImage, fingerprint: Int) {
        self.image = image
        self.fingerprint = fingerprint
    }
}

/// Resume card images. One entry per resume and size (the key has no edit date), so editing a resume replaces
/// its entry instead of piling up stale ones. Bounded by count and decoded size.
final class CKImageCache {
    static let shared = CKImageCache()
    private let cache = NSCache<NSString, CKThumbnailEntry>()

    private init() {
        cache.countLimit = 60
        cache.totalCostLimit = 32 * 1024 * 1024
        let storage = cache
        CKCacheClearing.register { storage.removeAllObjects() }
    }

    func entry(for key: String) -> CKThumbnailEntry? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, fingerprint: Int, for key: String) {
        cache.setObject(CKThumbnailEntry(image: image, fingerprint: fingerprint),
                        forKey: key as NSString,
                        cost: CKCacheClearing.cost(of: image))
    }

    func image(for key: String) -> UIImage? {
        entry(for: key)?.image
    }

    func set(_ image: UIImage, for key: String) {
        set(image, fingerprint: 0, for: key)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

/// A hash of everything that changes how a resume's page looks. The edit date, creation date and archive flag
/// are left out, so archiving or a save without visible changes does not re-render the card.
enum CKResumeFingerprint {
    static func make(_ resume: Resume) -> Int {
        var copy = resume
        let fixed = Date(timeIntervalSince1970: 0)
        copy.updatedAt = fixed
        copy.createdAt = fixed
        copy.isArchived = false
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(copy) else { return resume.id.hashValue }
        var hasher = Hasher()
        data.withUnsafeBytes { buffer in
            hasher.combine(bytes: buffer)
        }
        return hasher.finalize()
    }
}

// MARK: - Real thumbnail of a user's resume

/// First page of the person's own resume, rendered with the same renderer as preview and export.
/// Renders go through the serial `ThumbnailRenderer` (one at a time), are skipped when the card leaves the screen
/// before its turn, and wait for a quiet moment when the resume is being edited (the old image stays meanwhile).
struct CKResumeThumbnail: View {
    let resume: Resume
    let width: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    private struct Request: Equatable {
        let resume: Resume
        let width: CGFloat
        let scale: CGFloat
    }

    /// No edit date in the key: an edited resume reuses (and then replaces) its entry.
    private var cacheKey: String {
        "\(resume.id.uuidString)|\(Int(width))|\(Int(renderScale * 10))"
    }

    private var renderScale: CGFloat { min(max(displayScale, 1), 3) }

    private var pageHeight: CGFloat {
        let size = resume.pageSize.size
        return width * size.height / size.width
    }

    var body: some View {
        ZStack {
            Rectangle().fill(CK.Palette.surface)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: width, height: pageHeight)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(CK.Palette.hairline, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
        .task(id: Request(resume: resume, width: width, scale: renderScale)) { await load() }
        .accessibilityHidden(true)
    }

    private func load() async {
        let key = cacheKey
        let snapshot = resume
        let targetWidth = width
        let scale = renderScale
        let cached: CKThumbnailEntry? = CKImageCache.shared.entry(for: key)
        if image == nil, let cached {
            image = cached.image
        }
        let fingerprint: Int = await Task.detached(priority: .utility) { () -> Int in
            CKResumeFingerprint.make(snapshot)
        }.value
        if Task.isCancelled { return }
        if let cached, cached.fingerprint == fingerprint {
            image = cached.image
            return
        }
        if image != nil {
            // An open editor saves after every change. Wait until it settles before rendering again.
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
        }
        let spec: TemplateSpec? = TemplateLibrary.spec(id: snapshot.templateID)
            ?? TemplateLibrary.spec(id: TemplateLibrary.defaultTemplateID)
        guard let spec else { return }
        let rendered: UIImage? = await ThumbnailRenderer.shared.pageImage(width: targetWidth, scale: scale) {
            DocumentRenderer.render(snapshot, template: spec)
        }
        if Task.isCancelled { return }
        if let rendered {
            CKImageCache.shared.set(rendered, fingerprint: fingerprint, for: key)
            image = rendered
        }
    }
}

// MARK: - Actions

/// Every quick action a resume can offer. `ResumeActionHost` builds one and wires it to the store.
struct CKResumeActions {
    var edit: (Resume) -> Void
    var preview: (Resume) -> Void
    var duplicate: (Resume) -> Void
    var rename: (Resume) -> Void
    var changeTemplate: (Resume) -> Void
    var toggleArchive: (Resume) -> Void
    var createFromExisting: (Resume) -> Void
    var delete: (Resume) -> Void
}

struct CKResumeActionMenu: View {
    enum Style { case compact, full }

    let resume: Resume
    let actions: CKResumeActions
    var style: Style = .full

    var body: some View {
        Button { actions.edit(resume) } label: {
            Label("Edit", systemImage: "pencil")
        }
        Button { actions.preview(resume) } label: {
            Label("Preview", systemImage: "eye")
        }
        Button { actions.duplicate(resume) } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        Button { actions.rename(resume) } label: {
            Label("Rename", systemImage: "textformat")
        }
        if style == .full {
            Button { actions.changeTemplate(resume) } label: {
                Label("Change template", systemImage: "rectangle.on.rectangle")
            }
            Button { actions.createFromExisting(resume) } label: {
                Label("Create new from this", systemImage: "doc.badge.plus")
            }
            Button { actions.toggleArchive(resume) } label: {
                if resume.isArchived {
                    Label("Unarchive", systemImage: "tray.and.arrow.up")
                } else {
                    Label("Archive", systemImage: "archivebox")
                }
            }
        }
        Divider()
        Button(role: .destructive) { actions.delete(resume) } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Tile (Home carousel, My Resumes grid)

struct CKResumeTile: View {
    let resume: Resume
    let actions: CKResumeActions
    var width: CGFloat = 168
    var menuStyle: CKResumeActionMenu.Style = .compact

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.s + 2) {
            Button { actions.edit(resume) } label: {
                CKResumeThumbnail(resume: resume, width: width)
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(CKResumeMeta.completionPercent(resume))%")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(CK.Palette.forest)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(CK.Palette.surface))
                            .overlay(Capsule().stroke(CK.Palette.stone, lineWidth: 1))
                            .padding(6)
                            .accessibilityHidden(true)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Edit \(resume.title)"))
            .accessibilityValue(Text("\(CKResumeMeta.completionPercent(resume)) percent complete"))

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resume.title)
                        .font(CK.Font.label)
                        .foregroundStyle(CK.Palette.ink)
                        .lineLimit(2)
                    Text(CKResumeMeta.templateName(resume))
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                        .lineLimit(1)
                    Text(CKDate.edited(resume.updatedAt))
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Menu {
                    CKResumeActionMenu(resume: resume, actions: actions, style: menuStyle)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CK.Palette.graphite)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("More actions for \(resume.title)"))
            }
        }
        .frame(width: width, alignment: .leading)
        .contextMenu {
            CKResumeActionMenu(resume: resume, actions: actions, style: menuStyle)
        }
    }
}

// MARK: - Row (My Resumes list)

struct CKResumeRow: View {
    let resume: Resume
    let actions: CKResumeActions
    var menuStyle: CKResumeActionMenu.Style = .full

    var body: some View {
        HStack(spacing: CK.Space.m) {
            Button { actions.edit(resume) } label: {
                HStack(spacing: CK.Space.m) {
                    CKResumeThumbnail(resume: resume, width: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(resume.title)
                            .font(CK.Font.label)
                            .foregroundStyle(CK.Palette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(CKResumeMeta.templateName(resume))
                            .font(CK.Font.caption)
                            .foregroundStyle(CK.Palette.graphite)
                            .lineLimit(1)
                        Text(rowDetail)
                            .font(CK.Font.caption)
                            .foregroundStyle(CK.Palette.graphite)
                            .lineLimit(1)
                    }
                    Spacer(minLength: CK.Space.s)
                    ProgressRing(value: resume.completion, size: 44, lineWidth: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(resume.title), \(CKResumeMeta.templateName(resume)), \(CKDate.edited(resume.updatedAt))"))
            .accessibilityValue(Text("\(CKResumeMeta.completionPercent(resume)) percent complete"))
            .accessibilityHint(Text("Opens the editor"))

            Menu {
                CKResumeActionMenu(resume: resume, actions: actions, style: menuStyle)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CK.Palette.graphite)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("More actions for \(resume.title)"))
        }
        .padding(.vertical, CK.Space.s)
        .contextMenu {
            CKResumeActionMenu(resume: resume, actions: actions, style: menuStyle)
        }
    }

    private var rowDetail: String {
        let edited = CKDate.edited(resume.updatedAt)
        return resume.isArchived ? String(localized: "Archived. \(edited)") : edited
    }
}
