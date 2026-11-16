import SwiftUI

/// A rendered page shown while the first render is still running.
struct EdPageSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    bar(width: 150, height: 14)
                    bar(width: 100, height: 8)
                    Spacer().frame(height: 10)
                    ForEach(0..<9, id: \.self) { index in
                        bar(width: index % 3 == 2 ? 120 : 220, height: 7)
                    }
                }
                .padding(24)
            }
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
            .aspectRatio(0.707, contentMode: .fit)
            .opacity(dim ? 0.7 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { dim = true }
            }
            .accessibilityHidden(true)
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(CK.Palette.stone)
            .frame(width: width, height: height)
    }
}

/// Live preview surface used by every editor: PDF, page controls, subtle "updating" indicator.
struct PreviewPane: View {
    @ObservedObject var renderer: LivePreviewRenderer
    var accessibilityName: String = "Document preview"
    var showsPageControls = true
    var showsZoomControls = true

    @StateObject private var controller = PDFPreviewController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            CK.Palette.stone.ignoresSafeArea(edges: .bottom)
            if let document = renderer.document {
                PDFPreview(data: document.pdfData, controller: controller, accessibilityName: accessibilityName)
            } else {
                EdPageSkeleton()
                    .padding(CK.Space.l)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .overlay(alignment: .topTrailing) { updatingBadge }
        .overlay(alignment: .bottom) {
            if showsPageControls, renderer.document != nil { controls }
        }
    }

    @ViewBuilder
    private var updatingBadge: some View {
        if renderer.isRendering {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Updating")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(.regularMaterial, in: Capsule())
            .padding(10)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Updating preview")
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            controlButton("chevron.left", label: "Previous page", enabled: controller.canGoPrevious) { controller.goToPrevious() }
            Text("Page \(controller.currentPage) of \(max(controller.pageCount, 1))")
                .font(CK.Font.caption.monospacedDigit())
                .foregroundStyle(CK.Palette.ink)
                .padding(.horizontal, 6)
                .accessibilityLabel("Page \(controller.currentPage) of \(max(controller.pageCount, 1))")
            controlButton("chevron.right", label: "Next page", enabled: controller.canGoNext) { controller.goToNext() }
            if showsZoomControls {
                Rectangle().fill(CK.Palette.hairline).frame(width: 1, height: 22).padding(.horizontal, 2)
                controlButton("minus.magnifyingglass", label: "Zoom out", enabled: true) { controller.zoom(by: 0.8) }
                controlButton("plus.magnifyingglass", label: "Zoom in", enabled: true) { controller.zoom(by: 1.25) }
                controlButton("arrow.left.and.right", label: "Fit to width", enabled: !controller.isFitted) { controller.fitToWidth() }
            }
        }
        .padding(.horizontal, 4)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
        .padding(.bottom, 12)
    }

    private func controlButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? CK.Palette.ink : CK.Palette.graphite.opacity(0.45))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
