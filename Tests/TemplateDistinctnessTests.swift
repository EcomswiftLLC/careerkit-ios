import XCTest
import PDFKit
import UIKit
@testable import CareerKit

/// The structural fingerprint of a template, computed from its data only.
struct TemplateSignature: Equatable {
    let header: String
    /// Layout plus the rail side for header-then-two-column layouts.
    let columns: String
    /// none, narrow, regular or wide.
    let sidebarWidth: String
    let heading: String
    let entry: String
    let skills: String
    let bullets: String
    /// Page decoration: none, top bar, edge strip, frame or foot bar.
    let rules: String
    /// white or tinted.
    let paper: String
    let fonts: String
    /// Accent hue in 30 degree buckets, -1 for a near grey accent.
    let accentHue: Int
    let photo: String

    init(_ t: TemplateSpec) {
        header = t.header.rawValue
        columns = t.layout == .headerThenTwoColumn ? "\(t.layout.rawValue)-\(t.railSide.rawValue)" : t.layout.rawValue
        if t.layout == .singleColumn {
            sidebarWidth = "none"
        } else if t.sidebarFraction < 0.30 {
            sidebarWidth = "narrow"
        } else if t.sidebarFraction > 0.35 {
            sidebarWidth = "wide"
        } else {
            sidebarWidth = "regular"
        }
        heading = t.headingStyle.rawValue
        entry = t.entryLayout.rawValue
        skills = t.skillStyle.rawValue
        bullets = t.bullets.rawValue
        rules = t.pageAccent.rawValue
        paper = t.paperHex == nil ? "white" : "tinted"
        fonts = "\(t.headingFont.rawValue)/\(t.bodyFont.rawValue)"
        accentHue = TemplateSignature.hueBucket(t.accentHex)
        photo = t.photo.rawValue
    }

    var dimensions: [String] {
        return [header, columns, sidebarWidth, heading, entry, skills, bullets, rules, paper, fonts, String(accentHue), photo]
    }

    /// Header, column structure and heading style: no two templates may share all three.
    var structureKey: String { return "\(header)|\(columns)|\(heading)" }

    func differences(from other: TemplateSignature) -> Int {
        var count: Int = 0
        for (a, b) in zip(dimensions, other.dimensions) where a != b {
            count += 1
        }
        return count
    }

    static func hueBucket(_ hex: String) -> Int {
        guard let c = TemplateTestColor.components(hex) else { return -1 }
        let high: Double = max(c.r, c.g, c.b)
        let low: Double = min(c.r, c.g, c.b)
        let delta: Double = high - low
        if delta < 0.06 { return -1 }
        var hue: Double
        if high == c.r {
            hue = (c.g - c.b) / delta
        } else if high == c.g {
            hue = (c.b - c.r) / delta + 2
        } else {
            hue = (c.r - c.g) / delta + 4
        }
        hue *= 60
        if hue < 0 { hue += 360 }
        return Int(hue / 30) % 12
    }
}

final class TemplateDistinctnessTests: XCTestCase {
    private var all: [TemplateSpec] { TemplateLibrary.all }

    // MARK: Data signature

    func testNoTwoTemplatesShareHeaderColumnsAndHeading() {
        var seen: [String: String] = [:]
        for t in all {
            let key: String = TemplateSignature(t).structureKey
            if let other = seen[key] {
                XCTFail("\(t.name) and \(other) share header, columns and heading: \(key)")
            }
            seen[key] = t.name
        }
    }

    func testEveryPairDiffersInAtLeastThreeDimensions() {
        let signatures: [(String, TemplateSignature)] = all.map { ($0.name, TemplateSignature($0)) }
        var closest: (String, String, Int) = ("", "", Int.max)
        for i in 0..<signatures.count {
            for j in (i + 1)..<signatures.count {
                let d: Int = signatures[i].1.differences(from: signatures[j].1)
                if d < closest.2 { closest = (signatures[i].0, signatures[j].0, d) }
                XCTAssertGreaterThanOrEqual(d, 3, "\(signatures[i].0) and \(signatures[j].0) differ in only \(d) dimensions")
            }
        }
        print("Closest pair by signature: \(closest.0) / \(closest.1), \(closest.2) dimensions apart")
    }

    // MARK: Rendered fingerprint

    private static let gridColumns: Int = 24
    private static let gridRows: Int = 32
    private static let pixelWidth: Int = 96
    private static let pixelHeight: Int = 128

    /// The same content for every template, with the preview silhouette as the photo.
    private func fixtureResume() -> Resume {
        guard let base = EngineFixtures.cases().first(where: { $0.name == "one page" }) else {
            return Resume(title: "Empty", templateID: "x", sections: [])
        }
        var resume: Resume = base.resume
        resume.personal.photoData = PortraitSilhouette.jpegData
        return resume
    }

