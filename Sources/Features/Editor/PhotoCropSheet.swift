import SwiftUI
import UIKit

/// Pure crop arithmetic, kept out of the view so it can be tested.
enum PhotoCropMath {
    static let zoomRange: ClosedRange<CGFloat> = 1...4

    /// Scale that makes the image just cover a square frame of side `frame`.
    static func coverScale(imageSize: CGSize, frame: CGFloat) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0, frame > 0 else { return 1 }
        return max(frame / imageSize.width, frame / imageSize.height)
    }

    /// Keeps the image covering the frame: the offset can move it at most to its edges.
    static func clampedOffset(_ offset: CGSize, imageSize: CGSize, frame: CGFloat, zoom: CGFloat) -> CGSize {
        let scale: CGFloat = coverScale(imageSize: imageSize, frame: frame) * zoom
        let maxX: CGFloat = max(0, (imageSize.width * scale - frame) / 2)
        let maxY: CGFloat = max(0, (imageSize.height * scale - frame) / 2)
        return CGSize(width: min(max(offset.width, -maxX), maxX), height: min(max(offset.height, -maxY), maxY))
    }

    /// The square of the image (in image points) that is visible in the frame.
    static func cropRect(imageSize: CGSize, frame: CGFloat, zoom: CGFloat, offset: CGSize) -> CGRect {
        let scale: CGFloat = coverScale(imageSize: imageSize, frame: frame) * zoom
        guard scale > 0 else { return CGRect(origin: .zero, size: imageSize) }
        let safe: CGSize = clampedOffset(offset, imageSize: imageSize, frame: frame, zoom: zoom)
        let side: CGFloat = frame / scale
        let x: CGFloat = (imageSize.width * scale - frame) / 2 / scale - safe.width / scale
        let y: CGFloat = (imageSize.height * scale - frame) / 2 / scale - safe.height / scale
        return CGRect(x: max(0, x), y: max(0, y), width: min(side, imageSize.width), height: min(side, imageSize.height))
    }

    /// Draws the crop into a square image of at most `maxPixels` on a side.
    static func render(_ image: UIImage, crop: CGRect, maxPixels: CGFloat = 800) -> UIImage {
        let side: CGFloat = max(1, min(maxPixels, crop.width * image.scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let k: CGFloat = crop.width > 0 ? side / crop.width : 1
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            image.draw(in: CGRect(x: -crop.minX * k, y: -crop.minY * k,
                                  width: image.size.width * k, height: image.size.height * k))
        }
    }
}

/// Square crop with drag and pinch, plus buttons for zoom and position so it also works with VoiceOver,
/// Switch Control and without gestures. A circle overlay previews a round photo.
struct PhotoCropSheet: View {
    let image: UIImage
    var initialCircle: Bool = true
    let onDone: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var showCircle: Bool = true
    @State private var frameSide: CGFloat = 280

    private let step: CGFloat = 24

