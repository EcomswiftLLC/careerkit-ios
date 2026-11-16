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

final class CKImageCache {
    static let shared = CKImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 80
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

enum CKResumeMeta {
    static func templateName(_ resume: Resume) -> String {
        TemplateLibrary.spec(id: resume.templateID)?.name ?? String(localized: "Template")
    }

    static func completionPercent(_ resume: Resume) -> Int {
        Int((resume.completion * 100).rounded())
    }
}

// MARK: - Real thumbnail of a user's resume

/// First page of the person's own resume, rendered with the same renderer as preview and export.
struct CKResumeThumbnail: View {
    let resume: Resume
    let width: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    private var cacheKey: String {
        "\(resume.id.uuidString)|\(resume.updatedAt.timeIntervalSince1970)|\(resume.templateID)|\(Int(width))"
    }

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
        .task(id: cacheKey) { await load() }
        .accessibilityHidden(true)
    }

    private func load() async {
        let key = cacheKey
        if let cached = CKImageCache.shared.image(for: key) {
            image = cached
            return
        }
        guard let spec = TemplateLibrary.spec(id: resume.templateID)
            ?? TemplateLibrary.spec(id: TemplateLibrary.defaultTemplateID) else { return }
        let snapshot = resume
        let targetWidth = width
        let scale = min(displayScale, 3)
        let rendered: UIImage? = await Task.detached(priority: .utility) { () -> UIImage? in
            let document = DocumentRenderer.render(snapshot, template: spec)
            return CKPageImages.images(from: document.pdfData, width: targetWidth, scale: scale, maxPages: 1).first
        }.value
        if let rendered {
            CKImageCache.shared.set(rendered, for: key)
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