    private struct Fingerprint {
        let grid: [Double]
        let histogram: [Double]
    }

    /// First page drawn into a 96 x 128 RGBA bitmap, reduced to a 24 x 32 luminance grid and an 8 bucket colour
    /// histogram (white, grey, and six hue sextants for coloured pixels).
    private func fingerprint(_ template: TemplateSpec, resume: Resume) -> Fingerprint? {
        let doc: RenderedDocument = DocumentRenderer.render(resume, template: template)
        guard let pdf = PDFDocument(data: doc.pdfData), let page = pdf.page(at: 0) else { return nil }
        let w: Int = TemplateDistinctnessTests.pixelWidth
        let h: Int = TemplateDistinctnessTests.pixelHeight
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let bounds: CGRect = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        context.scaleBy(x: CGFloat(w) / bounds.width, y: CGFloat(h) / bounds.height)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: context)
        guard let raw = context.data else { return nil }
        let pixels = raw.bindMemory(to: UInt8.self, capacity: w * h * 4)

        let columns: Int = TemplateDistinctnessTests.gridColumns
        let rows: Int = TemplateDistinctnessTests.gridRows
        let cellW: Int = w / columns
        let cellH: Int = h / rows
        var grid = [Double](repeating: 0, count: columns * rows)
        var histogram = [Double](repeating: 0, count: 8)
        for y in 0..<h {
            for x in 0..<w {
                let i: Int = (y * w + x) * 4
                let r: Double = Double(pixels[i]) / 255
                let g: Double = Double(pixels[i + 1]) / 255
                let b: Double = Double(pixels[i + 2]) / 255
                let lum: Double = 0.2126 * r + 0.7152 * g + 0.0722 * b
                let cell: Int = min(rows - 1, y / cellH) * columns + min(columns - 1, x / cellW)
                grid[cell] += lum
                let high: Double = max(r, g, b)
                let low: Double = min(r, g, b)
                let delta: Double = high - low
                if delta < 0.10 {
                    histogram[lum > 0.9 ? 0 : 1] += 1
                } else {
                    var hue: Double
                    if high == r {
                        hue = (g - b) / delta
                    } else if high == g {
                        hue = (b - r) / delta + 2
                    } else {
                        hue = (r - g) / delta + 4
                    }
                    if hue < 0 { hue += 6 }
                    histogram[2 + min(5, Int(hue))] += 1
                }
            }
        }
        let perCell: Double = Double(cellW * cellH)
        let total: Double = Double(w * h)
        return Fingerprint(grid: grid.map { $0 / perCell }, histogram: histogram.map { $0 / total })
    }

    /// Mean absolute luminance difference of the grids plus half the L1 distance of the histograms (0...1 each).
    private func distance(_ a: Fingerprint, _ b: Fingerprint) -> Double {
        var gridSum: Double = 0
        for (x, y) in zip(a.grid, b.grid) { gridSum += abs(x - y) }
        var histSum: Double = 0
        for (x, y) in zip(a.histogram, b.histogram) { histSum += abs(x - y) }
        return gridSum / Double(max(1, a.grid.count)) + 0.5 * (histSum / 2)
    }

    /// Thumbnails must not look alike. The threshold is deliberately modest; CI prints the five closest pairs
    /// so it can be tuned against real renders.
    func testRenderedThumbnailsAreDistinct() {
        let resume: Resume = fixtureResume()
        var prints: [(String, Fingerprint)] = []
        for t in all {
            guard let fp = fingerprint(t, resume: resume) else {
                XCTFail("could not fingerprint \(t.name)")
                continue
            }
            prints.append((t.name, fp))
        }
        var pairs: [(String, String, Double)] = []
        for i in 0..<prints.count {
            for j in (i + 1)..<prints.count {
                pairs.append((prints[i].0, prints[j].0, distance(prints[i].1, prints[j].1)))
            }
        }
        pairs.sort { $0.2 < $1.2 }
        let report: String = pairs.prefix(5).map { "\($0.0) / \($0.1): \(String(format: "%.4f", $0.2))" }.joined(separator: "\n")
        print("Closest rendered pairs:\n\(report)")
        let threshold: Double = 0.015
        if let closest = pairs.first {
            XCTAssertGreaterThanOrEqual(closest.2, threshold,
                                        "Closest pair \(closest.0) / \(closest.1) is \(String(format: "%.4f", closest.2)) apart. Five closest:\n\(report)")
        }
    }
}