    var body: some View {
        NavigationStack {
            VStack(spacing: CK.Space.l) {
                Text("Drag to move and pinch to zoom, or use the buttons below.")
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                cropArea
                Toggle(isOn: $showCircle) {
                    Text("Preview as a circle").font(CK.Font.body).foregroundStyle(CK.Palette.ink)
                }
                .tint(CK.Palette.forest)
                .frame(minHeight: 44)
                controls
                Spacer(minLength: 0)
            }
            .padding(CK.Space.m)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .background(CK.Palette.ivory.ignoresSafeArea())
            .navigationTitle("Crop photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { finish() }.font(CK.Font.label)
                }
            }
            .onAppear { showCircle = initialCircle }
        }
    }

    // MARK: Crop area

    private var cropArea: some View {
        GeometryReader { proxy in
            let side: CGFloat = min(proxy.size.width, 320)
            let scale: CGFloat = PhotoCropMath.coverScale(imageSize: image.size, frame: side) * zoom
            let percent: Int = Int((zoom * 100).rounded())
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: image.size.width * scale, height: image.size.height * scale)
                    .offset(offset)
                    .frame(width: side, height: side)
                    .clipped()
                if showCircle {
                    CropCircleMask()
                        .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
                        .frame(width: side, height: side)
                        .allowsHitTesting(false)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                        .frame(width: side, height: side)
                        .allowsHitTesting(false)
                }
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
                    .frame(width: side, height: side)
                    .allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(dragGesture(side: side).simultaneously(with: zoomGesture(side: side)))
            .frame(maxWidth: .infinity)
            .onAppear { frameSide = side }
            .onChange(of: side) { _, newSide in frameSide = newSide }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Photo crop area"))
            .accessibilityValue(Text("Zoom \(percent) percent"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: changeZoom(by: 0.25)
                case .decrement: changeZoom(by: -0.25)
                @unknown default: break
                }
            }
        }
        .frame(height: 320)
    }

    private func dragGesture(side: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(width: baseOffset.width + value.translation.width,
                                      height: baseOffset.height + value.translation.height)
                offset = PhotoCropMath.clampedOffset(proposed, imageSize: image.size, frame: side, zoom: zoom)
            }
            .onEnded { _ in
                baseOffset = offset
            }
    }

    private func zoomGesture(side: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed: CGFloat = baseZoom * value
                zoom = min(max(proposed, PhotoCropMath.zoomRange.lowerBound), PhotoCropMath.zoomRange.upperBound)
                offset = PhotoCropMath.clampedOffset(offset, imageSize: image.size, frame: side, zoom: zoom)
            }
            .onEnded { _ in
                baseZoom = zoom
                baseOffset = offset
            }
    }

    // MARK: Buttons

    private var controls: some View {
        VStack(spacing: CK.Space.s) {
            HStack(spacing: CK.Space.m) {
                iconButton("minus.magnifyingglass", label: String(localized: "Zoom out")) { changeZoom(by: -0.25) }
                iconButton("plus.magnifyingglass", label: String(localized: "Zoom in")) { changeZoom(by: 0.25) }
                Spacer(minLength: CK.Space.s)
                Button {
                    zoom = 1
                    baseZoom = 1
                    offset = .zero
                    baseOffset = .zero
                } label: {
                    Text("Reset")
                        .font(CK.Font.label)
                        .foregroundStyle(CK.Palette.forest)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: CK.Space.m) {
                iconButton("arrow.left", label: String(localized: "Move photo left")) { move(dx: -step, dy: 0) }
                iconButton("arrow.up", label: String(localized: "Move photo up")) { move(dx: 0, dy: -step) }
                iconButton("arrow.down", label: String(localized: "Move photo down")) { move(dx: 0, dy: step) }
                iconButton("arrow.right", label: String(localized: "Move photo right")) { move(dx: step, dy: 0) }
                Spacer(minLength: 0)
            }
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CK.Palette.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(CK.Palette.stone))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    // MARK: Actions

    private func changeZoom(by delta: CGFloat) {
        zoom = min(max(zoom + delta, PhotoCropMath.zoomRange.lowerBound), PhotoCropMath.zoomRange.upperBound)
        baseZoom = zoom
        offset = PhotoCropMath.clampedOffset(offset, imageSize: image.size, frame: frameSide, zoom: zoom)
        baseOffset = offset
    }

    /// Moving the photo right shows more of its left side, like dragging it.
    private func move(dx: CGFloat, dy: CGFloat) {
        let proposed = CGSize(width: offset.width + dx, height: offset.height + dy)
        offset = PhotoCropMath.clampedOffset(proposed, imageSize: image.size, frame: frameSide, zoom: zoom)
        baseOffset = offset
    }

    private func finish() {
        let crop: CGRect = PhotoCropMath.cropRect(imageSize: image.size, frame: frameSide, zoom: zoom, offset: offset)
        let result: UIImage = PhotoCropMath.render(image, crop: crop)
        onDone(result)
        dismiss()
    }
}

/// A square with a circular hole, filled with even-odd so only the corners are dimmed.
private struct CropCircleMask: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addEllipse(in: rect)
        return path
    }
}
