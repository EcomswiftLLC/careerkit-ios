import UIKit

/// Renders a resume into a PDF. Pure and thread-safe: it touches no shared state and can run on a background task.
/// The same output is used for the live preview and for export.
enum DocumentRenderer {
    static func render(_ resume: Resume, template: TemplateSpec) -> RenderedDocument {
        // The user's structural overrides are applied here, once, so every builder sees the effective spec.
        let effective: TemplateSpec = template.applying(resume.style)
        let composer = RenderResumeComposer(resume: resume, template: effective)
        return composer.render()
    }
}

/// Lays out one resume: picks the geometry for the page layout, builds flow items per column,
/// paginates each column and draws every page.
final class RenderResumeComposer {
    private let resume: Resume
    private let template: TemplateSpec
    private let style: RenderStyle
    private let canvas = RenderCanvas()
    private let detector = RenderLinkDetector()

    init(resume: Resume, template: TemplateSpec) {
        self.resume = resume
        self.template = template
        self.style = RenderStyle.make(template: template, overrides: resume.style, pageSize: resume.pageSize.size)
    }

    private func context(theme: RenderTheme, width: CGFloat) -> RenderContext {
        return RenderContext(style: style, theme: theme, width: width, canvas: canvas, detector: detector)
    }

    func render() -> RenderedDocument {
        let page: CGSize = style.pageSize
        let allSections: [ResumeSection] = RenderContent.visibleSections(resume)

        // Which section goes where.
        var kind: PageLayout = template.layout
        var sideSections: [ResumeSection] = []
        var mainSections: [ResumeSection] = allSections
        if kind != .singleColumn {
            let sideKinds: Set<SectionKind> = Set(template.sidebarSections)
            sideSections = allSections.filter { sideKinds.contains($0.kind) }
            mainSections = allSections.filter { !sideKinds.contains($0.kind) }
        }
        let isSidebarLayout: Bool = kind == .sidebarLeft || kind == .sidebarRight
        let cardInSidebar: Bool = isSidebarLayout && template.header == .sidebarCard
        if kind != .singleColumn && sideSections.isEmpty && !cardInSidebar {
            kind = .singleColumn
            mainSections = allSections
        }

        // Geometry.
        let contentWidth: CGFloat = page.width - 2 * style.marginSide
        let gap: CGFloat = 24
        let innerPad: CGFloat = 18
        var mainLeft: CGFloat = style.marginSide
        var mainWidth: CGFloat = contentWidth
        var sideLeft: CGFloat = 0
        var sideWidth: CGFloat = 0
        var bandRect: CGRect? = nil
        var dividerX: CGFloat? = nil
        var bleedLeft: CGFloat = 0
        var bleedRight: CGFloat = page.width
        let fraction: CGFloat = CGFloat(min(max(template.sidebarFraction, 0.2), 0.4))

        switch kind {
        case .singleColumn:
            break
        case .sidebarLeft:
            sideWidth = min(max(contentWidth * fraction, 110), 230)
            let edge: CGFloat = max(20, style.marginSide * 0.75)
            sideLeft = edge
            let bandRight: CGFloat = edge + sideWidth + innerPad
            bandRect = CGRect(x: 0, y: 0, width: bandRight, height: page.height)
            mainLeft = bandRight + gap
            mainWidth = page.width - style.marginSide - mainLeft
            bleedLeft = bandRight
            bleedRight = page.width
        case .sidebarRight:
            sideWidth = min(max(contentWidth * fraction, 110), 230)
            let edge: CGFloat = max(20, style.marginSide * 0.75)
            let bandLeft: CGFloat = page.width - edge - sideWidth - innerPad
            bandRect = CGRect(x: bandLeft, y: 0, width: page.width - bandLeft, height: page.height)
            sideLeft = bandLeft + innerPad
            mainLeft = style.marginSide
            mainWidth = bandLeft - gap - mainLeft
            bleedLeft = 0
            bleedRight = bandLeft
        case .headerThenTwoColumn:
            sideWidth = min(max(contentWidth * fraction, 110), 230)
            mainWidth = contentWidth - sideWidth - gap
            sideLeft = style.marginSide + mainWidth + gap
            dividerX = style.marginSide + mainWidth + gap / 2
        }
        mainWidth = max(120, mainWidth)

        // Header region.
        let fullWidthHeader: Bool = kind == .singleColumn || kind == .headerThenTwoColumn
        let headerLeft: CGFloat = fullWidthHeader ? style.marginSide : mainLeft
        let headerWidth: CGFloat = fullWidthHeader ? contentWidth : mainWidth
        var headerKind: HeaderStyle = template.header
        if headerKind == .sidebarCard && !cardInSidebar {
            headerKind = .leftAligned
        }
        let photo: UIImage? = RenderPhoto.image(for: resume, template: template)
        let mainTheme: RenderTheme = style.mainTheme
        let sideTheme: RenderTheme = (kind == .headerThenTwoColumn) ? mainTheme : style.sidebarTheme

        var headerItem: RenderFlowItem? = nil
        if !cardInSidebar {
            let builder = RenderHeaderBuilder(ctx: context(theme: mainTheme, width: headerWidth),
                                              personal: resume.personal,
                                              photo: photo,
                                              bleedLeft: fullWidthHeader ? 0 : bleedLeft,
                                              bleedRight: fullWidthHeader ? page.width : bleedRight)
            headerItem = builder.build(headerKind)
        }

        // Column content.
        let mainBuilder = RenderSectionBuilder(ctx: context(theme: mainTheme, width: mainWidth), template: template)
        var mainItems: [RenderFlowItem] = []
        for section in mainSections {
            mainItems.append(contentsOf: mainBuilder.sectionItems(section))
        }

        var sideItems: [RenderFlowItem] = []
        if kind != .singleColumn {
            let sideContext: RenderContext = context(theme: sideTheme, width: sideWidth)
            let sideBuilder = RenderSectionBuilder(ctx: sideContext, template: template)
            if cardInSidebar {
                let cardBuilder = RenderHeaderBuilder(ctx: sideContext,
                                                      personal: resume.personal,
                                                      photo: photo,
                                                      bleedLeft: 0,
                                                      bleedRight: 0)
                let contactHeading: RenderFlowItem = sideBuilder.headingItem(label: String(localized: "Contact"), spaceBefore: 0)
                sideItems.append(contentsOf: cardBuilder.buildSidebarCard(contactHeading: contactHeading))
            }
            for section in sideSections {
                sideItems.append(contentsOf: sideBuilder.sectionItems(section))
            }
        }

        // Pagination.
        let bottom: CGFloat = page.height - style.marginBottom
        let headerHeight: CGFloat = headerItem?.height ?? 0
        let headerGap: CGFloat = max(10, style.sectionGap * 0.9)
        let belowHeader: CGFloat = headerItem == nil ? style.marginTop : style.marginTop + headerHeight + headerGap

        let mainColumn = RenderColumn(left: mainLeft, width: mainWidth, bottom: bottom,
                                      firstTop: belowHeader, otherTop: style.marginTop)
        let mainPages: [[RenderPlacement]] = RenderPaginator.paginate(mainItems, column: mainColumn)

        var sidePages: [[RenderPlacement]] = []
        if !sideItems.isEmpty {
            let sideFirstTop: CGFloat = (kind == .headerThenTwoColumn) ? belowHeader : style.marginTop
            let sideColumn = RenderColumn(left: sideLeft, width: sideWidth, bottom: bottom,
                                          firstTop: sideFirstTop, otherTop: style.marginTop)
            sidePages = RenderPaginator.paginate(sideItems, column: sideColumn)
        }
        let pageCount: Int = max(1, mainPages.count, sidePages.count)

        // Drawing.
        let ruleColor: UIColor = mainTheme.rule
        let fillColor: UIColor = style.sidebarFill
        let marginTop: CGFloat = style.marginTop
        let title: String = RenderContent.trimmed(resume.title).isEmpty
            ? RenderContent.trimmed(resume.personal.fullName)
            : RenderContent.trimmed(resume.title)
        let author: String = RenderContent.trimmed(resume.personal.fullName)

        let data: Data = RenderPDFWriter.makePDF(pageSize: page, pageCount: pageCount, title: title, author: author, canvas: canvas) { index in
            RenderDraw.fill(CGRect(origin: CGPoint.zero, size: page), UIColor.white)
            if let band = bandRect {
                RenderDraw.fill(band, fillColor)
            }
            if index == 0, let header = headerItem {
                header.drawBlock(CGPoint(x: headerLeft, y: marginTop), headerLeft)
            }
            var lowest: CGFloat = 0
            if index < mainPages.count {
                for placement in mainPages[index] {
                    placement.item.drawBlock(CGPoint(x: placement.x, y: placement.y), placement.columnLeft)
                    lowest = max(lowest, placement.y + placement.item.height)
                }
            }
            if index < sidePages.count {
                for placement in sidePages[index] {
                    placement.item.drawBlock(CGPoint(x: placement.x, y: placement.y), placement.columnLeft)
                    lowest = max(lowest, placement.y + placement.item.height)
                }
            }
            if let x = dividerX, lowest > 0 {
                let top: CGFloat = index == 0 ? belowHeader : marginTop
                RenderDraw.fill(CGRect(x: x - 0.25, y: top, width: 0.5, height: max(0, lowest - top)), ruleColor)
            }
        }
        return RenderedDocument(pdfData: data, pageCount: pageCount, pageSize: resume.pageSize)
    }
}
