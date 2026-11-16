import SwiftUI
import PDFKit
import UIKit

// MARK: - Controller

/// Bridges the UIKit PDFView to SwiftUI controls (page indicator, previous/next, fit to width).
@MainActor
final class PDFPreviewController: ObservableObject {
    @Published private(set) var currentPage = 1
    @Published private(set) var pageCount = 0
    @Published private(set) var isFitted = true

    fileprivate weak var pdfView: PDFView?

    var canGoPrevious: Bool { currentPage > 1 }
    var canGoNext: Bool { currentPage < pageCount }

    func goToPrevious() { pdfView?.goToPreviousPage(nil); refresh() }
    func goToNext() { pdfView?.goToNextPage(nil); refresh() }

    func fitToWidth() {
        guard let view = pdfView else { return }
        view.autoScales = true
        refresh()
    }

    func zoom(by factor: CGFloat) {
        guard let view = pdfView else { return }
        view.autoScales = false
        let next = view.scaleFactor * factor
        view.scaleFactor = min(max(next, view.minScaleFactor), view.maxScaleFactor)
        refresh()
    }

    func refresh() {
        guard let view = pdfView, let document = view.document else {
            currentPage = 1
            pageCount = 0
            return
        }
        pageCount = document.pageCount
        if let page = view.currentPage {
            currentPage = document.index(for: page) + 1
        }
        isFitted = view.autoScales
    }
}

// MARK: - UIKit view

/// PDFView that keeps sensible zoom limits relative to the fit-to-width scale.
final class CKPDFView: PDFView {
    override func layoutSubviews() {
        super.layoutSubviews()
        let fit = scaleFactorForSizeToFit
        if fit > 0 {
            minScaleFactor = fit * 0.8
            maxScaleFactor = fit * 4
        }
    }
}

// MARK: - SwiftUI wrapper

/// Reusable PDF viewer. Pinch zoom, double tap to zoom, text selection and VoiceOver come from PDFKit.
struct PDFPreview: UIViewRepresentable {
    let data: Data
    var controller: PDFPreviewController?
    var accessibilityName: String = String(localized: "Document preview")

    init(data: Data, controller: PDFPreviewController? = nil, accessibilityName: String = String(localized: "Document preview")) {
        self.data = data
        self.controller = controller
        self.accessibilityName = accessibilityName
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> CKPDFView {
        let view = CKPDFView()
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.displaysPageBreaks = true
        view.pageBreakMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        view.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: 0x262A27) : UIColor(hex: 0xECE7DC)
        }
        view.document = PDFDocument(data: data)
        view.accessibilityLabel = accessibilityName

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = context.coordinator
        view.addGestureRecognizer(doubleTap)

        context.coordinator.lastData = data
        context.coordinator.controller = controller
        context.coordinator.observe(view)
        controller?.pdfView = view
        controller?.refresh()
        return view
    }

    func updateUIView(_ view: CKPDFView, context: Context) {
        context.coordinator.controller = controller
        controller?.pdfView = view
        view.accessibilityLabel = accessibilityName
        guard context.coordinator.lastData != data else { return }
        context.coordinator.lastData = data

        // Keep the reader's place and zoom when a fresh render arrives.
        let pageIndex: Int = {
            guard let page = view.currentPage, let document = view.document else { return 0 }
            return document.index(for: page)
        }()
        let wasFitted = view.autoScales
        let scale = view.scaleFactor

        view.document = PDFDocument(data: data)

        if let document = view.document, pageIndex > 0, pageIndex < document.pageCount, let page = document.page(at: pageIndex) {
            view.go(to: page)
        }
        if !wasFitted { view.scaleFactor = scale }
        controller?.refresh()
    }

    static func dismantleUIView(_ view: CKPDFView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var lastData: Data?
        weak var controller: PDFPreviewController?
        private var tokens: [NSObjectProtocol] = []

        func observe(_ view: PDFView) {
            stopObserving()
            let center = NotificationCenter.default
            let names: [Notification.Name] = [.PDFViewPageChanged, .PDFViewScaleChanged, .PDFViewDocumentChanged]
            for name in names {
                let token = center.addObserver(forName: name, object: view, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.controller?.refresh() }
                }
                tokens.append(token)
            }
        }

        func stopObserving() {
            for token in tokens { NotificationCenter.default.removeObserver(token) }
            tokens.removeAll()
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? PDFView else { return }
            let fit = view.scaleFactorForSizeToFit
            if fit > 0, view.scaleFactor > fit * 1.15 {
                view.autoScales = true
            } else if fit > 0 {
                view.autoScales = false
                view.scaleFactor = min(fit * 2, view.maxScaleFactor)
            }
            controller?.refresh()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
