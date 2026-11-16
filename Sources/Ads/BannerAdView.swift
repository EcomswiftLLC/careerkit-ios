import SwiftUI
import UIKit
import GoogleMobileAds

/// Adaptive banner for browse screens only (Home, My Resumes, Templates, Cover Letters, Profile).
///
/// Takes zero height when the unit id is missing, consent does not allow ads, or the ad has not loaded.
/// Place it as its own row with spacing around it. Never put it next to a primary button, and never on
/// the editor, preview or export screens.
@MainActor
struct BannerAdView: View {
    private enum Status { case loading, loaded, failed }

    @ObservedObject private var ads = AdsManager.shared
    @State private var availableWidth: CGFloat = 0
    @State private var status: Status = .loading

    init() {}

    private var unitID: String? { AdsConfiguration.bannerUnitID }

    private var adSize: CGSize {
        guard availableWidth >= 1 else { return .zero }
        return currentOrientationAnchoredAdaptiveBanner(width: availableWidth).size
    }

    var body: some View {
        let size = adSize
        VStack(spacing: 0) {
            if let unitID = unitID, ads.canRequestAds, size.width > 0, size.height > 0 {
                BannerRepresentable(
                    unitID: unitID,
                    width: availableWidth,
                    onLoaded: { status = .loaded },
                    onFailed: { status = .failed }
                )
                .frame(width: size.width, height: status == .loaded ? size.height : 0)
                .clipped()
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Advertisement"))
                .accessibilityHidden(status != .loaded)
            }
        }
        .frame(maxWidth: .infinity)
        .background(widthReader)
    }

    /// Measures the width offered by the parent without taking any space of its own.
    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { updateWidth(proxy.size.width) }
                .onChange(of: proxy.size.width) { _, newValue in updateWidth(newValue) }
        }
    }

    private func updateWidth(_ width: CGFloat) {
        let rounded = width.rounded(.down)
        if abs(rounded - availableWidth) >= 1 { availableWidth = rounded }
    }
}

// MARK: - UIKit bridge

private struct BannerRepresentable: UIViewRepresentable {
    let unitID: String
    let width: CGFloat
    let onLoaded: () -> Void
    let onFailed: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerContainerView {
        let container = BannerContainerView()
        context.coordinator.onLoaded = onLoaded
        context.coordinator.onFailed = onFailed
        context.coordinator.attach(to: container, unitID: unitID)
        context.coordinator.apply(width: width)
        return container
    }

    func updateUIView(_ uiView: BannerContainerView, context: Context) {
        context.coordinator.onLoaded = onLoaded
        context.coordinator.onFailed = onFailed
        context.coordinator.apply(width: width)
    }

    @MainActor
    final class Coordinator: NSObject, BannerViewDelegate {
        var onLoaded: () -> Void = {}
        var onFailed: () -> Void = {}

        private var banner: BannerView?
        private var lastWidth: CGFloat = 0
        private var retryCount = 0
        private var retryTask: Task<Void, Never>?

        func attach(to container: BannerContainerView, unitID: String) {
            let view = BannerView()
            view.adUnitID = unitID
            view.delegate = self
            view.rootViewController = AdsPresenter.topViewController()
            container.install(view)
            banner = view
        }

        func apply(width: CGFloat) {
            guard let banner = banner, width >= 1, abs(width - lastWidth) >= 1 else { return }
            lastWidth = width
            banner.adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
            if banner.rootViewController == nil {
                banner.rootViewController = AdsPresenter.topViewController()
            }
            banner.load(Request())
        }

        // MARK: BannerViewDelegate

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            retryCount = 0
            onLoaded()
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            AdsLog.logger.info("Banner failed to load: \(error.localizedDescription, privacy: .public)")
            onFailed()
            scheduleRetry()
        }

        /// A few slow retries, then give up until the screen is rebuilt. Keeps request volume low.
        private func scheduleRetry() {
            guard retryCount < 3 else { return }
            retryCount += 1
            retryTask?.cancel()
            retryTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled, let self = self, let banner = self.banner else { return }
                guard AdsManager.shared.canRequestAds else { return }
                banner.load(Request())
            }
        }
    }
}

/// Hosts the banner at its natural size and clips it, so SwiftUI can collapse the row to zero height.
final class BannerContainerView: UIView {
    private var banner: BannerView?

    func install(_ view: BannerView) {
        banner = view
        clipsToBounds = true
        addSubview(view)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let banner = banner else { return }
        let size = banner.adSize.size
        banner.frame = CGRect(
            x: (bounds.width - size.width) / 2,
            y: 0,
            width: size.width,
            height: size.height
        )
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, let banner = banner else { return }
        if let owner = nearestViewController() {
            banner.rootViewController = owner
        }
    }

    private func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let controller = next as? UIViewController { return controller }
            responder = next
        }
        return nil
    }
}
