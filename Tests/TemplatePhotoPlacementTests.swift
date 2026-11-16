import XCTest
import PDFKit
import UIKit
@testable import CareerKit

/// Photo areas: the photo is drawn where the template says, header text never runs into it, and templates
/// without a photo (or resumes without one) lay out without a hole.
final class TemplatePhotoPlacementTests: XCTestCase {
    private var photoTemplates: [TemplateSpec] { TemplateLibrary.all.filter { $0.supportsPhoto } }

    private func sample(for template: TemplateSpec, photo: Bool) -> Resume {
        var resume: Resume = SampleContent.resume(for: template)
        resume.personal.photoData = photo ? EngineFixtures.photoData() : nil
        return resume
    }

    private func assertNoOverlap(_ resume: Resume, _ template: TemplateSpec, _ label: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let result = DocumentRenderer.renderInspecting(resume, template: template)
        let geometry: RenderGeometry = result.geometry
        XCTAssertEqual(geometry.photoRects.count, 1, "\(label): expected one photo", file: file, line: line)
        XCTAssertFalse(geometry.headerTextRects.isEmpty, "\(label): no header text recorded", file: file, line: line)
        let page: CGRect = CGRect(origin: .zero, size: resume.pageSize.size)
        for photo in geometry.photoRects {
            XCTAssertTrue(page.insetBy(dx: -0.5, dy: -0.5).contains(photo), "\(label): photo leaves the page \(photo)", file: file, line: line)
            for text in geometry.headerTextRects {
                let overlap: CGRect = text.intersection(photo)
                let area: CGFloat = overlap.isNull ? 0 : overlap.width * overlap.height
                XCTAssertLessThan(area, 1, "\(label): header text \(text) overlaps the photo \(photo)", file: file, line: line)
            }
        }
        let report: PDFValidationReport = PDFValidator.validate(result.document, resume: resume)
        XCTAssertTrue(report.passed, "\(label): \(report.issues.joined(separator: " | "))", file: file, line: line)
    }

    func testAtLeastEighteenTemplatesHaveAPhotoArea() {
        XCTAssertGreaterThanOrEqual(photoTemplates.count, 18)
    }

    func testHeaderTextNeverOverlapsThePhoto() {
        for template in photoTemplates {
            assertNoOverlap(sample(for: template, photo: true), template, template.name)
        }
    }

    func testEveryPhotoSizeBorderAndSideStaysClear() {
        for template in photoTemplates {
            for size in PhotoSizeOption.allCases {
                var resume: Resume = sample(for: template, photo: true)
                resume.style.photoSize = size
                resume.style.photoBorder = .ring
                assertNoOverlap(resume, template, "\(template.name) \(size.rawValue)")
                if template.supportsPhotoFlip {
                    resume.style.photoSide = template.photo == .headerLeft ? .right : .left
                    assertNoOverlap(resume, template, "\(template.name) \(size.rawValue) flipped")
                }
            }
        }
    }

    func testFixtureLayoutsKeepTheirPhotoClear() {
        guard let base = EngineFixtures.cases().first(where: { $0.name == "one page" }) else {
            return XCTFail("fixture missing")
        }
        var resume: Resume = base.resume
        resume.personal.photoData = EngineFixtures.photoData()
        for spec in EngineFixtures.specs where spec.photo != .none {
            assertNoOverlap(resume, spec, spec.id)
        }
    }

    func testNoPhotoMeansNoPhotoDrawn() {
        for template in TemplateLibrary.all {
            let result = DocumentRenderer.renderInspecting(sample(for: template, photo: false), template: template)
            XCTAssertTrue(result.geometry.photoRects.isEmpty, "\(template.name) drew a photo without one")
        }
        // A photo on a template without a photo area is kept in the data but not drawn.
        for template in TemplateLibrary.all where !template.supportsPhoto {
            let resume: Resume = sample(for: template, photo: true)
            let result = DocumentRenderer.renderInspecting(resume, template: template)
            XCTAssertTrue(result.geometry.photoRects.isEmpty, "\(template.name) has no photo area")
            XCTAssertNotNil(resume.personal.photoData)
        }
    }

    func testHiddenPhotoIsNotDrawn() {
        for template in photoTemplates {
            var resume: Resume = sample(for: template, photo: true)
            resume.style.showPhoto = false
            let result = DocumentRenderer.renderInspecting(resume, template: template)
            XCTAssertTrue(result.geometry.photoRects.isEmpty, template.name)
        }
    }

    func testSilhouetteOnlyLivesInPreviews() {
        XCTAssertFalse(PortraitSilhouette.jpegData.isEmpty)
        XCTAssertNotNil(UIImage(data: PortraitSilhouette.jpegData))
        for template in TemplateLibrary.all {
            // The sample content itself never carries the silhouette, so exports of a person's resume cannot either.
            XCTAssertNil(SampleContent.resume(for: template).personal.photoData, template.name)
            let preview: Resume = PortraitSilhouette.previewResume(for: template)
            XCTAssertEqual(preview.personal.photoData != nil, template.supportsPhoto, template.name)
        }
        let blank: Resume = ResumeFactory.blankResume(title: "Blank", pageSize: .a4)
        XCTAssertNil(blank.personal.photoData)
    }

    // MARK: Crop maths

    func testCropRectStaysInsideTheImage() {
        let size = CGSize(width: 1600, height: 1000)
        let centered: CGRect = PhotoCropMath.cropRect(imageSize: size, frame: 300, zoom: 1, offset: .zero)
        XCTAssertEqual(centered.width, 1000, accuracy: 0.5)
        XCTAssertEqual(centered.height, 1000, accuracy: 0.5)
        XCTAssertEqual(centered.minX, 300, accuracy: 0.5)
        XCTAssertEqual(centered.minY, 0, accuracy: 0.5)

        // Dragging far right shows the left edge and is clamped there.
        let dragged: CGRect = PhotoCropMath.cropRect(imageSize: size, frame: 300, zoom: 1, offset: CGSize(width: 5000, height: 0))
        XCTAssertEqual(dragged.minX, 0, accuracy: 0.5)

        let zoomed: CGRect = PhotoCropMath.cropRect(imageSize: size, frame: 300, zoom: 2, offset: .zero)
        XCTAssertEqual(zoomed.width, 500, accuracy: 0.5)
        XCTAssertTrue(CGRect(origin: .zero, size: size).insetBy(dx: -0.5, dy: -0.5).contains(zoomed))
    }

    func testCropRenderIsSquareAndCapped() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900))
        let image: UIImage = renderer.image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
        }
        let crop: CGRect = PhotoCropMath.cropRect(imageSize: image.size, frame: 280, zoom: 1, offset: .zero)
        let out: UIImage = PhotoCropMath.render(image, crop: crop)
        XCTAssertEqual(out.size.width, out.size.height, accuracy: 0.5)
        XCTAssertLessThanOrEqual(out.size.width * out.scale, 800.5)
    }
}
