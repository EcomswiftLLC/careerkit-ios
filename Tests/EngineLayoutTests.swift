import XCTest
import UIKit
@testable import CareerKit

final class EngineLayoutTests: XCTestCase {
    // MARK: Helpers

    private func block(_ height: CGFloat, space: CGFloat = 0, keep: Bool = false) -> RenderFlowItem {
        return RenderFlowItem(height: height, spaceBefore: space, keepWithNext: keep, draw: { _, _ in })
    }

    private func column(bottom: CGFloat = 100) -> RenderColumn {
        return RenderColumn(left: 10, width: 200, bottom: bottom, firstTop: 0, otherTop: 0)
    }

    private func textLayout(lines: Int, width: CGFloat = 300) -> RenderTextLayout {
        let text: String = (0..<lines).map { "Line number \($0)" }.joined(separator: "\n")
        let style = RenderTextStyle(font: UIFont.systemFont(ofSize: 10), color: UIColor.black, leading: 1.2)
        return RenderTextLayout(RenderText.attributed(text, style), width: width)
    }

    // MARK: Paginator

    func testEverythingFitsOnOnePage() {
        let items = [block(30), block(30, space: 5), block(30, space: 5)]
        let pages = RenderPaginator.paginate(items, column: column())
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].count, 3)
        XCTAssertEqual(pages[0][1].y, 35, accuracy: 0.01)
    }

    func testSpaceBeforeIsIgnoredAtThePageTop() {
        let items = [block(80), block(30, space: 20)]
        let pages = RenderPaginator.paginate(items, column: column())
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[1][0].y, 0, accuracy: 0.01)
    }

    func testHeadingNeverSitsAloneAtTheBottom() {
        let filler = block(80)
        let heading = block(12, space: 10, keep: true)
        let body = block(30)
        let pages = RenderPaginator.paginate([filler, heading, body], column: column())
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].count, 1)
        XCTAssertTrue(pages[1][0].item === heading)
        XCTAssertTrue(pages[1][1].item === body)
    }

    func testEntryHeaderStaysWithFirstBullet() {
        let filler = block(70)
        let header = block(20, space: 8, keep: true)
        let firstBullet = block(15, space: 2)
        let secondBullet = block(15, space: 2)
        let pages = RenderPaginator.paginate([filler, header, firstBullet, secondBullet], column: column())
        XCTAssertEqual(pages.count, 2)
        XCTAssertTrue(pages[1][0].item === header)
        XCTAssertTrue(pages[1][1].item === firstBullet)
    }

    func testChainOfThreeMovesTogether() {
        let filler = block(60)
        let a = block(10, space: 5, keep: true)
        let b = block(10, space: 2, keep: true)
        let c = block(20, space: 2)
        let pages = RenderPaginator.paginate([filler, a, b, c], column: column())
        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[1].count, 3)
    }

    func testNothingIsDroppedAcrossManyItems() {
        var items: [RenderFlowItem] = []
        var total: CGFloat = 0
        for i in 0..<120 {
            let h = CGFloat(8 + (i * 7) % 29)
            total += h
            items.append(block(h, space: 3, keep: i % 5 == 0))
        }
        let pages = RenderPaginator.paginate(items, column: column(bottom: 300))
        var placed: Int = 0
        var placedHeight: CGFloat = 0
        for page in pages {
            for placement in page {
                placed += 1
                placedHeight += placement.item.height
                XCTAssertLessThanOrEqual(placement.y + placement.item.height, 300.5)
            }
        }
        XCTAssertEqual(placed, items.count)
        XCTAssertEqual(placedHeight, total, accuracy: 0.01)
    }

    func testItemTallerThanAPageIsPlacedNotDropped() {
        let huge = block(500)
        let pages = RenderPaginator.paginate([block(20), huge, block(20)], column: column())
        var seen = 0
        for page in pages { seen += page.count }
        XCTAssertEqual(seen, 3)
    }

    func testLongParagraphSplitsBetweenLinesAcrossPages() {
        let layout = textLayout(lines: 60)
        let item = RenderFlowFactory.text(layout: layout)
        let pages = RenderPaginator.paginate([item], column: RenderColumn(left: 0, width: 300, bottom: 200, firstTop: 0, otherTop: 0))
        XCTAssertGreaterThan(pages.count, 2)
        var covered: CGFloat = 0
        for page in pages {
            XCTAssertFalse(page.isEmpty)
            for placement in page {
                XCTAssertLessThanOrEqual(placement.y + placement.item.height, 200.5)
                covered += placement.item.height
            }
        }
        XCTAssertGreaterThanOrEqual(covered, layout.height * 0.95)
    }

    func testHeaderTallerThanPageStartsColumnOnNextPage() {
        let col = RenderColumn(left: 0, width: 200, bottom: 100, firstTop: 90, otherTop: 5)
        let pages = RenderPaginator.paginate([block(20)], column: col)
        XCTAssertEqual(pages.count, 2)
        XCTAssertTrue(pages[0].isEmpty)
        XCTAssertEqual(pages[1][0].y, 5, accuracy: 0.01)
    }

    func testChainEndingInLongParagraphStartsOnThisPage() {
        let filler = block(60)
        let heading = block(14, space: 8, keep: true)
        let layout = textLayout(lines: 12)
        let paragraph = RenderFlowFactory.text(layout: layout)
        let pages = RenderPaginator.paginate([filler, heading, paragraph], column: column(bottom: 120))
        XCTAssertGreaterThanOrEqual(pages.count, 2)
        XCTAssertTrue(pages[0].contains(where: { $0.item === heading }), "heading should share the page with the start of its paragraph")
        XCTAssertGreaterThanOrEqual(pages[0].count, 3)
    }

    // MARK: Text layout

    func testStrictSplitKeepsTwoLinesOnBothSides() {
        let layout = textLayout(lines: 10)
        XCTAssertEqual(layout.lines.count, 10)
        let fiveLines = layout.partHeight(0..<5)
        let k = layout.splitIndex(range: 0..<10, maxHeight: fiveLines + 0.5, relaxed: false)
        XCTAssertEqual(k, 5)
        let tight = layout.splitIndex(range: 0..<10, maxHeight: layout.partHeight(0..<1) + 0.5, relaxed: false)
        XCTAssertNil(tight)
        let relaxed = layout.splitIndex(range: 0..<10, maxHeight: layout.partHeight(0..<1) + 0.5, relaxed: true)
        XCTAssertEqual(relaxed, 1)
        let nearEnd = layout.splitIndex(range: 0..<10, maxHeight: layout.height + 100, relaxed: false)
        XCTAssertEqual(nearEnd, 8)
    }

    func testSmallParagraphsDoNotSplitStrictly() {
        let layout = textLayout(lines: 3)
        XCTAssertNil(layout.splitIndex(range: 0..<3, maxHeight: layout.partHeight(0..<2), relaxed: false))
    }

    func testLongWordWrapsInsteadOfOverflowing() {
        let longWord = String(repeating: "abcdefghij", count: 30)
        let style = RenderTextStyle(font: UIFont.systemFont(ofSize: 10), color: UIColor.black)
        let layout = RenderTextLayout(RenderText.attributed(longWord, style), width: 120)
        XCTAssertGreaterThan(layout.lines.count, 1)
        XCTAssertLessThanOrEqual(layout.usedWidth, 121)
    }

    func testBaselineIsInsideTheFirstLine() {
        let layout = textLayout(lines: 2)
        let base = layout.baseline(ofLine: 0)
        XCTAssertGreaterThan(base, 0)
        XCTAssertLessThan(base, layout.lines[0].fragmentRect.height + 0.5)
    }

    // MARK: Fonts

    func testEveryFontChoiceResolvesInAllVariants() {
        for choice in FontChoice.allCases {
            for bold in [false, true] {
                for italic in [false, true] {
                    let font = RenderFonts.font(choice, size: 11, bold: bold, italic: italic)
                    XCTAssertEqual(font.pointSize, 11, accuracy: 0.01, "\(choice.rawValue) bold \(bold) italic \(italic)")
                    XCTAssertFalse(font.fontName.isEmpty)
                }
            }
        }
    }

    func testBoldFontIsNotLighterThanRegular() {
        for choice in [FontChoice.georgia, .helveticaNeue, .sfPro, .newYork] {
            let regular = RenderFonts.font(choice, size: 12)
            let bold = RenderFonts.font(choice, size: 12, bold: true)
            XCTAssertTrue(bold.fontDescriptor.symbolicTraits.contains(.traitBold) || regular.fontName != bold.fontName, choice.rawValue)
        }
    }

    // MARK: Content rules

    func testCleanBulletStripsPastedMarkersOnly() {
        XCTAssertEqual(RenderContent.cleanBullet("\u{2022} Built it"), "Built it")
        XCTAssertEqual(RenderContent.cleanBullet("- Built it"), "Built it")
        XCTAssertEqual(RenderContent.cleanBullet("-5% churn"), "-5% churn")
        XCTAssertEqual(RenderContent.cleanBullet("   "), "")
    }

    func testEmptyEntriesAndSectionsAreSkipped() {
        var section = EngineFixtures.section(.experience, entries: [EngineFixtures.entry(""), EngineFixtures.entry("", bullets: ["", "  "])])
        XCTAssertFalse(RenderContent.sectionIsRenderable(section))
        section.entries.append(EngineFixtures.entry("Real role"))
        XCTAssertTrue(RenderContent.sectionIsRenderable(section))
        XCTAssertEqual(RenderContent.renderableEntries(section).count, 1)
        section.isVisible = false
        XCTAssertFalse(RenderContent.sectionIsRenderable(section))
    }

    func testContactUrlsAreCleanAndLinked() {
        XCTAssertEqual(RenderContact.displayText(forWeb: "https://www.example.com/in/name/"), "example.com/in/name")
        XCTAssertEqual(RenderContact.webURL("example.com")?.absoluteString, "https://example.com")
        XCTAssertEqual(RenderContact.mailURL("a@b.co")?.absoluteString, "mailto:a@b.co")
        XCTAssertEqual(RenderContact.phoneURL("+1 (555) 014-2290")?.absoluteString, "tel:+15550142290")
        XCTAssertNil(RenderContact.mailURL("not an email"))
    }

    func testRightToLeftDetection() {
        XCTAssertTrue(RenderTextDirection.isRightToLeft("\u{0645}\u{062D}\u{0645}\u{062F}"))
        XCTAssertFalse(RenderTextDirection.isRightToLeft("Mohammed"))
        // Digits are neutral, so the first strong letter decides.
        XCTAssertTrue(RenderTextDirection.isRightToLeft("123 \u{0645}"))
        XCTAssertFalse(RenderTextDirection.isRightToLeft("123 Mohammed"))
    }

    func testNormaliseIgnoresLigaturesCaseAndSpacing() {
        XCTAssertEqual(PDFValidator.normalise("Of\u{FB01}ce  Manager"), PDFValidator.normalise("office manager"))
    }
}
