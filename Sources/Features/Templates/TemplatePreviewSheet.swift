import SwiftUI
import UIKit

/// Large preview of a template filled with the fictional sample resume, plus details.
struct CKTemplatePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    let template: TemplateSpec
    let onCreated: (UUID) -> Void

    @State private var pages: [UIImage] = []
    @State private var showFlow = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.l) {
                    previewPages
                    summary
                    details
                }
                .padding(CK.Space.m)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .ckScreen()
        }
        .task(id: template.id) { await loadPages() }
        .sheet(isPresented: $showFlow) {
            NewResumeFlow(templateID: template.id, onCreated: { newID in
                showFlow = false
                onCreated(newID)
            })
        }
    }

    // MARK: Pieces

    private var previewPages: some View {
        VStack(spacing: CK.Space.m) {
            Text(SampleContent.sampleLabel)
                .font(CK.Font.caption.weight(.medium))
                .foregroundStyle(CK.Palette.graphite)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(CK.Palette.stone))
                .frame(maxWidth: .infinity)

            if pages.isEmpty {
                TemplateThumbnail(template: template, size: 300)
                    .frame(width: 300, height: 300 * 1.414)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(CK.Palette.hairline, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text("\(template.name) template with sample content"))
            } else {
                ForEach(Array(pages.enumerated()), id: \.offset) { entry in
                    Image(uiImage: entry.element)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(CK.Palette.hairline, lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                        .accessibilityLabel(Text("\(template.name) sample, page \(entry.offset + 1) of \(pages.count)"))
                }
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: CK.Space.s + 2) {
            Text(template.name)
                .ckTitle(26)
                .accessibilityAddTraits(.isHeader)
            Text(template.tagline)
                .font(CK.Font.body)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
            if template.isATSFriendly {
                CKATSBadge()
                Text("A single reading order with no sidebar or photo, which applicant tracking software tends to read more reliably. No layout can promise how a particular employer's system will read it.")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("This design uses a sidebar, photo or decorative layout. It looks distinctive in print and as a PDF, but for online application forms an ATS friendly template is usually the safer choice.")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var details: some View {
        VStack(spacing: 0) {
            CKHairline()
            detailRow(String(localized: "Category"), template.category.rawValue)
            detailRow(String(localized: "Good for"), template.industries.map { $0.rawValue }.joined(separator: ", "))
            detailRow(String(localized: "Career level"), template.levels.map { $0.rawValue }.joined(separator: ", "))
            detailRow(String(localized: "Style"), template.designStyle.rawValue)
            detailRow(String(localized: "Layout"), layoutDescription)
            detailRow(String(localized: "Fonts"), fontDescription)
            detailRow(String(localized: "Typical length"), template.typicalPages <= 1 ? String(localized: "1 page") : String(localized: "\(template.typicalPages) pages"))
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: CK.Space.m) {
                Text(label)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                    .frame(width: 112, alignment: .leading)
                Text(value)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            CKHairline()
        }
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            CKHairline()
            Button {
                showFlow = true
            } label: {
                Text("Use This Template")
            }
            .buttonStyle(.ckPrimary)
            .padding(.horizontal, CK.Space.m)
            .padding(.vertical, CK.Space.m - 4)
            .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity)
        .background(CK.Palette.ivory)
    }

    // MARK: Copy helpers

    private var layoutDescription: String {
        var base: String
        switch template.layout {
        case .singleColumn: base = String(localized: "Single column")
        case .sidebarLeft: base = String(localized: "Sidebar on the left")
        case .sidebarRight: base = String(localized: "Sidebar on the right")
        case .headerThenTwoColumn: base = String(localized: "Two columns under a full-width header")
        }
        switch template.photo {
        case .none: base += String(localized: ", no photo")
        case .headerRight, .sidebarTop: base += String(localized: ", optional photo")
        }
        return base
    }

    private var fontDescription: String {
        if template.headingFont == template.bodyFont {
            return template.bodyFont.displayName
        }
        return String(localized: "\(template.headingFont.displayName) headings, \(template.bodyFont.displayName) text")
    }

    // MARK: Rendering

    private func loadPages() async {
        let spec = template
        let sample = SampleContent.resume(for: spec)
        let scale = min(displayScale, 2)
        let images: [UIImage] = await Task.detached(priority: .userInitiated) { () -> [UIImage] in
            let document = DocumentRenderer.render(sample, template: spec)
            return CKPageImages.images(from: document.pdfData, width: 600, scale: scale, maxPages: 3)
        }.value
        pages = images
    }
}
