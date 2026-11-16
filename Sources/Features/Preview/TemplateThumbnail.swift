import SwiftUI
import PDFKit
import UIKit

// MARK: - Cache and renderer

/// Renders first-page thumbnails one at a time on a background executor, so a grid of 30 never stalls scrolling.
actor ThumbnailRenderer {
    static let shared = ThumbnailRenderer()

    /// NSCache is thread safe. Values are keyed by template id, width and screen scale.
    static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 120
        return cache
    }()

    func image(key: String, width: CGFloat, scale: CGFloat, produce: @Sendable () -> RenderedDocument) -> UIImage? {
        if Task.isCancelled { return nil }
        if let cached = ThumbnailRenderer.cache.object(forKey: key as NSString) { return cached }
        let document = produce()
        if Task.isCancelled { return nil }
        guard let pdf = PDFDocument(data: document.pdfData), let page = pdf.page(at: 0) else { return nil }
        let image = ThumbnailRenderer.draw(page: page, width: width, scale: scale)
        ThumbnailRenderer.cache.setObject(image, forKey: key as NSString)
        return image
    }

    static func height(forWidth width: CGFloat) -> CGFloat {
        (width * 1.4142).rounded()
    }

    static func draw(page: PDFPage, width: CGFloat, scale: CGFloat) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        let size = CGSize(width: width, height: height(forWidth: width))
        let factor = bounds.width > 0 ? width / bounds.width : 1
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(scale, 1)
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            cg.saveGState()
            // PDF space has its origin at the bottom left; anchor the page to the top of the thumbnail.
            cg.translateBy(x: 0, y: bounds.height * factor)
            cg.scaleBy(x: factor, y: -factor)
            cg.translateBy(x: -bounds.minX, y: -bounds.minY)
            page.draw(with: .mediaBox, to: cg)
            cg.restoreGState()
        }
    }
}

// MARK: - Generic thumbnail view

struct PDFThumbnailView: View {
    let cacheKey: String
    let width: CGFloat
    let accessibilityName: String
    let produce: @Sendable () -> RenderedDocument

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    @State private var dim = false

    private var height: CGFloat { ThumbnailRenderer.height(forWidth: width) }
    private var key: String { "\(cacheKey)|\(Int(width))|\(Int(displayScale))" }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                skeleton
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(.isImage)
        .task(id: key) { await load() }
    }

    private var skeleton: some View {
        ZStack {
            Color.white
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(CK.Palette.stone).frame(width: width * 0.5, height: 7)
                RoundedRectangle(cornerRadius: 2).fill(CK.Palette.stone).frame(width: width * 0.3, height: 4)
                Spacer().frame(height: 6)
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2).fill(CK.Palette.stone)
                        .frame(width: width * (index % 3 == 2 ? 0.45 : 0.75), height: 4)
                }
                Spacer()
            }
            .padding(width * 0.1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .opacity(dim ? 0.65 : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { dim = true }
        }
    }

    private func load() async {
        if let cached = ThumbnailRenderer.cache.object(forKey: key as NSString) {
            image = cached
            return
        }
        let produce = self.produce
        let key = self.key
        let width = self.width
        let scale = self.displayScale
        let result = await ThumbnailRenderer.shared.image(key: key, width: width, scale: scale, produce: produce)
        if Task.isCancelled { return }
        if let result {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { image = result }
        }
    }
}

// MARK: - Public thumbnail for resume templates

/// First page of the template rendered with fictional sample content. `size` is the thumbnail width in points;
/// the height follows the A4 page ratio.
struct TemplateThumbnail: View {
    let template: TemplateSpec
    let size: CGFloat

    init(template: TemplateSpec, size: CGFloat) {
        self.template = template
        self.size = size
    }

    var body: some View {
        PDFThumbnailView(
            cacheKey: "resume.\(template.id)",
            width: size,
            accessibilityName: "\(template.name) template preview with sample content",
            produce: Self.work(for: template)
        )
    }

    private static func work(for template: TemplateSpec) -> @Sendable () -> RenderedDocument {
        return {
            let sample = SampleContent.resume(for: template)
            return DocumentRenderer.render(sample, template: template)
        }
    }
}

/// Same idea for the cover letter templates.
struct CoverLetterThumbnail: View {
    let template: CoverLetterTemplateSpec
    let size: CGFloat

    var body: some View {
        PDFThumbnailView(
            cacheKey: "letter.\(template.id)",
            width: size,
            accessibilityName: "\(template.name) cover letter preview with sample content",
            produce: Self.work(for: template)
        )
    }

    private static func work(for template: CoverLetterTemplateSpec) -> @Sendable () -> RenderedDocument {
        return {
            var sample = SampleContent.coverLetter()
            sample.templateID = template.id
            return CoverLetterRenderer.render(sample, template: template)
        }
    }
}
