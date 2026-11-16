import UIKit

/// A neutral head-and-shoulders silhouette drawn with Core Graphics. It stands in for a photo only in template
/// thumbnails and template previews (sample content), so photo templates show their photo area.
/// It is never written into a person's own resume, so it can never reach an exported PDF.
enum PortraitSilhouette {
    /// JPEG data, made once. Safe to read from any thread.
    static let jpegData: Data = makeJPEG()

    /// The sample resume for previews: photo templates get the silhouette, others are unchanged.
    static func previewResume(for template: TemplateSpec) -> Resume {
        var sample: Resume = SampleContent.resume(for: template)
        if template.supportsPhoto && sample.personal.photoData == nil {
            sample.personal.photoData = jpegData
        }
        return sample
    }

    private static func makeJPEG() -> Data {
        let side: CGFloat = 320
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let image: UIImage = renderer.image { context in
            let cg: CGContext = context.cgContext
            // Soft tonal background: a quiet vertical wash from light stone to a slightly deeper grey.
            let top = UIColor(red: 0.905, green: 0.902, blue: 0.890, alpha: 1)
            let bottom = UIColor(red: 0.800, green: 0.804, blue: 0.800, alpha: 1)
            let space: CGColorSpace = CGColorSpaceCreateDeviceRGB()
            let colors: [CGColor] = [top.cgColor, bottom.cgColor]
            if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: side), options: [])
            } else {
                top.setFill()
                cg.fill(CGRect(x: 0, y: 0, width: side, height: side))
            }

            let figure = UIColor(red: 0.640, green: 0.650, blue: 0.655, alpha: 1)
            let highlight = UIColor(red: 0.700, green: 0.708, blue: 0.712, alpha: 1)

            // Shoulders: a wide rounded mound rising from the bottom edge.
            let shoulders = UIBezierPath()
            shoulders.move(to: CGPoint(x: side * 0.10, y: side))
            shoulders.addCurve(to: CGPoint(x: side * 0.50, y: side * 0.66),
                               controlPoint1: CGPoint(x: side * 0.12, y: side * 0.76),
                               controlPoint2: CGPoint(x: side * 0.30, y: side * 0.66))
            shoulders.addCurve(to: CGPoint(x: side * 0.90, y: side),
                               controlPoint1: CGPoint(x: side * 0.70, y: side * 0.66),
                               controlPoint2: CGPoint(x: side * 0.88, y: side * 0.76))
            shoulders.close()
            figure.setFill()
            shoulders.fill()

            // Neck.
            let neck = UIBezierPath(roundedRect: CGRect(x: side * 0.435, y: side * 0.52, width: side * 0.13, height: side * 0.17),
                                    cornerRadius: side * 0.04)
            figure.setFill()
            neck.fill()

            // Head: a slightly tall oval.
            let head = UIBezierPath(ovalIn: CGRect(x: side * 0.355, y: side * 0.22, width: side * 0.29, height: side * 0.34))
            figure.setFill()
            head.fill()

            // A gentle light from the upper left keeps the shape from looking flat.
            cg.saveGState()
            head.addClip()
            highlight.setFill()
            cg.fillEllipse(in: CGRect(x: side * 0.33, y: side * 0.20, width: side * 0.20, height: side * 0.22))
            cg.restoreGState()
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}
